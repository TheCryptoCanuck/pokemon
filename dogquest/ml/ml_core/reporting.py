"""Metrics computation, confusion matrix analysis, and JSON report export.

Provides the evaluation and reporting utilities shared across training scripts
and evaluate_model.py.

Usage:
    from ml_core.reporting import (
        compute_per_class_metrics,
        find_top_confused_pairs,
        compute_normalized_entropy,
        build_evaluation_report,
        print_evaluation_summary,
        save_report,
    )
"""

from __future__ import annotations

import json
import os
from typing import Any, Optional

import numpy as np


# ══════════════════════════════════════════════════════════════════════════
# Per-class metrics
# ══════════════════════════════════════════════════════════════════════════


def compute_per_class_metrics(
    confusion_matrix: np.ndarray,
    label_names: list[str],
) -> list[dict[str, Any]]:
    """Compute precision, recall, F1, and accuracy per class.

    Args:
        confusion_matrix: (num_classes, num_classes) confusion matrix.
        label_names: List of class names.

    Returns:
        List of dicts, one per class, with keys: index, name, precision,
        recall, f1, accuracy, tp, fp, fn, support.
    """
    num_classes = confusion_matrix.shape[0]
    results: list[dict[str, Any]] = []

    for i in range(num_classes):
        tp = int(confusion_matrix[i, i])
        fn = int(confusion_matrix[i, :].sum() - tp)
        fp = int(confusion_matrix[:, i].sum() - tp)
        support = int(confusion_matrix[i, :].sum())

        precision = tp / (tp + fp) if (tp + fp) > 0 else 0.0
        recall = tp / (tp + fn) if (tp + fn) > 0 else 0.0
        f1 = (
            2 * precision * recall / (precision + recall)
            if (precision + recall) > 0
            else 0.0
        )
        accuracy = tp / support if support > 0 else 0.0

        results.append({
            "index": i,
            "name": label_names[i] if i < len(label_names) else f"class_{i}",
            "precision": float(precision),
            "recall": float(recall),
            "f1": float(f1),
            "accuracy": float(accuracy),
            "tp": tp,
            "fp": fp,
            "fn": fn,
            "support": support,
        })

    return results


# ══════════════════════════════════════════════════════════════════════════
# Confusion matrix analysis
# ══════════════════════════════════════════════════════════════════════════


def build_confusion_matrix(
    true_labels: np.ndarray,
    pred_labels: np.ndarray,
    num_classes: int,
) -> np.ndarray:
    """Build a confusion matrix from true and predicted labels.

    Args:
        true_labels: Array of ground truth class indices.
        pred_labels: Array of predicted class indices.
        num_classes: Total number of classes.

    Returns:
        (num_classes, num_classes) confusion matrix as int64.
    """
    cm = np.zeros((num_classes, num_classes), dtype=np.int64)
    for true_label, pred_label in zip(true_labels, pred_labels):
        if true_label < num_classes and pred_label < num_classes:
            cm[int(true_label), int(pred_label)] += 1
    return cm


def find_top_confused_pairs(
    confusion_matrix: np.ndarray,
    label_names: list[str],
    top_n: int = 10,
) -> list[dict[str, Any]]:
    """Find the N most confused class pairs from off-diagonal elements.

    Args:
        confusion_matrix: (num_classes, num_classes) confusion matrix.
        label_names: List of class names.
        top_n: Number of confused pairs to return.

    Returns:
        List of dicts with keys: actual, predicted, actual_index,
        predicted_index, count.
    """
    cm = confusion_matrix.copy().astype(np.int64)
    np.fill_diagonal(cm, 0)

    pairs: list[dict[str, Any]] = []
    for _ in range(top_n):
        max_val = cm.max()
        if max_val == 0:
            break
        i, j = np.unravel_index(cm.argmax(), cm.shape)
        name_i = label_names[i] if i < len(label_names) else f"class_{i}"
        name_j = label_names[j] if j < len(label_names) else f"class_{j}"
        pairs.append({
            "actual": name_i,
            "predicted": name_j,
            "actual_index": int(i),
            "predicted_index": int(j),
            "count": int(max_val),
        })
        cm[i, j] = 0

    return pairs


