"""Tests for serving components."""

import time

import pytest

from src.monitoring.metrics_collector import MetricsCollector
from src.serving.middleware import RateLimiter


class TestRateLimiter:
    def test_allows_within_limit(self):
        limiter = RateLimiter(requests_per_minute=10, burst_size=5)
        for _ in range(5):
            assert limiter.is_allowed("client1") is True

    def test_blocks_over_burst(self):
        limiter = RateLimiter(requests_per_minute=100, burst_size=3)
        for _ in range(3):
            assert limiter.is_allowed("client1") is True
        assert limiter.is_allowed("client1") is False

    def test_separate_clients(self):
        limiter = RateLimiter(requests_per_minute=5, burst_size=3)
        for _ in range(3):
            limiter.is_allowed("client1")
        # Different client should not be affected
        assert limiter.is_allowed("client2") is True


class TestMetricsCollector:
    @pytest.fixture
    def collector(self):
        return MetricsCollector(window_size=100)

    def test_record_prediction(self, collector):
        collector.record_prediction(
            latency_ms=50.0, confidence=0.95, predicted_class="robin"
        )
        summary = collector.get_summary()
        assert summary["total_predictions"] == 1
        assert summary["latency"]["mean_ms"] == 50.0

    def test_multiple_predictions(self, collector):
        for i in range(10):
            collector.record_prediction(
                latency_ms=float(i * 10),
                confidence=0.5 + i * 0.05,
                predicted_class=f"species_{i % 3}",
            )
        summary = collector.get_summary()
        assert summary["total_predictions"] == 10
        assert len(summary["top_predicted_classes"]) <= 10

    def test_error_tracking(self, collector):
        collector.record_prediction(latency_ms=10, confidence=0.9, predicted_class="robin")
        collector.record_error()
        summary = collector.get_summary()
        assert summary["errors"] == 1

    def test_cache_tracking(self, collector):
        collector.record_cache_hit()
        collector.record_cache_hit()
        collector.record_cache_miss()
        summary = collector.get_summary()
        assert summary["cache"]["hits"] == 2
        assert summary["cache"]["misses"] == 1
        assert abs(summary["cache"]["hit_rate"] - 2 / 3) < 0.01

    def test_image_features(self, collector):
        collector.record_image_features({
            "mean_pixel_intensity": 0.5,
            "image_brightness": 0.6,
        })
        summary = collector.get_summary()
        assert "image_features" in summary
        assert "mean_pixel_intensity" in summary["image_features"]

    def test_reset(self, collector):
        collector.record_prediction(latency_ms=10, confidence=0.9, predicted_class="robin")
        collector.reset()
        summary = collector.get_summary()
        assert summary["total_predictions"] == 0
