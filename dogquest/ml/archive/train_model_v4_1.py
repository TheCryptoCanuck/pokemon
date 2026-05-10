"""
Train a dog breed classifier using EfficientNetB0 on Stanford Dogs (120 breeds)
PLUS supplemental breed images from supplemental_dogs/{breed_name}/*.jpg.

v4.1 — Fix v4 on-device failure:
  - Replaced Lambda(signed_sqrt) + Lambda(l2_norm) with BatchNormalization
    (Lambda layers lose precision in int8 quantization — L2-normalized 1280-dim
    vectors have ~0.028 component magnitude = only ~7 int8 levels)
  - Reduced CutMix aggressiveness: prob 0.5->0.3, alpha 1.0->0.3
  - Reduced label smoothing: 0.1->0.05 (CutMix already provides soft labels)
  - BILINEAR_MODE config: "bn" (default), "concat_only", "none" (v3-style)
  - All other FGVC features retained: bbox crop, random erasing, fine-tune 40 layers

Output: assets/dog_model.tflite (uint8 input, uint8 output)
        assets/dog_labels.txt  (one breed name per line, matching model output order)

Usage:
  pip install tensorflow tensorflow-datasets Pillow
  python train_model_v4_1.py
"""
import os
import glob
import math
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
IMG_SIZE = 224
BATCH_SIZE = 64
EPOCHS = 5                  # head training
FINE_TUNE_EPOCHS = 10       # fine-tuning
FINE_TUNE_LAYERS = 40       # unfreeze more layers for fine-grained features
OUTPUT_DIR = "assets"
SUPPLEMENTAL_DIR = "supplemental_dogs"

# v4.1 fixes: reduced smoothing (CutMix already provides soft labels)
LABEL_SMOOTHING = 0.05      # was 0.1 in v4

# FGVC config
USE_BBOX_CROP = True
BBOX_PADDING = 0.15
BBOX_MIXED_RATE = 0.5

# v4.1 fixes: reduced CutMix aggressiveness
USE_CUTMIX = True
CUTMIX_ALPHA = 0.3          # was 1.0 — bimodal beta = smaller cuts, labels closer to one-hot
CUTMIX_PROB = 0.3           # was 0.5 — less double-label training

USE_RANDOM_ERASING = True
RANDOM_ERASING_PROB = 0.3

# v4.1: bilinear head mode — "bn" replaces broken Lambda layers
# Options: "bn" (BatchNorm after multiply), "concat_only" (no multiply), "none" (v3 GAP-only)
BILINEAR_MODE = "bn"

print(f"CPU cores: {cpu_count}")
print(f"TF inter-op threads: {tf.config.threading.get_inter_op_parallelism_threads()}")
print(f"TF intra-op threads: {tf.config.threading.get_intra_op_parallelism_threads()}")
print(f"\nv4.1 Config:")
print(f"  Bilinear mode: {BILINEAR_MODE}")
print(f"  Label smoothing: {LABEL_SMOOTHING}")
print(f"  CutMix: prob={CUTMIX_PROB}, alpha={CUTMIX_ALPHA}")
print(f"  Bbox crop: {USE_BBOX_CROP} (padding={BBOX_PADDING}, mixed={BBOX_MIXED_RATE})")
print(f"  Random erasing: {USE_RANDOM_ERASING} (prob={RANDOM_ERASING_PROB})")


# ── Step 1: Load Stanford Dogs WITH bounding boxes ────────────────────────
print("=" * 70)
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


