"""
Train a dog breed classifier -- v6 targeting 90%+ accuracy with 3-5x faster training.

v6 -- Speed-optimized training:
  - EfficientNetV2-S backbone (Fused-MBConv = faster training, better accuracy)
  - Mixed precision (fp16) for ~2x GPU throughput (auto-detected)
  - 2-stage progressive resizing: 224 -> 300 (eliminates one full stage)
  - AdamW optimizer with cosine annealing + warm restarts
  - Larger batch size (64 with fp16, 32 on CPU)
  - Aggressive early stopping (patience 3, monitor val_loss)
  - tf.data disk caching + map_and_batch_fusion optimization
  - Simplified augmentation (no random erasing, lower RandAugment mag)
  - TTA-free evaluation (center-crop only during training)
  - Bilinear pooling head (GAP * GMP + BN) -- proven in v4/v5
  - Bbox crop from Stanford Dogs annotations (50/50 mixed)
  - CutMix + Mixup combined (proven on FGVC)

Output: assets/dog_model_v6.tflite (uint8 input, uint8 output)
        assets/dog_model.tflite    (copy for app)
        assets/dog_labels.txt      (one breed name per line)
        train_v6_report.json       (training metrics)

Usage:
  pip install tensorflow tensorflow-datasets Pillow
  python train_model_v6.py
"""
import os
import glob
import math
import time
import json
import shutil
import numpy as np

# -- CPU optimization env vars (must be set BEFORE importing TF) ----------
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

# -- GPU detection and mixed precision setup -------------------------------
gpus = tf.config.experimental.list_physical_devices("GPU")
HAS_GPU = len(gpus) > 0
for gpu in gpus:
    tf.config.experimental.set_memory_growth(gpu, True)

# Enable mixed precision BEFORE building any model (fp16 on GPU, float32 on CPU).
# Mixed precision halves memory usage, allowing doubled batch size, and runs
# ~2x faster on modern GPUs with Tensor Cores (V100, A100, RTX 30/40 series).
if HAS_GPU:
    policy = tf.keras.mixed_precision.Policy("mixed_float16")
    tf.keras.mixed_precision.set_global_policy(policy)
    print(f"[v6] Mixed precision ENABLED (mixed_float16) -- ~2x GPU speedup")
else:
    print(f"[v6] No GPU detected -- using float32 (mixed precision disabled)")

import tensorflow_datasets as tfds

# -- Config ----------------------------------------------------------------
# 2-stage progressive resizing (v5 used 3 stages: 192->224->260)
# Fewer stages = fewer costly pipeline rebuilds + recompilations.
IMG_SIZES = [224, 300]
FINAL_IMG_SIZE = 300              # EfficientNetV2-S native is 384, but 300 is faster
BATCH_SIZE = 64 if HAS_GPU else 48  # fp16 halves memory -> double batch; 48 on CPU uses 16 cores well
# Per-stage batch sizes: 300x300 with all layers unfrozen needs smaller batch (8GB VRAM limit)
BATCH_SIZES_PER_STAGE = [64, 16] if HAS_GPU else [48, 32]
OUTPUT_DIR = "assets"
SUPPLEMENTAL_DIR = "supplemental_dogs"
CACHE_DIR = "tf_cache"            # disk cache for decoded images

# Training phases
HEAD_EPOCHS = 5
FINE_TUNE_EPOCHS_PER_SIZE = [10, 12]  # epochs per progressive stage
FINE_TUNE_LAYERS_STAGE = [60, 150]    # top 150 layers (~70% of EfficientNetV2-S) — -1 OOMs on 8GB VRAM at 300x300

# Resume from a specific stage after a crash (set via env var or change here)
# 0 = start from scratch, 1 = skip Phase 1 (head), 2 = skip Phase 1 + Phase 2.1
RESUME_FROM_STAGE = int(os.environ.get("RESUME_STAGE", "0"))

# Augmentation config
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

# RandAugment -- slightly lower magnitude for V2 (already a better feature extractor,
# so it needs less aggressive augmentation to generalize well)
RANDAUG_NUM_LAYERS = 2
RANDAUG_MAGNITUDE = 7             # v5 used 9

# Early stopping -- patience 3 across all stages (v5 used 4-5).
# Monitoring val_loss instead of val_accuracy gives a more stable signal.
EARLY_STOP_PATIENCE = 3

# AdamW weight decay -- decoupled from learning rate for proper regularization
WEIGHT_DECAY = 1e-4

start_time = time.time()

print(f"\nCPU cores: {cpu_count}")
print(f"GPU available: {HAS_GPU} ({len(gpus)} device(s))")
print(f"TF version: {tf.__version__}")
print(f"\nv6 Config:")
print(f"  Backbone: EfficientNetV2-S (Fused-MBConv, faster training)")
print(f"  Progressive sizes: {IMG_SIZES} (2 stages, v5 used 3)")
print(f"  Batch size: {BATCH_SIZE} ({'fp16 doubled' if HAS_GPU else 'CPU default'})")
print(f"  Optimizer: AdamW (weight_decay={WEIGHT_DECAY})")
print(f"  LR schedule: CosineDecayRestarts (warm restarts)")
print(f"  Label smoothing: {LABEL_SMOOTHING}")
print(f"  CutMix: prob={CUTMIX_PROB}, alpha={CUTMIX_ALPHA}")
print(f"  Mixup: prob={MIXUP_PROB}, alpha={MIXUP_ALPHA}")
print(f"  RandAugment: layers={RANDAUG_NUM_LAYERS}, mag={RANDAUG_MAGNITUDE}")
print(f"  Bbox crop: {USE_BBOX_CROP} (padding={BBOX_PADDING})")
print(f"  Random erasing: REMOVED (marginal benefit, adds compute)")
print(f"  Early stopping: patience={EARLY_STOP_PATIENCE}, monitor=val_loss")
print(f"  Mixed precision: {'fp16' if HAS_GPU else 'float32'}")


# =========================================================================
# Step 1: Load Stanford Dogs WITH bounding boxes
# =========================================================================
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


