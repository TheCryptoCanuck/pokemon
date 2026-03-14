"""
Train a dog breed classifier using MobileNetV2 + Stanford Dogs Dataset,
then export as TFLite (uint8 quantized) for DogQuest.

Output: assets/dog_model.tflite (uint8 input, uint8 output)
        assets/dog_labels.txt  (one breed name per line, matching model output order)

Usage:
  pip install tensorflow tensorflow-datasets Pillow
  python train_model.py

Takes ~30-60 min on a GPU, 2-4 hours on CPU.
"""
import os
import numpy as np

os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"

import tensorflow as tf

# Prevent TF from grabbing all GPU/CPU memory at once
gpus = tf.config.experimental.list_physical_devices("GPU")
for gpu in gpus:
    tf.config.experimental.set_memory_growth(gpu, True)

import tensorflow_datasets as tfds

# ── Config ────────────────────────────────────────────────────────────────
IMG_SIZE = 224
BATCH_SIZE = 16
EPOCHS = 10              # longer head training for better feature learning
FINE_TUNE_EPOCHS = 15    # aggressive fine-tuning for similar-breed discrimination
OUTPUT_DIR = "assets"

print("Loading Stanford Dogs dataset...")
(ds_train, ds_test), info = tfds.load(
    "stanford_dogs",
    split=["train", "test"],
    as_supervised=True,
    with_info=True,
)

NUM_CLASSES = info.features["label"].num_classes
CLASS_NAMES = info.features["label"].names
print(f"  {NUM_CLASSES} breeds, {info.splits['train'].num_examples} train, {info.splits['test'].num_examples} test")


# ── Preprocessing ─────────────────────────────────────────────────────────
def preprocess(image, label):
    image = tf.image.resize(image, [IMG_SIZE, IMG_SIZE])
    image = tf.cast(image, tf.float32) / 255.0
    return image, label


def augment(image, label):
    image = tf.image.resize(image, [IMG_SIZE + 40, IMG_SIZE + 40])
    image = tf.image.random_crop(image, [IMG_SIZE, IMG_SIZE, 3])
    image = tf.image.random_flip_left_right(image)
    image = tf.image.random_brightness(image, 0.25)
    image = tf.image.random_contrast(image, 0.7, 1.3)
    image = tf.image.random_saturation(image, 0.8, 1.2)
    image = tf.image.random_hue(image, 0.05)
    image = tf.clip_by_value(image, 0.0, 255.0)
    image = tf.cast(image, tf.float32) / 255.0
    return image, label


train_ds = (
    ds_train
    .map(augment, num_parallel_calls=tf.data.AUTOTUNE)
    .shuffle(1000)
    .batch(BATCH_SIZE)
    .prefetch(1)
)

test_ds = (
    ds_test
    .map(preprocess, num_parallel_calls=tf.data.AUTOTUNE)
    .batch(BATCH_SIZE)
    .prefetch(1)
)


# ── Model ─────────────────────────────────────────────────────────────────
print("Building MobileNetV2 model...")
base_model = tf.keras.applications.MobileNetV2(
    input_shape=(IMG_SIZE, IMG_SIZE, 3),
    include_top=False,
    weights="imagenet",
)
base_model.trainable = False

model = tf.keras.Sequential([
    base_model,
    tf.keras.layers.GlobalAveragePooling2D(),
    tf.keras.layers.Dropout(0.4),
    tf.keras.layers.Dense(512, activation="relu"),
    tf.keras.layers.BatchNormalization(),
    tf.keras.layers.Dropout(0.3),
    tf.keras.layers.Dense(256, activation="relu"),
    tf.keras.layers.Dropout(0.2),
    tf.keras.layers.Dense(NUM_CLASSES, activation="softmax"),
])

model.compile(
    optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
    loss="sparse_categorical_crossentropy",
    metrics=["accuracy"],
)

# ── Phase 1: Train head ──────────────────────────────────────────────────
print(f"\nPhase 1: Training head ({EPOCHS} epochs)...")
model.fit(train_ds, validation_data=test_ds, epochs=EPOCHS)

# ── Phase 2: Fine-tune top layers ────────────────────────────────────────
# ── Phase 2: Fine-tune (unfreeze top 50 layers, low LR + cosine decay) ──
print(f"\nPhase 2: Fine-tuning top 50 layers ({FINE_TUNE_EPOCHS} epochs)...")
base_model.trainable = True
for layer in base_model.layers[:-50]:   # unfreeze 50 layers (was 30)
    layer.trainable = False

total_fine_tune_steps = (info.splits["train"].num_examples // BATCH_SIZE) * FINE_TUNE_EPOCHS
model.compile(
    optimizer=tf.keras.optimizers.Adam(
        learning_rate=tf.keras.optimizers.schedules.CosineDecay(
            initial_learning_rate=5e-5,   # lower starting LR
            decay_steps=total_fine_tune_steps,
            alpha=1e-6,
        ),
    ),
    loss="sparse_categorical_crossentropy",
    metrics=["accuracy"],
)

model.fit(
    train_ds,
    validation_data=test_ds,
    epochs=EPOCHS + FINE_TUNE_EPOCHS,
    initial_epoch=EPOCHS,
)

# ── Evaluate ──────────────────────────────────────────────────────────────
loss, acc = model.evaluate(test_ds)
print(f"\nTest accuracy: {acc:.4f}")

# ── Convert to TFLite (uint8 quantized) ──────────────────────────────────
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
# Stanford Dogs labels are like "n02085620-Chihuahua" — extract clean names
labels_path = os.path.join(OUTPUT_DIR, "dog_labels.txt")
clean_names = []
for name in CLASS_NAMES:
    # Remove synset prefix if present (e.g., "n02085620-Chihuahua" -> "Chihuahua")
    if "-" in name:
        name = name.split("-", 1)[1]
    # Replace underscores with spaces
    name = name.replace("_", " ")
    clean_names.append(name)

with open(labels_path, "w", encoding="utf-8") as f:
    for name in clean_names:
        f.write(name + "\n")

print(f"Labels saved: {labels_path} ({len(clean_names)} breeds)")
print(f"\nDone! Files ready in {OUTPUT_DIR}/")
print(f"  dog_model.tflite — {model_size_mb:.1f} MB (uint8 quantized)")
print(f"  dog_labels.txt   — {len(clean_names)} breed labels")
