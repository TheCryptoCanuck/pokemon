"""A/B testing framework for comparing ML model versions.

Supports traffic splitting, experiment tracking, and statistical
analysis for data-driven model deployment decisions.
"""

from __future__ import annotations

import hashlib
import logging
import time
from dataclasses import dataclass, field
from enum import Enum

logger = logging.getLogger(__name__)


class ExperimentStatus(str, Enum):
    """Experiment lifecycle status."""

    DRAFT = "draft"
    RUNNING = "running"
    PAUSED = "paused"
    COMPLETED = "completed"


@dataclass
class Variant:
    """An experiment variant (model version)."""

    name: str
    model_version: str
    traffic_weight: float  # 0.0 to 1.0
    description: str = ""


@dataclass
class ExperimentConfig:
    """A/B test experiment configuration."""

    experiment_id: str
    name: str
    variants: list[Variant]
    status: ExperimentStatus = ExperimentStatus.DRAFT
    created_at: float = field(default_factory=time.time)
    min_samples_per_variant: int = 100
    max_duration_hours: float = 168.0  # 1 week


@dataclass
class VariantMetrics:
    """Accumulated metrics for a single variant."""

    requests: int = 0
    total_confidence: float = 0.0
    correct_predictions: int = 0  # If ground truth is available
    total_latency_ms: float = 0.0
    errors: int = 0

    @property
    def avg_confidence(self) -> float:
        return self.total_confidence / self.requests if self.requests > 0 else 0.0

    @property
    def avg_latency_ms(self) -> float:
        return self.total_latency_ms / self.requests if self.requests > 0 else 0.0

    @property
    def error_rate(self) -> float:
        return self.errors / self.requests if self.requests > 0 else 0.0


class ExperimentManager:
    """Manages A/B test experiments for model comparison.

    Handles deterministic traffic assignment, metric collection,
    and experiment lifecycle management.
    """

    def __init__(self) -> None:
        self._experiments: dict[str, ExperimentConfig] = {}
        self._metrics: dict[str, dict[str, VariantMetrics]] = {}

    def create_experiment(self, config: ExperimentConfig) -> ExperimentConfig:
        """Create a new A/B test experiment.

        Args:
            config: Experiment configuration.

        Returns:
            The created experiment config.

        Raises:
            ValueError: If traffic weights don't sum to 1.0.
        """
        total_weight = sum(v.traffic_weight for v in config.variants)
        if abs(total_weight - 1.0) > 0.01:
            raise ValueError(
                f"Variant traffic weights must sum to 1.0, got {total_weight}"
            )

        self._experiments[config.experiment_id] = config
        self._metrics[config.experiment_id] = {
            v.name: VariantMetrics() for v in config.variants
        }

        logger.info(
            "Created experiment '%s' with %d variants",
            config.experiment_id,
            len(config.variants),
        )
        return config

    def assign_variant(self, experiment_id: str, user_id: str) -> Variant | None:
        """Deterministically assign a user to an experiment variant.

        Uses consistent hashing so the same user always gets the same
        variant, ensuring a clean experiment.

        Args:
            experiment_id: The experiment to assign for.
            user_id: Unique user identifier.

        Returns:
            Assigned Variant, or None if experiment not found/running.
        """
        experiment = self._experiments.get(experiment_id)
        if experiment is None or experiment.status != ExperimentStatus.RUNNING:
            return None

        # Deterministic hash-based assignment
        hash_input = f"{experiment_id}:{user_id}"
        hash_value = int(hashlib.md5(hash_input.encode()).hexdigest(), 16)
        bucket = (hash_value % 1000) / 1000.0

        cumulative_weight = 0.0
        for variant in experiment.variants:
            cumulative_weight += variant.traffic_weight
            if bucket < cumulative_weight:
                return variant

        # Fallback to last variant
        return experiment.variants[-1]

    def record_outcome(
        self,
        experiment_id: str,
        variant_name: str,
        confidence: float,
        latency_ms: float,
        is_correct: bool | None = None,
        is_error: bool = False,
    ) -> None:
        """Record the outcome of a prediction in an experiment.

        Args:
            experiment_id: The experiment ID.
            variant_name: The variant that served the prediction.
            confidence: Prediction confidence score.
            latency_ms: Inference latency.
            is_correct: Whether the prediction was correct (if known).
            is_error: Whether the prediction resulted in an error.
        """
        if experiment_id not in self._metrics:
            return

        metrics = self._metrics[experiment_id].get(variant_name)
        if metrics is None:
            return

        metrics.requests += 1
        metrics.total_confidence += confidence
        metrics.total_latency_ms += latency_ms

        if is_error:
            metrics.errors += 1
        if is_correct is not None and is_correct:
            metrics.correct_predictions += 1

    def start_experiment(self, experiment_id: str) -> None:
        """Start a draft or paused experiment."""
        if experiment_id in self._experiments:
            self._experiments[experiment_id].status = ExperimentStatus.RUNNING
            logger.info("Experiment '%s' started", experiment_id)

    def stop_experiment(self, experiment_id: str) -> None:
        """Stop a running experiment."""
        if experiment_id in self._experiments:
            self._experiments[experiment_id].status = ExperimentStatus.COMPLETED
            logger.info("Experiment '%s' completed", experiment_id)

    def get_results(self, experiment_id: str) -> dict | None:
        """Get experiment results with per-variant metrics.

        Args:
            experiment_id: The experiment ID.

        Returns:
            Dictionary with experiment results, or None if not found.
        """
        experiment = self._experiments.get(experiment_id)
        if experiment is None:
            return None

        metrics = self._metrics.get(experiment_id, {})

        variant_results = {}
        for variant in experiment.variants:
            m = metrics.get(variant.name, VariantMetrics())
            variant_results[variant.name] = {
                "model_version": variant.model_version,
                "traffic_weight": variant.traffic_weight,
                "requests": m.requests,
                "avg_confidence": round(m.avg_confidence, 4),
                "avg_latency_ms": round(m.avg_latency_ms, 2),
                "error_rate": round(m.error_rate, 4),
                "correct_predictions": m.correct_predictions,
            }

        return {
            "experiment_id": experiment.experiment_id,
            "name": experiment.name,
            "status": experiment.status.value,
            "variants": variant_results,
        }

    def list_experiments(self) -> list[dict]:
        """List all experiments with their status."""
        return [
            {
                "experiment_id": exp.experiment_id,
                "name": exp.name,
                "status": exp.status.value,
                "num_variants": len(exp.variants),
                "created_at": exp.created_at,
            }
            for exp in self._experiments.values()
        ]
