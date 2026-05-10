"""Stanford Dogs dataset loading, supplemental breed merging, and label mapping.

Handles the full data pipeline: loading Stanford Dogs from TFDS, discovering
supplemental breed folders, merging into a unified label list, and building
train/test splits as tf.data.Dataset objects.

Usage:
    from ml_core.datasets import (
        load_stanford_dogs,
        discover_supplemental_breeds,
        build_unified_labels,
        build_supplemental_dataset,
        load_supplemental_test_images,
    )
"""

from __future__ import annotations

import glob
import os
import warnings
from dataclasses import dataclass, field
from typing import Optional

import numpy as np
import tensorflow as tf
import tensorflow_datasets as tfds


# ── Name cleaning ────────────────────────────────────────────────────────


def clean_stanford_name(raw_name: str) -> str:
    """Convert Stanford Dogs class name to display format.

    'n02085620-Chihuahua' -> 'Chihuahua'
    """
    if "-" in raw_name:
        raw_name = raw_name.split("-", 1)[1]
    return raw_name.replace("_", " ")


def clean_supplemental_name(folder_name: str) -> str:
    """Convert supplemental folder name to display format.

    'carolina_dog' -> 'Carolina Dog'
    """
    return folder_name.replace("_", " ").title()


# ── Data classes for structured results ──────────────────────────────────


@dataclass
class StanfordDogsData:
    """Result of loading Stanford Dogs from TFDS."""

    train_ds: tf.data.Dataset
    test_ds: tf.data.Dataset
    num_classes: int
    class_names: list[str]
    clean_names: list[str]
    train_count: int
    test_count: int


@dataclass
class SupplementalBreeds:
    """Result of discovering supplemental breed folders."""

    new_breeds: list[tuple[str, str]]  # (folder_name, clean_name) for new breeds
    overlap_breeds: list[tuple[str, str]]  # (folder_name, clean_name) for overlapping
    images: dict[str, list[str]]  # folder_name -> list of image paths
    excluded: list[str] = field(default_factory=list)  # folder names that were excluded


@dataclass
class UnifiedLabels:
    """Unified label list combining Stanford + supplemental breeds."""

    all_names: list[str]  # full ordered list of breed names
    num_classes: int
    stanford_count: int
    supplemental_offset: int  # index where supplemental breeds start
    label_map: dict[str, int]  # clean_name -> index
    overlap_label_map: dict[str, int]  # clean_name -> Stanford index for overlaps


# ── Stanford Dogs loading ────────────────────────────────────────────────


def load_stanford_dogs(
    *,
    as_supervised: bool = True,
    with_bbox: bool = False,
) -> StanfordDogsData:
    """Load Stanford Dogs dataset from TensorFlow Datasets.

    Args:
        as_supervised: If True, return (image, label) tuples.
            If False, return full example dicts (needed for bounding boxes).
        with_bbox: Convenience flag — sets as_supervised=False.

    Returns:
        StanfordDogsData with train/test datasets and metadata.
    """
    if with_bbox:
        as_supervised = False

    (ds_train, ds_test), info = tfds.load(
        "stanford_dogs",
        split=["train", "test"],
        as_supervised=as_supervised,
        with_info=True,
    )

    class_names = info.features["label"].names
    clean_names = [clean_stanford_name(n) for n in class_names]
    num_classes = info.features["label"].num_classes
    train_count = info.splits["train"].num_examples
    test_count = info.splits["test"].num_examples

    print(f"Stanford Dogs: {num_classes} breeds, "
          f"{train_count} train, {test_count} test")

    return StanfordDogsData(
        train_ds=ds_train,
        test_ds=ds_test,
        num_classes=num_classes,
        class_names=class_names,
        clean_names=clean_names,
        train_count=train_count,
        test_count=test_count,
    )


# ── Supplemental breed discovery ─────────────────────────────────────────


_IMAGE_EXTENSIONS = ("*.jpg", "*.jpeg", "*.png", "*.JPG", "*.JPEG", "*.PNG")


