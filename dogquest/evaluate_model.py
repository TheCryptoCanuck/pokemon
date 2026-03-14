"""
evaluate_model.py — Comprehensive TFLite model evaluation for DogQuest.

Runs full test-set inference on a uint8-quantized TFLite model and produces:
  1. Overall accuracy, top-3 accuracy, top-5 accuracy
  2. Per-breed precision, recall, F1-score
  3. Full confusion matrix (saved as .npy)
  4. Top-10 most confused breed pairs
  5. Breeds below 80% accuracy (flagged for remediation)
  6. JSON report (evaluate_v5_report.json or custom name)
  7. Formatted terminal summary

Works with any DogQuest TFLite model version (v3, v4.1, v5, etc.).

Usage:
  python evaluate_model.py
  python evaluate_model.py --model assets/dog_model_v3.tflite
  python evaluate_model.py --model assets/dog_model_v5.tflite --output evaluate_v5_report.json
  python evaluate_model.py --model assets/dog_model.tflite --num-images 0  # 0 = all test images
  python evaluate_model.py --include-supplemental  # also evaluate supplemental breeds
"""
import os
import sys
import glob
import json
import time
import argparse
import warnings
from collections import defaultdict

import numpy as np

os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"

import tensorflow as tf
import tensorflow_datasets as tfds

# ── Constants ────────────────────────────────────────────────────────────
SUPPLEMENTAL_DIR = "supplemental_dogs"
LABELS_FILE = "assets/dog_labels.txt"
BBOX_PADDING = 0.15


# ══════════════════════════════════════════════════════════════════════════
# CLI arguments
# ══════════════════════════════════════════════════════════════════════════
def parse_args():
    parser = argparse.ArgumentParser(
        description="Comprehensive TFLite model evaluation for DogQuest",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--model", default="assets/dog_model.tflite",
        help="Path to TFLite model (default: assets/dog_model.tflite)",
    )
    parser.add_argument(
        "--labels", default=LABELS_FILE,
        help="Path to labels file (default: assets/dog_labels.txt)",
    )
    parser.add_argument(
        "--output", default=None,
        help="Output JSON report path (default: evaluate_<version>_report.json)",
    )
    parser.add_argument(
        "--num-images", type=int, default=0,
        help="Max test images to evaluate (0 = all, default: all)",
    )
    parser.add_argument(
        "--include-supplemental", action="store_true",
        help="Include supplemental breed test images",
    )
    parser.add_argument(
        "--save-confusion-matrix", action="store_true",
        help="Save full confusion matrix as .npy file",
    )
    parser.add_argument(
        "--accuracy-threshold", type=float, default=0.80,
        help="Flag breeds below this accuracy (default: 0.80)",
    )
    parser.add_argument(
        "--top-confused", type=int, default=10,
        help="Number of most-confused breed pairs to show (default: 10)",
    )
    return parser.parse_args()


# ══════════════════════════════════════════════════════════════════════════
# Label loading
# ══════════════════════════════════════════════════════════════════════════
def load_labels(labels_path):
    """Load breed labels from text file (one per line)."""
    if not os.path.exists(labels_path):
        print(f"ERROR: Labels file not found: {labels_path}")
        sys.exit(1)
    with open(labels_path, "r", encoding="utf-8") as f:
        labels = [line.strip() for line in f if line.strip()]
    print(f"  Loaded {len(labels)} breed labels from {labels_path}")
    return labels


