"""Model training loop with distributed training and mixed precision support.

Production training pipeline for bird classification with early stopping,
learning rate scheduling, checkpointing, and experiment tracking.
"""

from __future__ import annotations

import logging
import time
from dataclasses import dataclass, field
from pathlib import Path

import torch
import torch.nn as nn
from torch.cuda.amp import GradScaler, autocast
from torch.utils.data import DataLoader

from src.features.augmentation import AugmentationScheduler, cutmix, mixup, mixup_criterion
from src.models.bird_classifier import BirdClassifier, ModelConfig

logger = logging.getLogger(__name__)


@dataclass
class TrainingConfig:
    """Training hyperparameters and settings."""

    num_epochs: int = 50
    learning_rate: float = 1e-3
    weight_decay: float = 1e-4
    warmup_epochs: int = 5
    min_lr: float = 1e-6
    batch_size: int = 32
    mixed_precision: bool = True
    label_smoothing: float = 0.1
    gradient_clip_norm: float = 1.0
    early_stopping_patience: int = 10
    early_stopping_min_delta: float = 0.001
    checkpoint_dir: str = "checkpoints"
    save_best_only: bool = True
    mixup_alpha: float = 0.2
    cutmix_alpha: float = 1.0

    @classmethod
    def from_dict(cls, config: dict) -> TrainingConfig:
        training_cfg = config.get("training", config)
        es_cfg = training_cfg.get("early_stopping", {})
        aug_cfg = training_cfg.get("augmentation", {})
        return cls(
            num_epochs=training_cfg.get("num_epochs", cls.num_epochs),
            learning_rate=training_cfg.get("learning_rate", cls.learning_rate),
            weight_decay=training_cfg.get("weight_decay", cls.weight_decay),
            warmup_epochs=training_cfg.get("warmup_epochs", cls.warmup_epochs),
            min_lr=training_cfg.get("min_lr", cls.min_lr),
            batch_size=training_cfg.get("batch_size", cls.batch_size),
            mixed_precision=training_cfg.get("mixed_precision", cls.mixed_precision),
            label_smoothing=training_cfg.get("label_smoothing", cls.label_smoothing),
            early_stopping_patience=es_cfg.get("patience", cls.early_stopping_patience),
            early_stopping_min_delta=es_cfg.get("min_delta", cls.early_stopping_min_delta),
            mixup_alpha=aug_cfg.get("mixup_alpha", cls.mixup_alpha),
            cutmix_alpha=aug_cfg.get("cutmix_alpha", cls.cutmix_alpha),
        )


@dataclass
class TrainingMetrics:
    """Tracks training metrics across epochs."""

    epoch: int = 0
    train_loss: float = 0.0
    train_accuracy: float = 0.0
    val_loss: float = 0.0
    val_accuracy: float = 0.0
    val_top5_accuracy: float = 0.0
    learning_rate: float = 0.0
    epoch_time_seconds: float = 0.0
    best_val_accuracy: float = 0.0
    history: list[dict[str, float]] = field(default_factory=list)


class EarlyStopping:
    """Early stopping to prevent overfitting."""

    def __init__(self, patience: int = 10, min_delta: float = 0.001) -> None:
        self.patience = patience
        self.min_delta = min_delta
        self.counter = 0
        self.best_score: float | None = None

    def should_stop(self, score: float) -> bool:
        if self.best_score is None:
            self.best_score = score
            return False

        if score > self.best_score + self.min_delta:
            self.best_score = score
            self.counter = 0
        else:
            self.counter += 1

        return self.counter >= self.patience


