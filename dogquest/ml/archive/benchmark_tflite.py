"""
benchmark_tflite.py — Benchmark all TFLite dog breed models.

For each model in assets/dog_model_*.tflite (plus dog_model.tflite):
  - Top-1 / Top-3 accuracy (TFLite, not Keras)
  - Average inference time (ms)
  - Average top-1 confidence
  - Average normalized entropy
  - Quantization accuracy drop (compared to Keras results in comparison_results.json)

Usage:
  python benchmark_tflite.py
  python benchmark_tflite.py --num-images 200
  python benchmark_tflite.py --models assets/dog_model.tflite assets/dog_model_nasnetmobile.tflite
"""
import os
import json
import time
import argparse
import numpy as np

os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"

import tensorflow as tf
import tensorflow_datasets as tfds


def parse_args():
    parser = argparse.ArgumentParser(description="TFLite model benchmark")
    parser.add_argument("--models", nargs="*", default=None,
                        help="Specific model paths (default: auto-discover)")
    parser.add_argument("--num-images", type=int, default=100,
                        help="Number of test images")
    parser.add_argument("--results-file", default="assets/comparison_results.json",
                        help="Keras results for quant drop calculation")
    parser.add_argument("--output", default="assets/benchmark_results.json",
                        help="Output benchmark results JSON")
    return parser.parse_args()


def discover_models(output_dir="assets"):
    """Find all TFLite dog models."""
    import glob
    models = glob.glob(os.path.join(output_dir, "dog_model*.tflite"))
    return sorted(models)


def load_tflite(model_path):
    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()[0]
    output_details = interpreter.get_output_details()[0]
    return interpreter, input_details, output_details


def infer(interpreter, input_details, output_details, image_uint8):
    if image_uint8.dtype != np.uint8:
        image_uint8 = np.clip(image_uint8, 0, 255).astype(np.uint8)
    if len(image_uint8.shape) == 3:
        image_uint8 = np.expand_dims(image_uint8, 0)

    interpreter.set_tensor(input_details["index"], image_uint8)
    interpreter.invoke()
    raw = interpreter.get_tensor(output_details["index"])[0]

    if output_details["dtype"] == np.uint8:
        return raw.astype(np.float32) / 255.0
    return raw.astype(np.float32)


def normalized_entropy(probs):
    n = len(probs)
    probs = np.clip(probs, 1e-10, 1.0)
    probs = probs / probs.sum()
    h = -np.sum(probs * np.log(probs))
    return h / np.log(n)


def benchmark_model(model_path, test_images, test_labels):
    """Benchmark a single TFLite model. Returns metrics dict."""
    if not os.path.exists(model_path):
        print(f"  [SKIP] {model_path} not found")
        return None

    interpreter, input_det, output_det = load_tflite(model_path)
    img_size = input_det["shape"][1]
    model_size = os.path.getsize(model_path) / (1024 * 1024)

    correct = 0
    top3_correct = 0
    total = 0
    confidences = []
    entropies = []
    inference_times = []

    for image, label in zip(test_images, test_labels):
        img_resized = tf.image.resize(image, [img_size, img_size])
        img_uint8 = tf.cast(tf.clip_by_value(img_resized, 0, 255), tf.uint8).numpy()

        t0 = time.perf_counter()
        probs = infer(interpreter, input_det, output_det, img_uint8)
        t1 = time.perf_counter()

        pred = np.argmax(probs)
        conf = probs[pred]
        ent = normalized_entropy(probs)

        if pred == label:
            correct += 1
        if label in np.argsort(probs)[-3:]:
            top3_correct += 1

        confidences.append(float(conf))
        entropies.append(float(ent))
        inference_times.append((t1 - t0) * 1000)
        total += 1

    return {
        "model_path": model_path,
        "model_size_mb": round(model_size, 2),
        "input_size": img_size,
        "num_images": total,
        "top1_accuracy": round(correct / total, 4) if total else 0,
        "top3_accuracy": round(top3_correct / total, 4) if total else 0,
        "avg_confidence": round(float(np.mean(confidences)), 4),
        "avg_entropy": round(float(np.mean(entropies)), 4),
        "median_entropy": round(float(np.median(entropies)), 4),
        "avg_inference_ms": round(float(np.mean(inference_times)), 2),
        "p95_inference_ms": round(float(np.percentile(inference_times, 95)), 2),
    }


