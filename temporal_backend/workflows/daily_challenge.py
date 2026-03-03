"""Daily Challenge Workflow — manages the lifecycle of a daily challenge.

This long-running workflow:
  1. Generates a daily challenge at the start of each day
  2. Accepts progress signals as users identify birds throughout the day
  3. Awards rewards when the challenge is completed
  4. Automatically expires at midnight (24-hour timer)

Demonstrates Temporal's durable timers, signal handling, and
continue-as-new patterns for recurring daily workflows.
"""

from __future__ import annotations

from datetime import timedelta
from dataclasses import dataclass

from temporalio import workflow
from temporalio.common import RetryPolicy

with workflow.unsafe.imports_passed_through():
    from activities.daily_challenge import (
        generate_daily_challenge,
        update_challenge_progress,
        award_challenge_reward,
    )
    from activities.user import award_xp


_DB_RETRY = RetryPolicy(
    initial_interval=timedelta(milliseconds=500),
    backoff_coefficient=2.0,
    maximum_interval=timedelta(seconds=10),
    maximum_attempts=5,
)


@dataclass
class DailyChallengeInput:
    user_id: str
    date: str  # ISO date YYYY-MM-DD


@dataclass
class ProgressSignal:
    increment: int = 1


@dataclass
class DailyChallengeOutput:
    challenge_id: str = ""
    challenge_description: str = ""
    target: int = 0
    current: int = 0
    completed: bool = False
    xp_awarded: int = 0


@workflow.defn
class DailyChallengeWorkflow:
    """Manages a single day's challenge for a user.

    The workflow runs for 24 hours, accepting progress signals as the user
    identifies birds. When the target is met, the reward is issued
    immediately. The workflow completes when the day ends.
    """

    def __init__(self) -> None:
        self._progress: int = 0
        self._completed: bool = False
        self._pending_increments: list[int] = []

    @workflow.signal
    async def record_progress(self, signal: ProgressSignal) -> None:
        """Signal sent each time the user makes progress toward the challenge."""
        self._pending_increments.append(signal.increment)

    @workflow.query
    def current_progress(self) -> int:
        return self._progress

    @workflow.query
    def is_completed(self) -> bool:
        return self._completed

    @workflow.run
    async def run(self, input: DailyChallengeInput) -> DailyChallengeOutput:
        # ---- Generate (or retrieve) today's challenge ----
        challenge = await workflow.execute_activity(
            generate_daily_challenge,
            input.date,
            start_to_close_timeout=timedelta(seconds=10),
            retry_policy=_DB_RETRY,
        )

        challenge_id = challenge["challenge_id"]
        target = challenge["target"]
        xp_reward = challenge["xp_reward"]

        output = DailyChallengeOutput(
            challenge_id=challenge_id,
            challenge_description=challenge["description"],
            target=target,
        )

        # ---- Process progress signals until day ends or challenge completed ----
        # The workflow stays alive for up to 24 hours, processing signals.
        deadline = workflow.now() + timedelta(hours=24)

        while not self._completed and workflow.now() < deadline:
            # Wait for either a progress signal or day expiry
            try:
                await workflow.wait_condition(
                    lambda: len(self._pending_increments) > 0,
                    timeout=deadline - workflow.now(),
                )
            except TimeoutError:
                break  # Day ended

            # Drain all pending increments
            while self._pending_increments:
                inc = self._pending_increments.pop(0)

                progress_result = await workflow.execute_activity(
                    update_challenge_progress,
                    args=[input.user_id, challenge_id, inc],
                    start_to_close_timeout=timedelta(seconds=10),
                    retry_policy=_DB_RETRY,
                )

                self._progress = progress_result.get("current", self._progress)
                self._completed = progress_result.get("completed", False)

                if self._completed:
                    break

        # ---- Award reward if challenge was completed ----
        if self._completed:
            await workflow.execute_activity(
                award_challenge_reward,
                args=[input.user_id, xp_reward],
                start_to_close_timeout=timedelta(seconds=10),
                retry_policy=_DB_RETRY,
            )

            await workflow.execute_activity(
                award_xp,
                args=[input.user_id, xp_reward],
                start_to_close_timeout=timedelta(seconds=10),
                retry_policy=_DB_RETRY,
            )
            output.xp_awarded = xp_reward

        output.current = self._progress
        output.completed = self._completed
        return output
