"""
test_20_images.py — End-to-end accuracy harness mirroring DogQuest's app pipeline.

Tests the deployed TFLite model + synonym clustering + preferred-name substitution
on 20 stratified random images from supplemental_dogs/ (5 common, 5 uncommon,
5 rare, 5 legendary).

Mirrors the app's pipeline exactly:
  - 300x300 uint8 input (EfficientNetV2-S v6, post-calibration-fix)
  - 3-variant TTA: tight center / flipped / zoomed-out (1.15x)
  - EXIF orientation bake
  - Entropy gate (>0.97 rejected)
  - Confidence-gap gate (top<0.05 AND gap<0.01 rejected)
  - _minConfidence=0.03 floor
  - Synonym clustering with preferred-name substitution (Option B, 2026-04-25)

Output: Markdown report at docs/session_2026-04-25/dogquest_20image_test.md
"""
import os
import sys
import json
import random
import math
from pathlib import Path

os.environ["TF_CPP_MIN_LOG_LEVEL"] = "3"

import numpy as np
from PIL import Image, ImageOps
import tensorflow as tf

# ─────────────────────────────────────────────────────────────────────────────
# Configuration — keep in sync with lib/services/tflite_identification_service.dart
# ─────────────────────────────────────────────────────────────────────────────
ROOT = Path(__file__).resolve().parent.parent
MODEL_PATH = ROOT / "assets/dog_model.tflite"
LABELS_PATH = ROOT / "assets/dog_labels.txt"
DOGS_JSON_PATH = ROOT / "assets/dogs.json"
SUPPLEMENTAL_DIR = ROOT / "supplemental_dogs"

INPUT_SIZE = 300
TOP_K = 3
MIN_CONFIDENCE = 0.03
ENTROPY_REJECT_THRESHOLD = 0.97

# Folders flagged for label noise — exclude from sampling.
FLAGGED_FOLDERS = {"siberian_husky", "belgian_laekenois", "american_bulldog", "combai"}

# Synonym clusters — mirror dogQuestSynonymClusters in the Dart service.
# First element is the preferred display name.
SYNONYM_CLUSTERS = [
    ["Cavalier King Charles Spaniel", "Blenheim Spaniel"],
    ["Yorkshire Terrier", "Biewer Terrier"],
    ["Belgian Sheepdog", "Belgian Tervuren"],
    ["Siberian Husky", "Alaskan Husky"],
    # Added 2026-04-25 to mirror lib/services/tflite_identification_service.dart
    # after empirical 20-image test surfaced these clusters:
    ["Poodle", "Standard Poodle", "Miniature Poodle", "Toy Poodle"],
    ["Australian Kelpie", "Working Kelpie"],
]

RANDOM_SEED = 42  # Deterministic so re-runs compare like-for-like.


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────
def cluster_key(dog_name: str) -> str:
    """Mirror of dogQuestClusterKey: returns preferred name, or self."""
    for cluster in SYNONYM_CLUSTERS:
        if dog_name in cluster:
            return cluster[0]
    return dog_name


def folder_to_breed(folder: str) -> str:
    """snake_case folder name → Title Case breed name (best-effort matching)."""
    return " ".join(w.capitalize() for w in folder.split("_"))


def bake_exif(img: Image.Image) -> Image.Image:
    """Apply EXIF orientation, mirroring img.bakeOrientation in Dart."""
    return ImageOps.exif_transpose(img)


def build_3variant_tta(img: Image.Image) -> list:
    """Return 3 uint8 numpy arrays of shape (300, 300, 3) — mirrors _preprocessImage."""
    img = bake_exif(img).convert("RGB")
    w, h = img.size
    short_edge = min(w, h)

    # Variant 1: tight center crop — scale short edge to 300, center crop.
    tight_scale = INPUT_SIZE / short_edge
    tw, th = round(w * tight_scale), round(h * tight_scale)
    tight = img.resize((tw, th), Image.BILINEAR)
    x0 = (tw - INPUT_SIZE) // 2
    y0 = (th - INPUT_SIZE) // 2
    tight_crop = tight.crop((x0, y0, x0 + INPUT_SIZE, y0 + INPUT_SIZE))

    # Variant 2: horizontal flip of variant 1.
    tight_flip = tight_crop.transpose(Image.FLIP_LEFT_RIGHT)

    # Variant 3: zoomed-out (1.15x).
    loose_target = round(INPUT_SIZE * 1.15)
    loose_scale = loose_target / short_edge
    lw, lh = round(w * loose_scale), round(h * loose_scale)
    loose = img.resize((lw, lh), Image.BILINEAR)
    lx0 = (lw - INPUT_SIZE) // 2
    ly0 = (lh - INPUT_SIZE) // 2
    loose_crop = loose.crop((lx0, ly0, lx0 + INPUT_SIZE, ly0 + INPUT_SIZE))

    return [
        np.array(tight_crop, dtype=np.uint8),
        np.array(tight_flip, dtype=np.uint8),
        np.array(loose_crop, dtype=np.uint8),
    ]


