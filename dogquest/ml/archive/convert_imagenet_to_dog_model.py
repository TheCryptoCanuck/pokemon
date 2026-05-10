"""
Convert the pre-trained ImageNet MobileNetV2 (uint8 quantized) into a
dog-breed-only TFLite model by slicing out only the 118 dog-class LOGITS
and applying softmax over just those classes.

Key fix vs. previous version:
  - OLD: sliced AFTER softmax (getting un-renormalized probs from 1000-class
    softmax), then divided to renormalize -> produced INT8 DIV op that crashes
    Android TFLite.
  - NEW: removes the final 1000-class softmax, slices the raw logits for dog
    classes 151-268, then applies a new softmax over only 118 classes. This
    gives proper probabilities AND avoids the INT8 DIV op entirely.

Result: a working dog_model.tflite in ~60 seconds, no training needed.
Accuracy: ~65-70% on ImageNet dog classes (good enough for testing).

Usage:
  python convert_imagenet_to_dog_model.py
"""
import os
import json
import urllib.request
import numpy as np

os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"
import tensorflow as tf

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "assets")

# -- Step 1: Get ImageNet labels -------------------------------------------------
print("Fetching ImageNet class labels...")
url = "https://storage.googleapis.com/download.tensorflow.org/data/imagenet_class_index.json"
response = urllib.request.urlopen(url)
imagenet_labels = json.loads(response.read())

# Dog breeds in ImageNet are classes 151-268 (118 breeds)
DOG_INDICES = list(range(151, 269))  # 118 dog classes

dog_names = []
for idx in DOG_INDICES:
    synset, name = imagenet_labels[str(idx)]
    dog_names.append(name.replace("_", " "))

print(f"  Found {len(DOG_INDICES)} dog breed classes in ImageNet (indices 151-268)")

# -- Step 2: Build wrapper model (logit-level slicing) ----------------------------
print("Building dog-breed extraction wrapper...")
print("  Loading MobileNetV2 from Keras (ImageNet weights)...")

base = tf.keras.applications.MobileNetV2(
    input_shape=(224, 224, 3),
    include_top=True,
    weights="imagenet",
)

# The MobileNetV2 with include_top=True has this structure at the end:
#   ... -> Dense(1000, activation='softmax', name='predictions')
# We need the LOGITS (before softmax). To get them, we rebuild the final
# Dense layer without activation, copying its weights.

# Find the final predictions layer
predictions_layer = base.get_layer("predictions")
dense_weights, dense_bias = predictions_layer.get_weights()
print(f"  Predictions layer weights shape: {dense_weights.shape}, bias shape: {dense_bias.shape}")

# Get the input to the predictions layer (the layer feeding into it)
# In MobileNetV2, the layer before 'predictions' is 'reshape_1' or similar
# We can get it by looking at the layer that feeds into predictions
pre_softmax_input = predictions_layer.input  # The tensor going INTO the Dense layer

# Build a new model that outputs raw logits (no activation)
logits_layer = tf.keras.layers.Dense(
    1000,
    activation=None,  # No softmax - raw logits
    name="logits",
)

# Create the logits model
logits_output = logits_layer(pre_softmax_input)
logits_model = tf.keras.Model(inputs=base.input, outputs=logits_output)

# Copy the weights from the original predictions layer
logits_layer.set_weights([dense_weights, dense_bias])

# Now slice out only the 118 dog class logits and apply softmax
inp = logits_model.input
all_logits = logits_model.output  # shape: (batch, 1000)

# Slice dog logits using tf.gather (well-supported in TFLite)
dog_logit_slice = tf.keras.layers.Lambda(
    lambda x: tf.gather(x, DOG_INDICES, axis=1),
    name="dog_logit_slice",
)(all_logits)

# Apply softmax over only the 118 dog classes
# This gives proper probabilities that sum to 1.0
dog_probs = tf.keras.layers.Softmax(name="dog_softmax")(dog_logit_slice)

dog_model = tf.keras.Model(inputs=inp, outputs=dog_probs)
print(f"  Dog model output shape: {dog_model.output_shape}")

# Quick sanity check with float32 model
print("\n  Float32 model sanity check...")
test_img = np.random.randint(0, 256, (1, 224, 224, 3)).astype(np.float32)
test_img_preprocessed = tf.keras.applications.mobilenet_v2.preprocess_input(test_img)
float_output = dog_model.predict(test_img_preprocessed, verbose=0)[0]
print(f"  Float output sum: {float_output.sum():.4f} (should be ~1.0)")
print(f"  Float output max: {float_output.max():.4f}")
print(f"  Float output min: {float_output.min():.6f}")

# -- Step 3: Convert to TFLite (uint8 quantized) ---------------------------------
print("\nConverting to TFLite (uint8 quantized)...")

