#!/usr/bin/env python3
"""
DogQuest v6 — Continued fine-tuning to improve accuracy.

Loads the best Phase 2.2 checkpoint and runs extended fine-tuning with:
  - All layers unfrozen (full model optimization)
  - batch_size=8 (safe for 8GB VRAM with all layers)
  - Lower learning rate (3e-6) for fine-grained tuning
  - Higher patience (6 epochs) to let cosine restarts work
  - 40 max epochs (vs 12 in original Phase 2.2)

This script reuses the same data pipeline from train_model_v6.py.

Usage:
    # In WSL2:
    wsl -u root
    NVIDIA_PATH=$(python3 -c "import nvidia; print(nvidia.__path__[0])")
    export LD_LIBRARY_PATH=$(find $NVIDIA_PATH -name "*.so*" -exec dirname {} \\; | sort -u | tr '\\n' ':')
    cd /mnt/c/Users/Administrator/AviQuest-/dogquest
    python3 continue_training_v6.py

Environment variables:
    BATCH_SIZE=8       Override batch size (default: 8, try 12 if not OOMing)
    EPOCHS=40          Max epochs (default: 40)
    LR=3e-6            Base learning rate (default: 3e-6)
    PATIENCE=6         Early stopping patience (default: 6)
    LAYERS=-1          Layers to unfreeze: -1=all, 200=top 200 (default: -1)
"""

import os
import sys
import gc
import glob
import time
import json
import numpy as np
import tensorflow as tf
import tensorflow_datasets as tfds

# ── GPU Setup ────────────────────────────────────────────────────────────
cpu_count = os.cpu_count() or 4
gpus = tf.config.list_physical_devices("GPU")
HAS_GPU = len(gpus) > 0

if HAS_GPU:
    for gpu in gpus:
        tf.config.experimental.set_memory_growth(gpu, True)
    policy = tf.keras.mixed_precision.Policy("mixed_float16")
    tf.keras.mixed_precision.set_global_policy(policy)
    print(f"[v6-continue] GPU detected, mixed precision ENABLED")
else:
    print(f"[v6-continue] No GPU — this will be slow")

# ── Config ───────────────────────────────────────────────────────────────
IMG_SIZE = 300
NUM_CLASSES = 296  # Will be verified against data
OUTPUT_DIR = "assets"
SUPPLEMENTAL_DIR = "supplemental_dogs"
CACHE_DIR = "tf_cache"

# Tunable via env vars
BATCH_SIZE = int(os.environ.get("BATCH_SIZE", "8"))
MAX_EPOCHS = int(os.environ.get("EPOCHS", "40"))
BASE_LR = float(os.environ.get("LR", "3e-6"))
PATIENCE = int(os.environ.get("PATIENCE", "6"))
UNFREEZE_LAYERS = int(os.environ.get("LAYERS", "-1"))  # -1 = all

# Augmentation (same as train_model_v6.py)
LABEL_SMOOTHING = 0.05
USE_BBOX_CROP = True
BBOX_PADDING = 0.15
BBOX_MIXED_RATE = 0.5
USE_CUTMIX = True
CUTMIX_ALPHA = 0.3
CUTMIX_PROB = 0.3
USE_MIXUP = True
MIXUP_ALPHA = 0.2
MIXUP_PROB = 0.3
RANDAUG_NUM_LAYERS = 2
RANDAUG_MAGNITUDE = 7
WEIGHT_DECAY = 1e-4

# Find best checkpoint
CHECKPOINT = None
for candidate in [
    "tf_cache/best_weights_continue.weights.h5",
    "tf_cache/best_weights_ft_stage1.weights.h5",
    "tf_cache/best_weights_ft_stage0.weights.h5",
]:
    if os.path.exists(candidate):
        CHECKPOINT = candidate
        break

if not CHECKPOINT:
    print("ERROR: No checkpoint found in tf_cache/")
    sys.exit(1)

start_time = time.time()

print(f"\n{'=' * 70}")
print(f"DogQuest v6 — CONTINUED FINE-TUNING")
print(f"{'=' * 70}")
print(f"  Checkpoint:    {CHECKPOINT}")
print(f"  Resolution:    {IMG_SIZE}x{IMG_SIZE}")
print(f"  Batch size:    {BATCH_SIZE}")
print(f"  Max epochs:    {MAX_EPOCHS}")
print(f"  Learning rate: {BASE_LR}")
print(f"  Patience:      {PATIENCE}")
print(f"  Layers:        {'ALL' if UNFREEZE_LAYERS == -1 else f'top {UNFREEZE_LAYERS}'}")
print(f"  Weight decay:  {WEIGHT_DECAY}")

