"""Alert management for ML system monitoring.

Routes alerts from drift detection, performance degradation,
and system health checks to configured notification channels.
"""

from __future__ import annotations

import json
import logging
import time
from dataclasses import dataclass, field
from enum import Enum
from typing import Protocol

logger = logging.getLogger(__name__)


class AlertSeverity(str, Enum):
    """Alert severity levels."""

    INFO = "info"
    WARNING = "warning"
    CRITICAL = "critical"


@dataclass
class Alert:
    """An alert event."""

    name: str
    message: str
    severity: AlertSeverity
    source: str  # e.g., "drift_detector", "performance_monitor"
    metadata: dict = field(default_factory=dict)
    timestamp: float = field(default_factory=time.time)
    resolved: bool = False

    def to_dict(self) -> dict:
        return {
            "name": self.name,
            "message": self.message,
            "severity": self.severity.value,
            "source": self.source,
            "metadata": self.metadata,
            "timestamp": self.timestamp,
            "resolved": self.resolved,
        }


class AlertChannel(Protocol):
    """Protocol for alert notification channels."""

    def send(self, alert: Alert) -> bool: ...


class LogAlertChannel:
    """Alert channel that logs alerts using Python logging."""

    def send(self, alert: Alert) -> bool:
        log_level = {
            AlertSeverity.INFO: logging.INFO,
            AlertSeverity.WARNING: logging.WARNING,
            AlertSeverity.CRITICAL: logging.ERROR,
        }.get(alert.severity, logging.WARNING)

        logger.log(
            log_level,
            "[ALERT:%s] %s — %s (source: %s)",
            alert.severity.value.upper(),
            alert.name,
            alert.message,
            alert.source,
        )
        return True


class WebhookAlertChannel:
    """Alert channel that sends alerts via HTTP webhook."""

    def __init__(self, url: str, timeout: float = 10.0) -> None:
        self.url = url
        self.timeout = timeout

    def send(self, alert: Alert) -> bool:
        try:
            import httpx

            response = httpx.post(
                self.url,
                json=alert.to_dict(),
                timeout=self.timeout,
            )
            return response.is_success
        except Exception as e:
            logger.error("Failed to send webhook alert: %s", e)
            return False


class AlertManager:
    """Manages alert routing, deduplication, and history.

    Routes alerts to configured channels, prevents alert storms
    through cooldown periods, and maintains an alert history.
    """

    def __init__(self, cooldown_seconds: float = 300.0) -> None:
        self._channels: list[AlertChannel] = []
        self._history: list[Alert] = []
        self._cooldown = cooldown_seconds
        self._last_alert_time: dict[str, float] = {}

    def add_channel(self, channel: AlertChannel) -> None:
        """Register an alert notification channel."""
        self._channels.append(channel)

    def fire(self, alert: Alert) -> bool:
        """Fire an alert, routing it to all configured channels.

        Respects cooldown to prevent duplicate alerts.

        Args:
            alert: The alert to fire.

        Returns:
            True if the alert was sent (not suppressed by cooldown).
        """
        # Check cooldown
        last_time = self._last_alert_time.get(alert.name, 0)
        if time.time() - last_time < self._cooldown:
            logger.debug("Alert '%s' suppressed (cooldown active)", alert.name)
            return False

        self._last_alert_time[alert.name] = time.time()
        self._history.append(alert)

        sent = False
        for channel in self._channels:
            try:
                if channel.send(alert):
                    sent = True
            except Exception as e:
                logger.error("Alert channel failed: %s", e)

        return sent

    def check_performance_alerts(
        self,
        metrics: dict,
        accuracy_threshold: float = 0.05,
        latency_p99_threshold: float = 500,
        error_rate_threshold: float = 0.01,
    ) -> list[Alert]:
        """Check metrics against thresholds and fire alerts.

        Args:
            metrics: Metrics summary from MetricsCollector.
            accuracy_threshold: Max allowed accuracy drop.
            latency_p99_threshold: Max P99 latency in ms.
            error_rate_threshold: Max error rate.

        Returns:
            List of fired alerts.
        """
        alerts = []

        # Latency alert
        latency_p99 = metrics.get("latency", {}).get("p99_ms", 0)
        if latency_p99 > latency_p99_threshold:
            alert = Alert(
                name="high_latency",
                message=f"P99 latency {latency_p99:.0f}ms exceeds {latency_p99_threshold}ms",
                severity=AlertSeverity.WARNING,
                source="performance_monitor",
                metadata={"p99_ms": latency_p99, "threshold_ms": latency_p99_threshold},
            )
            self.fire(alert)
            alerts.append(alert)

        # Error rate alert
        error_rate = metrics.get("error_rate", 0)
        if error_rate > error_rate_threshold:
            alert = Alert(
                name="high_error_rate",
                message=f"Error rate {error_rate:.2%} exceeds {error_rate_threshold:.2%}",
                severity=AlertSeverity.CRITICAL,
                source="performance_monitor",
                metadata={"error_rate": error_rate, "threshold": error_rate_threshold},
            )
            self.fire(alert)
            alerts.append(alert)

        # Low confidence alert
        low_conf_rate = metrics.get("confidence", {}).get("low_confidence_rate", 0)
        if low_conf_rate > 0.3:
            alert = Alert(
                name="low_confidence_predictions",
                message=f"{low_conf_rate:.0%} of predictions have low confidence",
                severity=AlertSeverity.WARNING,
                source="performance_monitor",
                metadata={"low_confidence_rate": low_conf_rate},
            )
            self.fire(alert)
            alerts.append(alert)

        return alerts

    def get_active_alerts(self) -> list[dict]:
        """Get unresolved alerts."""
        return [a.to_dict() for a in self._history if not a.resolved]

    def get_alert_history(self, limit: int = 50) -> list[dict]:
        """Get recent alert history."""
        return [a.to_dict() for a in self._history[-limit:]]
