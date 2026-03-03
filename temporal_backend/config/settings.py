"""Application settings for the AviQuest Temporal backend.

Settings are loaded from environment variables with sensible defaults
for local development.
"""

from __future__ import annotations

import os
from dataclasses import dataclass

TASK_QUEUE = "aviquest-main"


@dataclass
class Settings:
    """Configuration for Temporal connection and worker behavior."""

    # Temporal server connection
    temporal_host: str = "localhost:7233"
    temporal_namespace: str = "default"

    # Worker configuration
    task_queue: str = TASK_QUEUE
    max_concurrent_activities: int = 100
    max_concurrent_workflow_tasks: int = 100

    @classmethod
    def from_env(cls) -> Settings:
        return cls(
            temporal_host=os.environ.get("TEMPORAL_HOST", "localhost:7233"),
            temporal_namespace=os.environ.get("TEMPORAL_NAMESPACE", "default"),
            task_queue=os.environ.get("TEMPORAL_TASK_QUEUE", TASK_QUEUE),
            max_concurrent_activities=int(
                os.environ.get("TEMPORAL_MAX_ACTIVITIES", "100")
            ),
            max_concurrent_workflow_tasks=int(
                os.environ.get("TEMPORAL_MAX_WORKFLOW_TASKS", "100")
            ),
        )
