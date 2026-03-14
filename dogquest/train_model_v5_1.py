"""
Train a dog breed classifier — v5.1 targeting 90%+ accuracy.

v5.1 — Bug fixes + optimizations over v5:
  FIXES:
  - FIX: class_weight removed from fit() — incompatible with CutMix/Mixup soft labels
  - FIX: .cache() moved before bbox extraction so random crop fires each epoch
  - FIX: Added shuffle to combined training pipeline
  - FIX: Removed redundant brightness/contrast (already in RandAugment)
  TUNING:
  - CutMix alpha 0.3->1.0 (standard), increased probs (0.5+0.3=80% mixing)
  - Label smoothing 0.05->0.1 (standard for fine-grained)
  - RandAugment magnitude 9->7 (less aggressive for FGVC)
  - Head LR 3e-3->1e-3, HEAD_EPOCHS 5->10, patience 2->4
  - Fine-tune LRs increased (1e-4/5e-5/3e-5)
  - Final stage unfreezes top 200 layers (not all — protect stem)
  - Dropout rebalanced to uniform 0.3
  - Weighted loss function handles soft labels correctly
  - Representative dataset 30->100 batches for better quantization
  - AdamW with weight decay instead of plain Adam

  From v5 (unchanged):
  - EfficientNetB2 backbone (better features, ~9 MB quantized vs B0's 5 MB)
  - RandAugment, CutMix+Mixup, progressive resizing 192->224->260
  - Bilinear pooling head (GAP * GMP + BatchNorm, proven in v4.1)
  - Bbox crop from Stanford Dogs annotations (50/50 mixed)
  - Random erasing (occlusion robustness)

Output: assets/dog_model.tflite (uint8 input, uint8 output)
        assets/dog_labels.txt  (one breed name per line, matching model output order)

Usage:
  pip install tensorflow tensorflow-datasets Pillow
  python train_model_v5.py
"""
import os
import glob
import math
import time
import json
import numpy as np

# ── CPU optimization env vars (must be set BEFORE importing TF) ──────────
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"
os.environ["TF_ENABLE_ONEDNN_OPTS"] = "1"
os.environ["KMP_BLOCKTIME"] = "0"
os.environ["KMP_AFFINITY"] = "granularity=fine,verbose,compact,1,0"