# =========================================================================
# Data loading — reuse same pipeline logic from train_model_v6.py
# =========================================================================

# ── Name functions — MUST match train_model_v6.py EXACTLY ────────────────

def clean_stanford_name(raw_name):
    """Convert Stanford Dogs label to proper breed name (matches train_model_v6.py)."""
    if "-" in raw_name:
        raw_name = raw_name.split("-", 1)[1]
    informal = raw_name.replace("_", " ")
    _MAP = {
        "chihuahua": "Chihuahua", "japanese spaniel": "Japanese Chin",
        "maltese dog": "Maltese", "pekinese": "Pekingese",
        "shih-tzu": "Shih Tzu", "blenheim spaniel": "Blenheim Spaniel",
        "papillon": "Papillon", "toy terrier": "Toy Terrier",
        "rhodesian ridgeback": "Rhodesian Ridgeback", "afghan hound": "Afghan Hound",
        "basset": "Basset Hound", "beagle": "Beagle", "bloodhound": "Bloodhound",
        "bluetick": "Bluetick Coonhound",
        "black-and-tan coonhound": "Black and Tan Coonhound",
        "walker hound": "Walker Hound", "english foxhound": "English Foxhound",
        "redbone": "Redbone Coonhound", "borzoi": "Borzoi",
        "irish wolfhound": "Irish Wolfhound", "italian greyhound": "Italian Greyhound",
        "whippet": "Whippet", "ibizan hound": "Ibizan Hound",
        "norwegian elkhound": "Norwegian Elkhound", "otterhound": "Otterhound",
        "saluki": "Saluki", "scottish deerhound": "Scottish Deerhound",
        "weimaraner": "Weimaraner",
        "staffordshire bullterrier": "Staffordshire Bull Terrier",
        "american staffordshire terrier": "American Staffordshire Terrier",
        "bedlington terrier": "Bedlington Terrier", "border terrier": "Border Terrier",
        "kerry blue terrier": "Kerry Blue Terrier", "irish terrier": "Irish Terrier",
        "norfolk terrier": "Norfolk Terrier", "norwich terrier": "Norwich Terrier",
        "yorkshire terrier": "Yorkshire Terrier",
        "wire-haired fox terrier": "Wire Fox Terrier",
        "lakeland terrier": "Lakeland Terrier", "sealyham terrier": "Sealyham Terrier",
        "airedale": "Airedale Terrier", "cairn": "Cairn Terrier",
        "australian terrier": "Australian Terrier",
        "dandie dinmont": "Dandie Dinmont Terrier",
        "boston bull": "Boston Terrier", "miniature schnauzer": "Miniature Schnauzer",
        "giant schnauzer": "Giant Schnauzer", "standard schnauzer": "Standard Schnauzer",
        "scotch terrier": "Scottish Terrier", "tibetan terrier": "Tibetan Terrier",
        "silky terrier": "Silky Terrier",
        "soft-coated wheaten terrier": "Soft-Coated Wheaten Terrier",
        "west highland white terrier": "West Highland White Terrier",
        "lhasa": "Lhasa Apso", "flat-coated retriever": "Flat-Coated Retriever",
        "curly-coated retriever": "Curly-Coated Retriever",
        "golden retriever": "Golden Retriever", "labrador retriever": "Labrador Retriever",
        "chesapeake bay retriever": "Chesapeake Bay Retriever",
        "german short-haired pointer": "German Shorthaired Pointer",
        "vizsla": "Vizsla", "english setter": "English Setter",
        "irish setter": "Irish Setter", "gordon setter": "Gordon Setter",
        "brittany spaniel": "Brittany", "clumber": "Clumber Spaniel",
        "english springer": "English Springer Spaniel",
        "welsh springer spaniel": "Welsh Springer Spaniel",
        "cocker spaniel": "Cocker Spaniel", "sussex spaniel": "Sussex Spaniel",
        "irish water spaniel": "Irish Water Spaniel", "kuvasz": "Kuvasz",
        "schipperke": "Schipperke", "groenendael": "Belgian Sheepdog",
        "malinois": "Belgian Malinois", "briard": "Briard",
        "kelpie": "Australian Kelpie", "komondor": "Komondor",
        "old english sheepdog": "Old English Sheepdog",
        "shetland sheepdog": "Shetland Sheepdog", "collie": "Collie",
        "border collie": "Border Collie",
        "bouvier des flandres": "Bouvier des Flandres",
        "rottweiler": "Rottweiler", "german shepherd": "German Shepherd",
        "doberman": "Doberman Pinscher", "miniature pinscher": "Miniature Pinscher",
        "greater swiss mountain dog": "Greater Swiss Mountain Dog",
        "bernese mountain dog": "Bernese Mountain Dog",
        "appenzeller": "Appenzeller Sennenhund",
        "entlebucher": "Entlebucher Mountain Dog", "boxer": "Boxer",
        "bull mastiff": "Bullmastiff", "tibetan mastiff": "Tibetan Mastiff",
        "french bulldog": "French Bulldog", "great dane": "Great Dane",
        "saint bernard": "Saint Bernard", "eskimo dog": "American Eskimo Dog",
        "malamute": "Alaskan Malamute", "siberian husky": "Siberian Husky",
        "affenpinscher": "Affenpinscher", "basenji": "Basenji", "pug": "Pug",
        "leonberg": "Leonberger", "newfoundland": "Newfoundland",
        "great pyrenees": "Great Pyrenees", "samoyed": "Samoyed",
        "pomeranian": "Pomeranian", "chow": "Chow Chow", "keeshond": "Keeshond",
        "brabancon griffon": "Brussels Griffon",
        "pembroke": "Pembroke Welsh Corgi", "cardigan": "Cardigan Welsh Corgi",
        "toy poodle": "Toy Poodle", "miniature poodle": "Miniature Poodle",
        "standard poodle": "Standard Poodle", "mexican hairless": "Xoloitzcuintli",
        "dingo": None, "dhole": None, "african hunting dog": None,
    }
    return _MAP.get(informal, informal)


