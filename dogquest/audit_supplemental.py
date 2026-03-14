"""
Audit supplemental dog breed training images using the current TFLite model.

For each image in supplemental_dogs/{breed}/, runs inference and flags images
where the model predicts a different breed with high confidence — indicating
the image is likely mislabeled or noisy.

Outputs:
  - audit_report.txt  — text report of flagged images with model predictions
  - audit_gallery.html — visual gallery for fast manual review (red = suspect)
"""

import os
import sys
import json
import numpy as np
from pathlib import Path
from PIL import Image

# Use TF Lite interpreter
import tensorflow as tf

# --- Configuration ---
MODEL_PATH = "assets/dog_model.tflite"
LABELS_PATH = "assets/dog_labels.txt"
SUPPLEMENTAL_DIR = "supplemental_dogs"
INPUT_SIZE = 224

# Flagging thresholds
# Flag if model's top-1 is a different breed AND confidence > this
DIFFERENT_BREED_THRESHOLD = 0.40
# Flag if model's confidence for the folder's own breed < this
OWN_BREED_LOW_THRESHOLD = 0.05
# Flag if image pixel entropy is below this (blank/corrupt images)
MIN_IMAGE_ENTROPY = 1.0

# --- Mapping from folder name to label name ---
# Folder names use underscores; labels may differ. Build a flexible matcher.
def normalize(name):
    """Normalize a breed name for matching: lowercase, strip punctuation, collapse spaces."""
    return name.lower().replace("_", " ").replace("-", " ").strip()


def load_model_and_labels():
    interpreter = tf.lite.Interpreter(model_path=MODEL_PATH)
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    with open(LABELS_PATH, "r") as f:
        labels = [line.strip() for line in f if line.strip()]

    print(f"Model loaded: input={input_details[0]['shape']}, "
          f"dtype={input_details[0]['dtype']}, "
          f"output={output_details[0]['shape']}, "
          f"odtype={output_details[0]['dtype']}, "
          f"{len(labels)} labels")

    return interpreter, input_details, output_details, labels


def preprocess_image(image_path):
    """Load and preprocess image to match model input: 224x224 uint8 RGB."""
    try:
        img = Image.open(image_path).convert("RGB")
    except Exception as e:
        return None, f"Failed to open: {e}"

    # Center crop to square
    w, h = img.size
    crop_size = min(w, h)
    left = (w - crop_size) // 2
    top = (h - crop_size) // 2
    img = img.crop((left, top, left + crop_size, top + crop_size))

    # Resize
    img = img.resize((INPUT_SIZE, INPUT_SIZE), Image.BILINEAR)

    # Convert to numpy
    arr = np.array(img, dtype=np.uint8)
    return arr, None


def compute_image_entropy(arr):
    """Compute pixel entropy to detect blank/corrupt images."""
    hist, _ = np.histogram(arr.flatten(), bins=256, range=(0, 256))
    hist = hist / hist.sum()
    hist = hist[hist > 0]
    return -np.sum(hist * np.log2(hist))


def run_inference(interpreter, input_details, output_details, image_arr):
    """Run TFLite inference, return probabilities array."""
    input_data = np.expand_dims(image_arr, axis=0)

    # Match input dtype
    if input_details[0]['dtype'] == np.uint8:
        input_data = input_data.astype(np.uint8)
    else:
        input_data = input_data.astype(np.float32) / 255.0

    interpreter.set_tensor(input_details[0]['index'], input_data)
    interpreter.invoke()

    output = interpreter.get_tensor(output_details[0]['index'])[0]

    # Convert uint8 output to probabilities
    if output_details[0]['dtype'] == np.uint8:
        probs = output.astype(np.float64) / 255.0
    else:
        probs = output.astype(np.float64)

    # If logits (negative values), apply softmax
    if np.any(probs < 0):
        probs = probs - probs.max()
        probs = np.exp(probs)
        probs = probs / probs.sum()

    return probs


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
    best_idx = -1
    best_overlap = 0
    for i, label in enumerate(labels):
        label_words = set(normalize(label).split())
        overlap = len(folder_words & label_words)
        if overlap > best_overlap:
            best_overlap = overlap
            best_idx = i

    return best_idx if best_overlap > 0 else -1