def find_low_accuracy_breeds(
    per_class: list[dict[str, Any]],
    threshold: float = 0.80,
) -> list[dict[str, Any]]:
    """Find breeds below an accuracy threshold.

    Args:
        per_class: Per-class metrics from compute_per_class_metrics().
        threshold: Accuracy threshold (breeds below this are flagged).

    Returns:
        Sorted list of per-class metric dicts for low-accuracy breeds.
    """
    low = [
        c for c in per_class
        if c["support"] > 0 and c["accuracy"] < threshold
    ]
    low.sort(key=lambda c: c["accuracy"])
    return low


# ══════════════════════════════════════════════════════════════════════════
# Confidence and entropy
# ══════════════════════════════════════════════════════════════════════════


def compute_normalized_entropy(probs: np.ndarray) -> float:
    """Compute normalized entropy of a probability distribution.

    Returns a value in [0, 1] where 0 = perfectly confident and
    1 = uniform distribution.

    Args:
        probs: Probability array (will be normalized to sum to 1).

    Returns:
        Normalized entropy as a float.
    """
    num_classes = len(probs)
    probs = np.clip(probs, 1e-10, 1.0)
    probs = probs / probs.sum()
    entropy = -np.sum(probs * np.log(probs))
    max_entropy = np.log(num_classes)
    return float(entropy / max_entropy)


# ══════════════════════════════════════════════════════════════════════════
# Aggregate metrics computation
# ══════════════════════════════════════════════════════════════════════════


def compute_aggregate_metrics(
    per_class: list[dict[str, Any]],
) -> dict[str, float]:
    """Compute macro and weighted averages from per-class metrics.

    Args:
        per_class: Per-class metrics from compute_per_class_metrics().

    Returns:
        Dict with macro/weighted precision, recall, F1, and per-class
        accuracy statistics.
    """
    valid = [c for c in per_class if c["support"] > 0]
    if not valid:
        return {
            "macro_precision": 0.0,
            "macro_recall": 0.0,
            "macro_f1": 0.0,
            "weighted_precision": 0.0,
            "weighted_recall": 0.0,
            "weighted_f1": 0.0,
            "mean_per_class_accuracy": 0.0,
            "median_per_class_accuracy": 0.0,
            "std_per_class_accuracy": 0.0,
        }

    accs = [c["accuracy"] for c in valid]
    total_support = sum(c["support"] for c in valid)

    return {
        "macro_precision": float(np.mean([c["precision"] for c in valid])),
        "macro_recall": float(np.mean([c["recall"] for c in valid])),
        "macro_f1": float(np.mean([c["f1"] for c in valid])),
        "weighted_precision": float(
            sum(c["precision"] * c["support"] for c in valid) / total_support
        ),
        "weighted_recall": float(
            sum(c["recall"] * c["support"] for c in valid) / total_support
        ),
        "weighted_f1": float(
            sum(c["f1"] * c["support"] for c in valid) / total_support
        ),
        "mean_per_class_accuracy": float(np.mean(accs)),
        "median_per_class_accuracy": float(np.median(accs)),
        "std_per_class_accuracy": float(np.std(accs)),
    }


# ══════════════════════════════════════════════════════════════════════════
# Report building and export
# ══════════════════════════════════════════════════════════════════════════


