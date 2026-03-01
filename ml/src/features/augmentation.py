"""Advanced data augmentation strategies for bird image classification.

Implements Mixup, CutMix, and other augmentation techniques that improve
model generalization for fine-grained bird species recognition.
"""

from __future__ import annotations

import torch
import torch.nn.functional as F
import numpy as np


def mixup(
    images: torch.Tensor,
    labels: torch.Tensor,
    alpha: float = 0.2,
) -> tuple[torch.Tensor, torch.Tensor, torch.Tensor, float]:
    """Apply Mixup augmentation to a batch.

    Blends pairs of images and creates soft labels for improved
    generalization, especially useful for fine-grained classification.

    Args:
        images: Batch of images (B, C, H, W).
        labels: One-hot or class index labels (B,) or (B, num_classes).
        alpha: Beta distribution parameter controlling mix strength.

    Returns:
        Tuple of (mixed_images, labels_a, labels_b, lambda_value).
    """
    lam = np.random.beta(alpha, alpha) if alpha > 0 else 1.0
    batch_size = images.size(0)
    index = torch.randperm(batch_size, device=images.device)

    mixed_images = lam * images + (1 - lam) * images[index]
    return mixed_images, labels, labels[index], lam


def cutmix(
    images: torch.Tensor,
    labels: torch.Tensor,
    alpha: float = 1.0,
) -> tuple[torch.Tensor, torch.Tensor, torch.Tensor, float]:
    """Apply CutMix augmentation to a batch.

    Replaces a random rectangular region with a patch from another image.
    Particularly effective for bird classification where local features
    (beak, plumage patterns) are discriminative.

    Args:
        images: Batch of images (B, C, H, W).
        labels: Class index labels (B,).
        alpha: Beta distribution parameter.

    Returns:
        Tuple of (mixed_images, labels_a, labels_b, lambda_value).
    """
    lam = np.random.beta(alpha, alpha) if alpha > 0 else 1.0
    batch_size = images.size(0)
    index = torch.randperm(batch_size, device=images.device)

    _, _, h, w = images.shape

    # Sample bounding box
    cut_ratio = np.sqrt(1.0 - lam)
    cut_w = int(w * cut_ratio)
    cut_h = int(h * cut_ratio)

    cx = np.random.randint(w)
    cy = np.random.randint(h)

    x1 = max(0, cx - cut_w // 2)
    y1 = max(0, cy - cut_h // 2)
    x2 = min(w, cx + cut_w // 2)
    y2 = min(h, cy + cut_h // 2)

    mixed_images = images.clone()
    mixed_images[:, :, y1:y2, x1:x2] = images[index, :, y1:y2, x1:x2]

    # Adjust lambda based on actual area ratio
    lam = 1 - ((x2 - x1) * (y2 - y1)) / (w * h)

    return mixed_images, labels, labels[index], lam


def mixup_criterion(
    criterion: torch.nn.Module,
    predictions: torch.Tensor,
    labels_a: torch.Tensor,
    labels_b: torch.Tensor,
    lam: float,
) -> torch.Tensor:
    """Compute loss for Mixup/CutMix augmented batches.

    Args:
        criterion: Loss function (e.g., CrossEntropyLoss).
        predictions: Model output logits.
        labels_a: First set of labels.
        labels_b: Second set of labels.
        lam: Mixing coefficient.

    Returns:
        Blended loss value.
    """
    return lam * criterion(predictions, labels_a) + (1 - lam) * criterion(predictions, labels_b)


class AugmentationScheduler:
    """Schedule augmentation intensity across training epochs.

    Gradually reduces augmentation strength as training progresses,
    allowing the model to fine-tune on cleaner data near convergence.
    """

    def __init__(
        self,
        initial_mixup_alpha: float = 0.2,
        initial_cutmix_alpha: float = 1.0,
        warmup_epochs: int = 5,
        decay_start_epoch: int = 30,
        total_epochs: int = 50,
    ) -> None:
        self.initial_mixup_alpha = initial_mixup_alpha
        self.initial_cutmix_alpha = initial_cutmix_alpha
        self.warmup_epochs = warmup_epochs
        self.decay_start_epoch = decay_start_epoch
        self.total_epochs = total_epochs

    def get_augmentation_params(self, epoch: int) -> dict[str, float]:
        """Get augmentation parameters for the current epoch.

        Args:
            epoch: Current training epoch (0-indexed).

        Returns:
            Dictionary with 'mixup_alpha' and 'cutmix_alpha'.
        """
        if epoch < self.warmup_epochs:
            # Linear warmup
            factor = epoch / self.warmup_epochs
        elif epoch < self.decay_start_epoch:
            factor = 1.0
        else:
            # Linear decay
            remaining = self.total_epochs - self.decay_start_epoch
            factor = max(0.0, 1.0 - (epoch - self.decay_start_epoch) / remaining)

        return {
            "mixup_alpha": self.initial_mixup_alpha * factor,
            "cutmix_alpha": self.initial_cutmix_alpha * factor,
        }