# ── Bounding box crop utilities ───────────────────────────────────────────
def crop_to_bbox_with_padding(image, bbox, padding=BBOX_PADDING):
    """Crop image to bounding box with context padding.
    bbox format: [ymin, xmin, ymax, xmax] normalized to [0, 1]."""
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
    """50% bbox crop, 50% full image."""
    image = example["image"]
    label = example["label"]
    bbox = example["objects"]["bbox"]

    has_bbox = tf.shape(bbox)[0] > 0

    def do_crop():
        return crop_to_bbox_with_padding(image, bbox[0])

    def do_full():
        return image

    if USE_BBOX_CROP:
        use_crop = tf.logical_and(
            has_bbox,
            tf.random.uniform([], 0, 1) < BBOX_MIXED_RATE
        )
        result = tf.cond(use_crop, do_crop, do_full)
    else:
        result = image

    return result, label


def extract_with_bbox_crop(example):
    """Always crop to bbox (for test set)."""
    image = example["image"]
    label = example["label"]
    bbox = example["objects"]["bbox"]

    has_bbox = tf.shape(bbox)[0] > 0

    def do_crop():
        return crop_to_bbox_with_padding(image, bbox[0])

    result = tf.cond(has_bbox, do_crop, lambda: image)
    return result, label


ds_train_stanford = ds_train_stanford_raw.map(
    extract_with_mixed_crop, num_parallel_calls=tf.data.AUTOTUNE
)
ds_test_stanford = ds_test_stanford_raw.map(
    extract_with_bbox_crop, num_parallel_calls=tf.data.AUTOTUNE
)


# ── Step 2: Clean Stanford breed names ───────────────────────────────────
def clean_stanford_name(raw_name: str) -> str:
    if "-" in raw_name:
        raw_name = raw_name.split("-", 1)[1]
    return raw_name.replace("_", " ")


stanford_clean_names = [clean_stanford_name(n) for n in stanford_class_names]


# ── Step 3: Discover supplemental breeds ─────────────────────────────────
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
            print(f"  [SKIP] supplemental_dogs/{entry}/ -- no images found")
            continue
        supplemental_breeds.append((entry, folder_path))
        supplemental_images[entry] = imgs
else:
    print(f"\nNo supplemental_dogs/ directory found -- training on Stanford Dogs only.")

stanford_clean_lower = {n.lower() for n in stanford_clean_names}


def clean_supplemental_name(folder_name: str) -> str:
    return folder_name.replace("_", " ").title()


new_supplemental = []
extra_supplemental = []

for folder_name, _ in supplemental_breeds:
    clean = clean_supplemental_name(folder_name)
    if clean.lower() in stanford_clean_lower:
        extra_supplemental.append((folder_name, clean))
    else:
        new_supplemental.append((folder_name, clean))


# ── Build unified label list ─────────────────────────────────────────────
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
print(f"  Overlapping supplemental: {len(extra_supplemental)} (will augment Stanford data)")
print(f"  TOTAL classes:            {NUM_CLASSES}")

if new_supplemental:
    print(f"\n  New supplemental breeds:")
    for i, (folder_name, clean) in enumerate(new_supplemental):
        count = len(supplemental_images[folder_name])
        idx = supplemental_label_offset + i
        print(f"    [{idx:3d}] {clean} ({count} images)")

if extra_supplemental:
    print(f"\n  Overlapping breeds (extra data for Stanford breeds):")
    for folder_name, clean in extra_supplemental:
        count = len(supplemental_images[folder_name])
        print(f"    {clean} (+{count} images)")

print(f"{'=' * 70}\n")


# ── Step 4: Build supplemental tf.data.Dataset ──────────────────────────
def load_and_decode_image(file_path, label):
    raw = tf.io.read_file(file_path)
    image = tf.io.decode_jpeg(raw, channels=3)
    image = tf.image.resize(image, [IMG_SIZE, IMG_SIZE])
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

supp_new_train_ds, supp_new_train_count = build_supplemental_dataset(
    new_supplemental, label_map, is_train=True
)
supp_new_test_ds, supp_new_test_count = build_supplemental_dataset(
    new_supplemental, label_map, is_train=False
)

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


# ── Step 5: Preprocessing & Augmentation (FGVC-enhanced) ─────────────────