def build_evaluation_report(
    *,
    model_path: str,
    model_size_mb: float,
    img_size: int,
    num_classes: int,
    total_images: int,
    overall_accuracy: float,
    top3_accuracy: float = 0.0,
    top5_accuracy: float = 0.0,
    per_class: list[dict[str, Any]],
    confused_pairs: list[dict[str, Any]],
    low_accuracy_breeds: list[dict[str, Any]],
    confidences: Optional[list[float]] = None,
    entropies: Optional[list[float]] = None,
    inference_times_ms: Optional[list[float]] = None,
    evaluation_time_seconds: float = 0.0,
    accuracy_threshold: float = 0.80,
    extra_fields: Optional[dict[str, Any]] = None,
) -> dict[str, Any]:
    """Build a structured evaluation report dict.

    Args:
        model_path: Path to the evaluated model.
        model_size_mb: Model file size in MB.
        img_size: Input image size.
        num_classes: Number of output classes.
        total_images: Total test images evaluated.
        overall_accuracy: Top-1 accuracy.
        top3_accuracy: Top-3 accuracy.
        top5_accuracy: Top-5 accuracy.
        per_class: Per-class metrics list.
        confused_pairs: Top confused pairs list.
        low_accuracy_breeds: Low-accuracy breeds list.
        confidences: Optional list of confidence values.
        entropies: Optional list of entropy values.
        inference_times_ms: Optional list of per-image inference times in ms.
        evaluation_time_seconds: Total evaluation wall time.
        accuracy_threshold: Threshold used for low-accuracy flagging.
        extra_fields: Optional dict of additional fields to include.

    Returns:
        Complete report dict ready for JSON serialization.
    """
    agg = compute_aggregate_metrics(per_class)

    report: dict[str, Any] = {
        "model": {
            "path": model_path,
            "size_mb": model_size_mb,
            "input_size": img_size,
            "num_classes": num_classes,
        },
        "dataset": {
            "total_images": total_images,
        },
        "accuracy": {
            "top1": overall_accuracy,
            "top3": top3_accuracy,
            "top5": top5_accuracy,
            "mean_per_class": agg["mean_per_class_accuracy"],
            "median_per_class": agg["median_per_class_accuracy"],
            "std_per_class": agg["std_per_class_accuracy"],
        },
        "precision_recall_f1": {
            "macro_precision": agg["macro_precision"],
            "macro_recall": agg["macro_recall"],
            "macro_f1": agg["macro_f1"],
            "weighted_precision": agg["weighted_precision"],
            "weighted_recall": agg["weighted_recall"],
            "weighted_f1": agg["weighted_f1"],
        },
    }

    if confidences:
        confs = np.array(confidences)
        report["confidence"] = {
            "mean": float(confs.mean()),
            "min": float(confs.min()),
            "max": float(confs.max()),
            "std": float(confs.std()),
        }

    if entropies:
        ents = np.array(entropies)
        report["entropy"] = {
            "mean": float(ents.mean()),
            "median": float(np.median(ents)),
            "std": float(ents.std()),
        }

    if inference_times_ms:
        times = np.array(inference_times_ms)
        report["inference_speed_ms"] = {
            "mean": float(times.mean()),
            "p95": float(np.percentile(times, 95)),
            "min": float(times.min()),
            "max": float(times.max()),
        }

    report["top_confused_pairs"] = confused_pairs
    report["low_accuracy_breeds"] = [
        {
            "name": c["name"],
            "index": c["index"],
            "accuracy": c["accuracy"],
            "precision": c["precision"],
            "recall": c["recall"],
            "f1": c["f1"],
            "support": c["support"],
        }
        for c in low_accuracy_breeds
    ]
    report["per_class_metrics"] = [
        {
            "name": c["name"],
            "index": c["index"],
            "accuracy": c["accuracy"],
            "precision": c["precision"],
            "recall": c["recall"],
            "f1": c["f1"],
            "support": c["support"],
        }
        for c in per_class
    ]
    report["evaluation_time_seconds"] = evaluation_time_seconds
    report["accuracy_threshold"] = accuracy_threshold

    if extra_fields:
        report.update(extra_fields)

    return report


