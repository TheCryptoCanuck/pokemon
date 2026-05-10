"""TFLite conversion, uint8 quantization, and representative dataset generation.

Handles the end-of-training conversion pipeline: building a fixed-input model,
generating a representative dataset for quantization calibration, and converting
to a uint8-quantized TFLite model.

Usage:
    from ml_core.quantization import convert_to_tflite, save_tflite_model

    tflite_bytes = convert_to_tflite(
        model,
        input_size=260,
        representative_ds=test_ds,
    )
    save_tflite_model(tflite_bytes, "assets/dog_model.tflite")
"""

from __future__ import annotations

import os
from typing import Optional

import numpy as np
import tensorflow as tf


def make_representative_dataset(
    dataset: tf.data.Dataset,
    num_batches: int = 100,
):
    """Create a representative dataset generator for TFLite quantization.

    Yields individual images (with batch dim) from the given batched dataset,
    used by TFLite converter for calibration of quantization parameters.

    Args:
        dataset: A batched tf.data.Dataset of (images, labels).
        num_batches: Number of batches to sample from the dataset.

    Returns:
        A generator function that yields [image] for each calibration sample.
    """

    def gen():
        for images, _ in dataset.take(num_batches):
            for image in images:
                yield [tf.expand_dims(image, 0)]

    return gen


def convert_to_tflite(
    model: tf.keras.Model,
    *,
    input_size: Optional[int] = None,
    representative_ds: Optional[tf.data.Dataset] = None,
    num_calibration_batches: int = 100,
    uint8_io: bool = True,
) -> bytes:
    """Convert a Keras model to a uint8-quantized TFLite model.

    If the model has flexible input shape (None, None, 3), a fixed-input
    wrapper is created for TFLite compatibility.

    Args:
        model: Trained Keras model to convert.
        input_size: Fixed input image size. If provided and the model has
            flexible input shape, creates a fixed-input wrapper.
        representative_ds: Batched dataset for quantization calibration.
        num_calibration_batches: Number of batches from representative_ds to use.
        uint8_io: If True, set input/output types to uint8.

    Returns:
        The converted TFLite model as bytes.
    """
    convert_model = model

    # Create fixed-input wrapper if needed
    if input_size is not None:
        input_shape = model.input_shape
        # Check if input shape has None dimensions (flexible)
        if isinstance(input_shape, tuple) and any(
            d is None for d in input_shape[1:3]
        ):
            print(f"Creating fixed-input wrapper: ({input_size}, {input_size}, 3)")
            fixed_input = tf.keras.layers.Input(
                shape=(input_size, input_size, 3)
            )
            fixed_output = model(fixed_input)
            convert_model = tf.keras.Model(
                inputs=fixed_input, outputs=fixed_output
            )

    converter = tf.lite.TFLiteConverter.from_keras_model(convert_model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]

    if representative_ds is not None:
        converter.representative_dataset = make_representative_dataset(
            representative_ds, num_batches=num_calibration_batches
        )

    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]

    if uint8_io:
        converter.inference_input_type = tf.uint8
        converter.inference_output_type = tf.uint8

    print("Converting to TFLite (uint8 quantized)...")
    tflite_model = converter.convert()

    size_mb = len(tflite_model) / (1024 * 1024)
    print(f"TFLite model size: {size_mb:.1f} MB")

    return tflite_model


def save_tflite_model(
    tflite_bytes: bytes,
    path: str,
    *,
    also_save_as: Optional[str] = None,
) -> float:
    """Save TFLite model bytes to disk.

    Args:
        tflite_bytes: The converted TFLite model bytes.
        path: Primary output path.
        also_save_as: Optional secondary path (e.g., default model name).

    Returns:
        Model size in MB.
    """
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)

    with open(path, "wb") as f:
        f.write(tflite_bytes)

    size_mb = len(tflite_bytes) / (1024 * 1024)
    print(f"Model saved: {path} ({size_mb:.1f} MB)")

    if also_save_as:
        os.makedirs(os.path.dirname(also_save_as) or ".", exist_ok=True)
        with open(also_save_as, "wb") as f:
            f.write(tflite_bytes)
        print(f"Also saved as: {also_save_as}")

    return size_mb


# ── TFLite inference (for evaluation) ────────────────────────────────────


def load_tflite_interpreter(
    model_path: str,
) -> tuple[tf.lite.Interpreter, dict, dict, int, float]:
    """Load a TFLite model and return interpreter with metadata.

    Args:
        model_path: Path to .tflite file.

    Returns:
        (interpreter, input_details, output_details, img_size, model_size_mb)
    """
    if not os.path.exists(model_path):
        raise FileNotFoundError(f"Model file not found: {model_path}")

    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()[0]
    output_details = interpreter.get_output_details()[0]

    input_shape = input_details["shape"]  # [1, H, W, 3]
    img_size = int(input_shape[1])
    num_outputs = output_details["shape"][-1]
    model_size_mb = os.path.getsize(model_path) / (1024 * 1024)

    print(f"TFLite model: {model_path} ({model_size_mb:.1f} MB)")
    print(f"  Input:  {input_details['dtype'].__name__} {list(input_shape)}")
    print(f"  Output: {output_details['dtype'].__name__} [{num_outputs}]")

    # Print quantization parameters
    for name, details in [("Input", input_details), ("Output", output_details)]:
        if "quantization_parameters" in details:
            qp = details["quantization_parameters"]
            if "scales" in qp and len(qp["scales"]) > 0:
                print(
                    f"  {name} quant: scale={qp['scales'][0]:.8f}, "
                    f"zero_point={qp['zero_points'][0]}"
                )

    return interpreter, input_details, output_details, img_size, model_size_mb


def run_tflite_inference(
    interpreter: tf.lite.Interpreter,
    input_details: dict,
    output_details: dict,
    image_uint8: np.ndarray,
) -> np.ndarray:
    """Run a single image through a TFLite model.

    Args:
        interpreter: Allocated TFLite interpreter.
        input_details: Input tensor details dict.
        output_details: Output tensor details dict.
        image_uint8: Input image as uint8 array (H, W, 3) or (1, H, W, 3).

    Returns:
        Float32 confidence array normalized to [0, 1].
    """
    if image_uint8.dtype != np.uint8:
        image_uint8 = np.clip(image_uint8, 0, 255).astype(np.uint8)
    if len(image_uint8.shape) == 3:
        image_uint8 = np.expand_dims(image_uint8, axis=0)

    interpreter.set_tensor(input_details["index"], image_uint8)
    interpreter.invoke()
    raw_output = interpreter.get_tensor(output_details["index"])[0]

    # Convert uint8 output to float confidence [0, 1]
    if output_details["dtype"] == np.uint8:
        confidences = raw_output.astype(np.float32) / 255.0
    else:
        confidences = raw_output.astype(np.float32)

    return confidences
