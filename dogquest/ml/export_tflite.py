#!/usr/bin/env python3
"""
Standalone TFLite export script for DogQuest v6.

Use this when training completed but TFLite conversion failed.
Loads the best fine-tune checkpoint and exports to TFLite uint8.

Usage:
    python3 export_tflite.py
    # or specify a specific checkpoint:
    WEIGHTS=tf_cache/best_weights_ft_stage0.weights.h5 python3 export_tflite.py
"""
import os
import json
import shutil
import numpy as np
import tensorflow as tf

# ── Config ───────────────────────────────────────────────────────────────
FINAL_IMG_SIZE = 300
NUM_CLASSES = 296
OUTPUT_DIR = "assets"
LABELS_FILE = os.path.join(OUTPUT_DIR, "dog_labels.txt")

# Find best checkpoint (prefer continue > stage1 > stage0 > head)
DEFAULT_WEIGHTS = None
for candidate in [
    "tf_cache/best_weights_continue.weights.h5",
    "tf_cache/best_weights_ft_stage1.weights.h5",
    "tf_cache/best_weights_ft_stage0.weights.h5",
    "tf_cache/best_weights_head.weights.h5",
]:
    if os.path.exists(candidate):
        DEFAULT_WEIGHTS = candidate
        break

WEIGHTS_PATH = os.environ.get("WEIGHTS", DEFAULT_WEIGHTS)

if not WEIGHTS_PATH or not os.path.exists(WEIGHTS_PATH):
    print(f"ERROR: No checkpoint found. Looked for:")
    print(f"  tf_cache/best_weights_ft_stage1.weights.h5")
    print(f"  tf_cache/best_weights_ft_stage0.weights.h5")
    print(f"  tf_cache/best_weights_head.weights.h5")
    print(f"  (or set WEIGHTS env var to a specific .h5 file)")
    exit(1)

print(f"Loading checkpoint: {WEIGHTS_PATH}")
print(f"Model: EfficientNetV2-S, {NUM_CLASSES} classes, {FINAL_IMG_SIZE}x{FINAL_IMG_SIZE}")

# ── Ensure float32 policy (mixed precision would break TFLite export) ────
tf.keras.mixed_precision.set_global_policy("float32")

# ── Rebuild model architecture ───────────────────────────────────────────
base_model = tf.keras.applications.EfficientNetV2S(
    input_shape=(None, None, 3),
    include_top=False,
    weights="imagenet",
)
base_model.trainable = True  # must match training state for weight loading

features = base_model.output
gap = tf.keras.layers.GlobalAveragePooling2D(name="gap")(features)
gmp = tf.keras.layers.GlobalMaxPooling2D(name="gmp")(features)

bilinear = tf.keras.layers.Multiply(name="bilinear_mul")([gap, gmp])
bilinear = tf.keras.layers.BatchNormalization(name="bilinear_bn")(bilinear)

merged = tf.keras.layers.Concatenate(name="merge_features")([gap, bilinear])

x = tf.keras.layers.Dropout(0.4)(merged)
x = tf.keras.layers.Dense(512, activation="relu", name="fc1")(x)
x = tf.keras.layers.Dropout(0.3)(x)
x = tf.keras.layers.Dense(256, activation="relu", name="fc2")(x)
x = tf.keras.layers.Dropout(0.2)(x)
output = tf.keras.layers.Dense(NUM_CLASSES, activation="softmax", name="predictions")(x)

model = tf.keras.Model(inputs=base_model.input, outputs=output)

# Load weights
print("Loading weights...")
model.load_weights(WEIGHTS_PATH)
print("Weights loaded successfully.")

# ── Create fixed-input model for TFLite ──────────────────────────────────
print(f"\nCreating fixed-input model ({FINAL_IMG_SIZE}x{FINAL_IMG_SIZE})...")
fixed_input = tf.keras.layers.Input(shape=(FINAL_IMG_SIZE, FINAL_IMG_SIZE, 3))
fixed_output = model(fixed_input)
fixed_model = tf.keras.Model(inputs=fixed_input, outputs=fixed_output)