def build_training_report(
    *,
    version: str,
    backbone: str,
    num_classes: int,
    stanford_breeds: int,
    supplemental_breeds: int,
    total_train: int,
    total_test: int,
    test_accuracy: float,
    mean_per_class_accuracy: float,
    model_size_mb: float,
    training_time_minutes: float,
    low_accuracy_breeds: list[tuple[str, float]],
    extra_fields: Optional[dict[str, Any]] = None,
) -> dict[str, Any]:
    """Build a structured training report dict.

    Args:
        version: Model version string (e.g., "v5.1").
        backbone: Backbone architecture name.
        num_classes: Total number of classes.
        stanford_breeds: Number of Stanford Dogs breeds.
        supplemental_breeds: Number of supplemental breeds.
        total_train: Total training examples.
        total_test: Total test examples.
        test_accuracy: Final test accuracy.
        mean_per_class_accuracy: Mean per-class accuracy.
        model_size_mb: Model file size in MB.
        training_time_minutes: Total training wall time in minutes.
        low_accuracy_breeds: List of (name, accuracy) for low-accuracy breeds.
        extra_fields: Optional dict of additional fields.

    Returns:
        Training report dict ready for JSON serialization.
    """
    report: dict[str, Any] = {
        "version": version,
        "backbone": backbone,
        "num_classes": num_classes,
        "stanford_breeds": stanford_breeds,
        "supplemental_breeds": supplemental_breeds,
        "total_train": total_train,
        "total_test": total_test,
        "test_accuracy": test_accuracy,
        "mean_per_class_accuracy": mean_per_class_accuracy,
        "model_size_mb": model_size_mb,
        "training_time_minutes": training_time_minutes,
        "low_accuracy_breeds": [
            {"name": n, "accuracy": float(a)} for n, a in low_accuracy_breeds
        ],
    }

    if extra_fields:
        report.update(extra_fields)

    return report


def save_report(report: dict[str, Any], path: str) -> None:
    """Save a report dict as formatted JSON.

    Args:
        report: Report dict to serialize.
        path: Output file path.
    """
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)
    print(f"Report saved: {path}")


# ══════════════════════════════════════════════════════════════════════════
# Terminal output
# ══════════════════════════════════════════════════════════════════════════


def print_per_class_table(
    per_class: list[dict[str, Any]],
    *,
    accuracy_threshold: float = 0.80,
) -> None:
    """Print a formatted per-class accuracy table to stdout.

    Args:
        per_class: Per-class metrics from compute_per_class_metrics().
        accuracy_threshold: Breeds below this are marked with ***.
    """
    print(f"  {'Idx':>4s}  {'Breed':<35s} {'Acc':>6s} {'Prec':>6s} "
          f"{'Rec':>6s} {'F1':>6s} {'Support':>8s}")
    print(f"  {'─' * 4}  {'─' * 35} {'─' * 6} {'─' * 6} "
          f"{'─' * 6} {'─' * 6} {'─' * 8}")

    for c in per_class:
        if c["support"] == 0:
            continue
        marker = " *** " if c["accuracy"] < accuracy_threshold else ""
        print(
            f"  [{c['index']:3d}] {c['name']:<35s} "
            f"{c['accuracy'] * 100:5.1f}% "
            f"{c['precision'] * 100:5.1f}% "
            f"{c['recall'] * 100:5.1f}% "
            f"{c['f1'] * 100:5.1f}% "
            f"{c['support']:>7d}{marker}"
        )


def print_confused_pairs(
    pairs: list[dict[str, Any]],
    *,
    title: Optional[str] = None,
) -> None:
    """Print the top confused breed pairs to stdout.

    Args:
        pairs: Confused pairs from find_top_confused_pairs().
        title: Optional section title.
    """
    if title:
        print(f"\n{title}")
    for rank, pair in enumerate(pairs, 1):
        print(
            f"  {rank:2d}. {pair['actual']:<30s} -> "
            f"{pair['predicted']:<30s} ({pair['count']} misclassifications)"
        )