# ══════════════════════════════════════════════════════════════════════════
# TFLite model loading and inference
# ══════════════════════════════════════════════════════════════════════════
def load_tflite_model(model_path):
    """Load TFLite model, return interpreter and metadata."""
    if not os.path.exists(model_path):
        print(f"ERROR: Model file not found: {model_path}")
        sys.exit(1)

    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()[0]
    output_details = interpreter.get_output_details()[0]

    input_shape = input_details["shape"]  # [1, H, W, 3]
    img_size = int(input_shape[1])
    num_outputs = interpreter.get_output_details()[0]["shape"][-1]
    model_size_mb = os.path.getsize(model_path) / (1024 * 1024)

    print(f"  Model: {model_path} ({model_size_mb:.1f} MB)")
    print(f"  Input:  {input_details['dtype'].__name__} {list(input_shape)}")
    print(f"  Output: {output_details['dtype'].__name__} [{num_outputs}]")
    print(f"  Image size: {img_size}x{img_size}")

    # Print quantization parameters if present
    if "quantization_parameters" in input_details:
        qp = input_details["quantization_parameters"]
        if "scales" in qp and len(qp["scales"]) > 0:
            print(f"  Input quant:  scale={qp['scales'][0]:.8f}, "
                  f"zero_point={qp['zero_points'][0]}")
    if "quantization_parameters" in output_details:
        qp = output_details["quantization_parameters"]
        if "scales" in qp and len(qp["scales"]) > 0:
            print(f"  Output quant: scale={qp['scales'][0]:.8f}, "
                  f"zero_point={qp['zero_points'][0]}")

    return interpreter, input_details, output_details, img_size, model_size_mb


def run_inference(interpreter, input_details, output_details, image_uint8):
    """Run single image through TFLite model. Returns float32 confidence array."""
    if image_uint8.dtype != np.uint8:
        image_uint8 = np.clip(image_uint8, 0, 255).astype(np.uint8)
    if len(image_uint8.shape) == 3:
        image_uint8 = np.expand_dims(image_uint8, axis=0)

    interpreter.set_tensor(input_details["index"], image_uint8)
    interpreter.invoke()
    raw_output = interpreter.get_tensor(output_details["index"])[0]

    # Convert uint8 output to float confidence [0, 1]
    if output_details["dtype"] == np.uint8:
        confidences = raw_output.astype(np.float32) / 255.0
    else:
        confidences = raw_output.astype(np.float32)

    return confidences


# ══════════════════════════════════════════════════════════════════════════
# Data loading — Stanford Dogs
# ══════════════════════════════════════════════════════════════════════════
def clean_stanford_name(raw_name):
    """Clean Stanford Dogs class name to match label format."""
    if "-" in raw_name:
        raw_name = raw_name.split("-", 1)[1]
    return raw_name.replace("_", " ")


def clean_supplemental_name(folder_name):
    """Clean supplemental folder name to match label format."""
    return folder_name.replace("_", " ").title()


def crop_to_bbox(image, bbox, padding=BBOX_PADDING):
    """Crop image to bounding box with padding (numpy/TF)."""
    shape = tf.shape(image)
    h = tf.cast(shape[0], tf.float32)
    w = tf.cast(shape[1], tf.float32)

    ymin, xmin, ymax, xmax = bbox[0], bbox[1], bbox[2], bbox[3]
    box_h = ymax - ymin
    box_w = xmax - xmin
    pad_h = box_h * padding
    pad_w = box_w * padding

    ymin = tf.maximum(ymin - pad_h, 0.0)
    xmin = tf.maximum(xmin - pad_w, 0.0)
    ymax = tf.minimum(ymax + pad_h, 1.0)
    xmax = tf.minimum(xmax + pad_w, 1.0)

    y1 = tf.cast(tf.round(ymin * h), tf.int32)
    x1 = tf.cast(tf.round(xmin * w), tf.int32)
    y2 = tf.cast(tf.round(ymax * h), tf.int32)
    x2 = tf.cast(tf.round(xmax * w), tf.int32)

    crop_h = tf.maximum(y2 - y1, 10)
    crop_w = tf.maximum(x2 - x1, 10)
    y1 = tf.maximum(tf.minimum(y1, shape[0] - crop_h), 0)
    x1 = tf.maximum(tf.minimum(x1, shape[1] - crop_w), 0)

    return tf.image.crop_to_bounding_box(image, y1, x1, crop_h, crop_w)