def _collect_images(folder_path: str) -> list[str]:
    """Collect all image paths from a folder, deduplicating case variants."""
    imgs_set: set[str] = set()
    for ext in _IMAGE_EXTENSIONS:
        imgs_set.update(glob.glob(os.path.join(folder_path, ext)))
    return sorted(imgs_set)


def discover_supplemental_breeds(
    supplemental_dir: str = "supplemental_dogs",
    stanford_clean_names: Optional[list[str]] = None,
    exclude_breeds: Optional[set[str]] = None,
) -> SupplementalBreeds:
    """Discover supplemental breed folders and classify as new or overlapping.

    Args:
        supplemental_dir: Path to directory containing breed subfolders.
        stanford_clean_names: Cleaned Stanford breed names for overlap detection.
        exclude_breeds: Lowercase folder names to skip (e.g., {'poodle'}).

    Returns:
        SupplementalBreeds with new/overlap lists and image paths.
    """
    if exclude_breeds is None:
        exclude_breeds = set()

    images: dict[str, list[str]] = {}
    all_breeds: list[tuple[str, str]] = []  # (folder_name, folder_path)

    if not os.path.isdir(supplemental_dir):
        print(f"No supplemental directory found: {supplemental_dir}")
        return SupplementalBreeds(
            new_breeds=[], overlap_breeds=[], images={},
        )

    for entry in sorted(os.listdir(supplemental_dir)):
        folder_path = os.path.join(supplemental_dir, entry)
        if not os.path.isdir(folder_path):
            continue
        imgs = _collect_images(folder_path)
        if len(imgs) == 0:
            print(f"  [SKIP] {supplemental_dir}/{entry}/ -- no images found")
            continue
        all_breeds.append((entry, folder_path))
        images[entry] = imgs

    stanford_lower = set()
    if stanford_clean_names:
        stanford_lower = {n.lower() for n in stanford_clean_names}

    new_breeds: list[tuple[str, str]] = []
    overlap_breeds: list[tuple[str, str]] = []
    excluded: list[str] = []

    for folder_name, _ in all_breeds:
        clean = clean_supplemental_name(folder_name)
        if folder_name.lower() in exclude_breeds:
            excluded.append(folder_name)
            print(f"  EXCLUDED supplemental: {clean}")
            continue
        if clean.lower() in stanford_lower:
            overlap_breeds.append((folder_name, clean))
        else:
            new_breeds.append((folder_name, clean))

    result = SupplementalBreeds(
        new_breeds=new_breeds,
        overlap_breeds=overlap_breeds,
        images=images,
        excluded=excluded,
    )

    print(f"Supplemental: {len(new_breeds)} new, "
          f"{len(overlap_breeds)} overlapping, "
          f"{len(excluded)} excluded")

    return result


# ── Unified label building ───────────────────────────────────────────────


def build_unified_labels(
    stanford_clean_names: list[str],
    new_supplemental: list[tuple[str, str]],
    overlap_supplemental: list[tuple[str, str]],
) -> UnifiedLabels:
    """Build a unified label list: Stanford breeds first, then new supplemental.

    Args:
        stanford_clean_names: Cleaned Stanford breed names (indices 0..N-1).
        new_supplemental: (folder_name, clean_name) for new breeds.
        overlap_supplemental: (folder_name, clean_name) for overlapping breeds.

    Returns:
        UnifiedLabels with full label list and mappings.
    """
    all_names = list(stanford_clean_names)
    supplemental_offset = len(all_names)

    for _, clean in new_supplemental:
        all_names.append(clean)

    num_classes = len(all_names)
    label_map = {name: idx for idx, name in enumerate(all_names)}

    # Build overlap label map: supplemental clean_name -> Stanford index
    overlap_label_map: dict[str, int] = {}
    for _, clean in overlap_supplemental:
        for i, sname in enumerate(stanford_clean_names):
            if sname.lower() == clean.lower():
                overlap_label_map[clean] = i
                break

    print(f"Unified labels: {num_classes} classes "
          f"({len(stanford_clean_names)} Stanford + "
          f"{len(new_supplemental)} supplemental)")

    return UnifiedLabels(
        all_names=all_names,
        num_classes=num_classes,
        stanford_count=len(stanford_clean_names),
        supplemental_offset=supplemental_offset,
        label_map=label_map,
        overlap_label_map=overlap_label_map,
    )


