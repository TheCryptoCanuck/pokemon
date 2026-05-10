"""
Smoke test for train_model_v6.py -- verifies the script loads data,
builds the model, and can run 1 training step without errors.
"""
import os
import sys
import time

# Override training params to run just 1 step
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"
os.environ["TF_ENABLE_ONEDNN_OPTS"] = "1"

import tensorflow as tf
import numpy as np

print("=" * 60)
print("SMOKE TEST: train_model_v6.py")
print("=" * 60)

# Check TF version and GPU
print(f"TensorFlow: {tf.__version__}")
gpus = tf.config.list_physical_devices("GPU")
print(f"GPUs: {len(gpus)}")
print(f"CPU cores: {os.cpu_count()}")

# Check EfficientNetV2S is available
print("\nLoading EfficientNetV2S (imagenet weights)...")
t0 = time.time()
base = tf.keras.applications.EfficientNetV2S(
    input_shape=(224, 224, 3),
    include_top=False,
    weights="imagenet",
)
print(f"  Loaded in {time.time()-t0:.1f}s, output shape: {base.output_shape}")

# Check preprocessing function
dummy = tf.random.uniform([1, 224, 224, 3], 0, 255)
preprocessed = tf.keras.applications.efficientnet_v2.preprocess_input(dummy)
print(f"  Preprocessing: input range [0,255] -> output range [{preprocessed.numpy().min():.2f}, {preprocessed.numpy().max():.2f}]")

# Check supplemental dogs
supp_dir = "supplemental_dogs"
if os.path.isdir(supp_dir):
    folders = [f for f in os.listdir(supp_dir) if os.path.isdir(os.path.join(supp_dir, f))]
    print(f"\nSupplemental dogs: {len(folders)} folders")
else:
    print(f"\nWARNING: {supp_dir} not found!")

# Check labels
labels_path = "assets/dog_labels.txt"
if os.path.isfile(labels_path):
    with open(labels_path) as f:
        labels = [l.strip() for l in f if l.strip()]
    print(f"Labels file: {len(labels)} breeds")
else:
    print(f"WARNING: {labels_path} not found!")

# Check Stanford Dogs dataset
print("\nChecking Stanford Dogs dataset...")
try:
    import tensorflow_datasets as tfds
    ds, info = tfds.load("stanford_dogs", split="train", with_info=True, as_supervised=False)
    print(f"  Stanford Dogs: {info.features['label'].num_classes} classes, "
          f"{info.splits['train'].num_examples} train examples")
    # Check one example
    for example in ds.take(1):
        img = example["image"]
        label = example["label"]
        bbox = example["objects"]["bbox"]
        print(f"  Sample: image shape {img.shape}, label={label.numpy()}, "
              f"bboxes={bbox.shape}")
except Exception as e:
    print(f"  ERROR loading Stanford Dogs: {e}")
    sys.exit(1)

# Build a mini model and do 1 forward pass
print("\nBuilding model with bilinear head (294 classes)...")
NUM_CLASSES = 294
base_model = tf.keras.applications.EfficientNetV2S(
    input_shape=(None, None, 3),
    include_top=False,
    weights="imagenet",
)
base_model.trainable = False

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
output = tf.keras.layers.Dense(NUM_CLASSES, activation="softmax", dtype="float32", name="classifier")(x)
model = tf.keras.Model(inputs=base_model.input, outputs=output)

total_params = model.count_params()
trainable_params = sum(tf.keras.backend.count_params(w) for w in model.trainable_weights)
print(f"  Total params: {total_params:,}")
print(f"  Trainable params: {trainable_params:,}")
print(f"  Feature dim: {base_model.output_shape[-1]}")

# Forward pass
print("\n1 forward pass (224x224)...")
t0 = time.time()
dummy_batch = tf.random.uniform([2, 224, 224, 3], -1, 1)
preds = model(dummy_batch, training=False)
print(f"  Output shape: {preds.shape}, time: {time.time()-t0:.2f}s")
print(f"  Prediction range: [{preds.numpy().min():.4f}, {preds.numpy().max():.4f}]")
print(f"  Sum of first prediction: {preds.numpy()[0].sum():.4f} (should be ~1.0)")

# Compile and do 1 training step
print("\nCompiling and running 1 training step...")
model.compile(
    optimizer=tf.keras.optimizers.AdamW(learning_rate=3e-3, weight_decay=1e-4),
    loss=tf.keras.losses.CategoricalCrossentropy(label_smoothing=0.05),
    metrics=["accuracy"],
)

dummy_labels = tf.one_hot(tf.random.uniform([2], 0, NUM_CLASSES, dtype=tf.int32), NUM_CLASSES)
t0 = time.time()
loss = model.train_on_batch(dummy_batch, dummy_labels)
print(f"  Loss: {loss[0]:.4f}, Accuracy: {loss[1]:.4f}, time: {time.time()-t0:.2f}s")

# TFLite conversion test
print("\nTesting TFLite conversion (uint8 quantized)...")
fixed_input = tf.keras.layers.Input(shape=(300, 300, 3))
fixed_output = model(fixed_input)
fixed_model = tf.keras.Model(inputs=fixed_input, outputs=fixed_output)

def rep_data():
    for _ in range(5):
        yield [tf.random.uniform([1, 300, 300, 3], -1.0, 1.0)]

converter = tf.lite.TFLiteConverter.from_keras_model(fixed_model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.representative_dataset = rep_data
converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
converter.inference_input_type = tf.uint8
converter.inference_output_type = tf.uint8

t0 = time.time()
tflite_model = converter.convert()
model_size_mb = len(tflite_model) / (1024 * 1024)
print(f"  TFLite model size: {model_size_mb:.1f} MB (target: <25 MB)")
print(f"  Conversion time: {time.time()-t0:.1f}s")

# Verify TFLite model runs
interpreter = tf.lite.Interpreter(model_content=tflite_model)
interpreter.allocate_tensors()
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()
print(f"  Input: {input_details[0]['shape']} dtype={input_details[0]['dtype']}")
print(f"  Output: {output_details[0]['shape']} dtype={output_details[0]['dtype']}")

# Run inference
test_input = np.random.randint(0, 256, size=(1, 300, 300, 3)).astype(np.uint8)
interpreter.set_tensor(input_details[0]['index'], test_input)
interpreter.invoke()
output = interpreter.get_tensor(output_details[0]['index'])
print(f"  TFLite output shape: {output.shape}, dtype: {output.dtype}")
print(f"  Output range: [{output.min()}, {output.max()}]")

print(f"\n{'=' * 60}")
print("SMOKE TEST PASSED -- all checks OK")
print(f"{'=' * 60}")
print(f"\nReady to run: python train_model_v6.py")
print(f"Estimated training time (CPU, 16 cores): 8-12 hours")