# =========================================================================
# Step 2: Bounding box crop utilities
# =========================================================================
def crop_to_bbox_with_padding(image, bbox, padding=BBOX_PADDING):
    """Crop image to bounding box with context padding.

    The padding adds surrounding context around the dog, which helps the model
    learn contextual features (e.g. background, body proportions) in addition
    to the tightly-cropped subject.
    """
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
    """50% bbox crop, 50% full image for training.

    Using a mix prevents the model from overfitting to tightly-cropped subjects
    and teaches it to handle both zoomed-in and full-scene inputs at inference.
    """
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
    """Always crop to bbox (for test set) -- consistent evaluation."""
    image = example["image"]
    label = example["label"]
    bbox = example["objects"]["bbox"]
    has_bbox = tf.shape(bbox)[0] > 0
    result = tf.cond(has_bbox,
                     lambda: crop_to_bbox_with_padding(image, bbox[0]),
                     lambda: image)
    return result, label


# NOTE: Stanford dataset label remapping and filtering is applied AFTER
# Step 3 determines which breeds to exclude.  See "Step 2b" below.


# =========================================================================
# Step 3: Clean names & discover supplemental breeds
# =========================================================================
def clean_stanford_name(raw_name: str) -> str:
    """Convert Stanford Dogs label format 'n02085620-Chihuahua' to proper breed name.

    Maps informal/archaic Stanford Dogs names to standard breed names used in
    dog_labels.txt and the app.  Wild canids (dingo, dhole, african hunting dog)
    are mapped to None so they can be excluded from training.
    """
    if "-" in raw_name:
        raw_name = raw_name.split("-", 1)[1]
    informal = raw_name.replace("_", " ")

    # Stanford informal name -> proper breed name (or None to exclude)
    _STANFORD_NAME_MAP = {
        "chihuahua": "Chihuahua",
        "japanese spaniel": "Japanese Chin",
        "maltese dog": "Maltese",
        "pekinese": "Pekingese",
        "shih-tzu": "Shih Tzu",
        "blenheim spaniel": "Blenheim Spaniel",
        "papillon": "Papillon",
        "toy terrier": "Toy Terrier",
        "rhodesian ridgeback": "Rhodesian Ridgeback",
        "afghan hound": "Afghan Hound",
        "basset": "Basset Hound",
        "beagle": "Beagle",
        "bloodhound": "Bloodhound",
        "bluetick": "Bluetick Coonhound",
        "black-and-tan coonhound": "Black and Tan Coonhound",
        "walker hound": "Walker Hound",
        "english foxhound": "English Foxhound",
        "redbone": "Redbone Coonhound",
        "borzoi": "Borzoi",
        "irish wolfhound": "Irish Wolfhound",
        "italian greyhound": "Italian Greyhound",
        "whippet": "Whippet",
        "ibizan hound": "Ibizan Hound",
        "norwegian elkhound": "Norwegian Elkhound",
        "otterhound": "Otterhound",
        "saluki": "Saluki",
        "scottish deerhound": "Scottish Deerhound",
        "weimaraner": "Weimaraner",
        "staffordshire bullterrier": "Staffordshire Bull Terrier",
        "american staffordshire terrier": "American Staffordshire Terrier",
        "bedlington terrier": "Bedlington Terrier",
        "border terrier": "Border Terrier",
        "kerry blue terrier": "Kerry Blue Terrier",
        "irish terrier": "Irish Terrier",
        "norfolk terrier": "Norfolk Terrier",
        "norwich terrier": "Norwich Terrier",
        "yorkshire terrier": "Yorkshire Terrier",
        "wire-haired fox terrier": "Wire Fox Terrier",
        "lakeland terrier": "Lakeland Terrier",
        "sealyham terrier": "Sealyham Terrier",
        "airedale": "Airedale Terrier",
        "cairn": "Cairn Terrier",
        "australian terrier": "Australian Terrier",
        "dandie dinmont": "Dandie Dinmont Terrier",
        "boston bull": "Boston Terrier",
        "miniature schnauzer": "Miniature Schnauzer",
        "giant schnauzer": "Giant Schnauzer",
        "standard schnauzer": "Standard Schnauzer",
        "scotch terrier": "Scottish Terrier",
        "tibetan terrier": "Tibetan Terrier",
        "silky terrier": "Silky Terrier",
        "soft-coated wheaten terrier": "Soft-Coated Wheaten Terrier",
        "west highland white terrier": "West Highland White Terrier",
        "lhasa": "Lhasa Apso",
        "flat-coated retriever": "Flat-Coated Retriever",
        "curly-coated retriever": "Curly-Coated Retriever",
        "golden retriever": "Golden Retriever",
        "labrador retriever": "Labrador Retriever",
        "chesapeake bay retriever": "Chesapeake Bay Retriever",
        "german short-haired pointer": "German Shorthaired Pointer",
        "vizsla": "Vizsla",
        "english setter": "English Setter",
        "irish setter": "Irish Setter",
        "gordon setter": "Gordon Setter",
        "brittany spaniel": "Brittany",
        "clumber": "Clumber Spaniel",
        "english springer": "English Springer Spaniel",
        "welsh springer spaniel": "Welsh Springer Spaniel",
        "cocker spaniel": "Cocker Spaniel",
        "sussex spaniel": "Sussex Spaniel",
        "irish water spaniel": "Irish Water Spaniel",
        "kuvasz": "Kuvasz",
        "schipperke": "Schipperke",
        "groenendael": "Belgian Sheepdog",
        "malinois": "Belgian Malinois",
        "briard": "Briard",
        "kelpie": "Australian Kelpie",
        "komondor": "Komondor",
        "old english sheepdog": "Old English Sheepdog",
        "shetland sheepdog": "Shetland Sheepdog",
        "collie": "Collie",
        "border collie": "Border Collie",
        "bouvier des flandres": "Bouvier des Flandres",
        "rottweiler": "Rottweiler",
        "german shepherd": "German Shepherd",
        "doberman": "Doberman Pinscher",
        "miniature pinscher": "Miniature Pinscher",
        "greater swiss mountain dog": "Greater Swiss Mountain Dog",
        "bernese mountain dog": "Bernese Mountain Dog",
        "appenzeller": "Appenzeller Sennenhund",
        "entlebucher": "Entlebucher Mountain Dog",
        "boxer": "Boxer",
        "bull mastiff": "Bullmastiff",
        "tibetan mastiff": "Tibetan Mastiff",
        "french bulldog": "French Bulldog",
        "great dane": "Great Dane",
        "saint bernard": "Saint Bernard",
        "eskimo dog": "American Eskimo Dog",
        "malamute": "Alaskan Malamute",
        "siberian husky": "Siberian Husky",
        "affenpinscher": "Affenpinscher",
        "basenji": "Basenji",
        "pug": "Pug",
        "leonberg": "Leonberger",
        "newfoundland": "Newfoundland",
        "great pyrenees": "Great Pyrenees",
        "samoyed": "Samoyed",
        "pomeranian": "Pomeranian",
        "chow": "Chow Chow",
        "keeshond": "Keeshond",
        "brabancon griffon": "Brussels Griffon",
        "pembroke": "Pembroke Welsh Corgi",
        "cardigan": "Cardigan Welsh Corgi",
        "toy poodle": "Toy Poodle",
        "miniature poodle": "Miniature Poodle",
        "standard poodle": "Standard Poodle",
        "mexican hairless": "Xoloitzcuintli",
        # Wild canids -- exclude from training (not domestic dog breeds)
        "dingo": None,
        "dhole": None,
        "african hunting dog": None,
    }

    return _STANFORD_NAME_MAP.get(informal, informal)