# ── Supplemental dataset building ───────────────────────────────────────


def _load_and_decode_image(
    file_path: tf.Tensor,
    label: tf.Tensor,
) -> tuple[tf.Tensor, tf.Tensor]:
    """Load an image file from disk, decode to float32 tensor."""
    raw = tf.io.read_file(file_path)
    image = tf.io.decode_jpeg(raw, channels=3)
    image = tf.cast(image, tf.float32)
    label = tf.cast(label, tf.int64)
    return image, label


def build_supplemental_dataset(
    breeds_list: list[tuple[str, str]],
    label_map: dict[str, int],
    images: dict[str, list[str]],
    *,
    is_train: bool = True,
    train_fraction: float = 0.8,
    seed: int = 42,
) -> tuple[Optional[tf.data.Dataset], int]:
    """Build a tf.data.Dataset from supplemental image folders.

    Uses a deterministic 80/20 train/test split (seed=42) so that
    train and eval scripts produce identical splits.

    Args:
        breeds_list: List of (folder_name, clean_name) to include.
        label_map: clean_name -> label index mapping.
        images: folder_name -> list of image paths.
        is_train: If True, take the training portion; else the test portion.
        train_fraction: Fraction of images used for training.
        seed: Random seed for reproducible splits.

    Returns:
        (dataset, count) or (None, 0) if no images found.
    """
    all_paths: list[str] = []
    all_labels: list[int] = []

    for folder_name, clean_name in breeds_list:
        imgs = images.get(folder_name, [])
        if not imgs:
            continue
        label_idx = label_map[clean_name]
        np.random.seed(seed)
        indices = np.random.permutation(len(imgs))
        split_point = max(1, int(len(imgs) * train_fraction))

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
    ds = ds.map(_load_and_decode_image, num_parallel_calls=tf.data.AUTOTUNE)
    return ds, len(all_paths)


# ── Bounding box utilities ───────────────────────────────────────────────