class Trainer:
    """Production model trainer with best practices.

    Features:
    - Mixed precision training (AMP)
    - Cosine annealing with warmup
    - Mixup/CutMix augmentation
    - Early stopping
    - Gradient clipping
    - Checkpointing
    """

    def __init__(
        self,
        model: BirdClassifier,
        config: TrainingConfig,
        device: str | torch.device = "auto",
    ) -> None:
        if device == "auto":
            device = "cuda" if torch.cuda.is_available() else "cpu"
        self.device = torch.device(device)
        self.model = model.to(self.device)
        self.config = config

        # Loss function with label smoothing
        self.criterion = nn.CrossEntropyLoss(label_smoothing=config.label_smoothing)

        # Optimizer
        self.optimizer = torch.optim.AdamW(
            self.model.parameters(),
            lr=config.learning_rate,
            weight_decay=config.weight_decay,
        )

        # Mixed precision
        self.scaler = GradScaler(enabled=config.mixed_precision)

        # Early stopping
        self.early_stopping = EarlyStopping(
            patience=config.early_stopping_patience,
            min_delta=config.early_stopping_min_delta,
        )

        # Augmentation scheduler
        self.aug_scheduler = AugmentationScheduler(
            initial_mixup_alpha=config.mixup_alpha,
            initial_cutmix_alpha=config.cutmix_alpha,
            total_epochs=config.num_epochs,
        )

        # Metrics tracker
        self.metrics = TrainingMetrics()

        # Checkpoint directory
        self.checkpoint_dir = Path(config.checkpoint_dir)
        self.checkpoint_dir.mkdir(parents=True, exist_ok=True)

    def _build_scheduler(self, train_loader: DataLoader) -> torch.optim.lr_scheduler.LRScheduler:
        """Build learning rate scheduler with warmup."""
        total_steps = self.config.num_epochs * len(train_loader)
        warmup_steps = self.config.warmup_epochs * len(train_loader)

        def lr_lambda(step: int) -> float:
            if step < warmup_steps:
                return step / max(1, warmup_steps)
            progress = (step - warmup_steps) / max(1, total_steps - warmup_steps)
            # Cosine annealing
            import math
            return max(
                self.config.min_lr / self.config.learning_rate,
                0.5 * (1 + math.cos(math.pi * progress)),
            )

        return torch.optim.lr_scheduler.LambdaLR(self.optimizer, lr_lambda)

    def train_epoch(
        self,
        train_loader: DataLoader,
        scheduler: torch.optim.lr_scheduler.LRScheduler,
        epoch: int,
    ) -> tuple[float, float]:
        """Train for one epoch.

        Returns:
            Tuple of (average_loss, accuracy).
        """
        self.model.train()
        total_loss = 0.0
        correct = 0
        total = 0

        aug_params = self.aug_scheduler.get_augmentation_params(epoch)

        for batch_idx, (images, labels) in enumerate(train_loader):
            images = images.to(self.device, non_blocking=True)
            labels = labels.to(self.device, non_blocking=True)

            # Apply Mixup or CutMix
            use_mixup = aug_params["mixup_alpha"] > 0 and torch.rand(1).item() < 0.5
            use_cutmix = aug_params["cutmix_alpha"] > 0 and not use_mixup

            if use_mixup:
                images, labels_a, labels_b, lam = mixup(
                    images, labels, aug_params["mixup_alpha"]
                )
            elif use_cutmix:
                images, labels_a, labels_b, lam = cutmix(
                    images, labels, aug_params["cutmix_alpha"]
                )

            self.optimizer.zero_grad(set_to_none=True)

            with autocast(enabled=self.config.mixed_precision):
                outputs = self.model(images)
                if use_mixup or use_cutmix:
                    loss = mixup_criterion(self.criterion, outputs, labels_a, labels_b, lam)
                else:
                    loss = self.criterion(outputs, labels)

            self.scaler.scale(loss).backward()

            # Gradient clipping
            if self.config.gradient_clip_norm > 0:
                self.scaler.unscale_(self.optimizer)
                torch.nn.utils.clip_grad_norm_(
                    self.model.parameters(), self.config.gradient_clip_norm
                )

            self.scaler.step(self.optimizer)
            self.scaler.update()
            scheduler.step()

            total_loss += loss.item()
            _, predicted = outputs.max(1)
            total += labels.size(0)
            correct += predicted.eq(labels).sum().item()

        return total_loss / len(train_loader), correct / total

    @torch.no_grad()
    def evaluate(self, val_loader: DataLoader) -> tuple[float, float, float]:
        """Evaluate model on validation set.

        Returns:
            Tuple of (loss, top1_accuracy, top5_accuracy).
        """
        self.model.eval()
        total_loss = 0.0
        correct_top1 = 0
        correct_top5 = 0
        total = 0

        for images, labels in val_loader:
            images = images.to(self.device, non_blocking=True)
            labels = labels.to(self.device, non_blocking=True)

            outputs = self.model(images)
            loss = self.criterion(outputs, labels)

            total_loss += loss.item()
            total += labels.size(0)

            # Top-1
            _, predicted = outputs.max(1)
            correct_top1 += predicted.eq(labels).sum().item()

            # Top-5
            _, top5_predicted = outputs.topk(min(5, outputs.size(1)), dim=1)
            correct_top5 += sum(
                labels[i] in top5_predicted[i] for i in range(labels.size(0))
            )

        n_batches = len(val_loader)
        return total_loss / n_batches, correct_top1 / total, correct_top5 / total

    def train(
        self,
        train_loader: DataLoader,
        val_loader: DataLoader,
    ) -> TrainingMetrics:
        """Run the full training loop.

        Args:
            train_loader: Training data loader.
            val_loader: Validation data loader.

        Returns:
            TrainingMetrics with complete training history.
        """
        scheduler = self._build_scheduler(train_loader)
        best_val_accuracy = 0.0

        logger.info(
            "Starting training: %d epochs, %d train batches, %d val batches",
            self.config.num_epochs,
            len(train_loader),
            len(val_loader),
        )

        for epoch in range(self.config.num_epochs):
            epoch_start = time.time()

            # Train
            train_loss, train_acc = self.train_epoch(train_loader, scheduler, epoch)

            # Evaluate
            val_loss, val_top1, val_top5 = self.evaluate(val_loader)

            epoch_time = time.time() - epoch_start
            current_lr = self.optimizer.param_groups[0]["lr"]

            # Update metrics
            epoch_metrics = {
                "epoch": epoch + 1,
                "train_loss": train_loss,
                "train_accuracy": train_acc,
                "val_loss": val_loss,
                "val_accuracy": val_top1,
                "val_top5_accuracy": val_top5,
                "learning_rate": current_lr,
                "epoch_time_seconds": epoch_time,
            }
            self.metrics.history.append(epoch_metrics)

            logger.info(
                "Epoch %d/%d — train_loss: %.4f, train_acc: %.4f, "
                "val_loss: %.4f, val_acc: %.4f, val_top5: %.4f, lr: %.2e (%.1fs)",
                epoch + 1,
                self.config.num_epochs,
                train_loss,
                train_acc,
                val_loss,
                val_top1,
                val_top5,
                current_lr,
                epoch_time,
            )

            # Save best model
            if val_top1 > best_val_accuracy:
                best_val_accuracy = val_top1
                self.metrics.best_val_accuracy = best_val_accuracy
                checkpoint_path = self.checkpoint_dir / "best_model.pt"
                self.model.save(checkpoint_path)
                logger.info("New best model saved (val_acc: %.4f)", val_top1)

            # Early stopping
            if self.early_stopping.should_stop(val_top1):
                logger.info("Early stopping triggered at epoch %d", epoch + 1)
                break

        # Final metrics
        self.metrics.epoch = len(self.metrics.history)
        if self.metrics.history:
            last = self.metrics.history[-1]
            self.metrics.train_loss = last["train_loss"]
            self.metrics.train_accuracy = last["train_accuracy"]
            self.metrics.val_loss = last["val_loss"]
            self.metrics.val_accuracy = last["val_accuracy"]

        return self.metrics

    def save_checkpoint(self, path: str | Path, epoch: int) -> None:
        """Save a full training checkpoint for resumption.

        Args:
            path: Checkpoint file path.
            epoch: Current epoch number.
        """
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)

        torch.save(
            {
                "epoch": epoch,
                "model_state_dict": self.model.state_dict(),
                "optimizer_state_dict": self.optimizer.state_dict(),
                "scaler_state_dict": self.scaler.state_dict(),
                "metrics": self.metrics.history,
                "best_val_accuracy": self.metrics.best_val_accuracy,
            },
            path,
        )
        logger.info("Checkpoint saved: %s (epoch %d)", path, epoch)

    def load_checkpoint(self, path: str | Path) -> int:
        """Load a training checkpoint to resume training.

        Args:
            path: Checkpoint file path.

        Returns:
            The epoch number to resume from.
        """
        checkpoint = torch.load(path, map_location=self.device, weights_only=False)
        self.model.load_state_dict(checkpoint["model_state_dict"])
        self.optimizer.load_state_dict(checkpoint["optimizer_state_dict"])
        self.scaler.load_state_dict(checkpoint["scaler_state_dict"])
        self.metrics.history = checkpoint.get("metrics", [])
        self.metrics.best_val_accuracy = checkpoint.get("best_val_accuracy", 0.0)

        epoch = checkpoint["epoch"]
        logger.info("Checkpoint loaded: %s (resuming from epoch %d)", path, epoch)
        return epoch