def load_stanford_test_data(num_images=0):
    """Load Stanford Dogs test split with bbox crops.

    Args:
        num_images: Max images to load. 0 = all.

    Returns:
        images: list of float32 tensors (variable size, not resized yet)
        labels: list of int labels (Stanford index 0-119)
        stanford_names: list of clean breed names
        total_available: total images in test split
    """
    print("\nLoading Stanford Dogs test split...")
    ds_test_raw, info = tfds.load(
        "stanford_dogs",
        split="test",
        as_supervised=False,
        with_info=True,
    )

    stanford_class_names = info.features["label"].names
    stanford_clean = [clean_stanford_name(n) for n in stanford_class_names]
    total_available = info.splits["test"].num_examples

    images = []
    labels = []
    count = 0

    for example in ds_test_raw:
        if 0 < num_images <= count:
            break

        image = example["image"]
        label = example["label"].numpy()
        bbox = example["objects"]["bbox"]

        # Crop to bounding box if available (matches training preprocessing)
        if tf.shape(bbox)[0] > 0:
            image = crop_to_bbox(image, bbox[0])

        images.append(tf.cast(image, tf.float32))
        labels.append(int(label))
        count += 1

    print(f"  Loaded {len(images)} / {total_available} Stanford Dogs test images")
    return images, labels, stanford_clean, total_available


def load_supplemental_test_data(label_names):
    """Load supplemental breed test images (20% held-out split, matching training).

    Args:
        label_names: list of all breed names (to find label indices)

    Returns:
        images: list of float32 tensors
        labels: list of int labels (unified index)
        breed_counts: dict of breed_name -> count
    """
    if not os.path.isdir(SUPPLEMENTAL_DIR):
        print(f"\n  Supplemental directory not found: {SUPPLEMENTAL_DIR}")
        return [], [], {}

    label_name_lower = {n.lower(): i for i, n in enumerate(label_names)}

    images = []
    labels = []
    breed_counts = {}

    for entry in sorted(os.listdir(SUPPLEMENTAL_DIR)):
        folder_path = os.path.join(SUPPLEMENTAL_DIR, entry)
        if not os.path.isdir(folder_path):
            continue

        clean = clean_supplemental_name(entry)
        if clean.lower() not in label_name_lower:
            continue

        label_idx = label_name_lower[clean.lower()]

        # Gather images
        imgs_set = set()
        for ext in ("*.jpg", "*.jpeg", "*.png", "*.JPG", "*.JPEG", "*.PNG"):
            imgs_set.update(glob.glob(os.path.join(folder_path, ext)))
        imgs = sorted(imgs_set)

        if len(imgs) == 0:
            continue

        # Reproduce the same train/test split as training script (seed=42, 80/20)
        np.random.seed(42)
        indices = np.random.permutation(len(imgs))
        split_point = max(1, int(len(imgs) * 0.8))
        test_indices = indices[split_point:]

        test_count = 0
        for idx in test_indices:
            img_path = imgs[idx]
            try:
                raw = tf.io.read_file(img_path)
                image = tf.io.decode_jpeg(raw, channels=3)
                images.append(tf.cast(image, tf.float32))
                labels.append(label_idx)
                test_count += 1
            except Exception as e:
                warnings.warn(f"Failed to load {img_path}: {e}")

        if test_count > 0:
            breed_counts[clean] = test_count

    total = len(images)
    print(f"\n  Loaded {total} supplemental test images "
          f"from {len(breed_counts)} breeds")
    return images, labels, breed_counts


# ══════════════════════════════════════════════════════════════════════════
# Metrics computation
# ══════════════════════════════════════════════════════════════════════════
def compute_normalized_entropy(probs):
    """Normalized entropy: 0 = perfectly confident, 1 = uniform."""
    num_classes = len(probs)
    probs = np.clip(probs, 1e-10, 1.0)
    probs = probs / probs.sum()
    entropy = -np.sum(probs * np.log(probs))
    max_entropy = np.log(num_classes)
    return entropy / max_entropy


