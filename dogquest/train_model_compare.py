"""
train_model_compare.py — Parameterized backbone comparison for dog breed classification.

Trains the same dataset (151 breeds) with different backbones using a standardized
v3-style head (no bilinear/Lambda issues). Isolates the backbone variable.

Supported backbones:
  - efficientnetb0   (224x224, ~5 MB)   — current baseline
  - efficientnetv2b0 (224x224, ~6 MB)   — improved training, same size
  - nasnetmobile     (224x224, ~4 MB)   — architecture-searched for mobile
  - xception         (299x299, ~20 MB)  — best for fine-grained features
  - mobilenetv2      (224x224, ~3.5 MB) — already tried (73.8%)
  - resnet50         (224x224, ~25 MB)  — reference only, too large for mobile

Usage:
  python train_model_compare.py --backbone efficientnetv2b0
  python train_model_compare.py --backbone nasnetmobile
  python train_model_compare.py --backbone xception
"""
import os
import sys
import glob
import json
import time
import argparse
import numpy as np

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


# ── Backbone registry ────────────────────────────────────────────────────

BACKBONE_REGISTRY = {
    "efficientnetb0": {
        "class": "EfficientNetB0",
        "module": "efficientnet",
        "input_size": 224,
        "preprocess": "efficientnet",
    },
    "efficientnetv2b0": {
        "class": "EfficientNetV2B0",
        "module": "efficientnet_v2",
        "input_size": 224,
        "preprocess": "efficientnet_v2",
    },
    "nasnetmobile": {
        "class": "NASNetMobile",
        "module": "nasnet",
        "input_size": 224,
        "preprocess": "nasnet",
    },
    "xception": {
        "class": "Xception",
        "module": "xception",
        "input_size": 299,
        "preprocess": "xception",
    },
    "mobilenetv2": {
        "class": "MobileNetV2",
        "module": "mobilenet_v2",
        "input_size": 224,
        "preprocess": "mobilenet_v2",
    },
    "resnet50": {
        "class": "ResNet50",
        "module": "resnet50",
        "input_size": 224,
        "preprocess": "resnet50",
    },
}


def get_backbone_model(name, input_size):
    """Instantiate a Keras backbone with ImageNet weights."""
    cfg = BACKBONE_REGISTRY[name]
    cls = getattr(tf.keras.applications, cfg["class"])
    return cls(
        input_shape=(input_size, input_size, 3),
        include_top=False,
        weights="imagenet",
    )


def get_preprocess_fn(name):
    """Return the backbone's preprocess_input function."""
    cfg = BACKBONE_REGISTRY[name]
    module = getattr(tf.keras.applications, cfg["module"])
    return module.preprocess_input


def parse_args():
    parser = argparse.ArgumentParser(description="Backbone comparison training")
    parser.add_argument("--backbone", required=True,
                        choices=list(BACKBONE_REGISTRY.keys()),
                        help="Backbone architecture to train")
    parser.add_argument("--epochs-head", type=int, default=5,
                        help="Head-only training epochs")
    parser.add_argument("--epochs-finetune", type=int, default=8,
                        help="Fine-tuning epochs")
    parser.add_argument("--batch-size", type=int, default=64)
    parser.add_argument("--results-file", default="comparison_results.json",
                        help="JSON file to append results to")
    return parser.parse_args()


# ── Config ────────────────────────────────────────────────────────────────
OUTPUT_DIR = "assets"
SUPPLEMENTAL_DIR = "supplemental_dogs"
LABEL_SMOOTHING = 0.1  # standard smoothing (no CutMix in comparison)
FINE_TUNE_LAYERS = 30   # same as v3


