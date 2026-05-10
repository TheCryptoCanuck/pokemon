#!/usr/bin/env python3
"""
DogQuest — Audit & auto-clean supplemental training images.

Runs the v6 TFLite model against every image in supplemental_dogs/.
Flags images where the model confidently predicts a DIFFERENT breed,
and optionally auto-moves them to supplemental_dogs_removed/.

Key insight: even at 49% overall accuracy, when the model is 60%+
confident an image is a DIFFERENT breed, it's almost always right —
those are the clearly mislabeled/noisy images hurting training the most.

Modes:
  --report     Audit only, generate reports (default)
  --clean      Auto-move flagged images (with safety floor)
  --aggressive Lower thresholds for second-pass cleaning

Outputs:
  audit_report.txt      Text summary per breed
  audit_flagged.json    Machine-readable list of flagged images
  audit_gallery.html    Visual gallery for manual review
  audit_breed_stats.json Per-breed accuracy stats

Usage:
    python3 audit_and_clean.py                    # report only
    python3 audit_and_clean.py --clean             # auto-remove obvious junk
    python3 audit_and_clean.py --clean --aggressive # tighter thresholds (use after retrain)
    python3 audit_and_clean.py --min-keep 40       # lower safety floor for small breeds

Safety:
  - Images are MOVED (not deleted) to supplemental_dogs_removed/{breed}/
  - MIN_KEEP ensures at least N images survive per breed (default: 40)
  - Corrupt/unreadable images are always removed (no safety floor)
"""

import os
import sys
import json
import time
import shutil
import argparse
import numpy as np
from pathlib import Path
from collections import OrderedDict

try:
    from PIL import Image
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "Pillow", "-q"])
    from PIL import Image

import tensorflow as tf

# ── Config ────────────────────────────────────────────────────────────────
MODEL_PATH = "assets/dog_model.tflite"
LABELS_PATH = "assets/dog_labels.txt"
SUPPLEMENTAL_DIR = "supplemental_dogs"
REMOVED_DIR = "supplemental_dogs_removed"

# Default thresholds (conservative — safe for a 49% accuracy model)
DEFAULT_WRONG_BREED_THRESHOLD = 0.55   # model says different breed at 55%+
DEFAULT_OWN_LOW_THRESHOLD = 0.02       # own breed confidence below 2%
DEFAULT_MIN_ENTROPY = 1.0              # blank/corrupt image detection

# Aggressive thresholds (use after model is retrained to 65%+)
AGGRESSIVE_WRONG_BREED_THRESHOLD = 0.40
AGGRESSIVE_OWN_LOW_THRESHOLD = 0.05

DEFAULT_MIN_KEEP = 40  # never drop below this many images per breed


# ── Model loading ─────────────────────────────────────────────────────────

def load_model_and_labels():
    interpreter = tf.lite.Interpreter(model_path=MODEL_PATH)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    with open(LABELS_PATH, "r") as f:
        labels = [line.strip() for line in f if line.strip()]

    input_size = input_details[0]['shape'][1]

    print(f"Model: {MODEL_PATH}")
    print(f"  Input:  {input_details[0]['shape']} dtype={input_details[0]['dtype']}")
    print(f"  Output: {output_details[0]['shape']} dtype={output_details[0]['dtype']}")
    print(f"  Labels: {len(labels)}")
    print(f"  Input size: {input_size}x{input_size}")

    return interpreter, input_details, output_details, labels, input_size


def normalize(name):
    """Normalize breed name for fuzzy matching."""
    return name.lower().replace("_", " ").replace("-", " ").strip()


def find_label_index(folder_name, labels):
    """Find the label index that best matches a folder name."""
    norm_folder = normalize(folder_name)

    # Exact match
    for i, label in enumerate(labels):
        if normalize(label) == norm_folder:
            return i

    # Contains match
    for i, label in enumerate(labels):
        nl = normalize(label)
        if norm_folder in nl or nl in norm_folder:
            return i

    # Word overlap match
    folder_words = set(norm_folder.split())
    best_idx, best_overlap = -1, 0
    for i, label in enumerate(labels):
        overlap = len(folder_words & set(normalize(label).split()))
        if overlap > best_overlap:
            best_overlap = overlap
            best_idx = i

    return best_idx if best_overlap > 0 else -1


# ── Image processing ──────────────────────────────────────────────────────

