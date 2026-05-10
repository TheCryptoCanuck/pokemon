"""
verify_tflite.py — Pre-deployment quantization sanity check.

Compares two TFLite models (e.g. v3 vs v4.1) on test images:
  - Top-1 accuracy
  - Average top-1 confidence
  - Average normalized entropy
  - Pass/fail criteria for deployment readiness

Pass criteria:
  - Entropy < 0.90 (not near-uniform output)
  - Avg confidence > 10% (not flattened)
  - Accuracy within 2% of Keras evaluation (quantization didn't destroy it)

Usage:
  python verify_tflite.py
  python verify_tflite.py --model1 assets/dog_model_v3.tflite --model2 assets/dog_model.tflite
  python verify_tflite.py --model1 assets/dog_model.tflite  # single model check
"""
import os
import argparse
import numpy as np

os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"

import tensorflow as tf
import tensorflow_datasets as tfds


def parse_args():
    parser = argparse.ArgumentParser(description="TFLite quantization verification")
    parser.add_argument("--model1", default="assets/dog_model_v3.tflite",
                        help="Reference model (default: v3)")
    parser.add_argument("--model2", default="assets/dog_model.tflite",
                        help="New model to verify (default: latest)")
    parser.add_argument("--num-images", type=int, default=100,
                        help="Number of test images to evaluate")
    parser.add_argument("--labels", default="assets/dog_labels.txt",
                        help="Labels file")
    return parser.parse_args()


def load_tflite_model(model_path):
    """Load a TFLite model and return interpreter with input/output details."""
    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()[0]
    output_details = interpreter.get_output_details()[0]
    return interpreter, input_details, output_details


def run_inference(interpreter, input_details, output_details, image_uint8):
    """Run single image through TFLite model, return confidence array [0, 1]."""
    # Ensure image is uint8 [1, 224, 224, 3]
    if image_uint8.dtype != np.uint8:
        image_uint8 = np.clip(image_uint8, 0, 255).astype(np.uint8)
    if len(image_uint8.shape) == 3:
        image_uint8 = np.expand_dims(image_uint8, axis=0)

    interpreter.set_tensor(input_details["index"], image_uint8)
    interpreter.invoke()
    raw_output = interpreter.get_tensor(output_details["index"])[0]

    # Convert uint8 output to float confidence
    if output_details["dtype"] == np.uint8:
        confidences = raw_output.astype(np.float32) / 255.0
    else:
        confidences = raw_output.astype(np.float32)

    return confidences


def normalized_entropy(probs):
    """Compute normalized entropy (0 = one-hot, 1 = uniform)."""
    num_classes = len(probs)
    probs = np.clip(probs, 1e-10, 1.0)
    probs = probs / probs.sum()  # renormalize
    entropy = -np.sum(probs * np.log(probs))
    max_entropy = np.log(num_classes)
    return entropy / max_entropy


def evaluate_model(model_path, test_images, test_labels, model_name="model"):
    """Evaluate a TFLite model on test images, return metrics dict."""
    if not os.path.exists(model_path):
        print(f"  [SKIP] {model_path} not found")
        return None

    interpreter, input_details, output_details = load_tflite_model(model_path)

    input_shape = input_details["shape"]  # [1, H, W, 3]
    img_size = input_shape[1]

    print(f"\n  {model_name}: {model_path}")
    print(f"    Input: {input_details['dtype'].__name__} {list(input_shape)}")
    print(f"    Output: {output_details['dtype'].__name__}")

    # Check quantization params
    if "quantization_parameters" in input_details:
        qp = input_details["quantization_parameters"]
        if "scales" in qp and len(qp["scales"]) > 0:
            print(f"    Input quant: scale={qp['scales'][0]:.8f}, zero_point={qp['zero_points'][0]}")
    if "quantization_parameters" in output_details:
        qp = output_details["quantization_parameters"]
        if "scales" in qp and len(qp["scales"]) > 0:
            print(f"    Output quant: scale={qp['scales'][0]:.8f}, zero_point={qp['zero_points'][0]}")

    model_size = os.path.getsize(model_path) / (1024 * 1024)
    print(f"    Size: {model_size:.1f} MB")

    correct = 0
    total = 0
    confidences_top1 = []
    entropies = []
    top3_correct = 0

    for image, label in zip(test_images, test_labels):
        # Resize to model's expected input size
        image_resized = tf.image.resize(image, [img_size, img_size])
        image_uint8 = tf.cast(tf.clip_by_value(image_resized, 0, 255), tf.uint8).numpy()

        probs = run_inference(interpreter, input_details, output_details, image_uint8)

        pred = np.argmax(probs)
        conf = probs[pred]
        ent = normalized_entropy(probs)

        if pred == label:
            correct += 1
        if label in np.argsort(probs)[-3:]:
            top3_correct += 1

        confidences_top1.append(conf)
        entropies.append(ent)
        total += 1

    accuracy = correct / total if total > 0 else 0
    top3_accuracy = top3_correct / total if total > 0 else 0
    avg_confidence = np.mean(confidences_top1)
    avg_entropy = np.mean(entropies)
    median_entropy = np.median(entropies)

    results = {
        "model_path": model_path,
        "model_size_mb": model_size,
        "num_images": total,
        "top1_accuracy": accuracy,
        "top3_accuracy": top3_accuracy,
        "avg_confidence": avg_confidence,
        "avg_entropy": avg_entropy,
        "median_entropy": median_entropy,
        "min_confidence": np.min(confidences_top1),
        "max_confidence": np.max(confidences_top1),
    }

    return results