def crop_to_bbox(
    image: tf.Tensor,
    bbox: tf.Tensor,
    padding: float = 0.15,
) -> tf.Tensor:
    """Crop image to bounding box with context padding.

    Args:
        image: Input image tensor (H, W, 3).
        bbox: Bounding box as [ymin, xmin, ymax, xmax] in normalized coords.
        padding: Fractional padding added around the box.

    Returns:
        Cropped image tensor.
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
    y1 = tf.maximum(tf.minimum(y1, shape[0] - crop_h), 0)
    x1 = tf.maximum(tf.minimum(x1, shape[1] - crop_w), 0)

    return tf.image.crop_to_bounding_box(image, y1, x1, crop_h, crop_w)


def make_bbox_extract_fn(
    bbox_padding: float = 0.15,
    mixed_rate: float = 0.5,
    use_bbox: bool = True,
):
    """Create a map function that extracts (image, label) with optional bbox crop.

    Args:
        bbox_padding: Padding fraction around bounding box.
        mixed_rate: Probability of using bbox crop vs full image (training).
        use_bbox: Whether bbox cropping is enabled at all.

    Returns:
        A function mapping example dict -> (image, label) with mixed crop.
    """
    def extract_with_mixed_crop(example):
        """50/50 bbox crop vs full image (for training diversity)."""
        image = example["image"]
        label = example["label"]
        bbox = example["objects"]["bbox"]
        has_bbox = tf.shape(bbox)[0] > 0

        if use_bbox:
            use_crop = tf.logical_and(
                has_bbox, tf.random.uniform([], 0, 1) < mixed_rate)
            result = tf.cond(
                use_crop,
                lambda: crop_to_bbox(image, bbox[0], padding=bbox_padding),
                lambda: image)
        else:
            result = image
        return result, label

    return extract_with_mixed_crop


def make_bbox_test_fn(bbox_padding: float = 0.15):
    """Create a map function that always crops to bbox (for test/eval).

    Args:
        bbox_padding: Padding fraction around bounding box.

    Returns:
        A function mapping example dict -> (image, label) with bbox crop.
    """
    def extract_with_bbox(example):
        image = example["image"]
        label = example["label"]
        bbox = example["objects"]["bbox"]
        has_bbox = tf.shape(bbox)[0] > 0
        result = tf.cond(
            has_bbox,
            lambda: crop_to_bbox(image, bbox[0], padding=bbox_padding),
            lambda: image)
        return result, label

    return extract_with_bbox


# ── Class weight computation ─────────────────────────────────────────────


def compute_class_weights(
    num_classes: int,
    stanford_num_classes: int,
    stanford_train_count: int,
    new_supplemental: list[tuple[str, str]],
    overlap_supplemental: list[tuple[str, str]],
    supplemental_images: dict[str, list[str]],
    overlap_label_map: dict[str, int],
    supplemental_offset: int,
    *,
    max_weight: float = 10.0,
    min_weight: float = 0.1,
    train_fraction: float = 0.8,
) -> dict[int, float]:
    """Compute per-class weights to handle class imbalance.

    Uses inverse frequency weighting, clamped to [min_weight, max_weight].

    Args:
        num_classes: Total number of classes.
        stanford_num_classes: Number of Stanford Dogs classes.
        stanford_train_count: Total Stanford training images.
        new_supplemental: (folder_name, clean_name) for new breeds.
        overlap_supplemental: (folder_name, clean_name) for overlapping breeds.
        supplemental_images: folder_name -> list of image paths.
        overlap_label_map: clean_name -> Stanford index for overlaps.
        supplemental_offset: Index where supplemental breeds start.
        max_weight: Maximum class weight (caps rare breeds).
        min_weight: Minimum class weight (floors common breeds).
        train_fraction: Fraction of images used for training.

    Returns:
        Dict mapping class index -> weight.
    """
    class_counts = np.zeros(num_classes, dtype=np.float64)

    # Stanford breeds get approximately equal share
    avg_per_class = stanford_train_count / stanford_num_classes
    for i in range(stanford_num_classes):
        class_counts[i] += avg_per_class

    # Overlap supplemental adds to existing Stanford classes
    for folder_name, clean in overlap_supplemental:
        idx = overlap_label_map.get(clean)
        if idx is not None:
            n = max(1, int(len(supplemental_images.get(folder_name, [])) * train_fraction))
            class_counts[idx] += n

    # New supplemental breeds
    for i, (folder_name, _) in enumerate(new_supplemental):
        idx = supplemental_offset + i
        n = max(1, int(len(supplemental_images.get(folder_name, [])) * train_fraction))
        class_counts[idx] += n

    total_samples = class_counts.sum()
    class_weights: dict[int, float] = {}
    for i in range(num_classes):
        if class_counts[i] > 0:
            weight = total_samples / (num_classes * class_counts[i])
            weight = min(weight, max_weight)
            weight = max(weight, min_weight)
            class_weights[i] = weight
        else:
            class_weights[i] = 1.0

    weights_arr = np.array(list(class_weights.values()))
    print(f"Class weights: range=[{weights_arr.min():.3f}, {weights_arr.max():.3f}], "
          f"median={np.median(weights_arr):.3f}")

    return class_weights


# ── Test data loading for evaluation ─────────────────────────────────────


def load_stanford_test_images(
    num_images: int = 0,
    bbox_padding: float = 0.15,
) -> tuple[list[tf.Tensor], list[int], list[str], int]:
    """Load Stanford Dogs test images with bbox crops for evaluation.

    Args:
        num_images: Maximum images to load (0 = all).
        bbox_padding: Padding around bounding boxes.

    Returns:
        (images, labels, clean_names, total_available)
        images: list of float32 tensors (variable size, not resized).
        labels: list of int labels (Stanford index 0-119).
        clean_names: cleaned breed names.
        total_available: total images in test split.
    """
    print("Loading Stanford Dogs test split...")
    ds_test_raw, info = tfds.load(
        "stanford_dogs",
        split="test",
        as_supervised=False,
        with_info=True,
    )

    class_names = info.features["label"].names
    clean_names = [clean_stanford_name(n) for n in class_names]
    total_available = info.splits["test"].num_examples

    images: list[tf.Tensor] = []
    labels: list[int] = []
    count = 0

    for example in ds_test_raw:
        if 0 < num_images <= count:
            break
        image = example["image"]
        label = example["label"].numpy()
        bbox = example["objects"]["bbox"]
        if tf.shape(bbox)[0] > 0:
            image = crop_to_bbox(image, bbox[0], padding=bbox_padding)
        images.append(tf.cast(image, tf.float32))
        labels.append(int(label))
        count += 1

    print(f"  Loaded {len(images)} / {total_available} Stanford Dogs test images")
    return images, labels, clean_names, total_available


def load_supplemental_test_images(
    label_names: list[str],
    supplemental_dir: str = "supplemental_dogs",
    *,
    seed: int = 42,
    train_fraction: float = 0.8,
) -> tuple[list[tf.Tensor], list[int], dict[str, int]]:
    """Load supplemental breed test images (held-out split matching training).

    Args:
        label_names: Full list of breed names (to find label indices).
        supplemental_dir: Path to supplemental breeds directory.
        seed: Random seed for reproducible train/test split.
        train_fraction: Fraction used for training (test = remainder).

    Returns:
        (images, labels, breed_counts)
        images: list of float32 tensors.
        labels: list of int labels (unified index).
        breed_counts: breed_name -> count of test images.
    """
    if not os.path.isdir(supplemental_dir):
        print(f"  Supplemental directory not found: {supplemental_dir}")
        return [], [], {}

    label_name_lower = {n.lower(): i for i, n in enumerate(label_names)}
    images: list[tf.Tensor] = []
    labels: list[int] = []
    breed_counts: dict[str, int] = {}

    for entry in sorted(os.listdir(supplemental_dir)):
        folder_path = os.path.join(supplemental_dir, entry)
        if not os.path.isdir(folder_path):
            continue

        clean = clean_supplemental_name(entry)
        if clean.lower() not in label_name_lower:
            continue

        label_idx = label_name_lower[clean.lower()]
        imgs = _collect_images(folder_path)
        if not imgs:
            continue

        # Reproduce same split as training
        np.random.seed(seed)
        indices = np.random.permutation(len(imgs))
        split_point = max(1, int(len(imgs) * train_fraction))
        test_indices = indices[split_point:]

        test_count = 0
        for idx in test_indices:
            try:
                raw = tf.io.read_file(imgs[idx])
                image = tf.io.decode_jpeg(raw, channels=3)
                images.append(tf.cast(image, tf.float32))
                labels.append(label_idx)
                test_count += 1
            except Exception as e:
                warnings.warn(f"Failed to load {imgs[idx]}: {e}")

        if test_count > 0:
            breed_counts[clean] = test_count

    print(f"  Loaded {len(images)} supplemental test images "
          f"from {len(breed_counts)} breeds")
    return images, labels, breed_counts


# ── Label file I/O ───────────────────────────────────────────────────────


def save_labels(labels: list[str], path: str) -> None:
    """Write breed labels to a text file (one per line)."""
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        for name in labels:
            f.write(name + "\n")
    print(f"Labels saved: {path} ({len(labels)} breeds)")


def load_labels(path: str) -> list[str]:
    """Load breed labels from a text file (one per line)."""
    if not os.path.exists(path):
        raise FileNotFoundError(f"Labels file not found: {path}")
    with open(path, "r", encoding="utf-8") as f:
        labels = [line.strip() for line in f if line.strip()]
    print(f"Loaded {len(labels)} breed labels from {path}")
    return labels