def preprocess_image(image_path, input_size):
    """Load, center-crop, resize to model input."""
    try:
        img = Image.open(image_path).convert("RGB")
    except Exception as e:
        return None, str(e)

    w, h = img.size
    crop_size = min(w, h)
    left = (w - crop_size) // 2
    top = (h - crop_size) // 2
    img = img.crop((left, top, left + crop_size, top + crop_size))
    img = img.resize((input_size, input_size), Image.BILINEAR)
    return np.array(img, dtype=np.uint8), None


def compute_entropy(arr):
    hist, _ = np.histogram(arr.flatten(), bins=256, range=(0, 256))
    hist = hist / hist.sum()
    hist = hist[hist > 0]
    return -np.sum(hist * np.log2(hist))


def run_inference(interpreter, input_details, output_details, image_arr):
    input_data = np.expand_dims(image_arr, axis=0)
    if input_details[0]['dtype'] == np.uint8:
        input_data = input_data.astype(np.uint8)
    else:
        input_data = input_data.astype(np.float32) / 255.0

    interpreter.set_tensor(input_details[0]['index'], input_data)
    interpreter.invoke()

    output = interpreter.get_tensor(output_details[0]['index'])[0]
    if output_details[0]['dtype'] == np.uint8:
        probs = output.astype(np.float64) / 255.0
    else:
        probs = output.astype(np.float64)

    if np.any(probs < 0):
        probs = probs - probs.max()
        probs = np.exp(probs)
        probs /= probs.sum()

    return probs


# ── Main audit loop ───────────────────────────────────────────────────────

def audit_breed(folder, interpreter, input_details, output_details, labels,
                input_size, own_label_idx, thresholds):
    """Audit all images in a breed folder. Returns list of result dicts."""
    wrong_thresh, own_low_thresh, min_entropy = thresholds

    images = sorted([
        f for f in folder.iterdir()
        if f.suffix.lower() in ('.jpg', '.jpeg', '.png', '.webp')
    ])

    results = []
    for img_path in images:
        arr, err = preprocess_image(str(img_path), input_size)

        if arr is None:
            results.append({
                "breed": folder.name,
                "file": str(img_path),
                "filename": img_path.name,
                "flagged": True,
                "flag_reason": f"CORRUPT: {err}",
                "flag_type": "corrupt",
                "top1_label": "",
                "top1_conf": 0.0,
                "own_confidence": 0.0,
                "entropy": 0.0,
            })
            continue

        entropy = compute_entropy(arr)
        probs = run_inference(interpreter, input_details, output_details, arr)

        top1_idx = int(np.argmax(probs))
        top1_conf = float(probs[top1_idx])
        top1_label = labels[top1_idx] if top1_idx < len(labels) else "?"
        own_conf = float(probs[own_label_idx]) if own_label_idx >= 0 else 0.0

        flagged = False
        flag_reason = ""
        flag_type = ""

        if entropy < min_entropy:
            flagged, flag_type = True, "low_entropy"
            flag_reason = f"LOW_ENTROPY ({entropy:.1f})"
        elif own_label_idx >= 0 and top1_idx != own_label_idx and top1_conf > wrong_thresh:
            flagged, flag_type = True, "wrong_breed"
            flag_reason = f"WRONG: model says '{top1_label}' @ {top1_conf*100:.0f}%"
        elif own_label_idx >= 0 and own_conf < own_low_thresh and top1_idx != own_label_idx:
            flagged, flag_type = True, "low_own"
            flag_reason = f"LOW_OWN: {own_conf*100:.1f}% (top: {top1_label} @ {top1_conf*100:.0f}%)"

        results.append({
            "breed": folder.name,
            "file": str(img_path),
            "filename": img_path.name,
            "flagged": flagged,
            "flag_reason": flag_reason,
            "flag_type": flag_type,
            "top1_label": top1_label,
            "top1_conf": top1_conf,
            "own_confidence": own_conf,
            "entropy": entropy,
        })

    return results