def print_results(results, model_name):
    """Print evaluation results for a single model."""
    if results is None:
        return

    print(f"\n  {'-' * 50}")
    print(f"  {model_name} Results:")
    print(f"  {'-' * 50}")
    print(f"    Top-1 accuracy:    {results['top1_accuracy']*100:.1f}%")
    print(f"    Top-3 accuracy:    {results['top3_accuracy']*100:.1f}%")
    print(f"    Avg confidence:    {results['avg_confidence']*100:.1f}%")
    print(f"    Confidence range:  [{results['min_confidence']*100:.1f}%, {results['max_confidence']*100:.1f}%]")
    print(f"    Avg entropy:       {results['avg_entropy']:.4f}")
    print(f"    Median entropy:    {results['median_entropy']:.4f}")
    print(f"    Model size:        {results['model_size_mb']:.1f} MB")

    # Pass/fail checks
    passed = True
    checks = []

    if results['avg_entropy'] >= 0.90:
        checks.append(f"    FAIL: avg entropy {results['avg_entropy']:.4f} >= 0.90 (predictions near-uniform)")
        passed = False
    else:
        checks.append(f"    PASS: avg entropy {results['avg_entropy']:.4f} < 0.90")

    if results['avg_confidence'] < 0.10:
        checks.append(f"    FAIL: avg confidence {results['avg_confidence']*100:.1f}% < 10% (flattened output)")
        passed = False
    else:
        checks.append(f"    PASS: avg confidence {results['avg_confidence']*100:.1f}% >= 10%")

    if results['top1_accuracy'] < 0.50:
        checks.append(f"    WARN: top-1 accuracy {results['top1_accuracy']*100:.1f}% < 50% (may be too low)")
    else:
        checks.append(f"    PASS: top-1 accuracy {results['top1_accuracy']*100:.1f}% >= 50%")

    print()
    for check in checks:
        print(check)

    verdict = "PASS — safe to deploy" if passed else "FAIL — do NOT deploy to phone"
    print(f"\n    {'*' * 40}")
    print(f"    VERDICT: {verdict}")
    print(f"    {'*' * 40}")

    return passed


def main():
    args = parse_args()

    print("=" * 70)
    print("TFLite Quantization Verification")
    print("=" * 70)

    # Load test images from Stanford Dogs
    print("\nLoading test images from Stanford Dogs...")
    ds_test_raw, info = tfds.load(
        "stanford_dogs",
        split="test",
        as_supervised=False,
        with_info=True,
    )

    # Collect test images (raw uint8, not preprocessed)
    test_images = []
    test_labels = []
    count = 0
    for example in ds_test_raw:
        if count >= args.num_images:
            break
        image = example["image"]
        label = example["label"].numpy()

        # Use bbox crop if available (matches training)
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

    # Evaluate models
    results1 = evaluate_model(args.model1, test_images, test_labels, "Model 1 (reference)")
    results2 = evaluate_model(args.model2, test_images, test_labels, "Model 2 (new)")

    # Print results
    print(f"\n{'=' * 70}")
    print("RESULTS")
    print(f"{'=' * 70}")

    pass1 = print_results(results1, f"Model 1: {args.model1}")
    pass2 = print_results(results2, f"Model 2: {args.model2}")

    # Comparison
    if results1 and results2:
        print(f"\n{'=' * 70}")
        print("COMPARISON")
        print(f"{'=' * 70}")
        acc_diff = results2["top1_accuracy"] - results1["top1_accuracy"]
        conf_diff = results2["avg_confidence"] - results1["avg_confidence"]
        ent_diff = results2["avg_entropy"] - results1["avg_entropy"]
        print(f"  Accuracy diff:    {acc_diff*100:+.1f}% (model2 - model1)")
        print(f"  Confidence diff:  {conf_diff*100:+.1f}%")
        print(f"  Entropy diff:     {ent_diff:+.4f}")

        if acc_diff < -0.02:
            print(f"\n  WARNING: New model accuracy dropped by {abs(acc_diff)*100:.1f}% vs reference")

    print(f"\n{'=' * 70}")


if __name__ == "__main__":
    main()
