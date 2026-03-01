"""Tests for image preprocessing pipeline."""

import io

import numpy as np
import pytest
import torch
from PIL import Image

from src.features.preprocessing import (
    ImagePreprocessor,
    PreprocessingConfig,
    build_training_transforms,
    build_validation_transforms,
)


def _create_test_image(width: int = 640, height: int = 480, mode: str = "RGB") -> Image.Image:
    """Create a random test image."""
    arr = np.random.randint(0, 255, (height, width, 3), dtype=np.uint8)
    return Image.fromarray(arr, mode)


def _image_to_bytes(image: Image.Image, fmt: str = "JPEG") -> bytes:
    buf = io.BytesIO()
    image.save(buf, format=fmt)
    return buf.getvalue()


class TestImagePreprocessor:
    @pytest.fixture
    def preprocessor(self):
        return ImagePreprocessor(PreprocessingConfig(image_size=224))

    def test_preprocess_pil_image(self, preprocessor):
        img = _create_test_image()
        tensor = preprocessor.preprocess(img)
        assert tensor.shape == (1, 3, 224, 224)
        assert tensor.dtype == torch.float32

    def test_preprocess_bytes(self, preprocessor):
        img = _create_test_image()
        img_bytes = _image_to_bytes(img)
        tensor = preprocessor.preprocess(img_bytes)
        assert tensor.shape == (1, 3, 224, 224)

    def test_preprocess_batch(self, preprocessor):
        images = [_create_test_image() for _ in range(4)]
        batch = preprocessor.preprocess_batch(images)
        assert batch.shape == (4, 3, 224, 224)

    def test_validate_rgba_conversion(self, preprocessor):
        rgba = Image.fromarray(
            np.random.randint(0, 255, (100, 100, 4), dtype=np.uint8), "RGBA"
        )
        result = preprocessor.validate_image(rgba)
        assert result.mode == "RGB"

    def test_validate_grayscale_conversion(self, preprocessor):
        gray = Image.fromarray(
            np.random.randint(0, 255, (100, 100), dtype=np.uint8), "L"
        )
        result = preprocessor.validate_image(gray)
        assert result.mode == "RGB"

    def test_image_too_large(self, preprocessor):
        preprocessor.config.max_image_size_mb = 0.001  # Very small limit
        img = _create_test_image(1000, 1000)
        img_bytes = _image_to_bytes(img)
        with pytest.raises(ValueError, match="exceeds"):
            preprocessor.preprocess(img_bytes)

    def test_extract_image_features(self, preprocessor):
        img = _create_test_image(640, 480)
        features = preprocessor.extract_image_features(img)
        assert "mean_pixel_intensity" in features
        assert "image_brightness" in features
        assert "image_contrast" in features
        assert "aspect_ratio" in features
        assert abs(features["aspect_ratio"] - 640 / 480) < 0.01

    def test_resize_strategy_resize(self):
        preprocessor = ImagePreprocessor(
            PreprocessingConfig(image_size=224, resize_strategy="resize")
        )
        img = _create_test_image(800, 400)
        tensor = preprocessor.preprocess(img)
        assert tensor.shape == (1, 3, 224, 224)


class TestTransforms:
    def test_training_transforms(self):
        transform = build_training_transforms(image_size=224)
        img = _create_test_image()
        tensor = transform(img)
        assert tensor.shape == (3, 224, 224)

    def test_training_transforms_with_augmentation(self):
        aug_config = {
            "horizontal_flip": True,
            "rotation_range": 15,
            "color_jitter": {
                "brightness": 0.2,
                "contrast": 0.2,
                "saturation": 0.2,
                "hue": 0.1,
            },
            "random_erasing": 0.5,
        }
        transform = build_training_transforms(224, aug_config)
        img = _create_test_image()
        tensor = transform(img)
        assert tensor.shape == (3, 224, 224)

    def test_validation_transforms(self):
        transform = build_validation_transforms(image_size=224)
        img = _create_test_image()
        tensor = transform(img)
        assert tensor.shape == (3, 224, 224)

    def test_normalization_applied(self):
        transform = build_validation_transforms(image_size=224)
        # White image
        white = Image.fromarray(np.full((300, 300, 3), 255, dtype=np.uint8))
        tensor = transform(white)
        # After normalization, values should not be in [0, 1]
        assert tensor.max() > 1.0 or tensor.min() < 0.0
