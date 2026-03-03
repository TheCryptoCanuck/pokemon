"""Data drift and model drift detection for production monitoring.

Implements statistical tests to detect when incoming data distribution
shifts from the training distribution, signaling potential model
degradation.
"""

from __future__ import annotations

import logging
import time
from collections import deque
from dataclasses import dataclass, field
from enum import Enum

import numpy as np
from scipy import stats

logger = logging.getLogger(__name__)


class DriftStatus(str, Enum):
    """Drift detection status."""

    NO_DRIFT = "no_drift"
    WARNING = "warning"
    DRIFT_DETECTED = "drift_detected"
    INSUFFICIENT_DATA = "insufficient_data"


@dataclass
class DriftResult:
    """Result of a drift detection test."""

    feature_name: str
    test_name: str
    statistic: float
    p_value: float
    threshold: float
    status: DriftStatus
    timestamp: float = field(default_factory=time.time)

    @property
    def is_drift(self) -> bool:
        return self.status == DriftStatus.DRIFT_DETECTED


class DriftDetector:
    """Statistical drift detector for ML feature monitoring.

    Maintains a reference distribution window and compares incoming
    data against it using configurable statistical tests.
    """

    def __init__(
        self,
        reference_window_size: int = 1000,
        detection_window_size: int = 200,
        features: list[str] | None = None,
    ) -> None:
        self.reference_window_size = reference_window_size
        self.detection_window_size = detection_window_size
        self.features = features or []

        # Per-feature reference and detection windows
        self._reference: dict[str, deque] = {}
        self._detection: dict[str, deque] = {}
        self._results_history: list[DriftResult] = []

        for feature in self.features:
            self._reference[feature] = deque(maxlen=reference_window_size)
            self._detection[feature] = deque(maxlen=detection_window_size)

    def add_observation(self, features: dict[str, float]) -> None:
        """Add a new observation to the detection windows.

        Initially fills the reference window. Once the reference is full,
        new observations go to the detection window.

        Args:
            features: Dictionary of feature name to value.
        """
        for name, value in features.items():
            if name not in self._reference:
                self._reference[name] = deque(maxlen=self.reference_window_size)
                self._detection[name] = deque(maxlen=self.detection_window_size)

            if len(self._reference[name]) < self.reference_window_size:
                self._reference[name].append(value)
            else:
                self._detection[name].append(value)

    def check_drift(
        self,
        ks_threshold: float = 0.05,
        psi_threshold: float = 0.2,
    ) -> dict[str, DriftResult]:
        """Run drift detection tests on all monitored features.

        Args:
            ks_threshold: P-value threshold for Kolmogorov-Smirnov test.
            psi_threshold: Threshold for Population Stability Index.

        Returns:
            Dictionary mapping feature names to DriftResult.
        """
        results = {}

        for feature in self._reference:
            ref_data = list(self._reference[feature])
            det_data = list(self._detection[feature])

            if len(ref_data) < 30 or len(det_data) < 30:
                results[feature] = DriftResult(
                    feature_name=feature,
                    test_name="insufficient_data",
                    statistic=0.0,
                    p_value=1.0,
                    threshold=0.0,
                    status=DriftStatus.INSUFFICIENT_DATA,
                )
                continue

            # Kolmogorov-Smirnov test
            ks_stat, ks_p = stats.ks_2samp(ref_data, det_data)

            # Population Stability Index
            psi_value = self._compute_psi(np.array(ref_data), np.array(det_data))

            # Determine status
            if ks_p < ks_threshold and psi_value > psi_threshold:
                status = DriftStatus.DRIFT_DETECTED
            elif ks_p < ks_threshold or psi_value > psi_threshold * 0.5:
                status = DriftStatus.WARNING
            else:
                status = DriftStatus.NO_DRIFT

            result = DriftResult(
                feature_name=feature,
                test_name="ks_test+psi",
                statistic=ks_stat,
                p_value=ks_p,
                threshold=ks_threshold,
                status=status,
            )
            results[feature] = result
            self._results_history.append(result)

            if result.is_drift:
                logger.warning(
                    "DRIFT DETECTED for '%s': KS=%.4f (p=%.4f), PSI=%.4f",
                    feature,
                    ks_stat,
                    ks_p,
                    psi_value,
                )

        return results

    @staticmethod
    def _compute_psi(
        reference: np.ndarray,
        current: np.ndarray,
        n_bins: int = 10,
    ) -> float:
        """Compute Population Stability Index (PSI).

        PSI measures the shift between two distributions:
        - PSI < 0.1: No significant drift
        - 0.1 <= PSI < 0.2: Moderate drift
        - PSI >= 0.2: Significant drift

        Args:
            reference: Reference distribution values.
            current: Current distribution values.
            n_bins: Number of histogram bins.

        Returns:
            PSI value.
        """
        # Create bins from reference distribution
        breakpoints = np.percentile(reference, np.linspace(0, 100, n_bins + 1))
        breakpoints[0] = -np.inf
        breakpoints[-1] = np.inf

        ref_counts = np.histogram(reference, bins=breakpoints)[0]
        cur_counts = np.histogram(current, bins=breakpoints)[0]

        # Normalize to proportions with smoothing
        ref_pct = (ref_counts + 1) / (len(reference) + n_bins)
        cur_pct = (cur_counts + 1) / (len(current) + n_bins)

        psi = np.sum((cur_pct - ref_pct) * np.log(cur_pct / ref_pct))
        return float(psi)

    def get_drift_summary(self) -> dict:
        """Get a summary of drift detection results.

        Returns:
            Dictionary with drift status per feature and overall status.
        """
        results = self.check_drift()

        drift_count = sum(1 for r in results.values() if r.is_drift)
        warning_count = sum(
            1 for r in results.values() if r.status == DriftStatus.WARNING
        )

        return {
            "overall_status": (
                "drift_detected"
                if drift_count > 0
                else "warning"
                if warning_count > 0
                else "healthy"
            ),
            "features_with_drift": drift_count,
            "features_with_warnings": warning_count,
            "total_features_monitored": len(results),
            "per_feature": {
                name: {
                    "status": result.status.value,
                    "statistic": round(result.statistic, 4),
                    "p_value": round(result.p_value, 4),
                }
                for name, result in results.items()
            },
        }

    def reset_reference(self) -> None:
        """Reset reference window using current detection data.

        Call this after model retraining to establish a new baseline.
        """
        for feature in self._reference:
            if self._detection.get(feature):
                self._reference[feature] = deque(
                    self._detection[feature], maxlen=self.reference_window_size
                )
                self._detection[feature].clear()

        logger.info("Reference window reset from detection data")