def main():
    args = parse_args()

    print("=" * 70)
    print("TFLite Model Benchmark")
    print("=" * 70)

    # Discover models
    if args.models:
        model_paths = args.models
    else:
        model_paths = discover_models()

    if not model_paths:
        print("No TFLite models found in assets/")
        return

    print(f"\nModels to benchmark: {len(model_paths)}")
    for p in model_paths:
        print(f"  - {p}")

    # Load Keras results for quant drop
    keras_results = {}
    if os.path.exists(args.results_file):
        with open(args.results_file) as f:
            for r in json.load(f):
                keras_results[r.get("backbone", "")] = r.get("keras_accuracy", 0)

    # Load test images
    print(f"\nLoading {args.num_images} test images from Stanford Dogs...")
    ds_test_raw, info = tfds.load(
        "stanford_dogs", split="test", as_supervised=False, with_info=True,
    )

    test_images = []
    test_labels = []
    count = 0
    for example in ds_test_raw:
        if count >= args.num_images:
            break
        image = example["image"]
        label = example["label"].numpy()

        # Bbox crop for consistency
        bbox = example["objects"]["bbox"]
        if tf.shape(bbox)[0] > 0:
            shape = tf.shape(image)
            h = tf.cast(shape[0], tf.float32)
            w = tf.cast(shape[1], tf.float32)
            b = bbox[0]
            ymin = tf.maximum(b[0] - (b[2]-b[0])*0.15, 0.0)
            xmin = tf.maximum(b[1] - (b[3]-b[1])*0.15, 0.0)
            ymax = tf.minimum(b[2] + (b[2]-b[0])*0.15, 1.0)
            xmax = tf.minimum(b[3] + (b[3]-b[1])*0.15, 1.0)
            y1 = tf.cast(tf.round(ymin * h), tf.int32)
            x1 = tf.cast(tf.round(xmin * w), tf.int32)
            y2 = tf.cast(tf.round(ymax * h), tf.int32)
            x2 = tf.cast(tf.round(xmax * w), tf.int32)
            crop_h = tf.maximum(y2 - y1, 10)
            crop_w = tf.maximum(x2 - x1, 10)
            y1 = tf.maximum(tf.minimum(y1, shape[0] - crop_h), 0)
            x1 = tf.maximum(tf.minimum(x1, shape[1] - crop_w), 0)
            image = tf.image.crop_to_bounding_box(image, y1, x1, crop_h, crop_w)

        test_images.append(tf.cast(image, tf.float32))
        test_labels.append(label)
        count += 1

    print(f"  Loaded {len(test_images)} test images")

    # Benchmark each model
    all_results = []
    for model_path in model_paths:
        print(f"\nBenchmarking: {model_path}")
        result = benchmark_model(model_path, test_images, test_labels)
        if result is None:
            continue

        # Try to find Keras accuracy for quant drop
        basename = os.path.basename(model_path)
        for backbone_name, keras_acc in keras_results.items():
            if backbone_name in basename:
                result["keras_accuracy"] = keras_acc
                result["quant_accuracy_drop"] = round(keras_acc - result["top1_accuracy"], 4)
                break

        all_results.append(result)

    # Print comparison table
    print(f"\n{'=' * 100}")
    print("BENCHMARK RESULTS")
    print(f"{'=' * 100}")

    header = (f"{'Model':<40s} {'Size':>6s} {'Input':>5s} "
              f"{'Top-1':>6s} {'Top-3':>6s} {'Conf':>6s} "
              f"{'Entropy':>8s} {'Infer(ms)':>10s} {'Q.Drop':>7s}")
    print(header)
    print("-" * 100)

    for r in sorted(all_results, key=lambda x: -x["top1_accuracy"]):
        basename = os.path.basename(r["model_path"])
        qdrop = f"{r.get('quant_accuracy_drop', 0)*100:+.1f}%" if "quant_accuracy_drop" in r else "N/A"
        row = (f"{basename:<40s} {r['model_size_mb']:>5.1f}M {r['input_size']:>4d}px "
               f"{r['top1_accuracy']*100:>5.1f}% {r['top3_accuracy']*100:>5.1f}% "
               f"{r['avg_confidence']*100:>5.1f}% "
               f"{r['avg_entropy']:>7.4f} {r['avg_inference_ms']:>9.1f}ms {qdrop:>7s}")
        print(row)

    # Determine winner
    eligible = [r for r in all_results
                if r["model_size_mb"] < 10.0 and r["avg_entropy"] < 0.90]
    if eligible:
        winner = max(eligible, key=lambda x: x["top1_accuracy"])
        print(f"\n  WINNER (size<10MB, entropy<0.90): {os.path.basename(winner['model_path'])}")
        print(f"    Top-1: {winner['top1_accuracy']*100:.1f}%, "
              f"Size: {winner['model_size_mb']:.1f}MB, "
              f"Entropy: {winner['avg_entropy']:.4f}")
    else:
        print("\n  WARNING: No model meets criteria (size<10MB, entropy<0.90)")

    # Save results
    with open(args.output, "w") as f:
        json.dump(all_results, f, indent=2)
    print(f"\nResults saved to: {args.output}")


if __name__ == "__main__":
    main()