def random_erasing(image, probability=RANDOM_ERASING_PROB):
    if not USE_RANDOM_ERASING:
        return image

    should_erase = tf.random.uniform([]) < probability

    def do_erase():
        img_h = tf.shape(image)[0]
        img_w = tf.shape(image)[1]
        area = tf.cast(img_h * img_w, tf.float32)

        target_area = tf.random.uniform([], 0.02, 0.25) * area
        aspect_ratio = tf.random.uniform([], 0.3, 1.0 / 0.3)

        erase_h = tf.cast(tf.math.sqrt(target_area * aspect_ratio), tf.int32)
        erase_w = tf.cast(tf.math.sqrt(target_area / aspect_ratio), tf.int32)
        erase_h = tf.minimum(erase_h, img_h - 1)
        erase_w = tf.minimum(erase_w, img_w - 1)
        erase_h = tf.maximum(erase_h, 1)
        erase_w = tf.maximum(erase_w, 1)

        y = tf.random.uniform([], 0, img_h - erase_h, dtype=tf.int32)
        x = tf.random.uniform([], 0, img_w - erase_w, dtype=tf.int32)

        noise = tf.random.uniform([erase_h, erase_w, 3], 0.0, 255.0)

        top = tf.ones([y, img_w, 3])
        mid_left = tf.ones([erase_h, x, 3])
        mid_right = tf.ones([erase_h, img_w - x - erase_w, 3])
        mid = tf.concat([mid_left, tf.zeros([erase_h, erase_w, 3]), mid_right], axis=1)
        bottom = tf.ones([img_h - y - erase_h, img_w, 3])
        mask = tf.concat([top, mid, bottom], axis=0)

        noise_padded = tf.concat([
            tf.zeros([y, img_w, 3]),
            tf.concat([tf.zeros([erase_h, x, 3]), noise, tf.zeros([erase_h, img_w - x - erase_w, 3])], axis=1),
            tf.zeros([img_h - y - erase_h, img_w, 3]),
        ], axis=0)

        return image * mask + noise_padded

    return tf.cond(should_erase, do_erase, lambda: image)


def preprocess(image, label):
    image = tf.image.resize(image, [IMG_SIZE, IMG_SIZE])
    image = tf.cast(image, tf.float32)
    image = tf.keras.applications.efficientnet.preprocess_input(image)
    return image, label


def augment(image, label):
    image = tf.cast(image, tf.float32)
    image = tf.image.resize(image, [IMG_SIZE + 40, IMG_SIZE + 40])
    image = tf.image.random_crop(image, [IMG_SIZE, IMG_SIZE, 3])
    image = tf.image.random_flip_left_right(image)
    image = tf.image.random_brightness(image, 0.25)
    image = tf.image.random_contrast(image, 0.7, 1.3)
    image = tf.clip_by_value(image, 0.0, 255.0)
    image = random_erasing(image)
    image = tf.keras.applications.efficientnet.preprocess_input(image)
    return image, label


def preprocess_supplemental(image, label):
    image = tf.cast(image, tf.float32)
    image = tf.keras.applications.efficientnet.preprocess_input(image)
    return image, label


def augment_supplemental(image, label):
    image = tf.cast(image, tf.float32)
    image = tf.image.resize(image, [IMG_SIZE + 60, IMG_SIZE + 60])
    image = tf.image.random_crop(image, [IMG_SIZE, IMG_SIZE, 3])
    image = tf.image.random_flip_left_right(image)
    image = tf.image.random_brightness(image, 0.3)
    image = tf.image.random_contrast(image, 0.6, 1.4)
    image = tf.clip_by_value(image, 0.0, 255.0)
    image = random_erasing(image, probability=0.4)
    image = tf.keras.applications.efficientnet.preprocess_input(image)
    return image, label


