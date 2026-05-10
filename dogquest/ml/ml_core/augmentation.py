"""Augmentation pipelines — RandAugment, CutMix, Mixup, progressive resizing.

Contains the augmentation functions used across training scripts, extracted
from train_model_v5_1.py. All functions operate on TensorFlow tensors and
are graph-mode safe (no eager-only ops inside tf.cond branches).

Usage:
    from ml_core.augmentation import (
        rand_augment,
        random_erasing,
        make_augment_fn,
        make_preprocess_fn,
        cutmix_batch,
        mixup_batch,
        make_mix_fn,
    )
"""

from __future__ import annotations

import math

import tensorflow as tf


# ══════════════════════════════════════════════════════════════════════════
# Geometric transform helpers (graph-mode safe)
# ══════════════════════════════════════════════════════════════════════════


def _rotate_image(image: tf.Tensor, angle_deg: tf.Tensor) -> tf.Tensor:
    """Rotate image by angle in degrees using affine transform."""
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


def _shear_image(
    image: tf.Tensor, level: tf.Tensor, axis: str = "x"
) -> tf.Tensor:
    """Shear image along the given axis."""
    if axis == "x":
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


def _translate_image(image: tf.Tensor, mag: float) -> tf.Tensor:
    """Translate image by a random amount scaled by magnitude."""
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


# ══════════════════════════════════════════════════════════════════════════
# RandAugment
# ══════════════════════════════════════════════════════════════════════════


def rand_augment(
    image: tf.Tensor,
    num_layers: int = 2,
    magnitude: int = 7,
) -> tf.Tensor:
    """Apply RandAugment: multiple transforms each applied with independent probability.

    Graph-mode safe — uses tf.cond for all conditional operations.

    Args:
        image: Float32 image tensor in [0, 255] range.
        num_layers: Number of transform layers (controls per-transform probability).
        magnitude: Augmentation strength on 0-10 scale.

    Returns:
        Augmented image in [0, 255] range.
    """
    mag = float(magnitude) / 10.0
    prob = float(num_layers) / 8.0

    # Rotation +/-15 degrees
    image = tf.cond(
        tf.random.uniform([]) < prob,
        lambda: _rotate_image(image, tf.random.uniform([], -15.0, 15.0) * mag),
        lambda: image,
    )

    # Shear X
    image = tf.cond(
        tf.random.uniform([]) < prob,
        lambda: _shear_image(
            image, tf.random.uniform([], -0.3, 0.3) * mag, axis="x"
        ),
        lambda: image,
    )

    # Shear Y
    image = tf.cond(
        tf.random.uniform([]) < prob,
        lambda: _shear_image(
            image, tf.random.uniform([], -0.3, 0.3) * mag, axis="y"
        ),
        lambda: image,
    )

    # Translate
    image = tf.cond(
        tf.random.uniform([]) < prob,
        lambda: _translate_image(image, mag),
        lambda: image,
    )

    # Hue jitter
    hue_delta = 0.08 * mag
    image = tf.cond(
        tf.random.uniform([]) < prob,
        lambda: tf.image.adjust_hue(
            image / 255.0, tf.random.uniform([], -hue_delta, hue_delta)
        )
        * 255.0,
        lambda: image,
    )

    # Saturation jitter
    sat_lo = max(0.5, 1.0 - 0.5 * mag)
    sat_hi = 1.0 + 0.5 * mag
    image = tf.cond(
        tf.random.uniform([]) < prob,
        lambda: tf.image.adjust_saturation(
            image / 255.0, tf.random.uniform([], sat_lo, sat_hi)
        )
        * 255.0,
        lambda: image,
    )

    # Solarize
    threshold = 256.0 - 128.0 * mag
    image = tf.cond(
        tf.random.uniform([]) < prob,
        lambda: tf.where(image >= threshold, 255.0 - image, image),
        lambda: image,
    )

    # Autocontrast
    def _autocontrast(img: tf.Tensor) -> tf.Tensor:
        lo = tf.reduce_min(img, axis=[0, 1], keepdims=True)
        hi = tf.reduce_max(img, axis=[0, 1], keepdims=True)
        scale = 255.0 / tf.maximum(hi - lo, 1.0)
        return (img - lo) * scale

    image = tf.cond(
        tf.random.uniform([]) < prob,
        lambda: _autocontrast(image),
        lambda: image,
    )

    # Grayscale (lower probability)
    image = tf.cond(
        tf.random.uniform([]) < prob * 0.5,
        lambda: tf.tile(
            tf.reduce_mean(image, axis=-1, keepdims=True), [1, 1, 3]
        ),
        lambda: image,
    )

    return tf.clip_by_value(image, 0.0, 255.0)