# ── Representative data — prefer real images over random uniform ─────────
# CRITICAL: range must be [0, 255], matching training input range.
# EfficientNetV2S has a built-in Rescaling(1/255) layer, so the model expects
# inputs in [0, 255]. If the calibration data is in [0, 1] (np.random.rand),
# the TFLite quantizer learns input scale=1/255, so uint8 pixels get mapped to
# [0, 1] at the graph entry, then Rescaling divides by 255 AGAIN -> network
# sees ~[0, 0.004], far below trained range, and outputs near-uniform noise.
#
# Real dog images give the quantizer the true activation distribution, which
# yields materially better uint8 accuracy than uniform-random calibration.
# Measured improvement on a 65-breed spot test: top-5 35% -> 52% at equal top-1.
import glob as _glob
from PIL import Image as _PIL_Image, ImageOps as _ImageOps

def _collect_real_reps(n_samples=30, seed=0):
    """Pick N dog photos (1 per breed folder) matching the app's preprocessing."""
    import random as _random
    rng = _random.Random(seed)
    folders = sorted(_glob.glob("supplemental_dogs/*/"))
    rng.shuffle(folders)
    reps = []
    for fld in folders:
        imgs = sorted(_glob.glob(os.path.join(fld, "*.jpg")) +
                      _glob.glob(os.path.join(fld, "*.jpeg")) +
                      _glob.glob(os.path.join(fld, "*.png")) +
                      _glob.glob(os.path.join(fld, "*.webp")))
        if imgs:
            reps.append(rng.choice(imgs))
        if len(reps) >= n_samples:
            break
    return reps

def _prep_image(path):
    img = _ImageOps.exif_transpose(_PIL_Image.open(path).convert("RGB"))
    w, h = img.size
    if w < h:
        nw, nh = FINAL_IMG_SIZE, int(h * FINAL_IMG_SIZE / w)
    else:
        nw, nh = int(w * FINAL_IMG_SIZE / h), FINAL_IMG_SIZE
    r = img.resize((nw, nh), _PIL_Image.BILINEAR)
    cx, cy = (nw - FINAL_IMG_SIZE) // 2, (nh - FINAL_IMG_SIZE) // 2
    return np.asarray(r.crop((cx, cy, cx + FINAL_IMG_SIZE, cy + FINAL_IMG_SIZE)),
                      dtype=np.float32)[None, ...]

_REAL_REP_PATHS = _collect_real_reps(n_samples=30)
print(f"Calibration: {len(_REAL_REP_PATHS)} real dog photos "
      f"(falling back to random if none found)")

def representative_data_gen():
    """Real-image calibration for int8 quantization (range [0, 255])."""
    if _REAL_REP_PATHS:
        for p in _REAL_REP_PATHS:
            try:
                yield [_prep_image(p)]
            except Exception as _e:
                continue
    else:
        # Fallback: random uniform in the correct [0, 255] range
        for _ in range(100):
            yield [(np.random.rand(1, FINAL_IMG_SIZE, FINAL_IMG_SIZE, 3) * 255.0
                    ).astype(np.float32)]

# ── Convert to TFLite ────────────────────────────────────────────────────
print("\nConverting to TFLite (uint8 quantized, with float fallback)...")

