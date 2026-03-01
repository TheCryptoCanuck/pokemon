"""AviQuest Temporal Worker — entry point for the workflow worker process.

Registers all workflows and activities, connects to the Temporal server,
and runs the worker with graceful shutdown support.

Usage:
    python worker.py

Environment variables:
    TEMPORAL_HOST           Temporal server address (default: localhost:7233)
    TEMPORAL_NAMESPACE      Temporal namespace (default: default)
    TEMPORAL_TASK_QUEUE     Task queue name (default: aviquest-main)
    TEMPORAL_MAX_ACTIVITIES Max concurrent activities (default: 100)
"""

from __future__ import annotations

import asyncio
import logging
import signal

from temporalio.client import Client
from temporalio.worker import Worker

from config.settings import Settings
from workflows.identification import BirdIdentificationWorkflow
from workflows.onboarding import UserOnboardingWorkflow
from workflows.daily_challenge import DailyChallengeWorkflow
from workflows.achievement import AchievementProcessingWorkflow
from activities.identification import analyze_image, analyze_audio, lookup_bird_details
from activities.user import (
    get_user_profile,
    save_user_profile,
    add_species_to_collection,
    award_xp,
    update_streak,
)
from activities.achievement import (
    check_achievements,
    unlock_achievement,
    send_achievement_notification,
)
from activities.daily_challenge import (
    generate_daily_challenge,
    update_challenge_progress,
    award_challenge_reward,
)

logger = logging.getLogger(__name__)


async def run_worker() -> None:
    """Connect to Temporal and run the worker until interrupted."""
    settings = Settings.from_env()

    logger.info(
        "Connecting to Temporal at %s (namespace: %s)",
        settings.temporal_host,
        settings.temporal_namespace,
    )

    client = await Client.connect(
        settings.temporal_host,
        namespace=settings.temporal_namespace,
    )

    logger.info("Starting worker on task queue: %s", settings.task_queue)

    worker = Worker(
        client,
        task_queue=settings.task_queue,
        workflows=[
            BirdIdentificationWorkflow,
            UserOnboardingWorkflow,
            DailyChallengeWorkflow,
            AchievementProcessingWorkflow,
        ],
        activities=[
            # Identification
            analyze_image,
            analyze_audio,
            lookup_bird_details,
            # User management
            get_user_profile,
            save_user_profile,
            add_species_to_collection,
            award_xp,
            update_streak,
            # Achievements
            check_achievements,
            unlock_achievement,
            send_achievement_notification,
            # Daily challenges
            generate_daily_challenge,
            update_challenge_progress,
            award_challenge_reward,
        ],
        max_concurrent_activities=settings.max_concurrent_activities,
        max_concurrent_workflow_task_polls=settings.max_concurrent_workflow_tasks,
    )

    # Set up graceful shutdown on SIGINT / SIGTERM
    shutdown_event = asyncio.Event()

    def _signal_handler() -> None:
        logger.info("Shutdown signal received, stopping worker...")
        shutdown_event.set()

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, _signal_handler)

    # Run worker until shutdown signal
    async with worker:
        logger.info("Worker is running. Press Ctrl+C to stop.")
        await shutdown_event.wait()

    logger.info("Worker stopped gracefully.")


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )
    asyncio.run(run_worker())


if __name__ == "__main__":
    main()