# ══════════════════════════════════════════════════════════════════════════
# Random Erasing
# ══════════════════════════════════════════════════════════════════════════


def random_erasing(
    image: tf.Tensor,
    probability: float = 0.3,
) -> tf.Tensor:
    """Random rectangular erasing for occlusion robustness.

    Replaces a random rectangle with uniform noise. Graph-mode safe.

    Args:
        image: Float32 image tensor in [0, 255] range.
        probability: Probability of applying erasing.

    Returns:
        Image with (possibly) a random region erased.
    """
    should_erase = tf.random.uniform([]) < probability

    def do_erase() -> tf.Tensor:
        img_h = tf.shape(image)[0]
        img_w = tf.shape(image)[1]
        area = tf.cast(img_h * img_w, tf.float32)
        target_area = tf.random.uniform([], 0.02, 0.25) * area
        aspect_ratio = tf.random.uniform([], 0.3, 1.0 / 0.3)
        erase_h = tf.cast(tf.math.sqrt(target_area * aspect_ratio), tf.int32)
        erase_w = tf.cast(tf.math.sqrt(target_area / aspect_ratio), tf.int32)
        erase_h = tf.clip_by_value(erase_h, 1, img_h - 1)
        erase_w = tf.clip_by_value(erase_w, 1, img_w - 1)
        y = tf.random.uniform([], 0, img_h - erase_h, dtype=tf.int32)
        x = tf.random.uniform([], 0, img_w - erase_w, dtype=tf.int32)
        noise = tf.random.uniform([erase_h, erase_w, 3], 0.0, 255.0)
        # Build mask
        top = tf.ones([y, img_w, 3])
        mid_left = tf.ones([erase_h, x, 3])
        mid_right = tf.ones([erase_h, img_w - x - erase_w, 3])
        mid = tf.concat(
            [mid_left, tf.zeros([erase_h, erase_w, 3]), mid_right], axis=1
        )
        bottom = tf.ones([img_h - y - erase_h, img_w, 3])
        mask = tf.concat([top, mid, bottom], axis=0)
        noise_padded = tf.concat(
            [
                tf.zeros([y, img_w, 3]),
                tf.concat(
                    [
                        tf.zeros([erase_h, x, 3]),
                        noise,
                        tf.zeros([erase_h, img_w - x - erase_w, 3]),
                    ],
                    axis=1,
                ),
                tf.zeros([img_h - y - erase_h, img_w, 3]),
            ],
            axis=0,
        )
        return image * mask + noise_padded

    return tf.cond(should_erase, do_erase, lambda: image)


# ══════════════════════════════════════════════════════════════════════════
# Per-image augmentation factories (progressive resizing)
# ══════════════════════════════════════════════════════════════════════════


def make_augment_fn(
    img_size: int,
    *,
    randaug_layers: int = 2,
    randaug_magnitude: int = 7,
    erasing_prob: float = 0.3,
    preprocess_fn=None,
):
    """Create a training augmentation function for a given image size.

    Args:
        img_size: Target image size (square).
        randaug_layers: RandAugment num_layers parameter.
        randaug_magnitude: RandAugment magnitude (0-10).
        erasing_prob: Probability of random erasing.
        preprocess_fn: Backbone-specific preprocessing (default: EfficientNet).

    Returns:
        A function mapping (image, label) -> (augmented_image, label).
    """
    if preprocess_fn is None:
        preprocess_fn = tf.keras.applications.efficientnet.preprocess_input

    pad = max(40, int(img_size * 0.18))

    def augment(
        image: tf.Tensor, label: tf.Tensor
    ) -> tuple[tf.Tensor, tf.Tensor]:
        image = tf.cast(image, tf.float32)
        image = tf.image.resize(image, [img_size + pad, img_size + pad])
        image = tf.image.random_crop(image, [img_size, img_size, 3])
        image = tf.image.random_flip_left_right(image)
        image = rand_augment(image, num_layers=randaug_layers, magnitude=randaug_magnitude)
        image = tf.clip_by_value(image, 0.0, 255.0)
        image = random_erasing(image, probability=erasing_prob)
        image = preprocess_fn(image)
        return image, label

    return augment


