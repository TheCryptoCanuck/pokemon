"""Bird image dataset handling for training and evaluation.

Supports loading bird images from directory structures and provides
efficient data loading with preprocessing and augmentation.
"""

from __future__ import annotations

import json
import logging
from pathlib import Path

import torch
from PIL import Image
from torch.utils.data import DataLoader, Dataset, WeightedRandomSampler

from src.features.preprocessing import build_training_transforms, build_validation_transforms

logger = logging.getLogger(__name__)


class BirdImageDataset(Dataset):
    """Dataset for bird species classification.

    Expects images organized in a directory structure:
        root/
          species_name_1/
            image1.jpg
            image2.jpg
          species_name_2/
            ...

    Or a flat directory with a label mapping file.
    """

    def __init__(
        self,
        root_dir: str | Path,
        transform=None,
        label_map: dict[str, int] | None = None,
    ) -> None:
        self.root_dir = Path(root_dir)
        self.transform = transform
        self.samples: list[tuple[Path, int]] = []
        self.class_names: list[str] = []
        self.class_to_idx: dict[str, int] = {}

        if label_map is not None:
            self.class_to_idx = label_map
            self.class_names = sorted(label_map.keys(), key=lambda k: label_map[k])
            self._load_with_label_map()
        else:
            self._load_from_directory()

        logger.info(
            "Loaded dataset: %d images, %d classes from %s",
            len(self.samples),
            len(self.class_names),
            self.root_dir,
        )

    def _load_from_directory(self) -> None:
        """Load images from subdirectory structure."""
        class_dirs = sorted(
            [d for d in self.root_dir.iterdir() if d.is_dir()],
            key=lambda d: d.name,
        )

        for idx, class_dir in enumerate(class_dirs):
            class_name = class_dir.name
            self.class_names.append(class_name)
            self.class_to_idx[class_name] = idx

            for img_path in class_dir.iterdir():
                if img_path.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}:
                    self.samples.append((img_path, idx))

    def _load_with_label_map(self) -> None:
        """Load images using an external label mapping file."""
        label_file = self.root_dir / "labels.json"
        if label_file.exists():
            with open(label_file) as f:
                labels = json.load(f)

            for filename, class_name in labels.items():
                img_path = self.root_dir / filename
                if img_path.exists() and class_name in self.class_to_idx:
                    self.samples.append((img_path, self.class_to_idx[class_name]))

    def __len__(self) -> int:
        return len(self.samples)

    def __getitem__(self, idx: int) -> tuple[torch.Tensor, int]:
        img_path, label = self.samples[idx]

        image = Image.open(img_path).convert("RGB")

        if self.transform is not None:
            image = self.transform(image)

        return image, label

    def get_class_weights(self) -> torch.Tensor:
        """Compute inverse-frequency class weights for balanced training.

        Returns:
            Tensor of class weights for use with CrossEntropyLoss.
        """
        class_counts = torch.zeros(len(self.class_names))
        for _, label in self.samples:
            class_counts[label] += 1

        # Inverse frequency weighting
        weights = 1.0 / (class_counts + 1e-6)
        weights = weights / weights.sum() * len(self.class_names)
        return weights

    def get_sample_weights(self) -> list[float]:
        """Compute per-sample weights for WeightedRandomSampler.

        Returns:
            List of weights, one per sample.
        """
        class_weights = self.get_class_weights()
        return [float(class_weights[label]) for _, label in self.samples]


def create_data_loaders(
    train_dir: str | Path,
    val_dir: str | Path,
    image_size: int = 380,
    batch_size: int = 32,
    num_workers: int = 4,
    augmentation_config: dict | None = None,
    use_weighted_sampling: bool = True,
) -> tuple[DataLoader, DataLoader]:
    """Create training and validation data loaders.

    Args:
        train_dir: Path to training data directory.
        val_dir: Path to validation data directory.
        image_size: Target image size.
        batch_size: Batch size.
        num_workers: Number of data loading workers.
        augmentation_config: Training augmentation parameters.
        use_weighted_sampling: Whether to use class-balanced sampling.

    Returns:
        Tuple of (train_loader, val_loader).
    """
    train_transform = build_training_transforms(image_size, augmentation_config)
    val_transform = build_validation_transforms(image_size)

    train_dataset = BirdImageDataset(train_dir, transform=train_transform)
    val_dataset = BirdImageDataset(val_dir, transform=val_transform)

    # Ensure consistent class mapping
    val_dataset.class_to_idx = train_dataset.class_to_idx
    val_dataset.class_names = train_dataset.class_names

    sampler = None
    shuffle = True
    if use_weighted_sampling:
        sample_weights = train_dataset.get_sample_weights()
        sampler = WeightedRandomSampler(
            sample_weights, num_samples=len(sample_weights), replacement=True
        )
        shuffle = False  # Mutually exclusive with sampler

    train_loader = DataLoader(
        train_dataset,
        batch_size=batch_size,
        shuffle=shuffle,
        sampler=sampler,
        num_workers=num_workers,
        pin_memory=True,
        drop_last=True,
        persistent_workers=num_workers > 0,
    )

    val_loader = DataLoader(
        val_dataset,
        batch_size=batch_size,
        shuffle=False,
        num_workers=num_workers,
        pin_memory=True,
        persistent_workers=num_workers > 0,
    )

    logger.info(
        "Data loaders created: %d train samples, %d val samples, %d classes",
        len(train_dataset),
        len(val_dataset),
        len(train_dataset.class_names),
    )

    return train_loader, val_loader