def main():
    args = parse_args()
    backbone_name = args.backbone
    cfg = BACKBONE_REGISTRY[backbone_name]
    IMG_SIZE = cfg["input_size"]
    BATCH_SIZE = args.batch_size
    EPOCHS = args.epochs_head
    FINE_TUNE_EPOCHS = args.epochs_finetune

    preprocess_input = get_preprocess_fn(backbone_name)

    print("=" * 70)
    print(f"BACKBONE COMPARISON: {backbone_name}")
    print(f"  Input size: {IMG_SIZE}x{IMG_SIZE}")
    print(f"  Head epochs: {EPOCHS}, Fine-tune epochs: {FINE_TUNE_EPOCHS}")
    print(f"  Batch size: {BATCH_SIZE}")
    print("=" * 70)

    # ── Load Stanford Dogs (as_supervised=True, no bbox for fair comparison) ──
    print("\nLoading Stanford Dogs dataset...")
    (ds_train_stanford, ds_test_stanford), info = tfds.load(
        "stanford_dogs",
        split=["train", "test"],
        as_supervised=True,
        with_info=True,
    )

    stanford_num_classes = info.features["label"].num_classes
    stanford_class_names = info.features["label"].names
    stanford_train_count = info.splits["train"].num_examples
    stanford_test_count = info.splits["test"].num_examples
    print(f"  Stanford Dogs: {stanford_num_classes} breeds, "
          f"{stanford_train_count} train, {stanford_test_count} test")

    # ── Clean names ──
    def clean_stanford_name(raw_name):
        if "-" in raw_name:
            raw_name = raw_name.split("-", 1)[1]
        return raw_name.replace("_", " ")

    stanford_clean_names = [clean_stanford_name(n) for n in stanford_class_names]

    # ── Supplemental breeds ──
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

    stanford_clean_lower = {n.lower() for n in stanford_clean_names}

    def clean_supplemental_name(folder_name):
        return folder_name.replace("_", " ").title()

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
    print(f"  Total classes: {NUM_CLASSES}")

    # ── Supplemental dataset builder ──
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

    # ── Preprocessing (standard augmentation, no CutMix/bbox crop) ──
    def preprocess(image, label):
        image = tf.image.resize(image, [IMG_SIZE, IMG_SIZE])
        image = tf.cast(image, tf.float32)
        image = preprocess_input(image)
        return image, label

    def augment(image, label):
        image = tf.image.resize(image, [IMG_SIZE + 40, IMG_SIZE + 40])
        image = tf.image.random_crop(image, [IMG_SIZE, IMG_SIZE, 3])
        image = tf.image.random_flip_left_right(image)
        image = tf.image.random_brightness(image, 0.25)
        image = tf.image.random_contrast(image, 0.7, 1.3)
        image = tf.clip_by_value(image, 0.0, 255.0)
        image = tf.cast(image, tf.float32)
        image = preprocess_input(image)
        return image, label

    def preprocess_supplemental(image, label):
        image = tf.cast(image, tf.float32)
        image = preprocess_input(image)
        return image, label

    def augment_supplemental(image, label):
        image = tf.image.resize(image, [IMG_SIZE + 60, IMG_SIZE + 60])
        image = tf.image.random_crop(image, [IMG_SIZE, IMG_SIZE, 3])
        image = tf.image.random_flip_left_right(image)
        image = tf.image.random_brightness(image, 0.3)
        image = tf.image.random_contrast(image, 0.6, 1.4)
        image = tf.clip_by_value(image, 0.0, 255.0)
        image = tf.cast(image, tf.float32)
        image = preprocess_input(image)
        return image, label

    # ── Combine datasets ──
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
        .prefetch(tf.data.AUTOTUNE)
    )

    # Test dataset
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
        .cache()
        .with_options(data_options)
        .batch(BATCH_SIZE)
        .prefetch(tf.data.AUTOTUNE)
    )

    print(f"  Training: {total_train_count}, Test: {total_test_count}")
    print(f"  Steps/epoch: {steps_per_epoch}")

    # ── Class weights ──
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

    # ── Build model: standard v3-style head ──
    print(f"\nBuilding {backbone_name} model ({NUM_CLASSES} classes, v3-style head)...")

    base_model = get_backbone_model(backbone_name, IMG_SIZE)
    base_model.trainable = False

    model = tf.keras.Sequential([
        base_model,
        tf.keras.layers.GlobalAveragePooling2D(),
        tf.keras.layers.Dropout(0.4),
        tf.keras.layers.Dense(256, activation="relu"),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(NUM_CLASSES, activation="softmax"),
    ])

    def sparse_crossentropy_with_smoothing(y_true, y_pred):
        y_true_oh = tf.one_hot(tf.cast(y_true, tf.int32), NUM_CLASSES)
        return tf.keras.losses.categorical_crossentropy(
            y_true_oh, y_pred, label_smoothing=LABEL_SMOOTHING
        )

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=3e-3),
        loss=sparse_crossentropy_with_smoothing,
        metrics=["accuracy"],
    )
    model.summary()

    # ── Callbacks ──
    early_stop = tf.keras.callbacks.EarlyStopping(
        monitor="val_accuracy", patience=2, restore_best_weights=True, verbose=1,
    )
    reduce_lr = tf.keras.callbacks.ReduceLROnPlateau(
        monitor="val_accuracy", factor=0.5, patience=1, min_lr=1e-6, verbose=1,
    )

    # ── Phase 1: Train head ──
    print(f"\nPhase 1: Training head ({EPOCHS} epochs)...")
    start_time = time.time()

    model.fit(
        train_ds,
        validation_data=test_ds,
        epochs=EPOCHS,
        steps_per_epoch=steps_per_epoch,
        class_weight=class_weights,
        callbacks=[early_stop, reduce_lr],
    )

    # ── Phase 2: Fine-tune ──
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
        loss=sparse_crossentropy_with_smoothing,
        metrics=["accuracy"],
    )

    early_stop_ft = tf.keras.callbacks.EarlyStopping(
        monitor="val_accuracy", patience=2, restore_best_weights=True, verbose=1,
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

    train_time = time.time() - start_time

    # ── Evaluate Keras model ──
    loss, keras_acc = model.evaluate(test_ds)
    print(f"\nKeras test accuracy: {keras_acc:.4f}")

    # ── Convert to TFLite ──
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
    model_filename = f"dog_model_{backbone_name}.tflite"
    model_path = os.path.join(OUTPUT_DIR, model_filename)
    with open(model_path, "wb") as f:
        f.write(tflite_model)

    model_size_mb = len(tflite_model) / (1024 * 1024)
    print(f"Model saved: {model_path} ({model_size_mb:.1f} MB)")

    # ── Write labels (same for all backbones) ──
    labels_path = os.path.join(OUTPUT_DIR, "dog_labels.txt")
    with open(labels_path, "w", encoding="utf-8") as f:
        for name in all_clean_names:
            f.write(name + "\n")

    # ── Save results to JSON ──
    result = {
        "backbone": backbone_name,
        "input_size": IMG_SIZE,
        "num_classes": NUM_CLASSES,
        "keras_accuracy": float(keras_acc),
        "model_size_mb": round(model_size_mb, 2),
        "model_path": model_path,
        "train_time_minutes": round(train_time / 60, 1),
        "epochs_head": EPOCHS,
        "epochs_finetune": FINE_TUNE_EPOCHS,
        "batch_size": BATCH_SIZE,
    }

    # Append to results file
    results_path = os.path.join(OUTPUT_DIR, args.results_file)
    existing_results = []
    if os.path.exists(results_path):
        with open(results_path, "r") as f:
            existing_results = json.load(f)

    # Replace existing entry for same backbone, or append
    existing_results = [r for r in existing_results if r.get("backbone") != backbone_name]
    existing_results.append(result)

    with open(results_path, "w") as f:
        json.dump(existing_results, f, indent=2)

    print(f"\nResults appended to: {results_path}")

    # ── Summary ──
    print(f"\n{'=' * 70}")
    print(f"DONE! {backbone_name}")
    print(f"{'=' * 70}")
    print(f"  Model: {model_path} ({model_size_mb:.1f} MB)")
    print(f"  Keras accuracy: {keras_acc:.4f}")
    print(f"  Training time: {train_time/60:.1f} min")
    print(f"  Input size: {IMG_SIZE}x{IMG_SIZE}")
    print(f"  Classes: {NUM_CLASSES}")
    print(f"\n  Next: run benchmark_tflite.py to compare all models on TFLite inference")


if __name__ == "__main__":
    main()