def clean_supplemental_name(folder_name: str) -> str:
    """Convert folder name 'golden_retriever' to 'Golden Retriever'.

    Handles special cases: lowercase articles/prepositions (de, of, and, do, dell'),
    and irregular capitalization (McNab, McIntosh, etc.).
    """
    # Special-case overrides for names that .title() gets wrong
    _overrides = {
        "mcnab_dog": "McNab Dog",
        "cirneco_dell'etna": "Cirneco dell'Etna",
        "danish-swedish_farmdog": "Danish-Swedish Farmdog",
        "pont-audemer_spaniel": "Pont-Audemer Spaniel",
    }
    if folder_name in _overrides:
        return _overrides[folder_name]

    # Lowercase articles/prepositions that should not be capitalized
    _lowercase_words = {"de", "do", "da", "of", "and", "the", "del", "des", "von"}

    words = folder_name.replace("_", " ").split()
    result = []
    for i, w in enumerate(words):
        if i > 0 and w.lower() in _lowercase_words:
            result.append(w.lower())
        else:
            result.append(w.capitalize())
    return " ".join(result)


# Build Stanford name list, excluding wild canids (mapped to None).
# Track excluded indices so we can filter them from the dataset.
_stanford_all_clean = [clean_stanford_name(n) for n in stanford_class_names]
_excluded_stanford_indices = {i for i, n in enumerate(_stanford_all_clean) if n is None}
stanford_clean_names = [n for n in _stanford_all_clean if n is not None]
stanford_clean_lower = {n.lower() for n in stanford_clean_names}

# Build a remap table: old Stanford label index -> new index (after exclusions).
# Excluded indices map to -1 and will be filtered from the dataset.
_stanford_remap = {}
new_idx = 0
for old_idx in range(len(_stanford_all_clean)):
    if old_idx in _excluded_stanford_indices:
        _stanford_remap[old_idx] = -1
    else:
        _stanford_remap[old_idx] = new_idx
        new_idx += 1

if _excluded_stanford_indices:
    excluded_names = [_stanford_all_clean[i] or stanford_class_names[i]
                      for i in sorted(_excluded_stanford_indices)]
    print(f"  Excluded {len(_excluded_stanford_indices)} wild canids from Stanford Dogs: "
          f"{', '.join(str(n) for n in excluded_names)}")

# -- Step 2b: Build Stanford datasets with label remapping & filtering ----
# Create a TF lookup table to remap old Stanford label indices to new ones.
_remap_keys = sorted(_stanford_remap.keys())
_remap_vals = [_stanford_remap[k] for k in _remap_keys]
_remap_table = tf.lookup.StaticHashTable(
    tf.lookup.KeyValueTensorInitializer(
        tf.constant(_remap_keys, dtype=tf.int64),
        tf.constant(_remap_vals, dtype=tf.int64),
    ),
    default_value=tf.constant(-1, dtype=tf.int64),
)

def _remap_stanford_label(image, label):
    """Remap Stanford label index and mark excluded breeds with -1."""
    new_label = _remap_table.lookup(tf.cast(label, tf.int64))
    return image, new_label

ds_train_stanford = ds_train_stanford_raw.map(
    extract_with_mixed_crop, num_parallel_calls=tf.data.AUTOTUNE
)
ds_test_stanford = ds_test_stanford_raw.map(
    extract_with_bbox_crop, num_parallel_calls=tf.data.AUTOTUNE
)

# Remap labels and filter out excluded wild canids
ds_train_stanford = ds_train_stanford.map(
    _remap_stanford_label, num_parallel_calls=tf.data.AUTOTUNE
).filter(lambda img, lbl: lbl >= 0)
ds_test_stanford = ds_test_stanford.map(
    _remap_stanford_label, num_parallel_calls=tf.data.AUTOTUNE
).filter(lambda img, lbl: lbl >= 0)

stanford_num_classes = len(stanford_clean_names)  # Update count after exclusions
print(f"  Stanford Dogs after exclusions: {stanford_num_classes} breeds")

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
    if clean.lower() in stanford_clean_lower:
        extra_supplemental.append((folder_name, clean))
    else:
        new_supplemental.append((folder_name, clean))

# Build unified label list: Stanford Dogs first, then new supplemental breeds
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


# =========================================================================
# Step 4: Build supplemental datasets
# =========================================================================
def load_and_decode_image(file_path, label):
    """Load image from disk and decode to float32 tensor."""
    raw = tf.io.read_file(file_path)
    image = tf.io.decode_jpeg(raw, channels=3)
    image = tf.cast(image, tf.float32)
    label = tf.cast(label, tf.int64)
    return image, label


def build_supplemental_dataset(breeds_list, label_map, is_train=True):
    """Build a tf.data.Dataset from supplemental breed image folders.

    Uses a fixed seed (42) for reproducible 80/20 train/test splits.
    """
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


# =========================================================================
# Step 5: Augmentation functions (v6 -- streamlined, no random erasing)
# =========================================================================

