"""Image preprocessing pipeline for bird classification.

Handles image loading, validation, normalization, and transformation
for both training and inference pipelines.
"""

from __future__ import annotations

import io
import logging
from dataclasses import dataclass

import numpy as np
import torch
from PIL import Image
from torchvision import transforms

logger = logging.getLogger(__name__)

# ImageNet normalization defaults (used by pretrained backbones)
IMAGENET_MEAN = (0.485, 0.456, 0.406)
IMAGENET_STD = (0.229, 0.224, 0.225)


@dataclass
class PreprocessingConfig:
    """Configuration for image preprocessing."""

    image_size: int = 380
    normalize_mean: tuple[float, ...] = IMAGENET_MEAN
    normalize_std: tuple[float, ...] = IMAGENET_STD
    resize_strategy: str = "center_crop"  # "center_crop", "resize", "pad"
    max_image_size_mb: float = 10.0
    supported_formats: tuple[str, ...] = ("JPEG", "PNG", "WEBP")


class ImagePreprocessor:
    """Production image preprocessing pipeline.

    Handles image validation, resizing, normalization, and tensor
    conversion for inference.
    """

    def __init__(self, config: PreprocessingConfig | None = None) -> None:
        self.config = config or PreprocessingConfig()
        self._transform = self._build_transform()

    def _build_transform(self) -> transforms.Compose:
        """Build the torchvision transform pipeline."""
        transform_steps = []

        if self.config.resize_strategy == "center_crop":
            # Resize so shorter side matches, then center crop
            transform_steps.extend([
                transforms.Resize(
                    int(self.config.image_size * 1.14),
                    interpolation=transforms.InterpolationMode.BICUBIC,
                ),
                transforms.CenterCrop(self.config.image_size),
            ])
        elif self.config.resize_strategy == "resize":
            transform_steps.append(
                transforms.Resize(
                    (self.config.image_size, self.config.image_size),
                    interpolation=transforms.InterpolationMode.BICUBIC,
                )
            )
        elif self.config.resize_strategy == "pad":
            transform_steps.extend([
                transforms.Resize(
                    self.config.image_size,
                    interpolation=transforms.InterpolationMode.BICUBIC,
                ),
                transforms.CenterCrop(self.config.image_size),
            ])

        transform_steps.extend([
            transforms.ToTensor(),
            transforms.Normalize(
                mean=self.config.normalize_mean,
                std=self.config.normalize_std,
            ),
        ])

        return transforms.Compose(transform_steps)

    def validate_image(self, image: Image.Image | bytes) -> Image.Image:
        """Validate and convert image to PIL Image.

        Args:
            image: PIL Image or raw bytes.

        Returns:
            Validated PIL Image in RGB mode.

        Raises:
            ValueError: If image is invalid or too large.
        """
        if isinstance(image, bytes):
            if len(image) > self.config.max_image_size_mb * 1024 * 1024:
                raise ValueError(
                    f"Image exceeds {self.config.max_image_size_mb}MB limit"
                )
            image = Image.open(io.BytesIO(image))

        if image.format and image.format not in self.config.supported_formats:
            logger.warning("Unsupported format %s, attempting conversion", image.format)

        # Convert to RGB (handles RGBA, grayscale, etc.)
        if image.mode != "RGB":
            image = image.convert("RGB")

        return image

    def preprocess(self, image: Image.Image | bytes) -> torch.Tensor:
        """Preprocess a single image for model inference.

        Args:
            image: PIL Image or raw bytes.

        Returns:
            Preprocessed tensor of shape (1, 3, H, W).
        """
        image = self.validate_image(image)
        tensor = self._transform(image)
        return tensor.unsqueeze(0)  # Add batch dimension

    def preprocess_batch(self, images: list[Image.Image | bytes]) -> torch.Tensor:
        """Preprocess a batch of images.

        Args:
            images: List of PIL Images or raw bytes.

        Returns:
            Batch tensor of shape (B, 3, H, W).
        """
        tensors = [self.preprocess(img).squeeze(0) for img in images]
        return torch.stack(tensors)

    def extract_image_features(self, image: Image.Image | bytes) -> dict[str, float]:
        """Extract statistical features from an image for monitoring.

        Used for data drift detection — computes simple image statistics
        that can be tracked over time.

        Args:
            image: PIL Image or raw bytes.

        Returns:
            Dictionary of image statistics.
        """
        image = self.validate_image(image)
        arr = np.array(image, dtype=np.float32) / 255.0

        return {
            "mean_pixel_intensity": float(arr.mean()),
            "image_brightness": float(arr.mean(axis=(0, 1)).mean()),
            "image_contrast": float(arr.std()),
            "aspect_ratio": float(image.width / image.height),
            "width": float(image.width),
            "height": float(image.height),
        }


def build_training_transforms(
    image_size: int = 380,
    augmentation_config: dict | None = None,
) -> transforms.Compose:
    """Build training data augmentation pipeline.

    Args:
        image_size: Target image size.
        augmentation_config: Augmentation parameters from model config.

    Returns:
        Composed transform pipeline for training.
    """
    aug = augmentation_config or {}

    transform_list = [
        transforms.RandomResizedCrop(
            image_size,
            scale=(0.7, 1.0),
            interpolation=transforms.InterpolationMode.BICUBIC,
        ),
    ]

    if aug.get("horizontal_flip", True):
        transform_list.append(transforms.RandomHorizontalFlip())

    if aug.get("rotation_range", 0) > 0:
        transform_list.append(
            transforms.RandomRotation(aug["rotation_range"])
        )

    color_jitter = aug.get("color_jitter", {})
    if color_jitter:
        transform_list.append(
            transforms.ColorJitter(
                brightness=color_jitter.get("brightness", 0),
                contrast=color_jitter.get("contrast", 0),
                saturation=color_jitter.get("saturation", 0),
                hue=color_jitter.get("hue", 0),
            )
        )

    transform_list.extend([
        transforms.ToTensor(),
        transforms.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD),
    ])

    if aug.get("random_erasing", 0) > 0:
        transform_list.append(
            transforms.RandomErasing(p=aug["random_erasing"])
        )

    return transforms.Compose(transform_list)


def build_validation_transforms(image_size: int = 380) -> transforms.Compose:
    """Build validation/test transform pipeline (no augmentation).

    Args:
        image_size: Target image size.

    Returns:
        Composed transform pipeline for validation.
    """
    return transforms.Compose([
        transforms.Resize(
            int(image_size * 1.14),
            interpolation=transforms.InterpolationMode.BICUBIC,
        ),
        transforms.CenterCrop(image_size),
        transforms.ToTensor(),
        transforms.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD),
    ])