def clean_supplemental_name(folder_name):
    """Convert folder name to breed name (matches train_model_v6.py exactly)."""
    _overrides = {
        "mcnab_dog": "McNab Dog",
        "cirneco_dell'etna": "Cirneco dell'Etna",
        "danish-swedish_farmdog": "Danish-Swedish Farmdog",
        "pont-audemer_spaniel": "Pont-Audemer Spaniel",
    }
    if folder_name in _overrides:
        return _overrides[folder_name]
    _lowercase_words = {"de", "do", "da", "of", "and", "the", "del", "des", "von"}
    words = folder_name.replace("_", " ").split()
    result = []
    for i, w in enumerate(words):
        if i > 0 and w.lower() in _lowercase_words:
            result.append(w.lower())
        else:
            result.append(w.capitalize())
    return " ".join(result)

# Load Stanford Dogs
print("\nLoading Stanford Dogs dataset...")
(ds_train_stanford_raw, ds_test_stanford_raw), ds_info = tfds.load(
    "stanford_dogs", split=["train", "test"],
    with_info=True, as_supervised=False
)

# Build Stanford label mapping (using clean_stanford_name, same as train_model_v6.py)
raw_names = ds_info.features["label"].names
stanford_clean_names = []
wnid_to_idx = {}
for raw_idx, raw_name in enumerate(raw_names):
    clean = clean_stanford_name(raw_name)
    if clean is None:  # Wild canids (dingo, dhole, african hunting dog)
        wnid_to_idx[raw_idx] = -1
        continue
    wnid_to_idx[raw_idx] = len(stanford_clean_names)
    stanford_clean_names.append(clean)

stanford_clean_lower = {n.lower() for n in stanford_clean_names}
stanford_train_count = ds_info.splits["train"].num_examples
stanford_test_count = ds_info.splits["test"].num_examples

# Extract with bbox crop
def extract_with_bbox_crop(example):
    image = example["image"]
    label = example["label"]
    if USE_BBOX_CROP:
        bbox = example["objects"]["bbox"]
        if tf.shape(bbox)[0] > 0:
            box = bbox[0]
            h = tf.cast(tf.shape(image)[0], tf.float32)
            w = tf.cast(tf.shape(image)[1], tf.float32)
            y0 = tf.maximum(box[0] - BBOX_PADDING, 0.0)
            x0 = tf.maximum(box[1] - BBOX_PADDING, 0.0)
            y1 = tf.minimum(box[2] + BBOX_PADDING, 1.0)
            x1 = tf.minimum(box[3] + BBOX_PADDING, 1.0)
            image = tf.image.crop_to_bounding_box(
                image,
                tf.cast(y0 * h, tf.int32), tf.cast(x0 * w, tf.int32),
                tf.cast((y1 - y0) * h, tf.int32), tf.cast((x1 - x0) * w, tf.int32),
            )
    return image, label

