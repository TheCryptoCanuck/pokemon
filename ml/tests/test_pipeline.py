"""Tests for A/B testing, drift detection, and augmentation."""

import numpy as np
import pytest
import torch

from src.ab_testing.experiment import (
    ExperimentConfig,
    ExperimentManager,
    ExperimentStatus,
    Variant,
)
from src.ab_testing.statistics import compute_sample_size, proportion_z_test, welch_t_test
from src.features.augmentation import AugmentationScheduler, cutmix, mixup, mixup_criterion
from src.features.feature_store import InMemoryFeatureStore
from src.monitoring.drift_detection import DriftDetector, DriftStatus


class TestMixup:
    def test_mixup_shape(self):
        images = torch.randn(4, 3, 64, 64)
        labels = torch.tensor([0, 1, 2, 3])
        mixed, la, lb, lam = mixup(images, labels, alpha=0.2)
        assert mixed.shape == images.shape
        assert la.shape == labels.shape
        assert 0.0 <= lam <= 1.0

    def test_cutmix_shape(self):
        images = torch.randn(4, 3, 64, 64)
        labels = torch.tensor([0, 1, 2, 3])
        mixed, la, lb, lam = cutmix(images, labels, alpha=1.0)
        assert mixed.shape == images.shape

    def test_mixup_criterion(self):
        criterion = torch.nn.CrossEntropyLoss()
        preds = torch.randn(4, 10)
        labels_a = torch.tensor([0, 1, 2, 3])
        labels_b = torch.tensor([4, 5, 6, 7])
        loss = mixup_criterion(criterion, preds, labels_a, labels_b, 0.7)
        assert loss.item() > 0


class TestAugmentationScheduler:
    def test_warmup_phase(self):
        scheduler = AugmentationScheduler(
            initial_mixup_alpha=0.2, warmup_epochs=5, total_epochs=50
        )
        params = scheduler.get_augmentation_params(0)
        assert params["mixup_alpha"] == 0.0  # epoch 0

        params = scheduler.get_augmentation_params(2)
        assert 0.0 < params["mixup_alpha"] < 0.2

    def test_full_strength(self):
        scheduler = AugmentationScheduler(
            initial_mixup_alpha=0.2, warmup_epochs=5, decay_start_epoch=30
        )
        params = scheduler.get_augmentation_params(15)
        assert abs(params["mixup_alpha"] - 0.2) < 0.01


class TestFeatureStore:
    def test_put_and_get(self):
        store = InMemoryFeatureStore(max_size=10)
        store.put("id1", {"brightness": 0.5})
        record = store.get("id1")
        assert record is not None
        assert record.features["brightness"] == 0.5

    def test_cache_miss(self):
        store = InMemoryFeatureStore()
        assert store.get("nonexistent") is None

    def test_lru_eviction(self):
        store = InMemoryFeatureStore(max_size=3)
        store.put("a", {"v": 1})
        store.put("b", {"v": 2})
        store.put("c", {"v": 3})
        store.put("d", {"v": 4})  # Should evict "a"
        assert store.get("a") is None
        assert store.get("d") is not None

    def test_stats(self):
        store = InMemoryFeatureStore(max_size=10)
        store.put("a", {"v": 1})
        store.get("a")  # hit
        store.get("b")  # miss
        stats = store.get_stats()
        assert stats["hits"] == 1
        assert stats["misses"] == 1
        assert stats["size"] == 1

    def test_compute_feature_id(self):
        fid = InMemoryFeatureStore.compute_feature_id(b"test data")
        assert isinstance(fid, str)
        assert len(fid) == 64  # SHA-256 hex