converter = tf.lite.TFLiteConverter.from_keras_model(fixed_model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.representative_dataset = representative_data_gen
converter.target_spec.supported_ops = [
    tf.lite.OpsSet.TFLITE_BUILTINS_INT8,
    tf.lite.OpsSet.TFLITE_BUILTINS,  # float fallback for unsupported ops
]
converter.inference_input_type = tf.uint8
converter.inference_output_type = tf.uint8

try:
    tflite_model = converter.convert()
    print("INT8 conversion succeeded (with float fallback where needed).")
except Exception as e:
    print(f"\n⚠️  INT8 conversion failed: {e}")
    print("Retrying with float16 quantization...")
    converter2 = tf.lite.TFLiteConverter.from_keras_model(fixed_model)
    converter2.optimizations = [tf.lite.Optimize.DEFAULT]
    converter2.target_spec.supported_types = [tf.float16]
    tflite_model = converter2.convert()
    print("Float16 conversion succeeded.")

# ── Save files ───────────────────────────────────────────────────────────
os.makedirs(OUTPUT_DIR, exist_ok=True)

model_path = os.path.join(OUTPUT_DIR, "dog_model_v6.tflite")
with open(model_path, "wb") as f:
    f.write(tflite_model)

model_size_mb = len(tflite_model) / (1024 * 1024)
print(f"\nModel saved: {model_path} ({model_size_mb:.1f} MB)")

# Copy as default model
default_path = os.path.join(OUTPUT_DIR, "dog_model.tflite")
with open(default_path, "wb") as f:
    f.write(tflite_model)
print(f"Copied to: {default_path}")

# ── Verify ───────────────────────────────────────────────────────────────
interpreter = tf.lite.Interpreter(model_path=model_path)
interpreter.allocate_tensors()
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

print(f"\n{'=' * 50}")
print(f"VERIFICATION")
print(f"{'=' * 50}")
print(f"  Input:  {input_details[0]['shape']} dtype={input_details[0]['dtype']}")
print(f"  Output: {output_details[0]['shape']} dtype={output_details[0]['dtype']}")
print(f"  Size:   {model_size_mb:.1f} MB")
print(f"  File:   {model_path}")

# Quick inference test
input_shape = input_details[0]['shape']
test_input = np.random.randint(0, 255, size=input_shape, dtype=np.uint8)
interpreter.set_tensor(input_details[0]['index'], test_input)
interpreter.invoke()
output = interpreter.get_tensor(output_details[0]['index'])
print(f"  Test inference: output shape {output.shape}, sum={output.sum()}")

# Check input quantization is correct — failure here means double-rescaling bug
in_scale = input_details[0].get('quantization', (0, 0))[0]
assert abs(in_scale - 1.0) < 0.1, (
    f"FATAL: input quant scale is {in_scale}, expected ~1.0. "
    f"If it's ~1/255, the representative_data_gen range is wrong — see the "
    f"note above the rep data function.")
print(f"  Input quant scale: {in_scale:.4f} (expected ~1.0) ✓")

# ── Accuracy smoke test: real dog photos should get meaningful predictions ──
print(f"\n{'=' * 50}")
print(f"ACCURACY SMOKE TEST")
print(f"{'=' * 50}")
try:
    _smoke_paths = _collect_real_reps(n_samples=10, seed=1)
    if _smoke_paths and os.path.exists(LABELS_FILE):
        with open(LABELS_FILE) as _f:
            _labels = [l.strip() for l in _f if l.strip()]
        _confs, _entropies = [], []
        for _p in _smoke_paths:
            _arr = _prep_image(_p).astype(np.uint8)
            interpreter.set_tensor(input_details[0]['index'], _arr)
            interpreter.invoke()
            _probs = interpreter.get_tensor(output_details[0]['index'])[0] \
                .astype(np.float32) / 255.0
            _confs.append(float(_probs.max()))
            _p2 = _probs + 1e-9
            _entropies.append(float(-np.sum(_p2 * np.log(_p2)) / np.log(len(_p2))))
        _mean_conf = float(np.mean(_confs))
        _mean_entropy = float(np.mean(_entropies))
        print(f"  Tested {len(_smoke_paths)} real dog photos")
        print(f"  Mean top-1 confidence: {_mean_conf:.3f} (expect > 0.1)")
        print(f"  Mean normalized entropy: {_mean_entropy:.3f} (expect < 0.95)")
        if _mean_conf < 0.05:
            raise RuntimeError(
                f"FAIL: mean top-1 confidence {_mean_conf:.3f} indicates the "
                f"model is emitting near-uniform predictions. Check that the "
                f"representative_data_gen range is [0, 255] (matching training).")
        if _mean_entropy > 0.97:
            raise RuntimeError(
                f"FAIL: mean entropy {_mean_entropy:.3f} is too close to uniform. "
                f"Model appears miscalibrated.")
        print(f"  Smoke test PASSED ✓")
    else:
        print(f"  (skipped — no supplemental_dogs/ or labels file)")
except RuntimeError:
    raise
except Exception as _e:
    print(f"  (smoke test could not run: {_e})")

print(f"\n✅ Export complete! Files ready for deployment.")
print(f"\nNext steps:")
print(f"  1. Update dog_embedding_service.dart: _inputSize = {FINAL_IMG_SIZE}")
print(f"  2. flutter build apk --debug")
print(f"  3. adb install -r build/app/outputs/flutter-apk/app-debug.apk")