ds_train_stanford = ds_train_stanford_raw.map(extract_with_bbox_crop, num_parallel_calls=tf.data.AUTOTUNE)
ds_test_stanford = ds_test_stanford_raw.map(extract_with_bbox_crop, num_parallel_calls=tf.data.AUTOTUNE)

# Remap Stanford labels
remap_table = tf.constant([wnid_to_idx.get(i, -1) for i in range(len(raw_names))], dtype=tf.int32)

def _remap_stanford_label(image, label):
    return image, remap_table[label]

ds_train_stanford = ds_train_stanford.map(_remap_stanford_label, num_parallel_calls=tf.data.AUTOTUNE).filter(lambda img, lbl: lbl >= 0)
ds_test_stanford = ds_test_stanford.map(_remap_stanford_label, num_parallel_calls=tf.data.AUTOTUNE).filter(lambda img, lbl: lbl >= 0)

# Load supplemental breeds
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

# Build supplemental breed lists (same logic as train_model_v6.py)
new_supplemental = []
extra_supplemental = []
for folder_name, _ in supplemental_breeds:
    clean = clean_supplemental_name(folder_name)
    if clean.lower() in stanford_clean_lower:
        extra_supplemental.append((folder_name, clean))
    else:
        new_supplemental.append((folder_name, clean))

all_clean_names = list(stanford_clean_names)
supplemental_label_offset = len(all_clean_names)
for folder_name, clean in new_supplemental:
    all_clean_names.append(clean)

NUM_CLASSES = len(all_clean_names)
print(f"  Stanford breeds: {len(stanford_clean_names)}")
print(f"  Overlap (extra data): {len(extra_supplemental)}")
print(f"  New supplemental: {len(new_supplemental)}")
print(f"  Total classes: {NUM_CLASSES}")
assert NUM_CLASSES == 296, f"Expected 296 classes, got {NUM_CLASSES}. Supplemental folder mismatch."

# Build supplemental datasets
def _load_image(path, label):
    raw = tf.io.read_file(path)
    image = tf.image.decode_image(raw, channels=3, expand_animations=False)
    image.set_shape([None, None, 3])
    return image, label

import random as _random

def _build_supp_split(breed_list, label_fn, train_frac=0.8, seed=42):
    """Build train/test datasets from supplemental breeds.

    Shuffles lightweight file PATHS before creating the TF dataset,
    then splits. This avoids the OOM from tf.data.shuffle() holding
    42K decoded 300x300 images in its buffer at epoch boundaries.
    """
    all_paths, all_labels = [], []
    for folder_name, clean in breed_list:
        label = label_fn(folder_name, clean)
        imgs = supplemental_images.get(folder_name, [])
        all_paths.extend(imgs)
        all_labels.extend([label] * len(imgs))
    if not all_paths:
        return None, 0, None, 0

    # Shuffle paths (strings) — NOT decoded images
    rng = _random.Random(seed)
    indices = list(range(len(all_paths)))
    rng.shuffle(indices)
    all_paths = [all_paths[i] for i in indices]
    all_labels = [all_labels[i] for i in indices]

    # Split into train/test
    train_n = int(len(all_paths) * train_frac)
    train_ds = tf.data.Dataset.from_tensor_slices((all_paths[:train_n], all_labels[:train_n]))
    train_ds = train_ds.map(_load_image, num_parallel_calls=tf.data.AUTOTUNE)
    test_ds = tf.data.Dataset.from_tensor_slices((all_paths[train_n:], all_labels[train_n:]))
    test_ds = test_ds.map(_load_image, num_parallel_calls=tf.data.AUTOTUNE)
    return train_ds, train_n, test_ds, len(all_paths) - train_n

stanford_lower_to_idx = {n.lower(): i for i, n in enumerate(stanford_clean_names)}

def overlap_label_fn(folder_name, clean):
    return stanford_lower_to_idx[clean.lower()]

def new_label_fn(folder_name, clean):
    return supplemental_label_offset + [c for _, c in new_supplemental].index(clean)

supp_overlap_train_ds, supp_overlap_train_count, supp_overlap_test_ds, supp_overlap_test_count = _build_supp_split(extra_supplemental, overlap_label_fn)
supp_new_train_ds, supp_new_train_count, supp_new_test_ds, supp_new_test_count = _build_supp_split(new_supplemental, new_label_fn)

total_train_count = stanford_train_count + supp_overlap_train_count + supp_new_train_count
total_test_count = stanford_test_count + supp_overlap_test_count + supp_new_test_count
print(f"  Training images: {total_train_count}")
print(f"  Test images: {total_test_count}")