def print_low_accuracy_breeds(
    low_breeds: list[dict[str, Any]],
    confusion_matrix: np.ndarray,
    label_names: list[str],
    *,
    threshold: float = 0.80,
) -> None:
    """Print breeds below accuracy threshold with their top confusions.

    Args:
        low_breeds: Low-accuracy breed dicts.
        confusion_matrix: Full confusion matrix.
        label_names: List of breed names.
        threshold: Accuracy threshold used.
    """
    if not low_breeds:
        print(f"\n  All breeds at or above {threshold * 100:.0f}% accuracy.")
        return

    print(f"\nBREEDS BELOW {threshold * 100:.0f}% ACCURACY "
          f"({len(low_breeds)} breeds)")
    print("=" * 72)

    for c in low_breeds:
        row = confusion_matrix[c["index"]]
        top_confused_idx = np.argsort(row)[::-1]
        confused_with: list[str] = []
        for j in top_confused_idx:
            if j != c["index"] and row[j] > 0:
                confused_with.append(f"{label_names[j]}({row[j]})")
            if len(confused_with) >= 3:
                break
        confused_str = ", ".join(confused_with) if confused_with else "N/A"
        print(
            f"  [{c['index']:3d}] {c['name']:<35s} "
            f"{c['accuracy'] * 100:5.1f}% "
            f"(P={c['precision'] * 100:.0f}% R={c['recall'] * 100:.0f}% "
            f"F1={c['f1'] * 100:.0f}%) "
            f"confused: {confused_str}"
        )


def print_evaluation_summary(
    report: dict[str, Any],
) -> None:
    """Print a formatted evaluation summary to stdout.

    Args:
        report: Report dict from build_evaluation_report().
    """
    sep = "=" * 72
    dash = "─" * 50

    print(f"\n{sep}")
    print("EVALUATION RESULTS")
    print(sep)

    m = report["model"]
    d = report["dataset"]
    a = report["accuracy"]

    print(f"  Model:              {m['path']}")
    print(f"  Model size:         {m['size_mb']:.1f} MB")
    print(f"  Input size:         {m['input_size']}x{m['input_size']}")
    print(f"  Num classes:        {m['num_classes']}")
    print(f"  Test images:        {d['total_images']}")

    print(f"\n  {dash}")
    print("  ACCURACY")
    print(f"  {dash}")
    print(f"  Overall (top-1):    {a['top1'] * 100:.2f}%")
    print(f"  Top-3:              {a['top3'] * 100:.2f}%")
    print(f"  Top-5:              {a['top5'] * 100:.2f}%")
    print(f"  Mean per-class:     {a['mean_per_class'] * 100:.2f}%")
    print(f"  Median per-class:   {a['median_per_class'] * 100:.2f}%")

    prf = report["precision_recall_f1"]
    print(f"\n  {dash}")
    print("  PRECISION / RECALL / F1 (macro-averaged)")
    print(f"  {dash}")
    print(f"  Precision (macro):  {prf['macro_precision'] * 100:.2f}%")
    print(f"  Recall (macro):     {prf['macro_recall'] * 100:.2f}%")
    print(f"  F1 (macro):         {prf['macro_f1'] * 100:.2f}%")

    if "confidence" in report:
        c = report["confidence"]
        print(f"\n  {dash}")
        print("  CONFIDENCE")
        print(f"  {dash}")
        print(f"  Avg confidence:     {c['mean'] * 100:.1f}%")
        print(f"  Min confidence:     {c['min'] * 100:.1f}%")
        print(f"  Max confidence:     {c['max'] * 100:.1f}%")

    if "inference_speed_ms" in report:
        s = report["inference_speed_ms"]
        print(f"\n  {dash}")
        print("  INFERENCE SPEED (per image)")
        print(f"  {dash}")
        print(f"  Mean:               {s['mean']:.1f} ms")
        print(f"  P95:                {s['p95']:.1f} ms")