def main():
    os.chdir(os.path.dirname(os.path.abspath(__file__)))

    interpreter, input_details, output_details, labels = load_model_and_labels()

    # Gather all breed folders
    breed_folders = sorted([
        d for d in Path(SUPPLEMENTAL_DIR).iterdir() if d.is_dir()
    ])

    print(f"\nAuditing {len(breed_folders)} supplemental breed folders...\n")

    # Build folder→label index mapping
    folder_label_map = {}
    for folder in breed_folders:
        idx = find_label_index(folder.name, labels)
        if idx >= 0:
            folder_label_map[folder.name] = idx
            print(f"  {folder.name} -> label[{idx}] = '{labels[idx]}'")
        else:
            print(f"  WARNING: {folder.name} -> NO MATCHING LABEL")
            folder_label_map[folder.name] = -1

    print()

    # Audit each image
    all_results = []  # List of dicts
    flagged_count = 0
    total_count = 0

    for folder in breed_folders:
        breed_name = folder.name
        own_label_idx = folder_label_map[breed_name]

        images = sorted([
            f for f in folder.iterdir()
            if f.suffix.lower() in ('.jpg', '.jpeg', '.png', '.webp')
        ])

        breed_flagged = 0

        for img_path in images:
            total_count += 1

            arr, err = preprocess_image(str(img_path))
            if arr is None:
                result = {
                    "breed": breed_name,
                    "file": str(img_path),
                    "filename": img_path.name,
                    "flagged": True,
                    "flag_reason": f"CORRUPT: {err}",
                    "top3": [],
                    "own_confidence": 0.0,
                    "entropy": 0.0,
                }
                all_results.append(result)
                flagged_count += 1
                breed_flagged += 1
                continue

            # Check image entropy
            img_entropy = compute_image_entropy(arr)

            # Run inference
            probs = run_inference(interpreter, input_details, output_details, arr)

            # Get top-5
            top5_idx = np.argsort(probs)[::-1][:5]
            top5 = [(int(i), labels[i] if i < len(labels) else "?", float(probs[i])) for i in top5_idx]

            # Own breed confidence
            own_conf = float(probs[own_label_idx]) if own_label_idx >= 0 else 0.0

            # Determine if flagged
            flagged = False
            flag_reason = ""

            top1_idx, top1_label, top1_conf = top5[0]

            if img_entropy < MIN_IMAGE_ENTROPY:
                flagged = True
                flag_reason = f"LOW_ENTROPY ({img_entropy:.1f})"
            elif own_label_idx >= 0 and top1_idx != own_label_idx and top1_conf > DIFFERENT_BREED_THRESHOLD:
                flagged = True
                flag_reason = f"WRONG_BREED: model says '{top1_label}' @ {top1_conf*100:.1f}%"
            elif own_label_idx >= 0 and own_conf < OWN_BREED_LOW_THRESHOLD:
                flagged = True
                flag_reason = f"LOW_OWN_CONF: only {own_conf*100:.2f}% for expected breed"

            result = {
                "breed": breed_name,
                "file": str(img_path),
                "filename": img_path.name,
                "flagged": flagged,
                "flag_reason": flag_reason,
                "top3": [(l, f"{c*100:.1f}%") for _, l, c in top5[:3]],
                "own_confidence": own_conf,
                "entropy": img_entropy,
            }
            all_results.append(result)

            if flagged:
                flagged_count += 1
                breed_flagged += 1

        status = f"  {breed_name}: {len(images)} images, {breed_flagged} flagged"
        if breed_flagged > 0:
            status += " (!)"
        print(status)

    print(f"\n{'='*60}")
    print(f"TOTAL: {total_count} images, {flagged_count} flagged ({flagged_count/max(total_count,1)*100:.1f}%)")
    print(f"{'='*60}\n")

    # --- Write text report ---
    with open("audit_report.txt", "w", encoding="utf-8") as f:
        f.write(f"DogQuest Supplemental Image Audit Report\n")
        f.write(f"{'='*50}\n")
        f.write(f"Total images: {total_count}\n")
        f.write(f"Flagged: {flagged_count} ({flagged_count/max(total_count,1)*100:.1f}%)\n\n")

        current_breed = None
        for r in all_results:
            if r["breed"] != current_breed:
                current_breed = r["breed"]
                breed_results = [x for x in all_results if x["breed"] == current_breed]
                breed_flagged = sum(1 for x in breed_results if x["flagged"])
                f.write(f"\n{'-'*50}\n")
                f.write(f"BREED: {current_breed} ({len(breed_results)} images, {breed_flagged} flagged)\n")
                f.write(f"{'-'*50}\n")

            if r["flagged"]:
                f.write(f"\n  (!) FLAGGED: {r['filename']}\n")
                f.write(f"    Reason: {r['flag_reason']}\n")
                f.write(f"    Top-3: {r['top3']}\n")
                f.write(f"    Own confidence: {r['own_confidence']*100:.2f}%\n")

    print(f"Written: audit_report.txt")

    # --- Write HTML gallery ---
    write_html_gallery(all_results, breed_folders, labels, folder_label_map)
    print(f"Written: audit_gallery.html")

    # --- Write JSON for programmatic use ---
    flagged_list = [r for r in all_results if r["flagged"]]
    with open("audit_flagged.json", "w") as f:
        json.dump(flagged_list, f, indent=2)
    print(f"Written: audit_flagged.json ({len(flagged_list)} flagged images)")