# ── Class weights (static counting — NO dataset iteration to avoid OOM) ──
# Same approach as train_model_v6.py: count from file metadata, not decoded images.
class_counts = np.zeros(NUM_CLASSES, dtype=np.float64)
# Stanford: assume uniform distribution across 117 breeds
avg_stanford_per_class = float(stanford_train_count) / len(stanford_clean_names)
for i in range(len(stanford_clean_names)):
    class_counts[i] += avg_stanford_per_class
# Overlap supplemental (extra images for existing Stanford breeds)
for folder_name, clean in extra_supplemental:
    idx = stanford_lower_to_idx[clean.lower()]
    n_train = max(1, int(len(supplemental_images[folder_name]) * 0.8))
    class_counts[idx] += n_train
# New supplemental breeds
for i, (folder_name, clean) in enumerate(new_supplemental):
    idx = supplemental_label_offset + i
    n_train = max(1, int(len(supplemental_images[folder_name]) * 0.8))
    class_counts[idx] += n_train

class_weights = {}
total_samples = class_counts.sum()
for i in range(NUM_CLASSES):
    if class_counts[i] > 0:
        weight = total_samples / (NUM_CLASSES * class_counts[i])
        class_weights[i] = min(weight, 3.0)
    else:
        class_weights[i] = 1.0

class_weights_tensor = tf.constant(
    [class_weights.get(i, 1.0) for i in range(NUM_CLASSES)], dtype=tf.float32
)

# =========================================================================
# Augmentation functions (same as train_model_v6.py)
# =========================================================================

def rand_augment(image, num_layers=RANDAUG_NUM_LAYERS, magnitude=RANDAUG_MAGNITUDE):
    mag = float(magnitude) / 10.0

    def _rotate(img):
        angle = tf.random.uniform([], -30 * mag, 30 * mag) * (3.14159 / 180.0)
        cos_a = tf.cos(angle)
        sin_a = tf.sin(angle)
        h = tf.cast(tf.shape(img)[0], tf.float32)
        w = tf.cast(tf.shape(img)[1], tf.float32)
        cx, cy = w / 2.0, h / 2.0
        tx = cx - cos_a * cx - sin_a * cy
        ty = cy + sin_a * cx - cos_a * cy
        transform = [cos_a, sin_a, tx, -sin_a, cos_a, ty, 0.0, 0.0]
        rotated = tf.raw_ops.ImageProjectiveTransformV3(
            images=tf.expand_dims(img, 0),
            transforms=tf.expand_dims(transform, 0),
            output_shape=tf.shape(img)[:2],
            interpolation="BILINEAR",
            fill_mode="REFLECT",
            fill_value=0.0,
        )
        return rotated[0]

    def _shear_x(img):
        level = tf.random.uniform([], -0.3 * mag, 0.3 * mag)
        transform = [1.0, level, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0]
        result = tf.raw_ops.ImageProjectiveTransformV3(
            images=tf.expand_dims(img, 0),
            transforms=tf.expand_dims(transform, 0),
            output_shape=tf.shape(img)[:2],
            interpolation="BILINEAR",
            fill_mode="REFLECT",
            fill_value=0.0,
        )
        return result[0]

    def _translate(img):
        h = tf.cast(tf.shape(img)[0], tf.float32)
        w = tf.cast(tf.shape(img)[1], tf.float32)
        dx = tf.random.uniform([], -0.15 * mag * w, 0.15 * mag * w)
        dy = tf.random.uniform([], -0.15 * mag * h, 0.15 * mag * h)
        transform = [1.0, 0.0, -dx, 0.0, 1.0, -dy, 0.0, 0.0]
        result = tf.raw_ops.ImageProjectiveTransformV3(
            images=tf.expand_dims(img, 0),
            transforms=tf.expand_dims(transform, 0),
            output_shape=tf.shape(img)[:2],
            interpolation="BILINEAR",
            fill_mode="REFLECT",
            fill_value=0.0,
        )
        return result[0]

    def _brightness(img):
        return tf.image.random_brightness(img, 0.2 * mag)

    def _contrast(img):
        return tf.image.random_contrast(img, 1 - 0.3 * mag, 1 + 0.3 * mag)

    def _saturation(img):
        return tf.image.random_saturation(img, 1 - 0.3 * mag, 1 + 0.3 * mag)

    def _hue(img):
        return tf.image.random_hue(img, 0.05 * mag)

    transforms = [_rotate, _shear_x, _translate, _brightness, _contrast, _saturation, _hue]

    for _ in range(num_layers):
        idx = tf.random.uniform([], 0, len(transforms), dtype=tf.int32)
        for i, t in enumerate(transforms):
            image = tf.cond(tf.equal(idx, i), lambda t=t: t(image), lambda: image)

    return tf.clip_by_value(image, 0.0, 255.0)