def make_augment_supplemental_fn(
    img_size: int,
    *,
    randaug_layers: int = 3,
    randaug_magnitude: int = 7,
    erasing_prob: float = 0.4,
    preprocess_fn=None,
):
    """Create stronger augmentation for supplemental images (fewer samples).

    Args:
        img_size: Target image size (square).
        randaug_layers: RandAugment num_layers (higher for stronger aug).
        randaug_magnitude: RandAugment magnitude.
        erasing_prob: Random erasing probability (higher for supplemental).
        preprocess_fn: Backbone-specific preprocessing.

    Returns:
        A function mapping (image, label) -> (augmented_image, label).
    """
    if preprocess_fn is None:
        preprocess_fn = tf.keras.applications.efficientnet.preprocess_input

    pad = max(60, int(img_size * 0.25))

    def augment_supplemental(
        image: tf.Tensor, label: tf.Tensor
    ) -> tuple[tf.Tensor, tf.Tensor]:
        image = tf.cast(image, tf.float32)
        image = tf.image.resize(image, [img_size + pad, img_size + pad])
        image = tf.image.random_crop(image, [img_size, img_size, 3])
        image = tf.image.random_flip_left_right(image)
        image = rand_augment(image, num_layers=randaug_layers, magnitude=randaug_magnitude)
        image = tf.image.random_brightness(image, 0.3)
        image = tf.image.random_contrast(image, 0.6, 1.4)
        image = tf.clip_by_value(image, 0.0, 255.0)
        image = random_erasing(image, probability=erasing_prob)
        image = preprocess_fn(image)
        return image, label

    return augment_supplemental


def make_simple_augment_fn(
    img_size: int,
    *,
    preprocess_fn=None,
):
    """Create a simple augmentation function (v3-style, no RandAugment).

    Args:
        img_size: Target image size.
        preprocess_fn: Backbone-specific preprocessing.

    Returns:
        A function mapping (image, label) -> (augmented_image, label).
    """
    if preprocess_fn is None:
        preprocess_fn = tf.keras.applications.efficientnet.preprocess_input

    def augment(
        image: tf.Tensor, label: tf.Tensor
    ) -> tuple[tf.Tensor, tf.Tensor]:
        image = tf.image.resize(image, [img_size + 40, img_size + 40])
        image = tf.image.random_crop(image, [img_size, img_size, 3])
        image = tf.image.random_flip_left_right(image)
        image = tf.image.random_brightness(image, 0.25)
        image = tf.image.random_contrast(image, 0.7, 1.3)
        image = tf.clip_by_value(image, 0.0, 255.0)
        image = tf.cast(image, tf.float32)
        image = preprocess_fn(image)
        return image, label

    return augment


# ══════════════════════════════════════════════════════════════════════════
# Preprocessing factories (validation / test)
# ══════════════════════════════════════════════════════════════════════════


def make_preprocess_fn(
    img_size: int,
    *,
    preprocess_fn=None,
):
    """Create a validation/test preprocessing function.

    Args:
        img_size: Target image size (square).
        preprocess_fn: Backbone-specific preprocessing.

    Returns:
        A function mapping (image, label) -> (preprocessed_image, label).
    """
    if preprocess_fn is None:
        preprocess_fn = tf.keras.applications.efficientnet.preprocess_input

    def preprocess(
        image: tf.Tensor, label: tf.Tensor
    ) -> tuple[tf.Tensor, tf.Tensor]:
        image = tf.image.resize(image, [img_size, img_size])
        image = tf.cast(image, tf.float32)
        image = preprocess_fn(image)
        return image, label

    return preprocess