def infer_avg(interpreter, in_idx, out_idx, variants) -> np.ndarray:
    """Run each variant through TFLite, average the divided-by-255 probs."""
    n_classes = interpreter.get_output_details()[0]["shape"][-1]
    avg = np.zeros(n_classes, dtype=np.float64)
    for v in variants:
        x = np.expand_dims(v, axis=0).astype(np.uint8)
        interpreter.set_tensor(in_idx, x)
        interpreter.invoke()
        raw = interpreter.get_tensor(out_idx)[0].astype(np.float64) / 255.0
        avg += raw
    avg /= len(variants)
    return avg


def build_results(probs: np.ndarray, labels: list, dog_index: dict) -> dict:
    """
    Mirror of _buildResults: entropy/gap gates, then top-K with synonym
    clustering + preferred-name substitution.
    Returns a dict with the rejection reason or the displayed alternatives.
    """
    n = len(probs)
    entropy = -float(np.sum(probs[probs > 0] * np.log(probs[probs > 0])))
    max_entropy = math.log(n)
    norm_entropy = entropy / max_entropy if max_entropy > 0 else 0.0

    order = np.argsort(-probs)
    top1 = float(probs[order[0]])
    top2 = float(probs[order[1]]) if n > 1 else 0.0
    gap = top1 - top2

    if norm_entropy > ENTROPY_REJECT_THRESHOLD:
        return {"rejected": "entropy", "norm_entropy": norm_entropy,
                "top1": top1, "gap": gap}
    if top1 < 0.05 and gap < 0.01:
        return {"rejected": "gap", "norm_entropy": norm_entropy,
                "top1": top1, "gap": gap}

    raw_topk = []
    for idx in order[:5]:
        raw_topk.append((labels[idx], float(probs[idx])))

    # Cluster-aware top-K with preferred-name substitution.
    accepted = []
    seen_clusters = set()
    notes = []
    for idx in order[: TOP_K * 3]:
        prob = float(probs[idx])
        if prob < MIN_CONFIDENCE:
            break
        label = labels[idx]
        # Direct dogs.json lookup — labels are already canonical Dog.names.
        dog = dog_index.get(label)
        if dog is None:
            continue
        ckey = cluster_key(label)
        if ckey in seen_clusters:
            if ckey != label:
                notes.append(f'dropped "{label}" {prob:.1%} (synonym of "{ckey}")')
            continue
        seen_clusters.add(ckey)
        if ckey != label:
            notes.append(f'substituted: model said "{label}" {prob:.1%} → displayed as "{ckey}"')
        displayed = dog_index.get(ckey, dog)
        accepted.append({
            "displayed_name": ckey,
            "displayed_rarity": displayed.get("rarity", "common"),
            "model_label": label,
            "confidence": prob,
        })
        if len(accepted) >= TOP_K:
            break

    return {
        "rejected": None,
        "norm_entropy": norm_entropy,
        "top1": top1,
        "gap": gap,
        "raw_topk": raw_topk,
        "accepted": accepted,
        "notes": notes,
    }