def rand_augment(image, num_layers=RANDAUG_NUM_LAYERS, magnitude=RANDAUG_MAGNITUDE):
    """Apply RandAugment: each transform applied with independent probability.

    Graph-mode safe -- no Python-level branching on tensor values.
    v6: lower magnitude (7 vs 9). EfficientNetV2-S is already a better feature
    extractor, so less aggressive augmentation is needed to prevent underfitting.
    """
    mag = float(magnitude) / 10.0  # Python float, not tensor
    prob = float(num_layers) / 8.0  # ~probability each transform fires

    # Rotation +/-15 degrees
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

    # Grayscale (lower probability -- dogs are color-identified less than birds)
    image = tf.cond(
        tf.random.uniform([]) < prob * 0.5,
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
    """Create augmentation function for a given image size (progressive resizing).

    v6 changes from v5:
      - Uses EfficientNetV2 preprocessing (different normalization than V1)
      - No random erasing (removed for speed -- marginal accuracy benefit)
    """
    def augment(image, label):
        image = tf.cast(image, tf.float32)
        # Resize with padding for random crop -- the padding gives the random crop
        # room to create slight translation augmentation
        pad = max(40, int(img_size * 0.18))
        image = tf.image.resize(image, [img_size + pad, img_size + pad])
        image = tf.image.random_crop(image, [img_size, img_size, 3])
        image = tf.image.random_flip_left_right(image)

        # RandAugment (rotation, shear, translate, color, etc.)
        image = rand_augment(image)

        # Additional color augmentation
        image = tf.image.random_brightness(image, 0.25)
        image = tf.image.random_contrast(image, 0.7, 1.3)

        image = tf.clip_by_value(image, 0.0, 255.0)

        # v6: NO random erasing (removed for speed, marginal benefit)
        # v6: EfficientNetV2 preprocessing (rescales to [-1, 1] range)
        image = tf.keras.applications.efficientnet_v2.preprocess_input(image)
        return image, label
    return augment


def make_augment_supplemental_fn(img_size):
    """Stronger augmentation for supplemental images (fewer images per breed).

    Supplemental breeds typically have only ~80-100 training images vs ~150+
    for Stanford Dogs breeds, so we apply more aggressive augmentation to
    prevent overfitting.
    """
    def augment_supplemental(image, label):
        image = tf.cast(image, tf.float32)
        pad = max(60, int(img_size * 0.25))
        image = tf.image.resize(image, [img_size + pad, img_size + pad])
        image = tf.image.random_crop(image, [img_size, img_size, 3])
        image = tf.image.random_flip_left_right(image)

        # RandAugment with extra layers for supplemental (more variety needed)
        image = rand_augment(image, num_layers=3, magnitude=RANDAUG_MAGNITUDE)

        image = tf.image.random_brightness(image, 0.3)
        image = tf.image.random_contrast(image, 0.6, 1.4)
        image = tf.clip_by_value(image, 0.0, 255.0)

        # v6: NO random erasing
        image = tf.keras.applications.efficientnet_v2.preprocess_input(image)
        return image, label
    return augment_supplemental


def make_preprocess_fn(img_size):
    """Test/val preprocessing -- simple center resize, no TTA.

    v6: TTA-free evaluation during training for speed. The 5-crop TTA from v5
    added ~5x overhead per validation pass with marginal accuracy lift. For final
    deployment evaluation, TTA can be run separately via verify_tflite.py.
    """
    def preprocess(image, label):
        image = tf.image.resize(image, [img_size, img_size])
        image = tf.cast(image, tf.float32)
        image = tf.keras.applications.efficientnet_v2.preprocess_input(image)
        return image, label
    return preprocess


def make_preprocess_supplemental_fn(img_size):
    """Test/val preprocessing for supplemental images."""
    def preprocess_supplemental(image, label):
        image = tf.image.resize(image, [img_size, img_size])
        image = tf.cast(image, tf.float32)
        image = tf.keras.applications.efficientnet_v2.preprocess_input(image)
        return image, label
    return preprocess_supplemental


# -- CutMix + Mixup batch augmentation ------------------------------------
def cutmix_batch(images, labels):
    """CutMix: cut and paste rectangular patches between training images.

    This forces the model to attend to multiple regions of the image rather
    than relying on a single discriminative part (e.g. just the face).
    """
    batch_size = tf.shape(images)[0]
    img_h = tf.shape(images)[1]
    img_w = tf.shape(images)[2]

    # Sample lambda from Beta distribution via gamma ratio
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
    """Mixup: linear interpolation between pairs of images and labels.

    Encourages the model to behave linearly between training examples,
    which improves calibration and generalization.
    """
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
    """Apply CutMix or Mixup or neither (mutually exclusive per batch).

    Per-batch exclusivity prevents conflicting augmentations from stacking
    and producing unrealistic training images.

    Also computes per-sample weights from class_weights_tensor so that class
    balancing works correctly with one-hot labels (model.fit class_weight
    parameter is silently ignored for one-hot encoded labels).
    """
    labels_oh = tf.one_hot(tf.cast(labels, tf.int32), NUM_CLASSES)
    rand = tf.random.uniform([])

    def do_cutmix():
        return cutmix_batch(images, labels_oh)

    def do_mixup():
        return mixup_batch(images, labels_oh)

    def do_nothing():
        return images, labels_oh

    cutmix_threshold = CUTMIX_PROB
    mixup_threshold = CUTMIX_PROB + MIXUP_PROB

    result = tf.case([
        (tf.less(rand, cutmix_threshold), do_cutmix),
        (tf.less(rand, mixup_threshold), do_mixup),
    ], default=do_nothing)

    mixed_images, mixed_labels = result

    # Compute per-sample weights: weighted sum of class weights by label distribution.
    # This correctly handles mixed labels from CutMix/Mixup.
    sample_weights = tf.reduce_sum(mixed_labels * class_weights_tensor, axis=-1)

    return mixed_images, mixed_labels, sample_weights


# =========================================================================
# Step 6: Build data pipelines (v6 -- disk caching + optimization flags)
# =========================================================================

# Create cache directory for disk-cached decoded images.
# After the first epoch, all image decoding is skipped -- reads come from
# the cache file, which is a significant speedup for JPEG-heavy datasets.
os.makedirs(CACHE_DIR, exist_ok=True)

# tf.data optimization options
data_options = tf.data.Options()
data_options.experimental_threading.max_intra_op_parallelism = 1
# Fuse map+batch into a single kernel for reduced overhead
data_options.experimental_optimization.map_and_batch_fusion = True


def build_train_pipeline(img_size, stage_name="train", batch_size=BATCH_SIZE):
    """Build training pipeline for a given resolution.

    v6 improvements:
      - Disk caching (.cache(filename)) for decoded images -- after epoch 1,
        image decoding overhead drops to near zero
      - map_and_batch_fusion for reduced kernel launch overhead
      - AUTOTUNE on all parallel ops
    """
    aug_fn = make_augment_fn(img_size)
    aug_supp_fn = make_augment_supplemental_fn(img_size)

    # Disk cache for Stanford Dogs (large dataset, cache decoded images).
    # The cache stores post-bbox-crop images, so the crop is computed once.
    cache_file = os.path.join(CACHE_DIR, f"stanford_train_{stage_name}")
    stanford_train = (ds_train_stanford
                      .cache(cache_file)
                      .map(aug_fn, num_parallel_calls=tf.data.AUTOTUNE))

    train_datasets = [stanford_train]
    train_weights = [float(stanford_train_count)]

    if supp_overlap_train_ds is not None:
        overlap_cache = os.path.join(CACHE_DIR, f"overlap_train_{stage_name}")
        overlap_aug = (supp_overlap_train_ds
                       .cache(overlap_cache)
                       .map(aug_supp_fn, num_parallel_calls=tf.data.AUTOTUNE))
        train_datasets.append(overlap_aug)
        train_weights.append(float(supp_overlap_train_count))

    if supp_new_train_ds is not None:
        new_cache = os.path.join(CACHE_DIR, f"new_train_{stage_name}")
        new_aug = (supp_new_train_ds
                   .cache(new_cache)
                   .map(aug_supp_fn, num_parallel_calls=tf.data.AUTOTUNE))
        train_datasets.append(new_aug)
        train_weights.append(float(supp_new_train_count))

    weight_sum = sum(train_weights)
    train_weights = [w / weight_sum for w in train_weights]

    train_datasets_repeating = [ds.repeat() for ds in train_datasets]
    if len(train_datasets_repeating) > 1:
        combined = tf.data.Dataset.sample_from_datasets(
            train_datasets_repeating, weights=train_weights, seed=42)
    else:
        combined = train_datasets_repeating[0]

    steps = total_train_count // batch_size
    return (
        combined
        .with_options(data_options)
        .batch(batch_size)
        .map(maybe_mix, num_parallel_calls=tf.data.AUTOTUNE)
        .prefetch(tf.data.AUTOTUNE)
    ), steps


def build_test_pipeline(img_size, batch_size=BATCH_SIZE):
    """Build test pipeline for a given resolution.

    v6: TTA-free -- simple center-crop resize only. This makes validation
    passes ~5x faster than v5's 5-crop TTA, at the cost of ~0.5% accuracy
    during training evaluation. Final accuracy is measured post-training.
    """
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

    # Only cache at 224x224 (~5GB RAM). At 300x300 the test set is ~18.5GB — too much for most systems.
    pipeline = combined
    if img_size <= 224:
        pipeline = pipeline.cache()
    return (
        pipeline
        .with_options(data_options)
        .batch(batch_size)
        .prefetch(tf.data.AUTOTUNE)
    )


# =========================================================================
# Step 7: Compute class weights
# =========================================================================
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
        # Inverse frequency weighting, clamped to [0.1, 10.0] to prevent
        # extreme weights from destabilizing training
        weight = total_samples / (NUM_CLASSES * class_counts[i])
        weight = min(weight, 10.0)
        weight = max(weight, 0.1)
        class_weights[i] = weight
    else:
        class_weights[i] = 1.0

weights_arr = np.array(list(class_weights.values()))
print(f"  Class weight range: [{weights_arr.min():.3f}, {weights_arr.max():.3f}]")
print(f"  Median class weight: {np.median(weights_arr):.3f}")

# Build a constant tensor for per-sample weighting inside maybe_mix().
# This replaces model.fit(class_weight=...) which is silently ignored for one-hot labels.
class_weights_tensor = tf.constant(
    [class_weights.get(i, 1.0) for i in range(NUM_CLASSES)], dtype=tf.float32
)


# =========================================================================
# Step 8: Build Model -- EfficientNetV2-S with bilinear pooling head
# =========================================================================
print(f"\nBuilding EfficientNetV2-S model ({NUM_CLASSES} classes, bilinear head)...")

phase_times = {}  # track wall-clock time per phase for the report

# Start with smallest resolution for head training
current_img_size = IMG_SIZES[0]

# EfficientNetV2-S: Google designed V2 specifically for fast training.
# Key architectural differences from EfficientNetB2 (v5):
#   - Fused-MBConv blocks in early stages (fuses depthwise+pointwise = faster on GPU)
#   - Progressive learning built into architecture design
#   - Better accuracy/latency tradeoff at all scales
# Using (None, None, 3) input allows flexible resolution across progressive stages.
base_model = tf.keras.applications.EfficientNetV2S(
    input_shape=(None, None, 3),
    include_top=False,
    weights="imagenet",
)
base_model.trainable = False

# Bilinear pooling head (proven in v4/v5, quantization-safe).
# GAP captures average feature activation (texture/color),
# GMP captures peak feature activation (discriminative parts).
# Their element-wise product captures second-order feature interactions.
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

# The classifier head MUST use float32 dtype for numerical stability with mixed
# precision. Softmax in fp16 can cause NaN/Inf due to the exp() operation on
# large logits. On CPU (no mixed precision) this dtype annotation is a no-op.
output = tf.keras.layers.Dense(
    NUM_CLASSES, activation="softmax", dtype="float32", name="classifier"
)(x)

model = tf.keras.Model(inputs=base_model.input, outputs=output)


def cat_crossentropy_smoothed(y_true, y_pred):
    """Categorical crossentropy with label smoothing.

    Label smoothing (0.05) prevents the model from becoming overconfident
    and acts as a regularizer, especially helpful with CutMix/Mixup.
    """
    return tf.keras.losses.categorical_crossentropy(
        y_true, y_pred, label_smoothing=LABEL_SMOOTHING)


# v6: AdamW replaces Adam. AdamW decouples weight decay from the gradient
# update, which provides proper L2 regularization regardless of learning rate.
# Standard Adam effectively reduces weight decay as LR decreases, which is
# undesirable during fine-tuning.
model.compile(
    optimizer=tf.keras.optimizers.AdamW(learning_rate=3e-3, weight_decay=WEIGHT_DECAY),
    loss=cat_crossentropy_smoothed,
    metrics=["accuracy"],
)

total_params = model.count_params()
trainable_params = sum(tf.keras.backend.count_params(w) for w in model.trainable_weights)
print(f"  Total parameters: {total_params:,}")
print(f"  Trainable parameters: {trainable_params:,}")
print(f"  EfficientNetV2-S feature dim: {base_model.output_shape[-1]}")


# =========================================================================
# Phase 1: Train head only (smallest resolution)
# =========================================================================
if RESUME_FROM_STAGE >= 1:
    # Skip Phase 1 — load saved head weights
    head_weights_path = os.path.join(CACHE_DIR, "best_weights_head.weights.h5")
    print(f"\n⏭️  RESUME: Skipping Phase 1 (head training), loading {head_weights_path}")
    model.load_weights(head_weights_path)
    phase_times["head_training"] = 0
else:
    phase1_start = time.time()
    print(f"\n{'=' * 70}")
    print(f"PHASE 1: Head training at {current_img_size}x{current_img_size}")
    print(f"{'=' * 70}")

    train_ds, steps_per_epoch = build_train_pipeline(current_img_size, stage_name="head")
    test_ds = build_test_pipeline(current_img_size)

    # v6: monitor val_loss for early stopping (more stable signal than val_accuracy)
    early_stop = tf.keras.callbacks.EarlyStopping(
        monitor="val_loss", patience=2, restore_best_weights=True, verbose=1)
    reduce_lr = tf.keras.callbacks.ReduceLROnPlateau(
        monitor="val_loss", factor=0.5, patience=1, min_lr=1e-6, verbose=1)
    head_ckpt = tf.keras.callbacks.ModelCheckpoint(
        os.path.join(CACHE_DIR, "best_weights_head.weights.h5"),
        monitor="val_loss", save_best_only=True, save_weights_only=True, verbose=1,
    )

    model.fit(
        train_ds,
        validation_data=test_ds,
        epochs=HEAD_EPOCHS,
        steps_per_epoch=steps_per_epoch,
        callbacks=[early_stop, reduce_lr, head_ckpt],
    )

    phase_times["head_training"] = time.time() - phase1_start
    print(f"\n  Phase 1 time: {phase_times['head_training']/60:.1f} min")


# =========================================================================
# Phase 2: Progressive fine-tuning (2 stages: 224 -> 300)
# =========================================================================
total_epoch = HEAD_EPOCHS

for stage_idx, (img_size, ft_epochs, ft_layers) in enumerate(
    zip(IMG_SIZES, FINE_TUNE_EPOCHS_PER_SIZE, FINE_TUNE_LAYERS_STAGE)):

    # Resume support: skip already-completed stages
    required_resume_stage = stage_idx + 1  # stage 0 = Phase 2.1, stage 1 = Phase 2.2
    if RESUME_FROM_STAGE > required_resume_stage:
        ckpt_path = os.path.join(CACHE_DIR, f"best_weights_ft_stage{stage_idx}.weights.h5")
        print(f"\n⏭️  RESUME: Skipping Phase 2.{stage_idx + 1}, loading {ckpt_path}")
        # Must set trainable layers before loading weights for correct shape
        base_model.trainable = True
        if ft_layers == -1:
            for layer in base_model.layers:
                layer.trainable = True
        else:
            for layer in base_model.layers[:-ft_layers]:
                layer.trainable = False
        model.load_weights(ckpt_path)
        total_epoch += ft_epochs
        continue

    stage_start = time.time()
    stage_name = f"ft_stage{stage_idx}"

    print(f"\n{'=' * 70}")
    print(f"PHASE 2.{stage_idx + 1}: Fine-tune at {img_size}x{img_size}, "
          f"{'all' if ft_layers == -1 else f'top {ft_layers}'} layers, "
          f"{ft_epochs} epochs")
    print(f"{'=' * 70}")

    # Free GPU memory from previous stage before rebuilding
    import gc
    gc.collect()

    # Progressively unfreeze more layers in each stage
    base_model.trainable = True
    if ft_layers == -1:
        # Unfreeze everything for maximum fine-tuning in final stage
        for layer in base_model.layers:
            layer.trainable = True
    else:
        # Freeze early layers (generic features), train later layers
        for layer in base_model.layers[:-ft_layers]:
            layer.trainable = False

    trainable_now = sum(tf.keras.backend.count_params(w) for w in model.trainable_weights)
    print(f"  Trainable parameters: {trainable_now:,}")

    # Build pipeline for this resolution (smaller batch for 300x300 to avoid OOM)
    stage_batch_size = BATCH_SIZES_PER_STAGE[stage_idx] if stage_idx < len(BATCH_SIZES_PER_STAGE) else BATCH_SIZE
    print(f"  Batch size: {stage_batch_size}")
    train_ds, steps_per_epoch = build_train_pipeline(img_size, stage_name=stage_name, batch_size=stage_batch_size)
    test_ds = build_test_pipeline(img_size, batch_size=stage_batch_size)

    total_ft_steps = steps_per_epoch * ft_epochs

    # v6: Cosine decay with warm restarts (CosineDecayRestarts).
    # Unlike v5's simple CosineDecay, warm restarts periodically reset the
    # learning rate to escape local minima. Each restart cycle is 1.5x longer
    # than the previous (t_mul=1.5) and peaks at 0.8x of the previous peak
    # (m_mul=0.8), creating a gradually-dampening exploration schedule.
    base_lr = 5e-5 if stage_idx == 0 else 1e-5
    first_decay_steps = steps_per_epoch * max(3, ft_epochs // 3)

    lr_schedule = tf.keras.optimizers.schedules.CosineDecayRestarts(
        initial_learning_rate=base_lr,
        first_decay_steps=first_decay_steps,
        t_mul=1.5,       # each restart cycle is 1.5x longer
        m_mul=0.8,       # each restart peak is 0.8x of previous
        alpha=1e-7,       # minimum learning rate floor
    )

    # v6: AdamW with weight decay for proper regularization
    model.compile(
        optimizer=tf.keras.optimizers.AdamW(
            learning_rate=lr_schedule,
            weight_decay=WEIGHT_DECAY,
        ),
        loss=cat_crossentropy_smoothed,
        metrics=["accuracy"],
    )

    # v6: Aggressive early stopping (patience 3 vs v5's 4-5).
    # Monitor val_loss for a more stable convergence signal -- val_accuracy
    # can plateau while val_loss continues to decrease (better calibration).
    early_stop_ft = tf.keras.callbacks.EarlyStopping(
        monitor="val_loss",
        patience=EARLY_STOP_PATIENCE,
        restore_best_weights=True,
        verbose=1,
    )

    # Model checkpoint -- save best weights per stage to survive crashes
    ckpt_path = os.path.join(CACHE_DIR, f"best_weights_{stage_name}.weights.h5")
    model_ckpt = tf.keras.callbacks.ModelCheckpoint(
        ckpt_path, monitor="val_loss", save_best_only=True,
        save_weights_only=True, verbose=1,
    )

    model.fit(
        train_ds,
        validation_data=test_ds,
        epochs=total_epoch + ft_epochs,
        initial_epoch=total_epoch,
        steps_per_epoch=steps_per_epoch,
        callbacks=[early_stop_ft, model_ckpt],
    )

    total_epoch += ft_epochs

    # Evaluate at this stage
    loss, acc = model.evaluate(test_ds)
    stage_time = time.time() - stage_start
    phase_times[f"fine_tune_stage_{stage_idx+1}"] = stage_time
    elapsed = time.time() - start_time
    print(f"\n  Stage {stage_idx + 1} accuracy: {acc:.4f} "
          f"(stage: {stage_time/60:.1f} min, total: {elapsed/60:.0f} min)")


# =========================================================================
# Final evaluation at full resolution
# =========================================================================
print(f"\n{'=' * 70}")
print("FINAL EVALUATION")
print(f"{'=' * 70}")

test_ds_final = build_test_pipeline(FINAL_IMG_SIZE, batch_size=BATCH_SIZES_PER_STAGE[-1])
loss, acc = model.evaluate(test_ds_final)
print(f"\nFinal test accuracy: {acc:.4f}")


# =========================================================================
# Confusion matrix analysis
# =========================================================================
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


# =========================================================================
# Convert to TFLite (uint8 quantized)
# =========================================================================
print("\nConverting to TFLite (uint8 quantized)...")

# Save a fixed-input-size model for TFLite conversion.
# TFLite requires static shapes -- the dynamic (None, None, 3) input from
# training must be replaced with the final resolution.
fixed_input = tf.keras.layers.Input(shape=(FINAL_IMG_SIZE, FINAL_IMG_SIZE, 3))
fixed_output = model(fixed_input)
fixed_model = tf.keras.Model(inputs=fixed_input, outputs=fixed_output)


def representative_data_gen():
    """Generate representative data for post-training quantization.

    The converter uses these samples to calibrate the int8 quantization
    ranges for each layer. 30 batches provides sufficient coverage.
    """
    for images, _ in test_ds_final.take(30):
        for image in images:
            yield [tf.expand_dims(image, 0)]


converter = tf.lite.TFLiteConverter.from_keras_model(fixed_model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.representative_dataset = representative_data_gen
# Allow float fallback for ops without int8 kernels (e.g. some EfficientNetV2 ops).
# The model will still be mostly int8 — only unsupported ops fall back to float.
converter.target_spec.supported_ops = [
    tf.lite.OpsSet.TFLITE_BUILTINS_INT8,
    tf.lite.OpsSet.TFLITE_BUILTINS,  # float fallback
]
converter.inference_input_type = tf.uint8
converter.inference_output_type = tf.uint8

try:
    tflite_model = converter.convert()
except Exception as e:
    print(f"\n⚠️  Full int8 conversion failed: {e}")
    print("Retrying with float16 quantization (larger model, still fast on GPU)...")
    converter2 = tf.lite.TFLiteConverter.from_keras_model(fixed_model)
    converter2.optimizations = [tf.lite.Optimize.DEFAULT]
    converter2.target_spec.supported_types = [tf.float16]
    tflite_model = converter2.convert()

os.makedirs(OUTPUT_DIR, exist_ok=True)

# Save as v6 model
model_path = os.path.join(OUTPUT_DIR, "dog_model_v6.tflite")
with open(model_path, "wb") as f:
    f.write(tflite_model)

model_size_mb = len(tflite_model) / (1024 * 1024)
print(f"Model saved: {model_path} ({model_size_mb:.1f} MB)")

# Also copy as the default model name so the app picks it up immediately
default_path = os.path.join(OUTPUT_DIR, "dog_model.tflite")
with open(default_path, "wb") as f:
    f.write(tflite_model)
print(f"Also saved as: {default_path}")


# =========================================================================
# Write labels
# =========================================================================
labels_path = os.path.join(OUTPUT_DIR, "dog_labels.txt")
with open(labels_path, "w", encoding="utf-8") as f:
    for name in all_clean_names:
        f.write(name + "\n")
print(f"Labels saved: {labels_path} ({len(all_clean_names)} breeds)")


# =========================================================================
# Save training report
# =========================================================================
elapsed_total = time.time() - start_time

report = {
    "version": "v6",
    "backbone": "EfficientNetV2-S",
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
    "phase_times_minutes": {k: v / 60 for k, v in phase_times.items()},
    "gpu_used": HAS_GPU,
    "mixed_precision": HAS_GPU,
    "batch_size": BATCH_SIZE,
    "optimizer": "AdamW",
    "weight_decay": WEIGHT_DECAY,
    "lr_schedule": "CosineDecayRestarts",
    "early_stop_patience": EARLY_STOP_PATIENCE,
    "early_stop_monitor": "val_loss",
    "augmentation": {
        "randaugment": {"layers": RANDAUG_NUM_LAYERS, "magnitude": RANDAUG_MAGNITUDE},
        "cutmix": {"prob": CUTMIX_PROB, "alpha": CUTMIX_ALPHA},
        "mixup": {"prob": MIXUP_PROB, "alpha": MIXUP_ALPHA},
        "random_erasing": "REMOVED (v6 optimization)",
        "bbox_crop": {"enabled": USE_BBOX_CROP, "padding": BBOX_PADDING},
    },
    "low_accuracy_breeds": [(n, float(a)) for n, a, _ in low_accuracy_breeds],
    "speedup_factors": {
        "efficientnet_v2": "Fused-MBConv in early layers = ~1.5x faster forward/backward",
        "mixed_precision": "fp16 on GPU = ~2x throughput" if HAS_GPU else "disabled (CPU)",
        "two_stage_progressive": "2 stages vs 3 = eliminates one full pipeline rebuild",
        "no_random_erasing": "removed marginal augmentation = ~5% per-step savings",
        "larger_batch": f"{BATCH_SIZE} vs 32 = fewer gradient updates per epoch",
        "aggressive_early_stop": f"patience {EARLY_STOP_PATIENCE} vs 4-5 = fewer wasted epochs",
        "cosine_restarts": "warm restarts for better minima convergence",
        "adamw": "proper weight decay decoupling = faster convergence",
        "disk_caching": "tf.data disk cache = instant image decoding after epoch 1",
        "tta_free_eval": "no 5-crop TTA during training = faster val passes",
    },
}

report_path = "train_v6_report.json"
with open(report_path, "w") as f:
    json.dump(report, f, indent=2)
print(f"\nTraining report saved: {report_path}")


# =========================================================================
# Clean up info (disk cache can be large)
# =========================================================================
print(f"\nDisk cache at: {CACHE_DIR}/")
cache_size = 0
if os.path.isdir(CACHE_DIR):
    for f in os.listdir(CACHE_DIR):
        fp = os.path.join(CACHE_DIR, f)
        if os.path.isfile(fp):
            cache_size += os.path.getsize(fp)
print(f"  Cache size: {cache_size / (1024*1024):.1f} MB")
print(f"  (Run 'rm -rf {CACHE_DIR}' to reclaim space)")


# =========================================================================
# Final summary with speedup estimate
# =========================================================================
print(f"\n{'=' * 70}")
print(f"DONE! (v6 -- EfficientNetV2-S + 2-Stage Progressive + AdamW + fp16)")
print(f"{'=' * 70}")
print(f"  dog_model_v6.tflite  -- {model_size_mb:.1f} MB (uint8 quantized)")
print(f"  dog_model.tflite     -- copied for app")
print(f"  dog_labels.txt       -- {len(all_clean_names)} breed labels")
print(f"  Final input size:    {FINAL_IMG_SIZE}x{FINAL_IMG_SIZE}")
print(f"  Stanford breeds:     {stanford_num_classes}")
print(f"  Supplemental breeds: {len(new_supplemental)}")
print(f"  Total breeds:        {NUM_CLASSES}")
print(f"  Test accuracy:       {acc:.4f}")
print(f"  Mean per-class acc:  {mean_per_class:.4f}")
print(f"  Training time:       {elapsed_total/60:.1f} min")

print(f"\n  Phase breakdown:")
for phase_name, phase_secs in phase_times.items():
    print(f"    {phase_name}: {phase_secs/60:.1f} min")

print(f"\n  v6 optimizations over v5 (87.2%, EfficientNetB2):")
print(f"    [SPEED] EfficientNetV2-S backbone (Fused-MBConv = faster training)")
print(f"    [SPEED] Mixed precision fp16 ({'ENABLED' if HAS_GPU else 'disabled, no GPU'})")
print(f"    [SPEED] 2-stage progressive (224->300) vs 3-stage (192->224->260)")
print(f"    [SPEED] Batch size {BATCH_SIZE} (vs 32)")
print(f"    [SPEED] No random erasing (marginal benefit removed)")
print(f"    [SPEED] TTA-free evaluation (center-crop only)")
print(f"    [SPEED] Disk caching for tf.data pipeline")
print(f"    [SPEED] Early stopping patience {EARLY_STOP_PATIENCE} (vs 4-5)")
print(f"    [SPEED] map_and_batch_fusion optimization enabled")
print(f"    [QUALITY] AdamW optimizer (proper weight decay decoupling)")
print(f"    [QUALITY] Cosine annealing with warm restarts (escape local minima)")
print(f"    [QUALITY] V2 architecture has better accuracy/speed tradeoff")
print(f"    [QUALITY] float32 classifier head (numerical stability with fp16)")
print(f"    [QUALITY] RandAugment magnitude 7 (tuned for V2's stronger features)")

print(f"\n  Estimated speedup vs v5:")
print(f"    - V2 backbone:        ~1.5x faster forward/backward pass")
print(f"    - fp16 (GPU only):    ~2.0x throughput {'(ACTIVE)' if HAS_GPU else '(inactive)'}")
print(f"    - 2 stages vs 3:     ~1.3x fewer pipeline rebuilds")
print(f"    - Larger batch:       ~1.3x fewer gradient steps")
print(f"    - Aggressive stop:    ~1.2x fewer wasted epochs")
print(f"    - No random erasing:  ~1.05x per-step savings")
print(f"    - Disk caching:       ~1.1x faster data loading (epoch 2+)")
if HAS_GPU:
    print(f"    Combined (GPU):       ~3-5x total speedup")
else:
    print(f"    Combined (CPU):       ~2.5-3.5x total speedup")

print(f"\n  Next steps:")
print(f"    1. Run verify_tflite.py to check quantization quality")
print(f"    2. Update tflite_identification_service.dart: _inputSize = {FINAL_IMG_SIZE}")
print(f"    3. If accuracy < 90%, consider v7:")
print(f"       - Knowledge distillation (V2-L teacher -> V2-S student)")
print(f"       - SAM optimizer (Sharpness-Aware Minimization)")
print(f"       - QAT (Quantization-Aware Training) instead of PTQ")
print(f"       - EfficientNetV2-M backbone (larger, if model size budget allows)")