# ══════════════════════════════════════════════════════════════════════════
# Batch-level augmentations: CutMix and Mixup
# ══════════════════════════════════════════════════════════════════════════


def cutmix_batch(
    images: tf.Tensor,
    labels: tf.Tensor,
    alpha: float = 1.0,
) -> tuple[tf.Tensor, tf.Tensor]:
    """CutMix: cut and paste rectangular patches between images in a batch.

    Args:
        images: Batch of images (B, H, W, 3).
        labels: One-hot labels (B, num_classes).
        alpha: Beta distribution parameter controlling patch size.

    Returns:
        (mixed_images, mixed_labels) with soft labels.
    """
    batch_size = tf.shape(images)[0]
    img_h = tf.shape(images)[1]
    img_w = tf.shape(images)[2]

    gamma_a = tf.random.gamma([1], alpha)[0]
    gamma_b = tf.random.gamma([1], alpha)[0]
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
    actual_lam = 1.0 - tf.cast(
        (y2 - y1) * (x2 - x1), tf.float32
    ) / tf.cast(img_h * img_w, tf.float32)
    mixed_labels = labels * actual_lam + shuffled_labels * (1.0 - actual_lam)
    return mixed, mixed_labels


def mixup_batch(
    images: tf.Tensor,
    labels: tf.Tensor,
    alpha: float = 0.4,
) -> tuple[tf.Tensor, tf.Tensor]:
    """Mixup: linear interpolation between pairs of images in a batch.

    Args:
        images: Batch of images (B, H, W, 3).
        labels: One-hot labels (B, num_classes).
        alpha: Beta distribution parameter controlling mix ratio.

    Returns:
        (mixed_images, mixed_labels) with soft labels.
    """
    batch_size = tf.shape(images)[0]

    gamma_a = tf.random.gamma([1], alpha)[0]
    gamma_b = tf.random.gamma([1], alpha)[0]
    lam = gamma_a / (gamma_a + gamma_b + 1e-7)
    lam = tf.maximum(lam, 1.0 - lam)  # ensure lam >= 0.5

    indices = tf.random.shuffle(tf.range(batch_size))
    shuffled_images = tf.gather(images, indices)
    shuffled_labels = tf.gather(labels, indices)

    mixed = images * lam + shuffled_images * (1.0 - lam)
    mixed_labels = labels * lam + shuffled_labels * (1.0 - lam)
    return mixed, mixed_labels


def make_mix_fn(
    num_classes: int,
    *,
    cutmix_prob: float = 0.5,
    cutmix_alpha: float = 1.0,
    mixup_prob: float = 0.3,
    mixup_alpha: float = 0.4,
):
    """Create a batch-level mixing function (CutMix + Mixup, mutually exclusive).

    The function converts sparse integer labels to one-hot, then applies
    CutMix, Mixup, or neither based on configured probabilities.

    Args:
        num_classes: Number of output classes (for one-hot encoding).
        cutmix_prob: Probability of applying CutMix.
        cutmix_alpha: Beta distribution alpha for CutMix.
        mixup_prob: Probability of applying Mixup (if CutMix not chosen).
        mixup_alpha: Beta distribution alpha for Mixup.

    Returns:
        A function mapping (images, labels) -> (mixed_images, one_hot_labels).
    """
    cutmix_threshold = cutmix_prob
    mixup_threshold = cutmix_prob + mixup_prob

    def maybe_mix(
        images: tf.Tensor, labels: tf.Tensor
    ) -> tuple[tf.Tensor, tf.Tensor]:
        labels_oh = tf.one_hot(tf.cast(labels, tf.int32), num_classes)
        rand = tf.random.uniform([])

        result = tf.case(
            [
                (
                    tf.less(rand, cutmix_threshold),
                    lambda: cutmix_batch(images, labels_oh, alpha=cutmix_alpha),
                ),
                (
                    tf.less(rand, mixup_threshold),
                    lambda: mixup_batch(images, labels_oh, alpha=mixup_alpha),
                ),
            ],
            default=lambda: (images, labels_oh),
        )
        return result

    return maybe_mix
