"""
Train a dog breed classifier using EfficientNetB0 on Stanford Dogs (120 breeds)
PLUS supplemental breed images from supplemental_dogs/{breed_name}/*.jpg.

v3 — Optimized for faster CPU training:
  - EfficientNetB0 backbone (replaces MobileNetV2 for better accuracy)
  - CPU thread tuning (oneDNN, KMP_BLOCKTIME, KMP_AFFINITY)
  - .cache() on datasets to avoid re-decoding images every epoch
  - Batch size 64 (fewer steps/epoch, better GPU/CPU utilization)
  - Slimmer model head (removed 512-unit layer + extra BatchNorm)
  - sample_from_datasets instead of concatenate+shuffle for balanced sampling
  - Fixed augment_supplemental (removed dead rotation code, fixed dynamic resize)
  - Dropped expensive hue/saturation augmentation
  - 5 head epochs, 8 fine-tune epochs (top 30 layers)
  - Label smoothing 0.1

Output: assets/dog_model.tflite (uint8 input, uint8 output)
        assets/dog_labels.txt  (one breed name per line, matching model output order)

Usage:
  pip install tensorflow tensorflow-datasets Pillow
  python train_model_v3.py
"""
import os
import glob
import math
import numpy as np

# ── CPU optimization env vars (must be set BEFORE importing TF) ──────────
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"
os.environ["TF_ENABLE_ONEDNN_OPTS"] = "1"       # Enable oneDNN (MKL-DNN)
os.environ["KMP_BLOCKTIME"] = "0"                # Release threads immediately
os.environ["KMP_AFFINITY"] = "granularity=fine,verbose,compact,1,0"