def main():
    parser = argparse.ArgumentParser(description="Audit & clean supplemental training images")
    parser.add_argument("--clean", action="store_true",
                        help="Auto-move flagged images to supplemental_dogs_removed/")
    parser.add_argument("--aggressive", action="store_true",
                        help="Use tighter thresholds (for second-pass after retrain)")
    parser.add_argument("--min-keep", type=int, default=DEFAULT_MIN_KEEP,
                        help=f"Minimum images to keep per breed (default: {DEFAULT_MIN_KEEP})")
    parser.add_argument("--breeds", type=str, default=None,
                        help="Comma-separated breed folders to audit (default: all)")
    args = parser.parse_args()

    os.chdir(os.path.dirname(os.path.abspath(__file__)))

    # Set thresholds
    if args.aggressive:
        thresholds = (AGGRESSIVE_WRONG_BREED_THRESHOLD,
                      AGGRESSIVE_OWN_LOW_THRESHOLD,
                      DEFAULT_MIN_ENTROPY)
        print("Mode: AGGRESSIVE thresholds")
    else:
        thresholds = (DEFAULT_WRONG_BREED_THRESHOLD,
                      DEFAULT_OWN_LOW_THRESHOLD,
                      DEFAULT_MIN_ENTROPY)
        print("Mode: CONSERVATIVE thresholds")

    if args.clean:
        print(f"Action: AUTO-CLEAN (move flagged to {REMOVED_DIR}/)")
    else:
        print("Action: REPORT ONLY (add --clean to auto-move)")

    print(f"Safety floor: min {args.min_keep} images per breed\n")

    # Load model
    interpreter, input_details, output_details, labels, input_size = load_model_and_labels()

    # Gather breed folders
    supp_path = Path(SUPPLEMENTAL_DIR)
    if args.breeds:
        breed_names = [b.strip().lower().replace(" ", "_") for b in args.breeds.split(",")]
        breed_folders = sorted([
            d for d in supp_path.iterdir()
            if d.is_dir() and d.name in breed_names
        ])
    else:
        breed_folders = sorted([d for d in supp_path.iterdir() if d.is_dir()])

    print(f"\nAuditing {len(breed_folders)} breed folders...")
    print(f"Thresholds: wrong_breed>{thresholds[0]*100:.0f}%, "
          f"own_low<{thresholds[1]*100:.1f}%, "
          f"entropy<{thresholds[2]:.1f}")
    print(f"{'='*70}\n")

    # Map folders to label indices
    folder_label_map = {}
    unmatched = []
    for folder in breed_folders:
        idx = find_label_index(folder.name, labels)
        folder_label_map[folder.name] = idx
        if idx < 0:
            unmatched.append(folder.name)

    if unmatched:
        print(f"WARNING: {len(unmatched)} breeds have no matching label:")
        for name in unmatched:
            print(f"  - {name}")
        print()

    # Run audit
    all_results = []
    breed_stats = {}
    total_flagged = 0
    total_images = 0
    total_moved = 0

    start = time.time()

    for i, folder in enumerate(breed_folders, 1):
        own_idx = folder_label_map[folder.name]
        results = audit_breed(folder, interpreter, input_details, output_details,
                              labels, input_size, own_idx, thresholds)

        n_total = len(results)
        n_flagged = sum(1 for r in results if r["flagged"])
        n_correct = sum(1 for r in results
                        if not r["flagged"] and own_idx >= 0
                        and r.get("top1_label") == labels[own_idx])

        breed_acc = n_correct / max(n_total, 1) * 100
        flag_rate = n_flagged / max(n_total, 1) * 100

        breed_stats[folder.name] = {
            "total": n_total,
            "flagged": n_flagged,
            "correct_top1": n_correct,
            "accuracy": round(breed_acc, 1),
            "flag_rate": round(flag_rate, 1),
            "label": labels[own_idx] if own_idx >= 0 else "?",
        }

        # Status line
        status = f"[{i:3d}/{len(breed_folders)}] {folder.name:<35s} "
        status += f"{n_total:4d} imgs, {n_flagged:3d} flagged ({flag_rate:4.1f}%), "
        status += f"acc={breed_acc:5.1f}%"
        if n_flagged > 0:
            status += "  (!)"
        print(status)

        # Auto-clean if requested
        n_moved = 0
        if args.clean and n_flagged > 0:
            flagged_results = [r for r in results if r["flagged"]]
            # Sort by severity: corrupt first, then highest wrong-breed confidence
            flagged_results.sort(key=lambda r: (
                0 if r["flag_type"] == "corrupt" else 1,
                -r.get("top1_conf", 0)
            ))

            # Respect safety floor (corrupt images always removed)
            n_clean = n_total - n_flagged
            can_remove = max(0, n_clean + n_flagged - args.min_keep)
            # Always allow removing corrupt images
            n_corrupt = sum(1 for r in flagged_results if r["flag_type"] == "corrupt")
            can_remove = max(can_remove, n_corrupt)

            removed_dir = Path(REMOVED_DIR) / folder.name
            removed_dir.mkdir(parents=True, exist_ok=True)

            for j, r in enumerate(flagged_results):
                if j >= can_remove and r["flag_type"] != "corrupt":
                    break
                src = Path(r["file"])
                if src.exists():
                    dst = removed_dir / src.name
                    shutil.move(str(src), str(dst))
                    r["moved"] = True
                    n_moved += 1

            if n_moved > 0:
                remaining = n_total - n_moved
                print(f"       -> Moved {n_moved} images ({remaining} remaining)")

        total_images += n_total
        total_flagged += n_flagged
        total_moved += n_moved
        all_results.extend(results)

    elapsed = time.time() - start

    # ── Summary ───────────────────────────────────────────────────────────
    print(f"\n{'='*70}")
    print(f"AUDIT COMPLETE")
    print(f"{'='*70}")
    print(f"  Breeds audited:  {len(breed_folders)}")
    print(f"  Total images:    {total_images}")
    print(f"  Flagged:         {total_flagged} ({total_flagged/max(total_images,1)*100:.1f}%)")
    if args.clean:
        print(f"  Moved:           {total_moved}")
        print(f"  Remaining:       {total_images - total_moved}")
    print(f"  Time:            {elapsed:.0f}s ({elapsed/60:.1f} min)")

    # Worst breeds by flag rate
    sorted_breeds = sorted(breed_stats.items(), key=lambda x: -x[1]["flag_rate"])
    print(f"\n  WORST BREEDS (highest flag rate):")
    for name, stats in sorted_breeds[:15]:
        print(f"    {name:<35s} {stats['flag_rate']:5.1f}% flagged "
              f"({stats['flagged']}/{stats['total']}), acc={stats['accuracy']:.1f}%")

    # Best breeds
    sorted_by_acc = sorted(breed_stats.items(), key=lambda x: -x[1]["accuracy"])
    print(f"\n  BEST BREEDS (highest model accuracy):")
    for name, stats in sorted_by_acc[:10]:
        print(f"    {name:<35s} acc={stats['accuracy']:5.1f}% "
              f"({stats['correct_top1']}/{stats['total']})")

    # ── Write reports ─────────────────────────────────────────────────────

    # JSON: per-breed stats
    with open("audit_breed_stats.json", "w") as f:
        json.dump(breed_stats, f, indent=2)
    print(f"\n  Written: audit_breed_stats.json")

    # JSON: flagged images
    flagged_list = [r for r in all_results if r["flagged"]]
    with open("audit_flagged.json", "w") as f:
        json.dump(flagged_list, f, indent=2)
    print(f"  Written: audit_flagged.json ({len(flagged_list)} entries)")

    # Text report
    with open("audit_report.txt", "w", encoding="utf-8") as f:
        f.write(f"DogQuest Training Data Audit Report\n")
        f.write(f"{'='*50}\n")
        f.write(f"Date: {time.strftime('%Y-%m-%d %H:%M')}\n")
        f.write(f"Model: {MODEL_PATH}\n")
        f.write(f"Thresholds: wrong>{thresholds[0]*100:.0f}%, "
                f"own_low<{thresholds[1]*100:.1f}%, entropy<{thresholds[2]}\n")
        f.write(f"Total: {total_images} images, {total_flagged} flagged "
                f"({total_flagged/max(total_images,1)*100:.1f}%)\n")
        if args.clean:
            f.write(f"Moved: {total_moved} images\n")
        f.write(f"\n{'='*50}\n\n")

        for name, stats in sorted_breeds:
            f.write(f"{name:<35s} {stats['total']:4d} imgs, "
                    f"{stats['flagged']:3d} flagged ({stats['flag_rate']:4.1f}%), "
                    f"acc={stats['accuracy']:5.1f}%\n")

        f.write(f"\n{'='*50}\n")
        f.write(f"\nFLAGGED IMAGE DETAILS:\n\n")

        for r in all_results:
            if r["flagged"]:
                moved = " [MOVED]" if r.get("moved") else ""
                f.write(f"  {r['breed']}/{r['filename']}: {r['flag_reason']}{moved}\n")

    print(f"  Written: audit_report.txt")

    # Summary for next steps
    if not args.clean and total_flagged > 0:
        print(f"\n  To auto-clean, run:")
        print(f"    python3 audit_and_clean.py --clean")
        print(f"    # Then retrain: python3 train_model_v6.py")
        print(f"    # Then re-audit with tighter thresholds:")
        print(f"    python3 audit_and_clean.py --clean --aggressive")

    print(f"\n{'='*70}")


if __name__ == "__main__":
    main()