# ── CutMix batch augmentation ────────────────────────────────────────────
def cutmix_batch(images, labels):
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

    labels_oh = tf.one_hot(tf.cast(labels, tf.int32), NUM_CLASSES)
    shuffled_oh = tf.one_hot(tf.cast(shuffled_labels, tf.int32), NUM_CLASSES)
    mixed_labels = labels_oh * actual_lam + shuffled_oh * (1.0 - actual_lam)

    return mixed, mixed_labels


def maybe_cutmix(images, labels):
    if USE_CUTMIX:
        apply = tf.random.uniform([]) < CUTMIX_PROB
        labels_oh = tf.one_hot(tf.cast(labels, tf.int32), NUM_CLASSES)

        def do_cutmix():
            return cutmix_batch(images, labels)

        def no_cutmix():
            return images, labels_oh

        return tf.cond(apply, do_cutmix, no_cutmix)
    else:
        return images, tf.one_hot(tf.cast(labels, tf.int32), NUM_CLASSES)


# ── Step 6: Combine datasets ────────────────────────────────────────────

data_options = tf.data.Options()
data_options.experimental_threading.max_intra_op_parallelism = 1

stanford_train = (
    ds_train_stanford
    .cache()
    .map(augment, num_parallel_calls=tf.data.AUTOTUNE)
)

train_datasets = [stanford_train]
train_weights = [float(stanford_train_count)]

if supp_overlap_train_ds is not None:
    overlap_augmented = (
        supp_overlap_train_ds
        .cache()
        .map(augment_supplemental, num_parallel_calls=tf.data.AUTOTUNE)
    )
    train_datasets.append(overlap_augmented)
    train_weights.append(float(supp_overlap_train_count))

if supp_new_train_ds is not None:
    new_augmented = (
        supp_new_train_ds
        .cache()
        .map(augment_supplemental, num_parallel_calls=tf.data.AUTOTUNE)
    )
    train_datasets.append(new_augmented)
    train_weights.append(float(supp_new_train_count))

total_train_count = (stanford_train_count
                     + supp_new_train_count
                     + supp_overlap_train_count)

weight_sum = sum(train_weights)
train_weights = [w / weight_sum for w in train_weights]

train_datasets_repeating = [ds.repeat() for ds in train_datasets]

if len(train_datasets_repeating) > 1:
    combined_train_ds = tf.data.Dataset.sample_from_datasets(
        train_datasets_repeating, weights=train_weights, seed=42
    )
else:
    combined_train_ds = train_datasets_repeating[0]

steps_per_epoch = total_train_count // BATCH_SIZE

train_ds = (
    combined_train_ds
    .with_options(data_options)
    .batch(BATCH_SIZE)
    .map(maybe_cutmix, num_parallel_calls=tf.data.AUTOTUNE)
    .prefetch(tf.data.AUTOTUNE)
)

# --- Test/validation dataset (one-hot labels to match CutMix output) ---
def preprocess_to_onehot(image, label):
    image = tf.image.resize(image, [IMG_SIZE, IMG_SIZE])
    image = tf.cast(image, tf.float32)
    image = tf.keras.applications.efficientnet.preprocess_input(image)
    label_oh = tf.one_hot(tf.cast(label, tf.int32), NUM_CLASSES)
    return image, label_oh


def preprocess_supplemental_onehot(image, label):
    image = tf.cast(image, tf.float32)
    image = tf.keras.applications.efficientnet.preprocess_input(image)
    label_oh = tf.one_hot(tf.cast(label, tf.int32), NUM_CLASSES)
    return image, label_oh


test_components = [
    ds_test_stanford.map(preprocess_to_onehot, num_parallel_calls=tf.data.AUTOTUNE)
]

if supp_overlap_test_ds is not None:
    test_components.append(
        supp_overlap_test_ds.map(preprocess_supplemental_onehot, num_parallel_calls=tf.data.AUTOTUNE)
    )

if supp_new_test_ds is not None:
    test_components.append(
        supp_new_test_ds.map(preprocess_supplemental_onehot, num_parallel_calls=tf.data.AUTOTUNE)
    )