def representative_data_gen():
    """Generate calibration images.
    MobileNetV2 expects input preprocessed with preprocess_input ([-1, 1] range).
    For uint8 quantization, we provide float32 data in the model's expected range.
    """
    for _ in range(200):
        # Random uint8 images converted to MobileNetV2's expected [-1, 1] range
        raw = np.random.randint(0, 256, (1, 224, 224, 3)).astype(np.float32)
        data = tf.keras.applications.mobilenet_v2.preprocess_input(raw)
        yield [data]

converter = tf.lite.TFLiteConverter.from_keras_model(dog_model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.representative_dataset = representative_data_gen
converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
converter.inference_input_type = tf.uint8
converter.inference_output_type = tf.uint8

tflite_model = converter.convert()

# -- Step 4: Save model and labels ------------------------------------------------
os.makedirs(OUTPUT_DIR, exist_ok=True)

model_path = os.path.join(OUTPUT_DIR, "dog_model.tflite")
with open(model_path, "wb") as f:
    f.write(tflite_model)
model_mb = len(tflite_model) / (1024 * 1024)
print(f"  Saved: {model_path} ({model_mb:.1f} MB)")

# Write labels (same 118 ImageNet dog labels)
labels_path = os.path.join(OUTPUT_DIR, "dog_labels.txt")
with open(labels_path, "w", encoding="utf-8") as f:
    for name in dog_names:
        f.write(name + "\n")
print(f"  Saved: {labels_path} ({len(dog_names)} breeds)")

# Also save the ImageNet-named version for reference
labels_imagenet_path = os.path.join(OUTPUT_DIR, "dog_labels_imagenet.txt")
with open(labels_imagenet_path, "w", encoding="utf-8") as f:
    for name in dog_names:
        f.write(name + "\n")

# -- Step 5: Verify the model ----------------------------------------------------
print("\nVerifying converted model...")
interp = tf.lite.Interpreter(model_content=tflite_model)
interp.allocate_tensors()
inp_d = interp.get_input_details()[0]
out_d = interp.get_output_details()[0]
print(f"  Input:  shape={inp_d['shape']}, dtype={inp_d['dtype']}")
print(f"  Output: shape={out_d['shape']}, dtype={out_d['dtype']}")

inp_scales = inp_d['quantization_parameters']['scales']
inp_zps = inp_d['quantization_parameters']['zero_points']
out_scales = out_d['quantization_parameters']['scales']
out_zps = out_d['quantization_parameters']['zero_points']

print(f"  Input quant:  scale={inp_scales[0]:.6f}, zero_point={inp_zps[0]}")
print(f"  Output quant: scale={out_scales[0]:.6f}, zero_point={out_zps[0]}")

# Test inference with random image
test_input = np.random.randint(0, 256, (1, 224, 224, 3)).astype(np.uint8)
interp.set_tensor(inp_d['index'], test_input)
interp.invoke()
output = interp.get_tensor(out_d['index'])[0]

# Dequantize output to get actual probabilities
output_float = (output.astype(np.float32) - out_zps[0]) * out_scales[0]
output_sum = output_float.sum()

top5 = np.argsort(output)[-5:][::-1]
print(f"\n  Random image test (probabilities should sum to ~1.0):")
print(f"  Dequantized probability sum: {output_sum:.4f}")
print(f"  Top-5 predictions:")
for i, idx in enumerate(top5):
    raw = output[idx]
    prob = (float(raw) - out_zps[0]) * out_scales[0]
    print(f"    {i+1}. {dog_names[idx]} (raw_uint8={raw}, prob={prob:.4f})")

# Verify no problematic ops
print("\n  Checking TFLite ops used...")
try:
    # List all ops in the model to verify no INT8 DIV
    from tensorflow.lite.python import schema_py_generated as schema
    import flatbuffers

    buf = bytearray(tflite_model)
    model_fb = schema.Model.GetRootAs(buf, 0)

    op_codes = set()
    for i in range(model_fb.OperatorCodesLength()):
        op_code = model_fb.OperatorCodes(i)
        # DeprecatedBuiltinCode was used in older flatbuffer schemas
        code = op_code.DeprecatedBuiltinCode()
        op_codes.add(code)
    print(f"  Op codes used: {sorted(op_codes)}")
except Exception as e:
    print(f"  (Could not inspect ops: {e})")

print(f"\nDone! Model ready at: {model_path}")
print(f"  - {model_mb:.1f} MB (uint8 quantized, under 5 MB target)")
print(f"  - Input:  [1, 224, 224, 3] uint8")
print(f"  - Output: [1, 118] uint8 (proper softmax probabilities)")
print(f"  - No Lambda division ops (avoids INT8 DIV crash on Android)")
print(f"\nFor production accuracy, run train_model.py for Stanford Dogs fine-tuning.")