# Set thread counts based on available cores
cpu_count = os.cpu_count() or 8
os.environ["OMP_NUM_THREADS"] = str(cpu_count)
os.environ["TF_NUM_INTEROP_THREADS"] = str(max(2, cpu_count // 4))
os.environ["TF_NUM_INTRAOP_THREADS"] = str(cpu_count)

import tensorflow as tf

# Configure TF threading
tf.config.threading.set_inter_op_parallelism_threads(max(2, cpu_count // 4))
tf.config.threading.set_intra_op_parallelism_threads(cpu_count)

# Prevent TF from grabbing all GPU/CPU memory at once
gpus = tf.config.experimental.list_physical_devices("GPU")
for gpu in gpus:
    tf.config.experimental.set_memory_growth(gpu, True)

import tensorflow_datasets as tfds

# ── Config ────────────────────────────────────────────────────────────────
IMG_SIZE = 224
BATCH_SIZE = 64             # Doubled from 32 for fewer steps/epoch
EPOCHS = 5                  # head training
FINE_TUNE_EPOCHS = 8        # fine-tuning top 30 layers
OUTPUT_DIR = "assets"
SUPPLEMENTAL_DIR = "supplemental_dogs"
LABEL_SMOOTHING = 0.1

print(f"CPU cores: {cpu_count}")
print(f"TF inter-op threads: {tf.config.threading.get_inter_op_parallelism_threads()}")
print(f"TF intra-op threads: {tf.config.threading.get_intra_op_parallelism_threads()}")


# ── Step 1: Load Stanford Dogs ───────────────────────────────────────────
print("=" * 70)
print("Loading Stanford Dogs dataset...")
(ds_train_stanford, ds_test_stanford), info = tfds.load(
    "stanford_dogs",
    split=["train", "test"],
    as_supervised=True,
    with_info=True,
)

stanford_num_classes = info.features["label"].num_classes
stanford_class_names = info.features["label"].names  # e.g. "n02085620-Chihuahua"
stanford_train_count = info.splits["train"].num_examples
stanford_test_count = info.splits["test"].num_examples
print(f"  Stanford Dogs: {stanford_num_classes} breeds, "
      f"{stanford_train_count} train, {stanford_test_count} test")


# ── Step 2: Clean Stanford breed names ───────────────────────────────────
def clean_stanford_name(raw_name: str) -> str:
    """'n02085620-Chihuahua' -> 'Chihuahua'"""
    if "-" in raw_name:
        raw_name = raw_name.split("-", 1)[1]
    return raw_name.replace("_", " ")


stanford_clean_names = [clean_stanford_name(n) for n in stanford_class_names]


# ── Step 3: Discover supplemental breeds ─────────────────────────────────
supplemental_breeds = []   # list of (folder_name, folder_path)
supplemental_images = {}   # folder_name -> list of image paths

if os.path.isdir(SUPPLEMENTAL_DIR):
    for entry in sorted(os.listdir(SUPPLEMENTAL_DIR)):
        folder_path = os.path.join(SUPPLEMENTAL_DIR, entry)
        if not os.path.isdir(folder_path):
            continue
        # Collect images — use set to avoid double-counting .jpg/.JPG
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

# Determine which supplemental breeds are truly NEW (not already in Stanford)
stanford_clean_lower = {n.lower() for n in stanford_clean_names}


def clean_supplemental_name(folder_name: str) -> str:
    """'carolina_dog' -> 'Carolina Dog'"""
    return folder_name.replace("_", " ").title()


new_supplemental = []   # (folder_name, clean_name) for breeds NOT in Stanford
extra_supplemental = []  # (folder_name, clean_name) for breeds that overlap Stanford

for folder_name, _ in supplemental_breeds:
    clean = clean_supplemental_name(folder_name)
    if clean.lower() in stanford_clean_lower:
        extra_supplemental.append((folder_name, clean))
    else:
        new_supplemental.append((folder_name, clean))


# ── Build unified label list ─────────────────────────────────────────────
# Stanford breeds first (indices 0..119), then new supplemental breeds (120..)
all_clean_names = list(stanford_clean_names)  # copy
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
    """Load an image file, decode, resize to IMG_SIZE."""
    raw = tf.io.read_file(file_path)
    image = tf.io.decode_jpeg(raw, channels=3)
    image = tf.image.resize(image, [IMG_SIZE, IMG_SIZE])
    image = tf.cast(image, tf.float32)
    label = tf.cast(label, tf.int64)
    return image, label


def build_supplemental_dataset(breeds_list, label_map, is_train=True):
    """Build a tf.data.Dataset from supplemental image folders."""
    all_paths = []
    all_labels = []

    for folder_name, clean_name in breeds_list:
        imgs = supplemental_images[folder_name]
        label_idx = label_map[clean_name]

        # Split 80/20 for train/test
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

    ds = tf.data.Dataset.from_tensor_slices(
        (all_paths, all_labels)
    )
    ds = ds.map(load_and_decode_image, num_parallel_calls=tf.data.AUTOTUNE)

    return ds, len(all_paths)


# Build label_map: clean_name -> label index for ALL breeds
label_map = {name: idx for idx, name in enumerate(all_clean_names)}

# New supplemental breeds (label indices >= 120)
supp_new_train_ds, supp_new_train_count = build_supplemental_dataset(
    new_supplemental, label_map, is_train=True
)
supp_new_test_ds, supp_new_test_count = build_supplemental_dataset(
    new_supplemental, label_map, is_train=False
)

# Overlapping supplemental breeds (extra data for existing Stanford breeds)
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


# ── Step 5: Preprocessing & Augmentation ─────────────────────────────────
def preprocess(image, label):
    """Resize + EfficientNet preprocessing for validation/test."""
    image = tf.image.resize(image, [IMG_SIZE, IMG_SIZE])
    image = tf.cast(image, tf.float32)
    image = tf.keras.applications.efficientnet.preprocess_input(image)
    return image, label


def augment(image, label):
    """Random augmentation for training (standard breeds)."""
    image = tf.image.resize(image, [IMG_SIZE + 40, IMG_SIZE + 40])
    image = tf.image.random_crop(image, [IMG_SIZE, IMG_SIZE, 3])
    image = tf.image.random_flip_left_right(image)
    image = tf.image.random_brightness(image, 0.25)
    image = tf.image.random_contrast(image, 0.7, 1.3)
    image = tf.clip_by_value(image, 0.0, 255.0)
    image = tf.cast(image, tf.float32)
    image = tf.keras.applications.efficientnet.preprocess_input(image)
    return image, label


def preprocess_supplemental(image, label):
    """Supplemental images already resized — EfficientNet preprocessing."""
    image = tf.cast(image, tf.float32)
    image = tf.keras.applications.efficientnet.preprocess_input(image)
    return image, label


def augment_supplemental(image, label):
    """Stronger augmentation for supplemental images (fewer samples).
    Fixed: no dead code, fixed-size resize for XLA compatibility."""
    # Random zoom via fixed resize + crop
    image = tf.image.resize(image, [IMG_SIZE + 60, IMG_SIZE + 60])
    image = tf.image.random_crop(image, [IMG_SIZE, IMG_SIZE, 3])
    image = tf.image.random_flip_left_right(image)
    image = tf.image.random_brightness(image, 0.3)
    image = tf.image.random_contrast(image, 0.6, 1.4)
    image = tf.clip_by_value(image, 0.0, 255.0)
    image = tf.cast(image, tf.float32)
    image = tf.keras.applications.efficientnet.preprocess_input(image)
    return image, label


# ── Step 6: Combine datasets ────────────────────────────────────────────

# Data pipeline options
data_options = tf.data.Options()
data_options.experimental_threading.max_intra_op_parallelism = 1

# --- Training dataset ---
# Stanford train (augmented) — cache raw data, then augment
stanford_train = (
    ds_train_stanford
    .cache()
    .map(augment, num_parallel_calls=tf.data.AUTOTUNE)
)

# Build list of datasets and weights for sample_from_datasets
train_datasets = [stanford_train]
train_weights = [float(stanford_train_count)]

# Add supplemental overlap data
if supp_overlap_train_ds is not None:
    overlap_augmented = (
        supp_overlap_train_ds
        .cache()
        .map(augment_supplemental, num_parallel_calls=tf.data.AUTOTUNE)
    )
    train_datasets.append(overlap_augmented)
    train_weights.append(float(supp_overlap_train_count))

# Add new supplemental breed data
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

# Normalize weights
weight_sum = sum(train_weights)
train_weights = [w / weight_sum for w in train_weights]

# Use sample_from_datasets for balanced interleaving (avoids concatenate+shuffle)
# Each component dataset must repeat() for sample_from_datasets to work
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
    .prefetch(tf.data.AUTOTUNE)
)

# --- Test/validation dataset ---
test_components = [
    ds_test_stanford.map(preprocess, num_parallel_calls=tf.data.AUTOTUNE)
]

if supp_overlap_test_ds is not None:
    test_components.append(
        supp_overlap_test_ds.map(preprocess_supplemental, num_parallel_calls=tf.data.AUTOTUNE)
    )

if supp_new_test_ds is not None:
    test_components.append(
        supp_new_test_ds.map(preprocess_supplemental, num_parallel_calls=tf.data.AUTOTUNE)
    )

combined_test_ds = test_components[0]
for ds in test_components[1:]:
    combined_test_ds = combined_test_ds.concatenate(ds)

total_test_count = (stanford_test_count
                    + supp_new_test_count
                    + supp_overlap_test_count)

test_ds = (
    combined_test_ds
    .cache()  # Cache test set — it's read-only and reused every epoch
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


# ── Step 8: Build Model (slimmer head) ─────────────────────────────────
print(f"\nBuilding EfficientNetB0 model ({NUM_CLASSES} classes, slim head)...")
base_model = tf.keras.applications.EfficientNetB0(
    input_shape=(IMG_SIZE, IMG_SIZE, 3),
    include_top=False,
    weights="imagenet",
)
base_model.trainable = False

# Slimmer head: removed 512-unit layer + extra BatchNorm
# GlobalAvgPool -> Dropout -> 256 -> Dropout -> softmax
model = tf.keras.Sequential([
    base_model,
    tf.keras.layers.GlobalAveragePooling2D(),
    tf.keras.layers.Dropout(0.4),
    tf.keras.layers.Dense(256, activation="relu"),
    tf.keras.layers.Dropout(0.3),
    tf.keras.layers.Dense(NUM_CLASSES, activation="softmax"),
])


def sparse_categorical_crossentropy_with_smoothing(y_true, y_pred):
    """Sparse categorical crossentropy with label smoothing."""
    y_true_onehot = tf.one_hot(tf.cast(y_true, tf.int32), NUM_CLASSES)
    return tf.keras.losses.categorical_crossentropy(
        y_true_onehot, y_pred, label_smoothing=LABEL_SMOOTHING
    )


model.compile(
    optimizer=tf.keras.optimizers.Adam(learning_rate=3e-3),
    loss=sparse_categorical_crossentropy_with_smoothing,
    metrics=["accuracy"],
)
print(f"  Label smoothing: {LABEL_SMOOTHING}")
print(f"  Head parameters: {sum(l.count_params() for l in model.layers[1:]):,}")


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


# ── Phase 2: Fine-tune top 30 layers ────────────────────────────────────
print(f"\nPhase 2: Fine-tuning top 30 layers ({FINE_TUNE_EPOCHS} epochs)...")
base_model.trainable = True
for layer in base_model.layers[:-30]:
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
    loss=sparse_categorical_crossentropy_with_smoothing,
    metrics=["accuracy"],
)

early_stop_ft = tf.keras.callbacks.EarlyStopping(
    monitor="val_accuracy",
    patience=2,
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
for images, labels in test_ds:
    preds = model.predict(images, verbose=0)
    all_preds.extend(np.argmax(preds, axis=1))
    all_labels_list.extend(labels.numpy())

all_preds = np.array(all_preds)
all_labels_arr = np.array(all_labels_list)

cm = tf.math.confusion_matrix(all_labels_arr, all_preds, num_classes=NUM_CLASSES).numpy()

# Per-class accuracy for supplemental breeds
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

# Top-10 most confused pairs overall
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
print(f"DONE!")
print(f"{'=' * 70}")
print(f"  dog_model.tflite -- {model_size_mb:.1f} MB (uint8 quantized)")
print(f"  dog_labels.txt   -- {len(all_clean_names)} breed labels")
print(f"  Stanford breeds: {stanford_num_classes}")
print(f"  Supplemental breeds: {len(new_supplemental)}")
print(f"  Total breeds: {NUM_CLASSES}")
print(f"  Test accuracy: {acc:.4f}")