class TestDriftDetector:
    def test_insufficient_data(self):
        detector = DriftDetector(
            reference_window_size=100, detection_window_size=50
        )
        for i in range(10):
            detector.add_observation({"feature_a": float(i)})
        results = detector.check_drift()
        assert results["feature_a"].status == DriftStatus.INSUFFICIENT_DATA

    def test_no_drift(self):
        detector = DriftDetector(
            reference_window_size=100, detection_window_size=50
        )
        rng = np.random.RandomState(42)
        # Same distribution for reference and detection
        for _ in range(100):
            detector.add_observation({"feature_a": float(rng.normal(0, 1))})
        for _ in range(50):
            detector.add_observation({"feature_a": float(rng.normal(0, 1))})

        results = detector.check_drift()
        assert results["feature_a"].status in (DriftStatus.NO_DRIFT, DriftStatus.WARNING)

    def test_drift_detected(self):
        detector = DriftDetector(
            reference_window_size=200, detection_window_size=100
        )
        rng = np.random.RandomState(42)
        # Reference: N(0, 1)
        for _ in range(200):
            detector.add_observation({"feature_a": float(rng.normal(0, 1))})
        # Detection: N(5, 1) — significant shift
        for _ in range(100):
            detector.add_observation({"feature_a": float(rng.normal(5, 1))})

        results = detector.check_drift()
        assert results["feature_a"].status == DriftStatus.DRIFT_DETECTED

    def test_drift_summary(self):
        detector = DriftDetector(reference_window_size=50, detection_window_size=50)
        rng = np.random.RandomState(42)
        for _ in range(50):
            detector.add_observation({"f1": float(rng.normal(0, 1))})
        for _ in range(50):
            detector.add_observation({"f1": float(rng.normal(0, 1))})
        summary = detector.get_drift_summary()
        assert "overall_status" in summary
        assert "per_feature" in summary


class TestExperimentManager:
    @pytest.fixture
    def manager(self):
        return ExperimentManager()

    @pytest.fixture
    def experiment(self):
        return ExperimentConfig(
            experiment_id="exp-001",
            name="Model v1 vs v2",
            variants=[
                Variant(name="control", model_version="v1", traffic_weight=0.5),
                Variant(name="treatment", model_version="v2", traffic_weight=0.5),
            ],
        )

    def test_create_experiment(self, manager, experiment):
        created = manager.create_experiment(experiment)
        assert created.experiment_id == "exp-001"

    def test_invalid_weights(self, manager):
        config = ExperimentConfig(
            experiment_id="exp-bad",
            name="Bad weights",
            variants=[
                Variant(name="a", model_version="v1", traffic_weight=0.3),
                Variant(name="b", model_version="v2", traffic_weight=0.3),
            ],
        )
        with pytest.raises(ValueError, match="sum to 1.0"):
            manager.create_experiment(config)

    def test_assign_variant_deterministic(self, manager, experiment):
        manager.create_experiment(experiment)
        manager.start_experiment("exp-001")

        # Same user always gets same variant
        v1 = manager.assign_variant("exp-001", "user-123")
        v2 = manager.assign_variant("exp-001", "user-123")
        assert v1.name == v2.name

    def test_assign_variant_not_running(self, manager, experiment):
        manager.create_experiment(experiment)
        # Not started yet
        assert manager.assign_variant("exp-001", "user-123") is None

    def test_record_and_get_results(self, manager, experiment):
        manager.create_experiment(experiment)
        manager.start_experiment("exp-001")

        manager.record_outcome("exp-001", "control", confidence=0.9, latency_ms=50)
        manager.record_outcome("exp-001", "treatment", confidence=0.85, latency_ms=45)

        results = manager.get_results("exp-001")
        assert results["variants"]["control"]["requests"] == 1
        assert results["variants"]["treatment"]["requests"] == 1

    def test_list_experiments(self, manager, experiment):
        manager.create_experiment(experiment)
        listing = manager.list_experiments()
        assert len(listing) == 1
        assert listing[0]["experiment_id"] == "exp-001"


class TestStatistics:
    def test_proportion_z_test_significant(self):
        result = proportion_z_test(
            successes_a=900, total_a=1000,
            successes_b=800, total_b=1000,
        )
        assert result.is_significant is True

    def test_proportion_z_test_not_significant(self):
        result = proportion_z_test(
            successes_a=50, total_a=100,
            successes_b=48, total_b=100,
        )
        assert result.is_significant is False

    def test_proportion_z_test_empty(self):
        result = proportion_z_test(0, 0, 0, 0)
        assert result.is_significant is False

    def test_welch_t_test(self):
        rng = np.random.RandomState(42)
        a = rng.normal(100, 10, 500).tolist()
        b = rng.normal(110, 10, 500).tolist()
        result = welch_t_test(a, b)
        assert result.is_significant is True

    def test_compute_sample_size(self):
        n = compute_sample_size(
            baseline_rate=0.80,
            minimum_detectable_effect=0.05,
        )
        assert n > 0
        assert n > 100  # Should need a reasonable number of samples