def random_sample(dogs_json: list, supplemental: Path, n=20):
    """Pick `n` (folder, breed, rarity, image) tuples uniformly at random across
    all non-flagged folders that map to a Dog in dogs.json."""
    rng = random.Random(RANDOM_SEED + 1)  # different seed than stratified
    by_name = {d["name"]: d for d in dogs_json}
    pool = []
    for folder in sorted(p.name for p in supplemental.iterdir() if p.is_dir()):
        if folder in FLAGGED_FOLDERS:
            continue
        breed_guess = folder_to_breed(folder)
        match = None
        for candidate in [breed_guess, breed_guess.replace(" Dog", ""), "American " + breed_guess]:
            if candidate in by_name:
                match = candidate
                break
        if match is None:
            for name in by_name:
                if name.lower() == breed_guess.lower():
                    match = name
                    break
        if match is None:
            continue
        imgs = sorted(p for p in (supplemental / folder).iterdir()
                      if p.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"})
        for img in imgs:
            pool.append({"folder": folder, "breed": match,
                         "rarity": by_name[match].get("rarity", "common").lower(),
                         "image": img})
    print(f"Random pool size: {len(pool)} images across {len(set(p['breed'] for p in pool))} breeds")
    return rng.sample(pool, min(n, len(pool)))


def stratified_sample(dogs_json: list, supplemental: Path, n_per_bucket=5):
    """
    Pick `n_per_bucket` (folder, breed, rarity) tuples per rarity bucket.
    Folders must (a) exist in supplemental_dogs/, (b) not be in FLAGGED_FOLDERS,
    (c) map to a Dog in dogs.json, (d) contain at least 1 image.
    """
    rng = random.Random(RANDOM_SEED)
    by_name = {d["name"]: d for d in dogs_json}

    candidates = {"common": [], "uncommon": [], "rare": [], "legendary": []}
    for folder in sorted(p.name for p in supplemental.iterdir() if p.is_dir()):
        if folder in FLAGGED_FOLDERS:
            continue
        breed_guess = folder_to_breed(folder)
        # Try exact + a couple of common transforms.
        match = None
        for candidate in [
            breed_guess,
            breed_guess.replace(" Dog", ""),
            "American " + breed_guess,
        ]:
            if candidate in by_name:
                match = candidate
                break
        if match is None:
            # Fallback: case-insensitive match.
            for name, d in by_name.items():
                if name.lower() == breed_guess.lower():
                    match = name
                    break
        if match is None:
            continue
        rarity = by_name[match].get("rarity", "common").lower()
        if rarity not in candidates:
            continue
        # Pick a random image inside this folder.
        imgs = sorted(
            p for p in (supplemental / folder).iterdir()
            if p.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}
        )
        if not imgs:
            continue
        img = rng.choice(imgs)
        candidates[rarity].append({"folder": folder, "breed": match, "image": img})

    sample = []
    for bucket, items in candidates.items():
        if len(items) < n_per_bucket:
            print(f"WARN: only {len(items)} candidates for rarity={bucket}; using all")
            picks = items
        else:
            picks = rng.sample(items, n_per_bucket)
        sample.extend({"rarity": bucket, **p} for p in picks)
    return sample


# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────
def main():
    interpreter = tf.lite.Interpreter(model_path=str(MODEL_PATH))
    interpreter.allocate_tensors()
    in_idx = interpreter.get_input_details()[0]["index"]
    out_idx = interpreter.get_output_details()[0]["index"]

    labels = [ln.strip() for ln in LABELS_PATH.read_text(encoding="utf-8").splitlines() if ln.strip()]
    dogs_json = json.loads(DOGS_JSON_PATH.read_text(encoding="utf-8"))
    dog_index = {d["name"]: d for d in dogs_json}

    print(f"Model: {MODEL_PATH.name}, {len(labels)} labels, {len(dogs_json)} dogs.")
    mode = "random" if "--random" in sys.argv else "stratified"
    print(f"Sampling mode: {mode}")

    if mode == "random":
        sample = random_sample(dogs_json, SUPPLEMENTAL_DIR, n=20)
    else:
        sample = stratified_sample(dogs_json, SUPPLEMENTAL_DIR, n_per_bucket=5)
    print(f"Picked {len(sample)} test images.\n")

    rows = []
    correct_top1 = 0
    correct_top3 = 0
    rejected = 0
    cluster_hits = 0
    for i, item in enumerate(sample, 1):
        truth = item["breed"]
        truth_cluster = cluster_key(truth)
        try:
            img = Image.open(item["image"])
            variants = build_3variant_tta(img)
            probs = infer_avg(interpreter, in_idx, out_idx, variants)
            res = build_results(probs, labels, dog_index)
        except Exception as e:
            print(f"[{i:2}] ERROR on {item['image'].name}: {e}")
            rows.append({"item": item, "truth": truth, "error": str(e)})
            continue

        if res["rejected"]:
            rejected += 1
            verdict = f"REJECTED ({res['rejected']})"
        else:
            displayed_top1 = res["accepted"][0]["displayed_name"] if res["accepted"] else "(none)"
            displayed_clusters = [a["displayed_name"] for a in res["accepted"]]
            # Top-1 correctness: displayed top-1 matches truth's cluster (so a correct
            # "Cavalier" preferred-name substitution counts even if model said Blenheim).
            top1_hit = (displayed_top1 == truth_cluster)
            top3_hit = (truth_cluster in displayed_clusters)
            if top1_hit:
                correct_top1 += 1
            if top3_hit:
                correct_top3 += 1
            if any(n.startswith("substituted") for n in res["notes"]):
                cluster_hits += 1
            verdict = (
                f"top1={'✓' if top1_hit else '✗'} "
                f"top3={'✓' if top3_hit else '✗'} "
                f"→ {displayed_top1} ({res['accepted'][0]['confidence']:.1%})"
                if res["accepted"] else "no displayable results"
            )
        rows.append({"item": item, "truth": truth, "result": res, "verdict": verdict})
        print(f"[{i:2}] {item['rarity']:9} truth='{truth}' file={item['image'].name} | {verdict}")

    n = len([r for r in rows if "error" not in r])
    print(f"\nSummary: top-1={correct_top1}/{n} ({correct_top1/n:.0%}), "
          f"top-3={correct_top3}/{n} ({correct_top3/n:.0%}), "
          f"rejected={rejected}, cluster-substitutions={cluster_hits}")

    # ── Markdown report ──────────────────────────────────────────────────────
    suffix = "_random" if mode == "random" else "_stratified"
    out_path = ROOT / f"docs/session_2026-04-25/dogquest_20image_test{suffix}.md"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as f:
        f.write("# DogQuest — 20-image accuracy harness\n\n")
        f.write(f"**Date:** 2026-04-25  \n")
        f.write(f"**Model:** `assets/dog_model.tflite` (EfficientNetV2-S v6, post-calibration-fix, 300×300 uint8)  \n")
        f.write(f"**Pipeline:** 3-variant TTA + entropy/gap gates + synonym clustering w/ preferred-name (Option B)  \n")
        f.write(f"**Random seed:** {RANDOM_SEED} (re-runs are reproducible)  \n")
        f.write(f"**Sample:** {len(sample)} images, stratified 5 per rarity, drawn from `supplemental_dogs/` excluding {sorted(FLAGGED_FOLDERS)}  \n\n")
        f.write("## Headline\n\n")
        f.write(f"- **Top-1 (displayed):** {correct_top1}/{n} ({correct_top1/n:.0%})\n")
        f.write(f"- **Top-3 (displayed contains truth-cluster):** {correct_top3}/{n} ({correct_top3/n:.0%})\n")
        f.write(f"- **Rejected (entropy/gap):** {rejected}\n")
        f.write(f"- **Synonym substitutions fired:** {cluster_hits}\n\n")
        f.write("Top-1 / top-3 both compare against the *cluster* of the truth breed, so a "
                "Blenheim image whose model output is Blenheim-then-Cavalier scores top-1 ✓ "
                "(displayed: Cavalier King Charles Spaniel — preferred). This matches user-perceived behavior.\n\n")
        f.write("## Per-image\n\n")
        # Group by rarity.
        for bucket in ["common", "uncommon", "rare", "legendary"]:
            f.write(f"### {bucket.capitalize()}\n\n")
            for r in rows:
                if r["item"]["rarity"] != bucket:
                    continue
                f.write(f"**{r['truth']}** — `{r['item']['image'].name}`  \n")
                if "error" in r:
                    f.write(f"- ❌ ERROR: `{r['error']}`\n\n")
                    continue
                res = r["result"]
                if res["rejected"]:
                    f.write(f"- 🚫 Rejected ({res['rejected']}); norm_entropy={res['norm_entropy']:.3f}, top1={res['top1']:.1%}, gap={res['gap']:.1%}\n\n")
                    cont