def write_html_gallery(all_results, breed_folders, labels, folder_label_map):
    """Generate an HTML gallery for visual review."""

    html = """<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>DogQuest Supplemental Image Audit</title>
<style>
body { font-family: Arial, sans-serif; background: #1a1a2e; color: #eee; padding: 20px; }
h1 { color: #e94560; }
h2 { color: #0f3460; background: #e94560; padding: 10px; border-radius: 8px; margin-top: 40px; }
.breed-stats { color: #aaa; margin-bottom: 10px; }
.grid { display: flex; flex-wrap: wrap; gap: 8px; }
.card {
    width: 180px; border-radius: 8px; overflow: hidden;
    background: #16213e; border: 3px solid #16213e;
    transition: transform 0.2s;
}
.card:hover { transform: scale(1.05); }
.card.flagged { border-color: #e94560; background: #2a1020; }
.card img { width: 100%; height: 140px; object-fit: cover; }
.card .info { padding: 6px; font-size: 11px; }
.card .info .pred { color: #0f3460; font-weight: bold; }
.card.flagged .info .pred { color: #e94560; }
.card .info .reason { color: #ff6b6b; font-size: 10px; font-weight: bold; }
.card .info .conf { color: #7ec8e3; }
.summary { background: #16213e; padding: 15px; border-radius: 8px; margin-bottom: 20px; }
.summary .bad { color: #e94560; font-weight: bold; }
.summary .good { color: #4ecca3; }
.delete-btn {
    background: #e94560; color: white; border: none; padding: 2px 6px;
    border-radius: 4px; cursor: pointer; font-size: 10px; margin-top: 4px;
}
.delete-btn.marked { background: #333; text-decoration: line-through; }
#export-btn {
    position: fixed; bottom: 20px; right: 20px; background: #e94560;
    color: white; border: none; padding: 12px 24px; border-radius: 8px;
    cursor: pointer; font-size: 14px; font-weight: bold; z-index: 100;
    box-shadow: 0 4px 12px rgba(233,69,96,0.4);
}
#export-btn:hover { background: #c73650; }
#count-badge {
    position: fixed; bottom: 60px; right: 20px; background: #16213e;
    color: #e94560; padding: 8px 16px; border-radius: 8px; font-size: 12px;
    z-index: 100;
}
</style>
</head>
<body>
<h1>DogQuest Supplemental Image Audit</h1>
"""

    total = len(all_results)
    flagged = sum(1 for r in all_results if r["flagged"])

    html += f"""
<div class="summary">
    <strong>Total images:</strong> {total} |
    <span class="bad">Flagged: {flagged} ({flagged/max(total,1)*100:.1f}%)</span> |
    <span class="good">Clean: {total - flagged}</span>
    <br><br>
    <em>Red borders = suspected mislabeled. Click "Mark Delete" to build a deletion list, then "Export Delete List" to save.</em>
</div>
<div id="count-badge">Marked for deletion: <span id="del-count">0</span></div>
<button id="export-btn" onclick="exportDeleteList()">Export Delete List</button>
"""

    # Group by breed
    from collections import OrderedDict
    by_breed = OrderedDict()
    for r in all_results:
        by_breed.setdefault(r["breed"], []).append(r)

    for breed_name, results in by_breed.items():
        n_flagged = sum(1 for r in results if r["flagged"])
        label_idx = folder_label_map.get(breed_name, -1)
        label_name = labels[label_idx] if 0 <= label_idx < len(labels) else "?"

        html += f'<h2>{breed_name}</h2>\n'
        html += f'<div class="breed-stats">{len(results)} images, '
        if n_flagged > 0:
            html += f'<span style="color:#e94560">{n_flagged} flagged</span>'
        else:
            html += '<span style="color:#4ecca3">0 flagged</span>'
        html += f' | Model label: "{label_name}" (index {label_idx})</div>\n'
        html += '<div class="grid">\n'

        # Sort: flagged first
        sorted_results = sorted(results, key=lambda r: (not r["flagged"], r["filename"]))

        for r in sorted_results:
            cls = "card flagged" if r["flagged"] else "card"
            # Use file:// protocol for local images
            img_path = os.path.abspath(r["file"]).replace("\\", "/")

            top3_str = ", ".join(f"{l} {c}" for l, c in r["top3"]) if r["top3"] else "N/A"

            html += f'  <div class="{cls}">\n'
            html += f'    <img src="file:///{img_path}" loading="lazy">\n'
            html += f'    <div class="info">\n'
            html += f'      <div class="conf">Own: {r["own_confidence"]*100:.1f}%</div>\n'
            html += f'      <div class="pred">{top3_str}</div>\n'
            if r["flagged"]:
                html += f'      <div class="reason">{r["flag_reason"]}</div>\n'
            escaped_file = r["file"].replace("\\", "/")
            html += f'      <button class="delete-btn" onclick="toggleDelete(this, \'{escaped_file}\')">'
            html += 'Mark Delete</button>\n'
            html += f'    </div>\n'
            html += f'  </div>\n'

        html += '</div>\n'

    html += """
<script>
const deleteSet = new Set();

function toggleDelete(btn, filepath) {
    if (deleteSet.has(filepath)) {
        deleteSet.delete(filepath);
        btn.textContent = "Mark Delete";
        btn.classList.remove("marked");
    } else {
        deleteSet.add(filepath);
        btn.textContent = "Marked ✗";
        btn.classList.add("marked");
    }
    document.getElementById("del-count").textContent = deleteSet.size;
}

function exportDeleteList() {
    if (deleteSet.size === 0) {
        alert("No images marked for deletion.");
        return;
    }
    const text = Array.from(deleteSet).join("\\n");
    const blob = new Blob([text], {type: "text/plain"});
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = "to_delete.txt";
    a.click();
}
</script>
</body>
</html>
"""

    with open("audit_gallery.html", "w", encoding="utf-8") as f:
        f.write(html)


if __name__ == "__main__":
    main()