combined_test_ds = test_components[0]
for ds in test_components[1:]:
    combined_test_ds = combined_test_ds.concatenate(ds)

total_test_count = (stanford_test_count
                    + supp_new_test_count
                    + supp_overlap_test_count)

test_ds = (
    combined_test_ds
    .cache()
    .with_options(data_options)
    .batch(BATCH_SIZE)
    .prefetch(tf.data.AUTOTUNE)
)

print(f"Combined training examples: {total_train_count}")
print(f"Combined test examples:     {total_test_count}")
print(f"Steps per epoch:            {steps_per_epoch}")
print(f"Batch size:                 {BATCH_SIZE}")


# ── Step 7: Compute class weights for imbalance ─────────────────────────
print("\nComputing class weights for imbalance handling...")

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

high_weight_breeds = [(all_clean_names[i], class_weights[i])
                      for i in range(NUM_CLASSES)
                      if class_weights[i] > 3.0]
if high_weight_breeds:
    print(f"  Breeds with high weight (>3.0, likely low image count):")
    for name, w in sorted(high_weight_breeds, key=lambda x: -x[1])[:10]:
        print(f"    {name}: {w:.2f}")


# ── Step 8: Build Model (v4.1 — quantization-safe bilinear head) ────────
print(f"\nBuilding EfficientNetB0 model ({NUM_CLASSES} classes, "
      f"bilinear_mode={BILINEAR_MODE})...")

base_model = tf.keras.applications.EfficientNetB0(
    input_shape=(IMG_SIZE, IMG_SIZE, 3),
    include_top=False,
    weights="imagenet",
)
base_model.trainable = False

if BILINEAR_MODE == "bn":
    # v4.1 fix: BatchNorm replaces Lambda(signed_sqrt) + Lambda(l2_norm)
    # BatchNorm is a standard Keras op that quantizes cleanly (folds into
    # preceding layer during TFLite conversion). It normalizes bilinear
    # features to zero-mean unit-variance — similar stabilization but
    # with learned scale/offset that preserves int8 resolution.
    features = base_model.output  # (batch, 7, 7, 1280)

    gap = tf.keras.layers.GlobalAveragePooling2D(name="gap")(features)
    gmp = tf.keras.layers.GlobalMaxPooling2D(name="gmp")(features)

    bilinear = tf.keras.layers.Multiply(name="bilinear_mul")([gap, gmp])
    bilinear = tf.keras.layers.BatchNormalization(name="bilinear_bn")(bilinear)

    merged = tf.keras.layers.Concatenate(name="merge_features")([gap, bilinear])

    x = tf.keras.layers.Dropout(0.4)(merged)
    x = tf.keras.layers.Dense(256, activation="relu")(x)
    x = tf.keras.layers.Dropout(0.3)(x)
    output = tf.keras.layers.Dense(NUM_CLASSES, activation="softmax")(x)

    model = tf.keras.Model(inputs=base_model.input, outputs=output)

elif BILINEAR_MODE == "concat_only":
    # No multiply — just concatenate GAP + GMP (2560-dim)
    features = base_model.output

    gap = tf.keras.layers.GlobalAveragePooling2D(name="gap")(features)
    gmp = tf.keras.layers.GlobalMaxPooling2D(name="gmp")(features)

    merged = tf.keras.layers.Concatenate(name="merge_features")([gap, gmp])

    x = tf.keras.layers.Dropout(0.4)(merged)
    x = tf.keras.layers.Dense(256, activation="relu")(x)
    x = tf.keras.layers.Dropout(0.3)(x)
    output = tf.keras.layers.Dense(NUM_CLASSES, activation="softmax")(x)

    model = tf.keras.Model(inputs=base_model.input, outputs=output)

else:
    # "none" — v3-style GAP only
    model = tf.keras.Sequential([
        base_model,
        tf.keras.layers.GlobalAveragePooling2D(),
        tf.keras.layers.Dropout(0.4),
        tf.keras.layers.Dense(256, activation="relu"),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(NUM_CLASSES, activation="softmax"),
    ])