def compute_per_class_metrics(confusion_matrix, label_names):
    """Compute precision, recall, F1, accuracy per class from confusion matrix.

    Returns list of dicts, one per class.
    """
    num_classes = confusion_matrix.shape[0]
    results = []

    for i in range(num_classes):
        tp = confusion_matrix[i, i]
        fn = confusion_matrix[i, :].sum() - tp   # actual positives minus TP
        fp = confusion_matrix[:, i].sum() - tp    # predicted positives minus TP
        support = confusion_matrix[i, :].sum()    # total actual for this class

        precision = tp / (tp + fp) if (tp + fp) > 0 else 0.0
        recall = tp / (tp + fn) if (tp + fn) > 0 else 0.0
        f1 = (2 * precision * recall / (precision + recall)
              if (precision + recall) > 0 else 0.0)
        accuracy = tp / support if support > 0 else 0.0

        results.append({
            "index": i,
            "name": label_names[i] if i < len(label_names) else f"class_{i}",
            "precision": float(precision),
            "recall": float(recall),
            "f1": float(f1),
            "accuracy": float(accuracy),
            "tp": int(tp),
            "fp": int(fp),
            "fn": int(fn),
            "support": int(support),
        })

    return results


def find_top_confused_pairs(confusion_matrix, label_names, top_n=10):
    """Find the N most confused breed pairs (off-diagonal maxima).

    Returns list of (breed_a, breed_b, count) where breed_a is misclassified
    as breed_b.
    """
    cm = confusion_matrix.copy().astype(np.int64)
    np.fill_diagonal(cm, 0)

    pairs = []
    for _ in range(top_n):
        max_val = cm.max()
        if max_val == 0:
            break
        i, j = np.unravel_index(cm.argmax(), cm.shape)
        name_i = label_names[i] if i < len(label_names) else f"class_{i}"
        name_j = label_names[j] if j < len(label_names) else f"class_{j}"
        pairs.append({
            "actual": name_i,
            "predicted": name_j,
            "actual_index": int(i),
            "predicted_index": int(j),
            "count": int(max_val),
        })
        cm[i, j] = 0

    return pairs