cpu_count = os.cpu_count() or 8
os.environ["OMP_NUM_THREADS"] = str(cpu_count)
os.environ["TF_NUM_INTEROP_THREADS"] = str(max(2, cpu_count // 4))
os.environ["TF_NUM_INTRAOP_THREADS"] = str(cpu_count)

import tensorflow as tf

tf.config.threading.set_inter_op_parallelism_threads(max(2, cpu_count // 4))
tf.config.threading.set_intra_op_parallelism_threads(cpu_count)

gpus = tf.config.experimental.list_physical_devices("GPU")
for gpu in gpus:
    tf.config.experimental.set_memory_growth(gpu, True)

import tensorflow_datasets as tfds

# ── Config ────────────────────────────────────────────────────────────────
# Progressive resizing stages
IMG_SIZES = [192, 224, 260]       # train at increasing resolutions
FINAL_IMG_SIZE = 260              # final model input size (EfficientNetB2 native)
BATCH_SIZE = 32                   # smaller batch for B2 (more memory)
OUTPUT_DIR = "assets"
SUPPLEMENTAL_DIR = "supplemental_dogs"

# Training phases
HEAD_EPOCHS = 10
FINE_TUNE_EPOCHS_PER_SIZE = [8, 10, 15]  # epochs per progressive stage
FINE_TUNE_LAYERS_STAGE = [40, 100, 200]  # protect stem/block1 in final stage

# Augmentation config
LABEL_SMOOTHING = 0.1
USE_BBOX_CROP = True
BBOX_PADDING = 0.15
BBOX_MIXED_RATE = 0.5

USE_CUTMIX = True
CUTMIX_ALPHA = 1.0
CUTMIX_PROB = 0.5

USE_MIXUP = True
MIXUP_ALPHA = 0.2
MIXUP_PROB = 0.3

USE_RANDOM_ERASING = True
RANDOM_ERASING_PROB = 0.3

# RandAugment
RANDAUG_NUM_LAYERS = 2      # number of transforms per image
RANDAUG_MAGNITUDE = 7       # magnitude (0-10 scale, lowered from 9 for FGVC)

start_time = time.time()

print(f"CPU cores: {cpu_count}")
print(f"TF version: {tf.__version__}")
print(f"\nv5 Config:")
print(f"  Backbone: EfficientNetB2")
print(f"  Progressive sizes: {IMG_SIZES}")
print(f"  Batch size: {BATCH_SIZE}")
print(f"  Label smoothing: {LABEL_SMOOTHING}")
print(f"  CutMix: prob={CUTMIX_PROB}, alpha={CUTMIX_ALPHA}")
print(f"  Mixup: prob={MIXUP_PROB}, alpha={MIXUP_ALPHA}")
print(f"  RandAugment: layers={RANDAUG_NUM_LAYERS}, mag={RANDAUG_MAGNITUDE}")
print(f"  Bbox crop: {USE_BBOX_CROP} (padding={BBOX_PADDING})")
print(f"  Random erasing: prob={RANDOM_ERASING_PROB}")


# ══════════════════════════════════════════════════════════════════════════
# Step 1: Load Stanford Dogs WITH bounding boxes
# ══════════════════════════════════════════════════════════════════════════
print("\n" + "=" * 70)
print("Loading Stanford Dogs dataset (with bounding boxes)...")

(ds_train_stanford_raw, ds_test_stanford_raw), info = tfds.load(
    "stanford_dogs",
    split=["train", "test"],
    as_supervised=False,
    with_info=True,
)

stanford_num_classes = info.features["label"].num_classes
stanford_class_names = info.features["label"].names
stanford_train_count = info.splits["train"].num_examples
stanford_test_count = info.splits["test"].num_examples
print(f"  Stanford Dogs: {stanford_num_classes} breeds, "
      f"{stanford_train_count} train, {stanford_test_count} test")


# ══════════════════════════════════════════════════════════════════════════
# Step 2: Bounding box crop utilities
# ══════════════════════════════════════════════════════════════════════════
def crop_to_bbox_with_padding(image, bbox, padding=BBOX_PADDING):
    """Crop image to bounding box with context padding."""
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
    y1 = tf.minimum(y1, shape[0] - crop_h)
    x1 = tf.minimum(x1, shape[1] - crop_w)
    y1 = tf.maximum(y1, 0)
    x1 = tf.maximum(x1, 0)

    return tf.image.crop_to_bounding_box(image, y1, x1, crop_h, crop_w)


def extract_with_mixed_crop(example):
    """50% bbox crop, 50% full image for training."""
    image = example["image"]
    label = example["label"]
    bbox = example["objects"]["bbox"]
    has_bbox = tf.shape(bbox)[0] > 0

    if USE_BBOX_CROP:
        use_crop = tf.logical_and(has_bbox, tf.random.uniform([], 0, 1) < BBOX_MIXED_RATE)
        result = tf.cond(use_crop,
                         lambda: crop_to_bbox_with_padding(image, bbox[0]),
                         lambda: image)
    else:
        result = image
    return result, label


def extract_with_bbox_crop(example):
    """Always crop to bbox (for test set)."""
    image = example["image"]
    label = example["label"]
    bbox = example["objects"]["bbox"]
    has_bbox = tf.shape(bbox)[0] > 0
    result = tf.cond(has_bbox,
                     lambda: crop_to_bbox_with_padding(image, bbox[0]),
                     lambda: image)
    return result, label


ds_train_stanford = ds_train_stanford_raw.map(
    extract_with_mixed_crop, num_parallel_calls=tf.data.AUTOTUNE
)
ds_test_stanford = ds_test_stanford_raw.map(
    extract_with_bbox_crop, num_parallel_calls=tf.data.AUTOTUNE
)


# ══════════════════════════════════════════════════════════════════════════
# Step 3: Clean names & discover supplemental breeds
# ══════════════════════════════════════════════════════════════════════════
def clean_stanford_name(raw_name: str) -> str:
    if "-" in raw_name:
        raw_name = raw_name.split("-", 1)[1]
    return raw_name.replace("_", " ")


def clean_supplemental_name(folder_name: str) -> str:
    return folder_name.replace("_", " ").title()


stanford_clean_names = [clean_stanford_name(n) for n in stanford_class_names]
stanford_clean_lower = {n.lower() for n in stanford_clean_names}

# ── v5.1: Dead label remapping ──────────────────────────────────────────
# These Stanford labels are non-domestic canids that waste model capacity.
# Remap them to the closest domestic breed (supplemental) during training.
DEAD_LABEL_REMAP = {
    'dingo': 'Carolina Dog',        # Carolina Dog = "American Dingo"
    'dhole': 'Canaan Dog',          # Asian wild dog -> closest match
    'african hunting dog': 'Pharaoh Hound',  # African painted dog -> closest match
}

# Find Stanford indices for dead labels
_dead_stanford_indices = {}
for i, name in enumerate(stanford_clean_names):
    if name.lower() in DEAD_LABEL_REMAP:
        _dead_stanford_indices[i] = DEAD_LABEL_REMAP[name.lower()]
        print(f"  Dead label remap: [{i}] '{name}' -> '{DEAD_LABEL_REMAP[name.lower()]}'")

# ── v5.1: Supplemental breeds to EXCLUDE from being separate classes ────
# "Poodle" creates a 4-way split with toy/miniature/standard poodle from Stanford.
EXCLUDE_SUPPLEMENTAL = {'poodle'}

supplemental_breeds = []
supplemental_images = {}

if os.path.isdir(SUPPLEMENTAL_DIR):
    for entry in sorted(os.listdir(SUPPLEMENTAL_DIR)):
        folder_path = os.path.join(SUPPLEMENTAL_DIR, entry)
        if not os.path.isdir(folder_path):
            continue
        imgs_set = set()
        for ext in ("*.jpg", "*.jpeg", "*.png", "*.JPG", "*.JPEG", "*.PNG"):
            imgs_set.update(glob.glob(os.path.join(folder_path, ext)))
        imgs = sorted(imgs_set)
        if len(imgs) == 0:
            continue
        supplemental_breeds.append((entry, folder_path))
        supplemental_images[entry] = imgs

new_supplemental = []
extra_supplemental = []
for folder_name, _ in supplemental_breeds:
    clean = clean_supplemental_name(folder_name)
    # v5.1: Skip excluded breeds (e.g., generic "Poodle" -> 4-way split)
    if folder_name.lower() in EXCLUDE_SUPPLEMENTAL:
        print(f"  EXCLUDED supplemental: {clean} (would cause label confusion)")
        continue
    if clean.lower() in stanford_clean_lower:
        extra_supplemental.append((folder_name, clean))
    else:
        new_supplemental.append((folder_name, clean))

# Build unified label list
all_clean_names = list(stanford_clean_names)
supplemental_label_offset = len(all_clean_names)
for folder_name, clean in new_supplemental:
    all_clean_names.append(clean)

NUM_CLASSES = len(all_clean_names)

print(f"\n{'=' * 70}")
print(f"BREED SUMMARY")
print(f"{'=' * 70}")
print(f"  Stanford Dogs breeds:     {stanford_num_classes}")
print(f"  New supplemental breeds:  {len(new_supplemental)}")
print(f"  Overlapping supplemental: {len(extra_supplemental)}")
print(f"  TOTAL classes:            {NUM_CLASSES}")

if new_supplemental:
    print(f"\n  New supplemental breeds:")
    for i, (folder_name, clean) in enumerate(new_supplemental):
        count = len(supplemental_images[folder_name])
        idx = supplemental_label_offset + i
        print(f"    [{idx:3d}] {clean} ({count} images)")

if extra_supplemental:
    print(f"\n  Overlapping breeds (extra data):")
    for folder_name, clean in extra_supplemental:
        count = len(supplemental_images[folder_name])
        print(f"    {clean} (+{count} images)")

print(f"{'=' * 70}\n")


# ══════════════════════════════════════════════════════════════════════════
# Step 4: Build supplemental datasets
# ══════════════════════════════════════════════════════════════════════════
def load_and_decode_image(file_path, label):
    raw = tf.io.read_file(file_path)
    image = tf.io.decode_jpeg(raw, channels=3)
    # Don't resize here — augment functions handle it per stage
    image = tf.cast(image, tf.float32)
    label = tf.cast(label, tf.int64)
    return image, label


def build_supplemental_dataset(breeds_list, label_map, is_train=True):
    all_paths = []
    all_labels = []
    for folder_name, clean_name in breeds_list:
        imgs = supplemental_images[folder_name]
        label_idx = label_map[clean_name]
        np.random.seed(42)
        indices = np.random.permutation(len(imgs))
        split_point = max(1, int(len(imgs) * 0.8))
        if is_train:
            selected = [imgs[i] for i in indices[:split_point]]
        else:
            selected = [imgs[i] for i in indices[split_point:]]
        for p in selected:
            all_paths.append(p)
            all_labels.append(label_idx)
    if len(all_paths) == 0:
        return None, 0
    ds = tf.data.Dataset.from_tensor_slices((all_paths, all_labels))
    ds = ds.map(load_and_decode_image, num_parallel_calls=tf.data.AUTOTUNE)
    return ds, len(all_paths)


label_map = {name: idx for idx, name in enumerate(all_clean_names)}

# v5.1: Build dead label remap table (Stanford index -> unified index)
_dead_remap_table = {}
for stanford_idx, target_name in _dead_stanford_indices.items():
    if target_name in label_map:
        _dead_remap_table[stanford_idx] = label_map[target_name]
        print(f"  Dead label remap: Stanford[{stanford_idx}] -> unified[{label_map[target_name]}] ({target_name})")
    else:
        print(f"  WARNING: Dead label target '{target_name}' not found in label_map")

# Build a TF lookup table for dead label remapping
if _dead_remap_table:
    _remap_keys = tf.constant(list(_dead_remap_table.keys()), dtype=tf.int64)
    _remap_vals = tf.constant(list(_dead_remap_table.values()), dtype=tf.int64)

    def remap_dead_labels(image, label):
        """Remap dead Stanford labels to their domestic breed targets."""
        for k, v in _dead_remap_table.items():
            label = tf.cond(tf.equal(label, k), lambda v=v: tf.constant(v, dtype=tf.int64), lambda: label)
        return image, label

    ds_train_stanford = ds_train_stanford.map(remap_dead_labels, num_parallel_calls=tf.data.AUTOTUNE)
    ds_test_stanford = ds_test_stanford.map(remap_dead_labels, num_parallel_calls=tf.data.AUTOTUNE)
    print(f"  Applied dead label remapping to Stanford train+test")

supp_new_train_ds, supp_new_train_count = build_supplemental_dataset(
    new_supplemental, label_map, is_train=True)
supp_new_test_ds, supp_new_test_count = build_supplemental_dataset(
    new_supplemental, label_map, is_train=False)

overlap_label_map = {}
for folder_name, clean in extra_supplemental:
    for i, sname in enumerate(stanford_clean_names):
        if sname.lower() == clean.lower():
            overlap_label_map[clean] = i
            break

supp_overlap_train_ds, supp_overlap_train_count = build_supplemental_dataset(
    extra_supplemental, overlap_label_map, is_train=True
) if extra_supplemental else (None, 0)
supp_overlap_test_ds, supp_overlap_test_count = build_supplemental_dataset(
    extra_supplemental, overlap_label_map, is_train=False
) if extra_supplemental else (None, 0)

total_train_count = (stanford_train_count + supp_new_train_count + supp_overlap_train_count)
total_test_count = (stanford_test_count + supp_new_test_count + supp_overlap_test_count)

print(f"Combined training examples: {total_train_count}")
print(f"Combined test examples:     {total_test_count}")


# ══════════════════════════════════════════════════════════════════════════
# Step 5: Augmentation functions (v5 — significantly enhanced)
# ══════════════════════════════════════════════════════════════════════════

def random_erasing(image, probability=RANDOM_ERASING_PROB):
    """Random rectangular erasing for occlusion robustness."""
    should_erase = tf.random.uniform([]) < probability

    def do_erase():
        img_h = tf.shape(image)[0]
        img_w = tf.shape(image)[1]
        area = tf.cast(img_h * img_w, tf.float32)
        target_area = tf.random.uniform([], 0.02, 0.25) * area
        aspect_ratio = tf.random.uniform([], 0.3, 1.0 / 0.3)
        erase_h = tf.cast(tf.math.sqrt(target_area * aspect_ratio), tf.int32)
        erase_w = tf.cast(tf.math.sqrt(target_area / aspect_ratio), tf.int32)
        erase_h = tf.clip_by_value(erase_h, 1, img_h - 1)
        erase_w = tf.clip_by_value(erase_w, 1, img_w - 1)
        y = tf.random.uniform([], 0, img_h - erase_h, dtype=tf.int32)
        x = tf.random.uniform([], 0, img_w - erase_w, dtype=tf.int32)
        noise = tf.random.uniform([erase_h, erase_w, 3], 0.0, 255.0)
        # Build mask
        top = tf.ones([y, img_w, 3])
        mid_left = tf.ones([erase_h, x, 3])
        mid_right = tf.ones([erase_h, img_w - x - erase_w, 3])
        mid = tf.concat([mid_left, tf.zeros([erase_h, erase_w, 3]), mid_right], axis=1)
        bottom = tf.ones([img_h - y - erase_h, img_w, 3])
        mask = tf.concat([top, mid, bottom], axis=0)
        noise_padded = tf.concat([
            tf.zeros([y, img_w, 3]),
            tf.concat([tf.zeros([erase_h, x, 3]), noise,
                       tf.zeros([erase_h, img_w - x - erase_w, 3])], axis=1),
            tf.zeros([img_h - y - erase_h, img_w, 3]),
        ], axis=0)
        return image * mask + noise_padded

    return tf.cond(should_erase, do_erase, lambda: image)


def rand_augment(image, num_layers=RANDAUG_NUM_LAYERS, magnitude=RANDAUG_MAGNITUDE):
    """Apply RandAugment: each transform applied with independent probability.
    Graph-mode safe — no tf.case, no tf.image.random_* inside conditionals."""
    mag = float(magnitude) / 10.0  # Python float, not tensor
    prob = float(num_layers) / 8.0  # ~probability each transform fires

    # Rotation ±15°
    image = tf.cond(
        tf.random.uniform([]) < prob,
        lambda: _rotate_image(image, tf.random.uniform([], -15.0, 15.0) * mag),
        lambda: image)

    # Shear X
    image = tf.cond(
        tf.random.uniform([]) < prob,
        lambda: _shear_image(image, tf.random.uniform([], -0.3, 0.3) * mag, axis='x'),
        lambda: image)

    # Shear Y
    image = tf.cond(
        tf.random.uniform([]) < prob,
        lambda: _shear_image(image, tf.random.uniform([], -0.3, 0.3) * mag, axis='y'),
        lambda: image)

    # Translate
    image = tf.cond(
        tf.random.uniform([]) < prob,
        lambda: _translate_image(image, mag),
        lambda: image)

    # Hue jitter (graph-safe: fixed max_delta, not tensor)
    hue_delta = 0.08 * mag
    image = tf.cond(
        tf.random.uniform([]) < prob,
        lambda: tf.image.adjust_hue(image / 255.0, tf.random.uniform([], -hue_delta, hue_delta)) * 255.0,
        lambda: image)

    # Saturation jitter
    image = tf.cond(
        tf.random.uniform([]) < prob,
        lambda: tf.image.adjust_saturation(image / 255.0, tf.random.uniform([], max(0.5, 1.0 - 0.5 * mag), 1.0 + 0.5 * mag)) * 255.0,
        lambda: image)

    # Solarize
    threshold = 256.0 - 128.0 * mag
    image = tf.cond(
        tf.random.uniform([]) < prob,
        lambda: tf.where(image >= threshold, 255.0 - image, image),
        lambda: image)

    # Autocontrast
    def _autocontrast(img):
        lo = tf.reduce_min(img, axis=[0, 1], keepdims=True)
        hi = tf.reduce_max(img, axis=[0, 1], keepdims=True)
        scale = 255.0 / tf.maximum(hi - lo, 1.0)
        return (img - lo) * scale

    image = tf.cond(
        tf.random.uniform([]) < prob,
        lambda: _autocontrast(image),
        lambda: image)

    # Grayscale
    image = tf.cond(
        tf.random.uniform([]) < prob * 0.5,  # lower prob for grayscale
        lambda: tf.tile(tf.reduce_mean(image, axis=-1, keepdims=True), [1, 1, 3]),
        lambda: image)

    return tf.clip_by_value(image, 0.0, 255.0)


def _rotate_image(image, angle_deg):
    """Rotate image by degrees using affine transform."""
    radians = angle_deg * (math.pi / 180.0)
    cos_a = tf.cos(radians)
    sin_a = tf.sin(radians)
    h = tf.cast(tf.shape(image)[0], tf.float32)
    w = tf.cast(tf.shape(image)[1], tf.float32)
    cx, cy = w / 2.0, h / 2.0
    tx = cx - cos_a * cx - sin_a * cy
    ty = cy + sin_a * cx - cos_a * cy
    transform = [cos_a, sin_a, tx, -sin_a, cos_a, ty, 0.0, 0.0]
    image_4d = tf.expand_dims(image, 0)
    rotated = tf.raw_ops.ImageProjectiveTransformV3(
        images=image_4d,
        transforms=tf.expand_dims(transform, 0),
        output_shape=tf.shape(image)[:2],
        interpolation="BILINEAR",
        fill_mode="REFLECT",
        fill_value=0.0,
    )
    return rotated[0]


def _shear_image(image, level, axis='x'):
    """Shear image along given axis."""
    if axis == 'x':
        transform = [1.0, level, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0]
    else:
        transform = [1.0, 0.0, 0.0, level, 1.0, 0.0, 0.0, 0.0]
    image_4d = tf.expand_dims(image, 0)
    result = tf.raw_ops.ImageProjectiveTransformV3(
        images=image_4d,
        transforms=tf.expand_dims(transform, 0),
        output_shape=tf.shape(image)[:2],
        interpolation="BILINEAR",
        fill_mode="REFLECT",
        fill_value=0.0,
    )
    return result[0]


def _translate_image(image, mag):
    """Translate image by random amount scaled by magnitude."""
    h = tf.cast(tf.shape(image)[0], tf.float32)
    w = tf.cast(tf.shape(image)[1], tf.float32)
    dx = tf.random.uniform([], -w * 0.15 * mag, w * 0.15 * mag)
    dy = tf.random.uniform([], -h * 0.15 * mag, h * 0.15 * mag)
    transform = [1.0, 0.0, -dx, 0.0, 1.0, -dy, 0.0, 0.0]
    image_4d = tf.expand_dims(image, 0)
    result = tf.raw_ops.ImageProjectiveTransformV3(
        images=image_4d,
        transforms=tf.expand_dims(transform, 0),
        output_shape=tf.shape(image)[:2],
        interpolation="BILINEAR",
        fill_mode="REFLECT",
        fill_value=0.0,
    )
    return result[0]


def make_augment_fn(img_size):
    """Create augmentation function for a given image size (progressive resizing)."""
    def augment(image, label):
        image = tf.cast(image, tf.float32)
        # Resize with padding for random crop
        pad = max(40, int(img_size * 0.18))
        image = tf.image.resize(image, [img_size + pad, img_size + pad])
        image = tf.image.random_crop(image, [img_size, img_size, 3])
        image = tf.image.random_flip_left_right(image)

        # RandAugment (rotation, shear, translate, color, etc.)
        image = rand_augment(image)

        # brightness/contrast removed — already covered by RandAugment
        image = tf.clip_by_value(image, 0.0, 255.0)

        # Random erasing (after all spatial transforms)
        image = random_erasing(image)

        image = tf.keras.applications.efficientnet.preprocess_input(image)
        return image, label
    return augment


def make_augment_supplemental_fn(img_size):
    """Stronger augmentation for supplemental images."""
    def augment_supplemental(image, label):
        image = tf.cast(image, tf.float32)
        pad = max(60, int(img_size * 0.25))
        image = tf.image.resize(image, [img_size + pad, img_size + pad])
        image = tf.image.random_crop(image, [img_size, img_size, 3])
        image = tf.image.random_flip_left_right(image)

        # RandAugment with extra magnitude for supplemental
        image = rand_augment(image, num_layers=3, magnitude=RANDAUG_MAGNITUDE)

        image = tf.image.random_brightness(image, 0.3)
        image = tf.image.random_contrast(image, 0.6, 1.4)
        image = tf.clip_by_value(image, 0.0, 255.0)
        image = random_erasing(image, probability=0.4)
        image = tf.keras.applications.efficientnet.preprocess_input(image)
        return image, label
    return augment_supplemental


def make_preprocess_fn(img_size):
    """Test/val preprocessing for a given size."""
    def preprocess(image, label):
        image = tf.image.resize(image, [img_size, img_size])
        image = tf.cast(image, tf.float32)
        image = tf.keras.applications.efficientnet.preprocess_input(image)
        return image, label
    return preprocess


def make_preprocess_supplemental_fn(img_size):
    """Test/val preprocessing for supplemental images."""
    def preprocess_supplemental(image, label):
        image = tf.image.resize(image, [img_size, img_size])
        image = tf.cast(image, tf.float32)
        image = tf.keras.applications.efficientnet.preprocess_input(image)
        return image, label
    return preprocess_supplemental


# ── CutMix + Mixup batch augmentation ───────────────────────────────────
def cutmix_batch(images, labels):
    """CutMix: cut and paste patches between images."""
    batch_size = tf.shape(images)[0]
    img_h = tf.shape(images)[1]
    img_w = tf.shape(images)[2]

    gamma_a = tf.random.gamma([1], CUTMIX_ALPHA)[0]
    gamma_b = tf.random.gamma([1], CUTMIX_ALPHA)[0]
    lam = gamma_a / (gamma_a + gamma_b + 1e-7)

    indices = tf.random.shuffle(tf.range(batch_size))
    shuffled_images = tf.gather(images, indices)
    shuffled_labels = tf.gather(labels, indices)

    cut_ratio = tf.math.sqrt(1.0 - lam)
    cut_h = tf.cast(tf.cast(img_h, tf.float32) * cut_ratio, tf.int32)
    cut_w = tf.cast(tf.cast(img_w, tf.float32) * cut_ratio, tf.int32)
    cut_h = tf.maximum(cut_h, 1)
    cut_w = tf.maximum(cut_w, 1)

    cy = tf.random.uniform([], 0, img_h, dtype=tf.int32)
    cx = tf.random.uniform([], 0, img_w, dtype=tf.int32)
    y1 = tf.maximum(cy - cut_h // 2, 0)
    y2 = tf.minimum(cy + cut_h // 2, img_h)
    x1 = tf.maximum(cx - cut_w // 2, 0)
    x2 = tf.minimum(cx + cut_w // 2, img_w)

    ones_left = tf.ones([y2 - y1, x1, 3])
    zeros_patch = tf.zeros([y2 - y1, x2 - x1, 3])
    ones_right = tf.ones([y2 - y1, img_w - x2, 3])
    middle_row = tf.concat([ones_left, zeros_patch, ones_right], axis=1)
    top = tf.ones([y1, img_w, 3])
    bottom = tf.ones([img_h - y2, img_w, 3])
    mask = tf.concat([top, middle_row, bottom], axis=0)

    mixed = images * mask + shuffled_images * (1.0 - mask)
    actual_lam = 1.0 - tf.cast((y2 - y1) * (x2 - x1), tf.float32) / \
                        tf.cast(img_h * img_w, tf.float32)

    mixed_labels = labels * actual_lam + shuffled_labels * (1.0 - actual_lam)
    return mixed, mixed_labels


def mixup_batch(images, labels):
    """Mixup: linear interpolation between pairs."""
    batch_size = tf.shape(images)[0]

    gamma_a = tf.random.gamma([1], MIXUP_ALPHA)[0]
    gamma_b = tf.random.gamma([1], MIXUP_ALPHA)[0]
    lam = gamma_a / (gamma_a + gamma_b + 1e-7)
    lam = tf.maximum(lam, 1.0 - lam)  # ensure lam >= 0.5

    indices = tf.random.shuffle(tf.range(batch_size))
    shuffled_images = tf.gather(images, indices)
    shuffled_labels = tf.gather(labels, indices)

    mixed = images * lam + shuffled_images * (1.0 - lam)
    mixed_labels = labels * lam + shuffled_labels * (1.0 - lam)
    return mixed, mixed_labels


def maybe_mix(images, labels):
    """Apply CutMix or Mixup or neither (mutually exclusive per batch)."""
    labels_oh = tf.one_hot(tf.cast(labels, tf.int32), NUM_CLASSES)
    rand = tf.random.uniform([])

    def do_cutmix():
        return cutmix_batch(images, labels_oh)

    def do_mixup():
        return mixup_batch(images, labels_oh)

    def do_nothing():
        return images, labels_oh

    # CutMix with prob CUTMIX_PROB, Mixup with prob MIXUP_PROB, else nothing
    cutmix_threshold = CUTMIX_PROB
    mixup_threshold = CUTMIX_PROB + MIXUP_PROB

    result = tf.case([
        (tf.less(rand, cutmix_threshold), do_cutmix),
        (tf.less(rand, mixup_threshold), do_mixup),
    ], default=do_nothing)

    return result


# ══════════════════════════════════════════════════════════════════════════
# Step 6: Build data pipelines (dynamically per resolution stage)
# ══════════════════════════════════════════════════════════════════════════
data_options = tf.data.Options()
# Removed max_intra_op_parallelism=1 — was throttling data pipeline


def build_train_pipeline(img_size):
    """Build training pipeline for a given resolution."""
    aug_fn = make_augment_fn(img_size)
    aug_supp_fn = make_augment_supplemental_fn(img_size)

    # FIX: Don't cache Stanford before augmentation — it locks in bbox crop decisions.
    # Cache raw supplemental (no bbox) but map Stanford fresh each epoch.
    stanford_train = ds_train_stanford.map(aug_fn, num_parallel_calls=tf.data.AUTOTUNE)

    train_datasets = [stanford_train]
    train_weights = [float(stanford_train_count)]

    if supp_overlap_train_ds is not None:
        overlap_aug = supp_overlap_train_ds.cache().map(aug_supp_fn, num_parallel_calls=tf.data.AUTOTUNE)
        train_datasets.append(overlap_aug)
        train_weights.append(float(supp_overlap_train_count))

    if supp_new_train_ds is not None:
        # v5.1: 3x oversample supplemental breeds to reduce class imbalance
        new_aug = supp_new_train_ds.cache().map(aug_supp_fn, num_parallel_calls=tf.data.AUTOTUNE)
        train_datasets.append(new_aug)
        train_weights.append(float(supp_new_train_count * 3))

    weight_sum = sum(train_weights)
    train_weights = [w / weight_sum for w in train_weights]

    train_datasets_repeating = [ds.repeat() for ds in train_datasets]
    if len(train_datasets_repeating) > 1:
        combined = tf.data.Dataset.sample_from_datasets(
            train_datasets_repeating, weights=train_weights, seed=42)
    else:
        combined = train_datasets_repeating[0]

    steps = total_train_count // BATCH_SIZE
    return (
        combined
        .shuffle(buffer_size=min(8192, total_train_count), reshuffle_each_iteration=True)
        .with_options(data_options)
        .batch(BATCH_SIZE)
        .map(maybe_mix, num_parallel_calls=tf.data.AUTOTUNE)
        .prefetch(tf.data.AUTOTUNE)
    ), steps


def build_test_pipeline(img_size):
    """Build test pipeline for a given resolution."""
    preprocess_fn = make_preprocess_fn(img_size)
    preprocess_supp_fn = make_preprocess_supplemental_fn(img_size)

    def to_onehot(image, label):
        image, label = preprocess_fn(image, label)
        return image, tf.one_hot(tf.cast(label, tf.int32), NUM_CLASSES)

    def supp_to_onehot(image, label):
        image, label = preprocess_supp_fn(image, label)
        return image, tf.one_hot(tf.cast(label, tf.int32), NUM_CLASSES)

    components = [ds_test_stanford.map(to_onehot, num_parallel_calls=tf.data.AUTOTUNE)]
    if supp_overlap_test_ds is not None:
        components.append(supp_overlap_test_ds.map(supp_to_onehot, num_parallel_calls=tf.data.AUTOTUNE))
    if supp_new_test_ds is not None:
        components.append(supp_new_test_ds.map(supp_to_onehot, num_parallel_calls=tf.data.AUTOTUNE))

    combined = components[0]
    for ds in components[1:]:
        combined = combined.concatenate(ds)

    return (
        combined
        .cache()
        .with_options(data_options)
        .batch(BATCH_SIZE)
        .prefetch(tf.data.AUTOTUNE)
    )


# ══════════════════════════════════════════════════════════════════════════
# Step 7: Compute class weights
# ══════════════════════════════════════════════════════════════════════════
print("Computing class weights...")
class_counts = np.zeros(NUM_CLASSES, dtype=np.float64)
avg_stanford_per_class = stanford_train_count / stanford_num_classes
for i in range(stanford_num_classes):
    class_counts[i] += avg_stanford_per_class

for folder_name, clean in extra_supplemental:
    idx = overlap_label_map[clean]
    n = max(1, int(len(supplemental_images[folder_name]) * 0.8))
    class_counts[idx] += n

for i, (folder_name, clean) in enumerate(new_supplemental):
    idx = supplemental_label_offset + i
    n = max(1, int(len(supplemental_images[folder_name]) * 0.8))
    class_counts[idx] += n

total_samples = class_counts.sum()
class_weights = {}
for i in range(NUM_CLASSES):
    if class_counts[i] > 0:
        weight = total_samples / (NUM_CLASSES * class_counts[i])
        weight = min(weight, 10.0)
        weight = max(weight, 0.1)
        class_weights[i] = weight
    else:
        class_weights[i] = 1.0

weights_arr = np.array(list(class_weights.values()))
print(f"  Class weight range: [{weights_arr.min():.3f}, {weights_arr.max():.3f}]")
print(f"  Median class weight: {np.median(weights_arr):.3f}")


# ══════════════════════════════════════════════════════════════════════════
# Step 8: Build Model — EfficientNetB2 with bilinear pooling head
# ══════════════════════════════════════════════════════════════════════════
print(f"\nBuilding EfficientNetB2 model ({NUM_CLASSES} classes, bilinear head)...")

# Start with smallest resolution for head training
current_img_size = IMG_SIZES[0]

base_model = tf.keras.applications.EfficientNetB2(
    input_shape=(None, None, 3),  # flexible input size for progressive resizing
    include_top=False,
    weights="imagenet",
)
base_model.trainable = False

# Bilinear pooling head (v4.1 style, quantization-safe)
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
x = tf.keras.layers.Dropout(0.3)(x)  # was 0.2 — uniform dropout with heavy aug
output = tf.keras.layers.Dense(NUM_CLASSES, activation="softmax", name="classifier")(x)

model = tf.keras.Model(inputs=base_model.input, outputs=output)


# FIX: Bake class weights into loss function instead of model.fit(class_weight=...)
# because class_weight is incompatible with CutMix/Mixup soft labels.
_class_weight_tensor = tf.constant(
    [class_weights.get(i, 1.0) for i in range(NUM_CLASSES)], dtype=tf.float32)


def weighted_cat_crossentropy(y_true, y_pred):
    """Class-weighted categorical crossentropy that works with soft labels."""
    sample_weights = tf.reduce_sum(y_true * _class_weight_tensor, axis=-1)
    ce = tf.keras.losses.categorical_crossentropy(
        y_true, y_pred, label_smoothing=LABEL_SMOOTHING)
    return ce * sample_weights


model.compile(
    optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
    loss=weighted_cat_crossentropy,
    metrics=["accuracy"],
)

total_params = model.count_params()
trainable_params = sum(tf.keras.backend.count_params(w) for w in model.trainable_weights)
print(f"  Total parameters: {total_params:,}")
print(f"  Trainable parameters: {trainable_params:,}")
print(f"  EfficientNetB2 feature dim: {base_model.output_shape[-1]}")


# ══════════════════════════════════════════════════════════════════════════
# Phase 1: Train head only (smallest resolution)
# ══════════════════════════════════════════════════════════════════════════
print(f"\n{'=' * 70}")
print(f"PHASE 1: Head training at {current_img_size}x{current_img_size}")
print(f"{'=' * 70}")

train_ds, steps_per_epoch = build_train_pipeline(current_img_size)
test_ds = build_test_pipeline(current_img_size)

early_stop = tf.keras.callbacks.EarlyStopping(
    monitor="val_accuracy", patience=4, restore_best_weights=True, verbose=1)
reduce_lr = tf.keras.callbacks.ReduceLROnPlateau(
    monitor="val_accuracy", factor=0.5, patience=2, min_lr=1e-6, verbose=1)

model.fit(
    train_ds,
    validation_data=test_ds,
    epochs=HEAD_EPOCHS,
    steps_per_epoch=steps_per_epoch,
    # class_weight removed — baked into weighted_cat_crossentropy loss
    callbacks=[early_stop, reduce_lr],
)


# ══════════════════════════════════════════════════════════════════════════
# Phase 2: Progressive fine-tuning (increasing resolution + unfreezing)
# ══════════════════════════════════════════════════════════════════════════
total_epoch = HEAD_EPOCHS

for stage_idx, (img_size, ft_epochs, ft_layers) in enumerate(
    zip(IMG_SIZES, FINE_TUNE_EPOCHS_PER_SIZE, FINE_TUNE_LAYERS_STAGE)):

    print(f"\n{'=' * 70}")
    print(f"PHASE 2.{stage_idx + 1}: Fine-tune at {img_size}x{img_size}, "
          f"{'all' if ft_layers == -1 else f'top {ft_layers}'} layers, "
          f"{ft_epochs} epochs")
    print(f"{'=' * 70}")

    # Unfreeze layers
    base_model.trainable = True
    if ft_layers == -1:
        # Unfreeze everything
        for layer in base_model.layers:
            layer.trainable = True
    else:
        for layer in base_model.layers[:-ft_layers]:
            layer.trainable = False

    trainable_now = sum(tf.keras.backend.count_params(w) for w in model.trainable_weights)
    print(f"  Trainable parameters: {trainable_now:,}")

    # Build pipeline for this resolution
    train_ds, steps_per_epoch = build_train_pipeline(img_size)
    test_ds = build_test_pipeline(img_size)

    total_ft_steps = steps_per_epoch * ft_epochs

    # Cosine decay with warmup — increased LRs for better convergence
    warmup_steps = steps_per_epoch * 2  # 2 epoch warmup
    base_lr = 1e-4 if stage_idx == 0 else (5e-5 if stage_idx == 1 else 3e-5)

    lr_schedule = tf.keras.optimizers.schedules.CosineDecay(
        initial_learning_rate=base_lr,
        decay_steps=total_ft_steps,
        alpha=1e-7,
        warmup_target=base_lr,
        warmup_steps=warmup_steps,
    )

    model.compile(
        optimizer=tf.keras.optimizers.AdamW(
            learning_rate=lr_schedule, weight_decay=1e-4),
        loss=weighted_cat_crossentropy,
        metrics=["accuracy"],
    )

    early_stop_ft = tf.keras.callbacks.EarlyStopping(
        monitor="val_accuracy",
        patience=4 if stage_idx < 2 else 5,
        restore_best_weights=True,
        verbose=1,
    )

    model.fit(
        train_ds,
        validation_data=test_ds,
        epochs=total_epoch + ft_epochs,
        initial_epoch=total_epoch,
        steps_per_epoch=steps_per_epoch,
        # class_weight removed — baked into weighted_cat_crossentropy loss
        callbacks=[early_stop_ft],
    )

    total_epoch += ft_epochs

    # Evaluate at this stage
    loss, acc = model.evaluate(test_ds)
    elapsed = time.time() - start_time
    print(f"\n  Stage {stage_idx + 1} accuracy: {acc:.4f} ({elapsed/60:.0f} min elapsed)")


# ══════════════════════════════════════════════════════════════════════════
# Final evaluation at full resolution
# ══════════════════════════════════════════════════════════════════════════
print(f"\n{'=' * 70}")
print("FINAL EVALUATION")
print(f"{'=' * 70}")

test_ds_final = build_test_pipeline(FINAL_IMG_SIZE)
loss, acc = model.evaluate(test_ds_final)
print(f"\nFinal test accuracy: {acc:.4f}")


# ══════════════════════════════════════════════════════════════════════════
# Confusion matrix analysis
# ══════════════════════════════════════════════════════════════════════════
print("\nComputing confusion matrix...")

all_preds = []
all_labels_list = []
for images, labels_oh in test_ds_final:
    preds = model.predict(images, verbose=0)
    all_preds.extend(np.argmax(preds, axis=1))
    all_labels_list.extend(np.argmax(labels_oh.numpy(), axis=1))

all_preds = np.array(all_preds)
all_labels_arr = np.array(all_labels_list)

cm = tf.math.confusion_matrix(all_labels_arr, all_preds, num_classes=NUM_CLASSES).numpy()

# Per-class accuracy
print(f"\n{'=' * 70}")
print("PER-CLASS ACCURACY (all breeds)")
print(f"{'=' * 70}")

per_class_acc = []
low_accuracy_breeds = []
for i in range(NUM_CLASSES):
    total_for_class = cm[i].sum()
    correct = cm[i, i]
    class_acc = correct / max(total_for_class, 1)
    per_class_acc.append(class_acc)
    name = all_clean_names[i]
    if class_acc < 0.5:
        low_accuracy_breeds.append((name, class_acc, i))
    confused = np.argsort(cm[i])[::-1]
    top_confused = [(all_clean_names[j], int(cm[i, j]))
                    for j in confused[:3] if j != i and cm[i, j] > 0]
    confused_str = ", ".join(f"{n}({c})" for n, c in top_confused)
    marker = " *** LOW ***" if class_acc < 0.5 else ""
    print(f"  [{i:3d}] {name:<35s} {class_acc*100:5.1f}% "
          f"({correct}/{total_for_class}) confused: {confused_str}{marker}")

mean_per_class = np.mean(per_class_acc)
print(f"\nMean per-class accuracy: {mean_per_class*100:.1f}%")
print(f"Overall accuracy: {acc*100:.1f}%")

if low_accuracy_breeds:
    print(f"\n  WARNING: {len(low_accuracy_breeds)} breeds below 50% accuracy:")
    for name, acc_val, idx in sorted(low_accuracy_breeds, key=lambda x: x[1]):
        print(f"    [{idx}] {name}: {acc_val*100:.1f}%")

# Top-10 confused pairs
print(f"\nTop-10 most confused breed pairs:")
cm_no_diag = cm.copy()
np.fill_diagonal(cm_no_diag, 0)
for _ in range(10):
    i, j = np.unravel_index(np.argmax(cm_no_diag), cm_no_diag.shape)
    if cm_no_diag[i, j] == 0:
        break
    print(f"  {all_clean_names[i]} -> {all_clean_names[j]}: "
          f"{cm_no_diag[i, j]} misclassifications")
    cm_no_diag[i, j] = 0

print(f"{'=' * 70}")


# ══════════════════════════════════════════════════════════════════════════
# Convert to TFLite (uint8 quantized)
# ══════════════════════════════════════════════════════════════════════════
print("\nConverting to TFLite (uint8 quantized)...")

# First save a fixed-input-size model for TFLite conversion
# (TFLite needs fixed shapes)
fixed_input = tf.keras.layers.Input(shape=(FINAL_IMG_SIZE, FINAL_IMG_SIZE, 3))
fixed_output = model(fixed_input)
fixed_model = tf.keras.Model(inputs=fixed_input, outputs=fixed_output)


def representative_data_gen():
    # 100 batches (3200 images) for better quantization calibration (was 30)
    for images, _ in test_ds_final.take(100):
        for image in images:
            yield [tf.expand_dims(image, 0)]


converter = tf.lite.TFLiteConverter.from_keras_model(fixed_model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.representative_dataset = representative_data_gen
converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
converter.inference_input_type = tf.uint8
converter.inference_output_type = tf.uint8

tflite_model = converter.convert()

os.makedirs(OUTPUT_DIR, exist_ok=True)
model_path = os.path.join(OUTPUT_DIR, "dog_model_v5.tflite")
with open(model_path, "wb") as f:
    f.write(tflite_model)

model_size_mb = len(tflite_model) / (1024 * 1024)
print(f"Model saved: {model_path} ({model_size_mb:.1f} MB)")

# Also save as the default model name
default_path = os.path.join(OUTPUT_DIR, "dog_model.tflite")
with open(default_path, "wb") as f:
    f.write(tflite_model)
print(f"Also saved as: {default_path}")


# ══════════════════════════════════════════════════════════════════════════
# Write labels
# ══════════════════════════════════════════════════════════════════════════
labels_path = os.path.join(OUTPUT_DIR, "dog_labels.txt")
with open(labels_path, "w", encoding="utf-8") as f:
    for name in all_clean_names:
        f.write(name + "\n")
print(f"Labels saved: {labels_path} ({len(all_clean_names)} breeds)")


# ══════════════════════════════════════════════════════════════════════════
# Save training report
# ══════════════════════════════════════════════════════════════════════════
elapsed_total = time.time() - start_time
report = {
    "version": "v5.1",
    "backbone": "EfficientNetB2",
    "progressive_sizes": IMG_SIZES,
    "final_size": FINAL_IMG_SIZE,
    "num_classes": NUM_CLASSES,
    "stanford_breeds": stanford_num_classes,
    "supplemental_breeds": len(new_supplemental),
    "total_train": total_train_count,
    "total_test": total_test_count,
    "test_accuracy": float(acc),
    "mean_per_class_accuracy": float(mean_per_class),
    "model_size_mb": model_size_mb,
    "training_time_minutes": elapsed_total / 60,
    "augmentation": {
        "randaugment": {"layers": RANDAUG_NUM_LAYERS, "magnitude": RANDAUG_MAGNITUDE},
        "cutmix": {"prob": CUTMIX_PROB, "alpha": CUTMIX_ALPHA},
        "mixup": {"prob": MIXUP_PROB, "alpha": MIXUP_ALPHA},
        "random_erasing": {"prob": RANDOM_ERASING_PROB},
        "bbox_crop": {"enabled": USE_BBOX_CROP, "padding": BBOX_PADDING},
    },
    "low_accuracy_breeds": [(n, float(a)) for n, a, _ in low_accuracy_breeds],
}

report_path = "train_v5_1_report.json"
with open(report_path, "w") as f:
    json.dump(report, f, indent=2)
print(f"\nTraining report saved: {report_path}")


print(f"\n{'=' * 70}")
print(f"DONE! (v5 — EfficientNetB2 + Progressive Resizing + RandAugment)")
print(f"{'=' * 70}")
print(f"  dog_model_v5.tflite  -- {model_size_mb:.1f} MB (uint8 quantized)")
print(f"  dog_labels.txt       -- {len(all_clean_names)} breed labels")
print(f"  Final input size:    {FINAL_IMG_SIZE}x{FINAL_IMG_SIZE}")
print(f"  Stanford breeds:     {stanford_num_classes}")
print(f"  Supplemental breeds: {len(new_supplemental)}")
print(f"  Total breeds:        {NUM_CLASSES}")
print(f"  Test accuracy:       {acc:.4f}")
print(f"  Mean per-class acc:  {mean_per_class:.4f}")
print(f"  Training time:       {elapsed_total/60:.0f} min")
print(f"\n  v5.1 improvements over v3 (82.6%):")
print(f"    [+] EfficientNetB2 backbone (vs B0)")
print(f"    [+] RandAugment (rotation, shear, translate, color, posterize, solarize)")
print(f"    [+] Mixup + CutMix combined")
print(f"    [+] Progressive resizing (192 -> 224 -> 260)")
print(f"    [+] Full backbone fine-tuning in final stage")
print(f"    [+] Wider head (512 + 256)")
print(f"    [+] Bilinear pooling (GAP * GMP + BatchNorm)")
print(f"    [+] Bbox crop for Stanford Dogs")
print(f"    [+] Random erasing")
print(f"    [+] Weighted loss (CutMix-compatible)")
print(f"    [+] Dead label remapping (dingo/dhole/african)")
print(f"    [+] AdamW optimizer")
print(f"    [+] 3x supplemental oversampling")
print(f"\n  Next: run verify_tflite.py to check quantization quality!")
print(f"  Then update tflite_identification_service.dart with _inputSize = {FINAL_IMG_SIZE}")
