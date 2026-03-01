"""Model evaluation metrics and reporting for bird classification.

Provides comprehensive evaluation including per-class metrics, confusion
analysis, and confidence calibration assessment.
"""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
import torch
from torch.utils.data import DataLoader

from src.models.bird_classifier import BirdClassifier

logger = logging.getLogger(__name__)


@dataclass
class EvaluationReport:
    """Comprehensive model evaluation results."""

    top1_accuracy: float = 0.0
    top3_accuracy: float = 0.0
    top5_accuracy: float = 0.0
    macro_precision: float = 0.0
    macro_recall: float = 0.0
    macro_f1: float = 0.0
    mean_confidence: float = 0.0
    per_class_accuracy: dict[str, float] = field(default_factory=dict)
    confusion_pairs: list[dict[str, str | float]] = field(default_factory=list)
    total_samples: int = 0
    num_classes: int = 0

    def to_dict(self) -> dict:
        return {
            "top1_accuracy": self.top1_accuracy,
            "top3_accuracy": self.top3_accuracy,
            "top5_accuracy": self.top5_accuracy,
            "macro_precision": self.macro_precision,
            "macro_recall": self.macro_recall,
            "macro_f1": self.macro_f1,
            "mean_confidence": self.mean_confidence,
            "total_samples": self.total_samples,
            "num_classes": self.num_classes,
            "per_class_accuracy": self.per_class_accuracy,
            "top_confusion_pairs": self.confusion_pairs[:20],
        }

    def save(self, path: str | Path) -> None:
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "w") as f:
            json.dump(self.to_dict(), f, indent=2)
        logger.info("Evaluation report saved to %s", path)


class ModelEvaluator:
    """Comprehensive model evaluation for bird classification.

    Computes multi-level accuracy metrics, per-class performance,
    and identifies common confusion patterns.
    """

    def __init__(
        self,
        model: BirdClassifier,
        device: str | torch.device = "cpu",
        class_names: list[str] | None = None,
    ) -> None:
        self.model = model.to(device)
        self.model.eval()
        self.device = torch.device(device)
        self.class_names = class_names or model.class_names or []

    @torch.no_grad()
    def evaluate(self, data_loader: DataLoader) -> EvaluationReport:
        """Run comprehensive evaluation on a dataset.

        Args:
            data_loader: Evaluation data loader.

        Returns:
            EvaluationReport with detailed metrics.
        """
        all_predictions = []
        all_labels = []
        all_confidences = []

        for images, labels in data_loader:
            images = images.to(self.device, non_blocking=True)
            logits = self.model(images)
            probs = torch.softmax(logits, dim=-1)

            all_predictions.append(probs.cpu())
            all_labels.append(labels)
            max_probs, _ = probs.max(dim=-1)
            all_confidences.append(max_probs.cpu())

        predictions = torch.cat(all_predictions, dim=0)
        labels = torch.cat(all_labels, dim=0)
        confidences = torch.cat(all_confidences, dim=0)

        report = EvaluationReport(
            total_samples=len(labels),
            num_classes=predictions.size(1),
            mean_confidence=float(confidences.mean()),
        )

        # Top-K accuracy
        for k in [1, 3, 5]:
            top_k = min(k, predictions.size(1))
            _, top_indices = predictions.topk(top_k, dim=1)
            correct = sum(labels[i] in top_indices[i] for i in range(len(labels)))
            accuracy = correct / len(labels)
            setattr(report, f"top{k}_accuracy", accuracy)

        # Per-class metrics
        num_classes = predictions.size(1)
        pred_classes = predictions.argmax(dim=1)

        tp = torch.zeros(num_classes)
        fp = torch.zeros(num_classes)
        fn = torch.zeros(num_classes)

        for c in range(num_classes):
            tp[c] = ((pred_classes == c) & (labels == c)).sum()
            fp[c] = ((pred_classes == c) & (labels != c)).sum()
            fn[c] = ((pred_classes != c) & (labels == c)).sum()

        precision = tp / (tp + fp + 1e-8)
        recall = tp / (tp + fn + 1e-8)
        f1 = 2 * precision * recall / (precision + recall + 1e-8)

        # Only average over classes that appear in the dataset
        active_classes = (tp + fn) > 0
        report.macro_precision = float(precision[active_classes].mean())
        report.macro_recall = float(recall[active_classes].mean())
        report.macro_f1 = float(f1[active_classes].mean())

        # Per-class accuracy
        if self.class_names:
            for c in range(min(num_classes, len(self.class_names))):
                class_mask = labels == c
                if class_mask.sum() > 0:
                    class_acc = float((pred_classes[class_mask] == c).float().mean())
                    report.per_class_accuracy[self.class_names[c]] = class_acc

        # Confusion analysis — find most confused pairs
        confusion = self._compute_confusion_pairs(pred_classes, labels, num_classes)
        report.confusion_pairs = confusion

        return report

    def _compute_confusion_pairs(
        self,
        predictions: torch.Tensor,
        labels: torch.Tensor,
        num_classes: int,
    ) -> list[dict[str, str | float]]:
        """Find the most commonly confused class pairs.

        Returns top pairs sorted by confusion count.
        """
        confusion_matrix = torch.zeros(num_classes, num_classes, dtype=torch.long)
        for pred, true in zip(predictions, labels):
            confusion_matrix[true, pred] += 1

        # Zero out the diagonal (correct predictions)
        confusion_matrix.fill_diagonal_(0)

        # Find top confused pairs
        pairs = []
        flat_indices = confusion_matrix.flatten().argsort(descending=True)

        for flat_idx in flat_indices[:50]:
            true_class = int(flat_idx // num_classes)
            pred_class = int(flat_idx % num_classes)
            count = int(confusion_matrix[true_class, pred_class])

            if count == 0:
                break

            true_name = (
                self.class_names[true_class]
                if true_class < len(self.class_names)
                else str(true_class)
            )
            pred_name = (
                self.class_names[pred_class]
                if pred_class < len(self.class_names)
                else str(pred_class)
            )

            pairs.append({
                "true_class": true_name,
                "predicted_class": pred_name,
                "count": count,
            })

        return pairs


def compute_calibration_error(
    predictions: torch.Tensor,
    labels: torch.Tensor,
    n_bins: int = 15,
) -> dict[str, float]:
    """Compute Expected Calibration Error (ECE).

    Measures how well predicted probabilities match actual accuracy,
    critical for production systems where confidence scores drive decisions.

    Args:
        predictions: Probability predictions (B, num_classes).
        labels: True labels (B,).
        n_bins: Number of calibration bins.

    Returns:
        Dictionary with ECE and per-bin calibration data.
    """
    confidences, predicted = predictions.max(dim=1)
    accuracies = predicted.eq(labels).float()

    bin_boundaries = torch.linspace(0, 1, n_bins + 1)
    ece = 0.0

    for i in range(n_bins):
        mask = (confidences > bin_boundaries[i]) & (confidences <= bin_boundaries[i + 1])
        if mask.sum() > 0:
            bin_accuracy = accuracies[mask].mean()
            bin_confidence = confidences[mask].mean()
            bin_weight = mask.float().mean()
            ece += bin_weight * abs(bin_accuracy - bin_confidence)

    return {
        "expected_calibration_error": float(ece),
        "n_bins": n_bins,
    }