# ══════════════════════════════════════════════════════════════════════════
# Main evaluation
# ══════════════════════════════════════════════════════════════════════════
def run_evaluation(args):
    start_time = time.time()

    print("=" * 72)
    print("DogQuest Model Evaluation")
    print("=" * 72)

    # ── Load labels ──────────────────────────────────────────────────────
    print(f"\nLoading labels...")
    label_names = load_labels(args.labels)
    num_classes = len(label_names)

    # ── Load model ───────────────────────────────────────────────────────
    print(f"\nLoading TFLite model...")
    (interpreter, input_details, output_details,
     img_size, model_size_mb) = load_tflite_model(args.model)

    # Verify model output dimension matches labels
    model_num_outputs = interpreter.get_output_details()[0]["shape"][-1]
    if model_num_outputs != num_classes:
        print(f"\n  WARNING: Model outputs {model_num_outputs} classes "
              f"but labels file has {num_classes} entries.")
        print(f"  Using min({model_num_outputs}, {num_classes}) for evaluation.")
        num_classes = min(model_num_outputs, num_classes)

    # ── Load test data ───────────────────────────────────────────────────
    stanford_images, stanford_labels, stanford_names, stanford_total = \
        load_stanford_test_data(num_images=args.num_images)

    # Build a mapping from Stanford label index -> unified label index
    # by matching cleaned names against the labels file
    label_name_lower = {n.lower(): i for i, n in enumerate(label_names)}
    stanford_to_unified = {}
    unmapped = []
    for si, sname in enumerate(stanford_names):
        if sname.lower() in label_name_lower:
            stanford_to_unified[si] = label_name_lower[sname.lower()]
        else:
            unmapped.append((si, sname))

    if unmapped:
        print(f"\n  WARNING: {len(unmapped)} Stanford breeds not found in labels:")
        for si, sname in unmapped[:5]:
            print(f"    [{si}] {sname}")
        if len(unmapped) > 5:
            print(f"    ... and {len(unmapped) - 5} more")

    # Remap Stanford labels to unified indices; skip unmapped
    all_images = []
    all_labels = []
    for img, lab in zip(stanford_images, stanford_labels):
        if lab in stanford_to_unified:
            all_images.append(img)
            all_labels.append(stanford_to_unified[lab])

    skipped = len(stanford_images) - len(all_images)
    if skipped > 0:
        print(f"  Skipped {skipped} images with unmapped labels")

    # Supplemental data
    supp_count = 0
    if args.include_supplemental:
        supp_images, supp_labels, supp_breeds = \
            load_supplemental_test_data(label_names)
        all_images.extend(supp_images)
        all_labels.extend(supp_labels)
        supp_count = len(supp_images)

    total_images = len(all_images)
    print(f"\n  Total test images: {total_images}")
    if args.include_supplemental:
        print(f"    Stanford: {total_images - supp_count}")
        print(f"    Supplemental: {supp_count}")

    if total_images == 0:
        print("ERROR: No test images loaded. Exiting.")
        sys.exit(1)

    # ── Run inference ────────────────────────────────────────────────────
    print(f"\n{'=' * 72}")
    print("Running inference...")
    print(f"{'=' * 72}")

    all_preds = []
    all_confs = []
    all_top3_correct = 0
    all_top5_correct = 0
    all_entropies = []
    inference_times = []

    for idx, (image, label) in enumerate(zip(all_images, all_labels)):
        # Resize to model input size
        image_resized = tf.image.resize(image, [img_size, img_size])
        image_uint8 = tf.cast(
            tf.clip_by_value(image_resized, 0, 255), tf.uint8
        ).numpy()

        t0 = time.time()
        probs = run_inference(interpreter, input_details, output_details, image_uint8)
        inference_times.append(time.time() - t0)

        pred = int(np.argmax(probs))
        conf = float(probs[pred])
        ent = compute_normalized_entropy(probs)

        all_preds.append(pred)
        all_confs.append(conf)
        all_entropies.append(ent)

        # Top-3 and top-5
        top_k_indices = np.argsort(probs)[::-1]
        if label in top_k_indices[:3]:
            all_top3_correct += 1
        if label in top_k_indices[:5]:
            all_top5_correct += 1

        # Progress
        if (idx + 1) % 500 == 0 or (idx + 1) == total_images:
            elapsed = time.time() - start_time
            correct_so_far = sum(
                1 for p, l in zip(all_preds, all_labels[:idx+1]) if p == l
            )
            acc_so_far = correct_so_far / (idx + 1)
            print(f"  [{idx+1:5d}/{total_images}] "
                  f"acc={acc_so_far*100:.1f}% "
                  f"avg_conf={np.mean(all_confs)*100:.1f}% "
                  f"({elapsed:.0f}s)")

    all_preds = np.array(all_preds)
    all_labels_arr = np.array(all_labels)

    # ── Confusion matrix ─────────────────────────────────────────────────
    print(f"\nComputing confusion matrix ({num_classes}x{num_classes})...")
    cm = np.zeros((num_classes, num_classes), dtype=np.int64)
    for true_label, pred_label in zip(all_labels_arr, all_preds):
        if true_label < num_classes and pred_label < num_classes:
            cm[true_label, pred_label] += 1

    # ── Per-class metrics ────────────────────────────────────────────────
    per_class = compute_per_class_metrics(cm, label_names)

    # ── Aggregate metrics ────────────────────────────────────────────────
    correct = int((all_preds == all_labels_arr).sum())
    overall_accuracy = correct / total_images
    top3_accuracy = all_top3_correct / total_images
    top5_accuracy = all_top5_correct / total_images
    avg_confidence = float(np.mean(all_confs))
    avg_entropy = float(np.mean(all_entropies))
    median_entropy = float(np.median(all_entropies))

    # Per-class accuracy stats
    class_accuracies = [c["accuracy"] for c in per_class if c["support"] > 0]
    mean_per_class_acc = float(np.mean(class_accuracies)) if class_accuracies else 0.0
    median_per_class_acc = float(np.median(class_accuracies)) if class_accuracies else 0.0
    std_per_class_acc = float(np.std(class_accuracies)) if class_accuracies else 0.0

    # Macro-averaged precision, recall, F1
    valid_classes = [c for c in per_class if c["support"] > 0]
    macro_precision = float(np.mean([c["precision"] for c in valid_classes]))
    macro_recall = float(np.mean([c["recall"] for c in valid_classes]))
    macro_f1 = float(np.mean([c["f1"] for c in valid_classes]))

    # Weighted averages (weighted by support)
    total_support = sum(c["support"] for c in valid_classes)
    weighted_precision = sum(
        c["precision"] * c["support"] for c in valid_classes
    ) / total_support if total_support > 0 else 0.0
    weighted_recall = sum(
        c["recall"] * c["support"] for c in valid_classes
    ) / total_support if total_support > 0 else 0.0
    weighted_f1 = sum(
        c["f1"] * c["support"] for c in valid_classes
    ) / total_support if total_support > 0 else 0.0

    # Inference speed
    avg_inference_ms = float(np.mean(inference_times) * 1000)
    p95_inference_ms = float(np.percentile(inference_times, 95) * 1000)

    # ── Top confused pairs ───────────────────────────────────────────────
    confused_pairs = find_top_confused_pairs(
        cm, label_names, top_n=args.top_confused
    )

    # ── Breeds below threshold ───────────────────────────────────────────
    threshold = args.accuracy_threshold
    low_accuracy_breeds = [
        c for c in per_class
        if c["support"] > 0 and c["accuracy"] < threshold
    ]
    low_accuracy_breeds.sort(key=lambda c: c["accuracy"])

    # ── Elapsed time ─────────────────────────────────────────────────────
    total_elapsed = time.time() - start_time

    # ══════════════════════════════════════════════════════════════════════
    # Print formatted summary
    # ══════════════════════════════════════════════════════════════════════
    print(f"\n{'=' * 72}")
    print("EVALUATION RESULTS")
    print(f"{'=' * 72}")
    print(f"  Model:              {args.model}")
    print(f"  Model size:         {model_size_mb:.1f} MB")
    print(f"  Input size:         {img_size}x{img_size}")
    print(f"  Num classes:        {num_classes}")
    print(f"  Test images:        {total_images}")
    print(f"  Evaluation time:    {total_elapsed:.1f}s")

    print(f"\n  {'─' * 50}")
    print(f"  ACCURACY")
    print(f"  {'─' * 50}")
    print(f"  Overall (top-1):    {overall_accuracy*100:.2f}%  ({correct}/{total_images})")
    print(f"  Top-3:              {top3_accuracy*100:.2f}%")
    print(f"  Top-5:              {top5_accuracy*100:.2f}%")
    print(f"  Mean per-class:     {mean_per_class_acc*100:.2f}%")
    print(f"  Median per-class:   {median_per_class_acc*100:.2f}%")
    print(f"  Std per-class:      {std_per_class_acc*100:.2f}%")

    print(f"\n  {'─' * 50}")
    print(f"  PRECISION / RECALL / F1 (macro-averaged)")
    print(f"  {'─' * 50}")
    print(f"  Precision (macro):  {macro_precision*100:.2f}%")
    print(f"  Recall (macro):     {macro_recall*100:.2f}%")
    print(f"  F1 (macro):         {macro_f1*100:.2f}%")
    print(f"  Precision (wt):     {weighted_precision*100:.2f}%")
    print(f"  Recall (wt):        {weighted_recall*100:.2f}%")
    print(f"  F1 (wt):            {weighted_f1*100:.2f}%")

    print(f"\n  {'─' * 50}")
    print(f"  CONFIDENCE & ENTROPY")
    print(f"  {'─' * 50}")
    print(f"  Avg confidence:     {avg_confidence*100:.1f}%")
    print(f"  Min confidence:     {min(all_confs)*100:.1f}%")
    print(f"  Max confidence:     {max(all_confs)*100:.1f}%")
    print(f"  Avg entropy:        {avg_entropy:.4f}")
    print(f"  Median entropy:     {median_entropy:.4f}")

    print(f"\n  {'─' * 50}")
    print(f"  INFERENCE SPEED (per image, CPU)")
    print(f"  {'─' * 50}")
    print(f"  Mean:               {avg_inference_ms:.1f} ms")
    print(f"  P95:                {p95_inference_ms:.1f} ms")

    # Per-class breakdown
    print(f"\n{'=' * 72}")
    print(f"PER-BREED ACCURACY (all {num_classes} breeds)")
    print(f"{'=' * 72}")
    print(f"  {'Idx':>4s}  {'Breed':<35s} {'Acc':>6s} {'Prec':>6s} "
          f"{'Rec':>6s} {'F1':>6s} {'Support':>8s}")
    print(f"  {'─' * 4}  {'─' * 35} {'─' * 6} {'─' * 6} "
          f"{'─' * 6} {'─' * 6} {'─' * 8}")

    for c in per_class:
        if c["support"] == 0:
            continue
        marker = " *** " if c["accuracy"] < threshold else ""
        print(f"  [{c['index']:3d}] {c['name']:<35s} "
              f"{c['accuracy']*100:5.1f}% "
              f"{c['precision']*100:5.1f}% "
              f"{c['recall']*100:5.1f}% "
              f"{c['f1']*100:5.1f}% "
              f"{c['support']:>7d}{marker}")

    # Top confused pairs
    print(f"\n{'=' * 72}")
    print(f"TOP-{args.top_confused} MOST CONFUSED BREED PAIRS")
    print(f"{'=' * 72}")
    for rank, pair in enumerate(confused_pairs, 1):
        print(f"  {rank:2d}. {pair['actual']:<30s} -> {pair['predicted']:<30s} "
              f"({pair['count']} misclassifications)")

    # Low accuracy breeds
    if low_accuracy_breeds:
        print(f"\n{'=' * 72}")
        print(f"BREEDS BELOW {threshold*100:.0f}% ACCURACY "
              f"({len(low_accuracy_breeds)} breeds)")
        print(f"{'=' * 72}")
        for c in low_accuracy_breeds:
            # Find what this breed is most confused with
            row = cm[c["index"]]
            top_confused_idx = np.argsort(row)[::-1]
            confused_with = []
            for j in top_confused_idx:
                if j != c["index"] and row[j] > 0:
                    confused_with.append(
                        f"{label_names[j]}({row[j]})"
                    )
                if len(confused_with) >= 3:
                    break
            confused_str = ", ".join(confused_with) if confused_with else "N/A"
            print(f"  [{c['index']:3d}] {c['name']:<35s} "
                  f"{c['accuracy']*100:5.1f}% "
                  f"(P={c['precision']*100:.0f}% R={c['recall']*100:.0f}% "
                  f"F1={c['f1']*100:.0f}%) "
                  f"confused: {confused_str}")
    else:
        print(f"\n  All breeds at or above {threshold*100:.0f}% accuracy.")

    # ══════════════════════════════════════════════════════════════════════
    # Save confusion matrix
    # ══════════════════════════════════════════════════════════════════════
    if args.save_confusion_matrix:
        cm_path = args.model.replace(".tflite", "_confusion_matrix.npy")
        np.save(cm_path, cm)
        print(f"\n  Confusion matrix saved: {cm_path}")

    # ══════════════════════════════════════════════════════════════════════
    # Build and save JSON report
    # ══════════════════════════════════════════════════════════════════════

    # Determine output path
    if args.output:
        report_path = args.output
    else:
        # Infer version from model filename
        model_basename = os.path.basename(args.model)
        if "_v" in model_basename:
            version = model_basename.split("_v")[-1].replace(".tflite", "")
        elif model_basename == "dog_model.tflite":
            version = "latest"
        else:
            version = "eval"
        report_path = f"evaluate_v{version}_report.json"

    report = {
        "model": {
            "path": args.model,
            "size_mb": model_size_mb,
            "input_size": img_size,
            "num_classes": model_num_outputs,
            "input_dtype": input_details["dtype"].__name__,
            "output_dtype": output_details["dtype"].__name__,
        },
        "dataset": {
            "total_images": total_images,
            "stanford_images": total_images - supp_count,
            "supplemental_images": supp_count,
            "include_supplemental": args.include_supplemental,
        },
        "accuracy": {
            "top1": overall_accuracy,
            "top3": top3_accuracy,
            "top5": top5_accuracy,
            "mean_per_class": mean_per_class_acc,
            "median_per_class": median_per_class_acc,
            "std_per_class": std_per_class_acc,
        },
        "precision_recall_f1": {
            "macro_precision": macro_precision,
            "macro_recall": macro_recall,
            "macro_f1": macro_f1,
            "weighted_precision": weighted_precision,
            "weighted_recall": weighted_recall,
            "weighted_f1": weighted_f1,
        },
        "confidence": {
            "mean": avg_confidence,
            "min": float(min(all_confs)),
            "max": float(max(all_confs)),
            "std": float(np.std(all_confs)),
        },
        "entropy": {
            "mean": avg_entropy,
            "median": median_entropy,
            "std": float(np.std(all_entropies)),
        },
        "inference_speed_ms": {
            "mean": avg_inference_ms,
            "p95": p95_inference_ms,
            "min": float(min(inference_times) * 1000),
            "max": float(max(inference_times) * 1000),
        },
        "top_confused_pairs": confused_pairs,
        "low_accuracy_breeds": [
            {
                "name": c["name"],
                "index": c["index"],
                "accuracy": c["accuracy"],
                "precision": c["precision"],
                "recall": c["recall"],
                "f1": c["f1"],
                "support": c["support"],
            }
            for c in low_accuracy_breeds
        ],
        "per_class_metrics": [
            {
                "name": c["name"],
                "index": c["index"],
                "accuracy": c["accuracy"],
                "precision": c["precision"],
                "recall": c["recall"],
                "f1": c["f1"],
                "support": c["support"],
            }
            for c in per_class
        ],
        "evaluation_time_seconds": total_elapsed,
        "accuracy_threshold": threshold,
    }

    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)

    print(f"\n{'=' * 72}")
    print(f"Report saved: {report_path}")
    print(f"{'=' * 72}")

    # ── Final verdict ────────────────────────────────────────────────────
    print(f"\n{'=' * 72}")
    print("VERDICT")
    print(f"{'=' * 72}")

    checks = []
    passed = True

    if overall_accuracy >= 0.85:
        checks.append(f"  PASS  Top-1 accuracy {overall_accuracy*100:.1f}% >= 85%")
    elif overall_accuracy >= 0.80:
        checks.append(f"  OK    Top-1 accuracy {overall_accuracy*100:.1f}% >= 80% (target: 85%+)")
    else:
        checks.append(f"  WARN  Top-1 accuracy {overall_accuracy*100:.1f}% < 80%")

    if avg_entropy < 0.90:
        checks.append(f"  PASS  Avg entropy {avg_entropy:.4f} < 0.90")
    else:
        checks.append(f"  FAIL  Avg entropy {avg_entropy:.4f} >= 0.90 (near-uniform output)")
        passed = False

    if avg_confidence >= 0.10:
        checks.append(f"  PASS  Avg confidence {avg_confidence*100:.1f}% >= 10%")
    else:
        checks.append(f"  FAIL  Avg confidence {avg_confidence*100:.1f}% < 10% (flattened)")
        passed = False

    if len(low_accuracy_breeds) == 0:
        checks.append(f"  PASS  All breeds >= {threshold*100:.0f}% accuracy")
    elif len(low_accuracy_breeds) <= 10:
        checks.append(f"  WARN  {len(low_accuracy_breeds)} breeds below "
                       f"{threshold*100:.0f}% accuracy")
    else:
        checks.append(f"  WARN  {len(low_accuracy_breeds)} breeds below "
                       f"{threshold*100:.0f}% accuracy (review needed)")

    if macro_f1 >= 0.80:
        checks.append(f"  PASS  Macro F1 {macro_f1*100:.1f}% >= 80%")
    else:
        checks.append(f"  WARN  Macro F1 {macro_f1*100:.1f}% < 80%")

    for check in checks:
        print(check)

    verdict = "PASS" if passed else "FAIL"
    print(f"\n  Overall: {verdict}")
    print(f"{'=' * 72}")

    return report


# ══════════════════════════════════════════════════════════════════════════
# Entry point
# ══════════════════════════════════════════════════════════════════════════
if __name__ == "__main__":
    args = parse_args()
    run_evaluation(args)