def categorical_crossentropy_with_smoothing(y_true, y_pred):
    return tf.keras.losses.categorical_crossentropy(
        y_true, y_pred, label_smoothing=LABEL_SMOOTHING
    )


model.compile(
    optimizer=tf.keras.optimizers.Adam(learning_rate=3e-3),
    loss=categorical_crossentropy_with_smoothing,
    metrics=["accuracy"],
)

model.summary()
print(f"\n  Label smoothing: {LABEL_SMOOTHING}")
trainable_count = sum(tf.keras.backend.count_params(w) for w in model.trainable_weights)
print(f"  Trainable parameters: {trainable_count:,}")


# ── Callbacks ─────────────────────────────────────────────────────────────
early_stop = tf.keras.callbacks.EarlyStopping(
    monitor="val_accuracy",
    patience=2,
    restore_best_weights=True,
    verbose=1,
)

reduce_lr = tf.keras.callbacks.ReduceLROnPlateau(
    monitor="val_accuracy",
    factor=0.5,
    patience=1,
    min_lr=1e-6,
    verbose=1,
)


# ── Phase 1: Train head ─────────────────────────────────────────────────
print(f"\nPhase 1: Training head ({EPOCHS} epochs, {steps_per_epoch} steps/epoch)...")
model.fit(
    train_ds,
    validation_data=test_ds,
    epochs=EPOCHS,
    steps_per_epoch=steps_per_epoch,
    class_weight=class_weights,
    callbacks=[early_stop, reduce_lr],
)


# ── Phase 2: Fine-tune top layers ───────────────────────────────────────
print(f"\nPhase 2: Fine-tuning top {FINE_TUNE_LAYERS} layers ({FINE_TUNE_EPOCHS} epochs)...")
base_model.trainable = True
for layer in base_model.layers[:-FINE_TUNE_LAYERS]:
    layer.trainable = False

total_fine_tune_steps = steps_per_epoch * FINE_TUNE_EPOCHS
model.compile(
    optimizer=tf.keras.optimizers.Adam(
        learning_rate=tf.keras.optimizers.schedules.CosineDecay(
            initial_learning_rate=5e-5,
            decay_steps=total_fine_tune_steps,
            alpha=1e-6,
        ),
    ),
    loss=categorical_crossentropy_with_smoothing,
    metrics=["accuracy"],
)

early_stop_ft = tf.keras.callbacks.EarlyStopping(
    monitor="val_accuracy",
    patience=3,
    restore_best_weights=True,
    verbose=1,
)

model.fit(
    train_ds,
    validation_data=test_ds,
    epochs=EPOCHS + FINE_TUNE_EPOCHS,
    initial_epoch=EPOCHS,
    steps_per_epoch=steps_per_epoch,
    class_weight=class_weights,
    callbacks=[early_stop_ft],
)


# ── Evaluate ─────────────────────────────────────────────────────────────
loss, acc = model.evaluate(test_ds)
print(f"\nTest accuracy: {acc:.4f}")


# ── Confusion Matrix Analysis ────────────────────────────────────────────
print("\nComputing confusion matrix on test set...")

all_preds = []
all_labels_list = []
for images, labels_oh in test_ds:
    preds = model.predict(images, verbose=0)
    all_preds.extend(np.argmax(preds, axis=1))
    all_labels_list.extend(np.argmax(labels_oh.numpy(), axis=1))

all_preds = np.array(all_preds)
all_labels_arr = np.array(all_labels_list)

cm = tf.math.confusion_matrix(all_labels_arr, all_preds, num_classes=NUM_CLASSES).numpy()