def make_augment_fn(img_size):
    def augment(image, label):
        image = tf.cast(image, tf.float32)
        target = img_size + 32
        image = tf.image.resize(image, [target, target])
        image = tf.image.random_crop(image, [img_size, img_size, 3])
        image = tf.image.random_flip_left_right(image)
        image = rand_augment(image)
        image = tf.image.random_brightness(image, 0.1)
        image = tf.image.random_contrast(image, 0.9, 1.1)
        image = tf.clip_by_value(image, 0.0, 255.0)
        return image, label
    return augment


def make_augment_supplemental_fn(img_size):
    def augment_supplemental(image, label):
        image = tf.cast(image, tf.float32)
        target = img_size + 48
        image = tf.image.resize(image, [target, target])
        image = tf.image.random_crop(image, [img_size, img_size, 3])
        image = tf.image.random_flip_left_right(image)
        image = rand_augment(image, num_layers=3, magnitude=RANDAUG_MAGNITUDE)
        image = tf.image.random_brightness(image, 0.15)
        image = tf.image.random_contrast(image, 0.85, 1.15)
        image = tf.image.random_saturation(image, 0.85, 1.15)
        image = tf.clip_by_value(image, 0.0, 255.0)
        return image, label
    return augment_supplemental


def make_preprocess_fn(img_size):
    def preprocess(image, label):
        image = tf.cast(image, tf.float32)
        image = tf.image.resize(image, [img_size, img_size])
        return image, label
    return preprocess


def make_preprocess_supplemental_fn(img_size):
    return make_preprocess_fn(img_size)


