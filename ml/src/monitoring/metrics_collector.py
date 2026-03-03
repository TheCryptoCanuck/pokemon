"""Prometheus-compatible metrics collection for ML serving.

Tracks prediction latency, throughput, confidence distributions,
class distribution, and system resource usage.
"""

from __future__ import annotations

import logging
import time
from collections import Counter, deque
from dataclasses import dataclass, field
from threading import Lock

logger = logging.getLogger(__name__)


@dataclass
class LatencyStats:
    """Rolling latency statistics."""

    values: deque = field(default_factory=lambda: deque(maxlen=1000))

    def add(self, value: float) -> None:
        self.values.append(value)

    def percentile(self, p: float) -> float:
        if not self.values:
            return 0.0
        sorted_vals = sorted(self.values)
        idx = int(len(sorted_vals) * p / 100)
        return sorted_vals[min(idx, len(sorted_vals) - 1)]

    def mean(self) -> float:
        return sum(self.values) / len(self.values) if self.values else 0.0

    def count(self) -> int:
        return len(self.values)


class MetricsCollector:
    """Thread-safe metrics collector for ML serving.

    Tracks key production metrics:
    - Prediction latency (p50, p95, p99)
    - Throughput (requests per second)
    - Prediction confidence distribution
    - Class distribution
    - Cache hit/miss rates
    - Error rates
    - Image feature statistics for drift monitoring
    """

    def __init__(self, window_size: int = 1000) -> None:
        self._lock = Lock()
        self._start_time = time.time()

        # Prediction metrics
        self._latency = LatencyStats(deque(maxlen=window_size))
        self._confidences: deque[float] = deque(maxlen=window_size)
        self._class_counts: Counter = Counter()
        self._total_predictions = 0
        self._errors = 0

        # Cache metrics
        self._cache_hits = 0
        self._cache_misses = 0

        # Image feature statistics (for drift detection)
        self._feature_stats: dict[str, deque] = {}

    def record_prediction(
        self,
        latency_ms: float,
        confidence: float,
        predicted_class: str,
    ) -> None:
        """Record a prediction event.

        Args:
            latency_ms: Inference latency in milliseconds.
            confidence: Top-1 prediction confidence.
            predicted_class: Predicted class name.
        """
        with self._lock:
            self._latency.add(latency_ms)
            self._confidences.append(confidence)
            self._class_counts[predicted_class] += 1
            self._total_predictions += 1

    def record_error(self) -> None:
        """Record a prediction error."""
        with self._lock:
            self._errors += 1

    def record_cache_hit(self) -> None:
        """Record a cache hit."""
        with self._lock:
            self._cache_hits += 1

    def record_cache_miss(self) -> None:
        """Record a cache miss."""
        with self._lock:
            self._cache_misses += 1

    def record_image_features(self, features: dict[str, float]) -> None:
        """Record image feature statistics for drift monitoring.

        Args:
            features: Dictionary of feature name to value.
        """
        with self._lock:
            for name, value in features.items():
                if name not in self._feature_stats:
                    self._feature_stats[name] = deque(maxlen=1000)
                self._feature_stats[name].append(value)

    def get_summary(self) -> dict:
        """Get a summary of all collected metrics.

        Returns:
            Dictionary of metric names to values.
        """
        with self._lock:
            uptime = time.time() - self._start_time
            total_cache = self._cache_hits + self._cache_misses

            summary = {
                "uptime_seconds": round(uptime, 1),
                "total_predictions": self._total_predictions,
                "predictions_per_second": round(
                    self._total_predictions / uptime if uptime > 0 else 0, 2
                ),
                "errors": self._errors,
                "error_rate": round(
                    self._errors / max(1, self._total_predictions), 4
                ),
                "latency": {
                    "mean_ms": round(self._latency.mean(), 2),
                    "p50_ms": round(self._latency.percentile(50), 2),
                    "p95_ms": round(self._latency.percentile(95), 2),
                    "p99_ms": round(self._latency.percentile(99), 2),
                },
                "confidence": {
                    "mean": round(
                        sum(self._confidences) / len(self._confidences)
                        if self._confidences
                        else 0,
                        4,
                    ),
                    "low_confidence_rate": round(
                        sum(1 for c in self._confidences if c < 0.3)
                        / max(1, len(self._confidences)),
                        4,
                    ),
                },
                "cache": {
                    "hits": self._cache_hits,
                    "misses": self._cache_misses,
                    "hit_rate": round(
                        self._cache_hits / total_cache if total_cache > 0 else 0, 4
                    ),
                },
                "top_predicted_classes": dict(self._class_counts.most_common(10)),
            }

            # Feature distribution stats
            if self._feature_stats:
                feature_summary = {}
                for name, values in self._feature_stats.items():
                    if values:
                        sorted_vals = sorted(values)
                        n = len(sorted_vals)
                        feature_summary[name] = {
                            "mean": round(sum(values) / n, 4),
                            "min": round(sorted_vals[0], 4),
                            "max": round(sorted_vals[-1], 4),
                            "p50": round(sorted_vals[n // 2], 4),
                        }
                summary["image_features"] = feature_summary

            return summary

    def reset(self) -> None:
        """Reset all metrics."""
        with self._lock:
            self._start_time = time.time()
            self._latency = LatencyStats()
            self._confidences.clear()
            self._class_counts.clear()
            self._total_predictions = 0
            self._errors = 0
            self._cache_hits = 0
            self._cache_misses = 0
            self._feature_stats.clear()