print(f"\n{'=' * 70}")
print("PER-CLASS ACCURACY (supplemental breeds)")
print(f"{'=' * 70}")
low_accuracy_breeds = []
for i in range(supplemental_label_offset, NUM_CLASSES):
    total_for_class = cm[i].sum()
    correct = cm[i, i]
    class_acc = correct / max(total_for_class, 1)
    name = all_clean_names[i]
    status = "OK" if class_acc >= 0.4 else "LOW"
    if class_acc < 0.4:
        low_accuracy_breeds.append((name, class_acc))
    confused = np.argsort(cm[i])[::-1]
    top_confused = [(all_clean_names[j], int(cm[i, j]))
                    for j in confused[:3] if j != i and cm[i, j] > 0]
    confused_str = ", ".join(f"{n}({c})" for n, c in top_confused)
    print(f"  [{i:3d}] {name:<35s} {class_acc*100:5.1f}% ({correct}/{total_for_class}) "
          f"[{status}] confused: {confused_str}")

if low_accuracy_breeds:
    print(f"\n  WARNING: {len(low_accuracy_breeds)} breeds below 40% accuracy:")
    for name, acc_val in sorted(low_accuracy_breeds, key=lambda x: x[1]):
        print(f"    {name}: {acc_val*100:.1f}%")

print(f"\nTop-10 most confused breed pairs:")
cm_no_diag = cm.copy()
np.fill_diagonal(cm_no_diag, 0)
for _ in range(10):
    i, j = np.unravel_index(np.argmax(cm_no_diag), cm_no_diag.shape)
    if cm_no_diag[i, j] == 0:
        break
    print(f"  {all_clean_names[i]} -> {all_clean_names[j]}: {cm_no_diag[i, j]} misclassifications")
    cm_no_diag[i, j] = 0

print(f"{'=' * 70}")


# ── Convert to TFLite (uint8 quantized) ─────────────────────────────────
print("\nConverting to TFLite (uint8 quantized)...")


def representative_data_gen():
    for images, _ in test_ds.take(20):
        for image in images:
            yield [tf.expand_dims(image, 0)]


converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.representative_dataset = representative_data_gen
converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
converter.inference_input_type = tf.uint8
converter.inference_output_type = tf.uint8

tflite_model = converter.convert()

os.makedirs(OUTPUT_DIR, exist_ok=True)
model_path = os.path.join(OUTPUT_DIR, "dog_model.tflite")
with open(model_path, "wb") as f:
    f.write(tflite_model)

model_size_mb = len(tflite_model) / (1024 * 1024)
print(f"Model saved: {model_path} ({model_size_mb:.1f} MB)")


# ── Write labels ─────────────────────────────────────────────────────────
labels_path = os.path.join(OUTPUT_DIR, "dog_labels.txt")
with open(labels_path, "w", encoding="utf-8") as f:
    for name in all_clean_names:
        f.write(name + "\n")

print(f"Labels saved: {labels_path} ({len(all_clean_names)} breeds)")

print(f"\n{'=' * 70}")
print(f"DONE! (v4.1 — Quantization-safe bilinear head)")
print(f"{'=' * 70}")
print(f"  dog_model.tflite -- {model_size_mb:.1f} MB (uint8 quantized)")
print(f"  dog_labels.txt   -- {len(all_clean_names)} breed labels")
print(f"  Stanford breeds: {stanford_num_classes}")
print(f"  Supplemental breeds: {len(new_supplemental)}")
print(f"  Total breeds: {NUM_CLASSES}")
print(f"  Test accuracy: {acc:.4f}")
print(f"\n  v4.1 changes from v4:")
print(f"    Bilinear mode: {BILINEAR_MODE} (was: Lambda signed_sqrt + l2_norm)")
print(f"    Label smoothing: {LABEL_SMOOTHING} (was: 0.1)")
print(f"    CutMix prob: {CUTMIX_PROB} (was: 0.5)")
print(f"    CutMix alpha: {CUTMIX_ALPHA} (was: 1.0)")
print(f"\n  Next: run verify_tflite.py to check quantization quality before deploying!")