# CutMix + Mixup
def cutmix_batch(images, labels_oh):
    batch_size_t = tf.shape(images)[0]
    h = tf.shape(images)[1]
    w = tf.shape(images)[2]
    gamma_a = tf.random.gamma([1], CUTMIX_ALPHA)[0]
    gamma_b = tf.random.gamma([1], CUTMIX_ALPHA)[0]
    lam = gamma_a / (gamma_a + gamma_b + 1e-8)
    cut_ratio = tf.sqrt(1.0 - lam)
    cut_h = tf.cast(tf.cast(h, tf.float32) * cut_ratio, tf.int32)
    cut_w = tf.cast(tf.cast(w, tf.float32) * cut_ratio, tf.int32)
    cy = tf.random.uniform([], 0, h, dtype=tf.int32)
    cx = tf.random.uniform([], 0, w, dtype=tf.int32)
    y1 = tf.maximum(cy - cut_h // 2, 0)
    y2 = tf.minimum(cy + cut_h // 2, h)
    x1 = tf.maximum(cx - cut_w // 2, 0)
    x2 = tf.minimum(cx + cut_w // 2, w)
    indices = tf.random.shuffle(tf.range(batch_size_t))
    shuffled_images = tf.gather(images, indices)
    shuffled_labels = tf.gather(labels_oh, indices)
    mask = tf.ones([h, w], dtype=tf.float32)
    patch = tf.zeros([y2 - y1, x2 - x1], dtype=tf.float32)
    padding = [[y1, h - y2], [x1, w - x2]]
    mask = mask - tf.pad(tf.ones_like(patch), padding) + tf.pad(patch, padding)
    mask = tf.reshape(mask, [1, h, w, 1])
    mixed_images = images * mask + shuffled_images * (1.0 - mask)
    actual_lam = 1.0 - tf.cast((y2 - y1) * (x2 - x1), tf.float32) / tf.cast(h * w, tf.float32)
    mixed_labels = labels_oh * actual_lam + shuffled_labels * (1.0 - actual_lam)
    return mixed_images, mixed_labels

def mixup_batch(images, labels_oh):
    batch_size_t = tf.shape(images)[0]
    gamma_a = tf.random.gamma([1], MIXUP_ALPHA)[0]
    gamma_b = tf.random.gamma([1], MIXUP_ALPHA)[0]
    lam = gamma_a / (gamma_a + gamma_b + 1e-8)
    indices = tf.random.shuffle(tf.range(batch_size_t))
    mixed_images = lam * images + (1.0 - lam) * tf.gather(images, indices)
    mixed_labels = lam * labels_oh + (1.0 - lam) * tf.gather(labels_oh, indices)
    return mixed_images, mixed_labels


def maybe_mix(images, labels):
    labels_oh = labels if len(labels.shape) > 1 else tf.one_hot(tf.cast(labels, tf.int32), NUM_CLASSES)
    rand = tf.random.uniform([])

    def do_cutmix():
        return cutmix_batch(images, labels_oh)
    def do_mixup():
        return mixup_batch(images, labels_oh)
    def do_nothing():
        return images, labels_oh

    result = tf.case([
        (tf.less(rand, CUTMIX_PROB), do_cutmix),
        (tf.less(rand, CUTMIX_PROB + MIXUP_PROB), do_mixup),
    ], default=do_nothing)

    mixed_images, mixed_labels = result
    sample_weights = tf.reduce_sum(mixed_labels * class_weights_tensor, axis=-1)
    return mixed_images, mixed_labels, sample_weights


# ── Data pipelines ───────────────────────────────────────────────────────
os.makedirs(CACHE_DIR, exist_ok=True)
data_options = tf.data.Options()
data_options.experimental_threading.max_intra_op_parallelism = 1
data_options.experimental_optimization.map_and_batch_fusion = True


def build_train_pipeline():
    aug_fn = make_augment_fn(IMG_SIZE)
    aug_supp_fn = make_augment_supplemental_fn(IMG_SIZE)

    # NO .cache() at 300x300 — eats all RAM and gets OOM-killed
    stanford_train = ds_train_stanford.map(aug_fn, num_parallel_calls=tf.data.AUTOTUNE)

    train_datasets = [stanford_train]
    train_weights = [float(stanford_train_count)]

    if supp_overlap_train_ds is not None:
        overlap_aug = supp_overlap_train_ds.map(aug_supp_fn, num_parallel_calls=tf.data.AUTOTUNE)
        train_datasets.append(overlap_aug)
        train_weights.append(float(supp_overlap_train_count))

    if supp_new_train_ds is not None:
        new_aug = supp_new_train_ds.map(aug_supp_fn, num_parallel_calls=tf.data.AUTOTUNE)
        train_datasets.append(new_aug)
        train_weights.append(float(supp_new_train_count))

    weight_sum = sum(train_weights)
    train_weights = [w / weight_sum for w in train_weights]

    train_datasets_repeating = [ds.repeat() for ds in train_datasets]
    if len(train_datasets_repeating) > 1:
        # NO seed= parameter — seed creates an internal ShuffleDatasetV3 that
        # holds 42K decoded images in its buffer, causing OOM at epoch boundaries.
        # Without seed, TF uses stateless random sampling (no shuffle buffer).
        combined = tf.data.Dataset.sample_from_datasets(
            train_datasets_repeating, weights=train_weights)
    else:
        combined = train_datasets_repeating[0]

    steps = total_train_count // BATCH_SIZE
    return (
        combined.with_options(data_options)
        .batch(BATCH_SIZE)
        .map(maybe_mix, num_parallel_calls=tf.data.AUTOTUNE)
        .prefetch(2)  # Fixed prefetch instead of AUTOTUNE to limit memory
    ), steps


def build_test_pipeline():
    preprocess_fn = make_preprocess_fn(IMG_SIZE)
    preprocess_supp_fn = make_preprocess_supplemental_fn(IMG_SIZE)

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

    # NO .cache() at 300x300 — would use ~18.5GB RAM
    return (
        combined.with_options(data_options)
        .batch(BATCH_SIZE)
        .prefetch(tf.data.AUTOTUNE)
    )


# =========================================================================
# Build model & load checkpoint
# =========================================================================
print(f"\nBuilding EfficientNetV2-S model ({NUM_CLASSES} classes)...")

base_model = tf.keras.applications.EfficientNetV2S(
    input_shape=(None, None, 3),
    include_top=False,
    weights="imagenet",
)

# Must set trainable state before loading weights
base_model.trainable = True
if UNFREEZE_LAYERS == -1:
    for layer in base_model.layers:
        layer.trainable = True
else:
    for layer in base_model.layers[:-UNFREEZE_LAYERS]:
        layer.trainable = False

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

print(f"Loading checkpoint: {CHECKPOINT}")
model.load_weights(CHECKPOINT)

trainable_count = sum(tf.keras.backend.count_params(w) for w in model.trainable_weights)
total_count = sum(tf.keras.backend.count_params(w) for w in model.weights)
print(f"  Trainable: {trainable_count:,} / {total_count:,} parameters")

# =========================================================================
# Build pipelines
# =========================================================================
print("\nBuilding data pipelines...")
train_ds, steps_per_epoch = build_train_pipeline()
test_ds = build_test_pipeline()

# =========================================================================
# Compile & train
# =========================================================================
def cat_crossentropy_smoothed(y_true, y_pred):
    return tf.keras.losses.categorical_crossentropy(
        y_true, y_pred, label_smoothing=LABEL_SMOOTHING)

first_decay_steps = steps_per_epoch * max(4, MAX_EPOCHS // 5)
lr_schedule = tf.keras.optimizers.schedules.CosineDecayRestarts(
    initial_learning_rate=BASE_LR,
    first_decay_steps=first_decay_steps,
    t_mul=1.5,
    m_mul=0.85,
    alpha=1e-8,
)

model.compile(
    optimizer=tf.keras.optimizers.AdamW(
        learning_rate=lr_schedule,
        weight_decay=WEIGHT_DECAY,
    ),
    loss=cat_crossentropy_smoothed,
    metrics=["accuracy"],
)

# Pre-training evaluation (must be after compile)
print("\nPre-training evaluation (should match ~48.9% from last training)...")
pre_loss, pre_acc = model.evaluate(test_ds, verbose=1)
print(f"  Starting accuracy: {pre_acc*100:.2f}%")

early_stop = tf.keras.callbacks.EarlyStopping(
    monitor="val_loss",
    patience=PATIENCE,
    restore_best_weights=True,
    verbose=1,
)

ckpt_path = os.path.join(CACHE_DIR, "best_weights_continue.weights.h5")
model_ckpt = tf.keras.callbacks.ModelCheckpoint(
    ckpt_path, monitor="val_loss", save_best_only=True,
    save_weights_only=True, verbose=1,
)

print(f"\n{'=' * 70}")
print(f"PHASE 3: Extended fine-tuning at {IMG_SIZE}x{IMG_SIZE}")
print(f"  {'ALL layers' if UNFREEZE_LAYERS == -1 else f'Top {UNFREEZE_LAYERS} layers'}")
print(f"  {MAX_EPOCHS} max epochs, patience={PATIENCE}, LR={BASE_LR}")
print(f"  Batch size: {BATCH_SIZE}")
print(f"{'=' * 70}")

history = model.fit(
    train_ds,
    validation_data=test_ds,
    epochs=MAX_EPOCHS,
    steps_per_epoch=steps_per_epoch,
    callbacks=[early_stop, model_ckpt],
)

# =========================================================================
# Final evaluation
# =========================================================================
train_time = time.time() - start_time
loss, acc = model.evaluate(test_ds)

print(f"\n{'=' * 70}")
print(f"RESULTS")
print(f"{'=' * 70}")
print(f"  Starting accuracy:  {pre_acc*100:.2f}%")
print(f"  Final accuracy:     {acc*100:.2f}%")
print(f"  Improvement:        {(acc - pre_acc)*100:+.2f}%")
print(f"  Training time:      {train_time/60:.1f} min")
print(f"  Best checkpoint:    {ckpt_path}")

# =========================================================================
# Export to TFLite
# =========================================================================
if acc > pre_acc:
    print(f"\n  Accuracy IMPROVED — exporting TFLite via export_tflite.py...")

    # ── Delegate to export_tflite.py ────────────────────────────────────
    # We can't convert inline because the model was built under mixed_float16.
    # Changing the global policy only affects NEW layers — existing layers in
    # `model` retain their f16 dtypes. Wrapping with a new Input still passes
    # through the f16 internals, so TFLiteConverter sees f16 ops and fails
    # with ERROR_NEEDS_FLEX_OPS (TF issue #46380).
    #
    # export_tflite.py handles this correctly: it starts fresh in float32,
    # rebuilds the architecture, loads weights, and converts. No architecture
    # duplication needed here.
    import subprocess
    result = subprocess.run(
        [sys.executable, "export_tflite.py"],
        env={**os.environ, "WEIGHTS": ckpt_path},
        capture_output=False,
    )
    if result.returncode != 0:
        print(f"\n  WARNING: export_tflite.py failed (exit {result.returncode})")
        print(f"  You can retry manually: WEIGHTS={ckpt_path} python3 export_tflite.py")
else:
    print(f"\n  Accuracy did NOT improve ({acc*100:.2f}% vs {pre_acc*100:.2f}%)")
    print(f"  Keeping existing model. Try:")
    print(f"    BATCH_SIZE=12 EPOCHS=60 LR=1e-6 PATIENCE=8 python3 continue_training_v6.py")

print(f"\n{'=' * 70}")
print(f"DONE — total time: {train_time/60:.1f} min")
print(f"{'=' * 70}")
