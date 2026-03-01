"""Achievement Processing Workflow — batch achievement evaluation.

This workflow evaluates all achievements for a user after state changes
(identification, level-up, streak update). It processes achievements in
order and handles each unlock as a compensatable step in a saga.

Use cases:
  - Called as a child workflow from BirdIdentificationWorkflow
  - Called standalone for periodic achievement reconciliation
  - Called after admin grants or profile imports
"""

from __future__ import annotations

from datetime import timedelta
from dataclasses import dataclass, field

from temporalio import workflow
from temporalio.common import RetryPolicy
from temporalio.exceptions import ActivityError

with workflow.unsafe.imports_passed_through():
    from activities.user import get_user_profile, award_xp
    from activities.achievement import (
        check_achievements,
        unlock_achievement,
        send_achievement_notification,
    )


_DB_RETRY = RetryPolicy(
    initial_interval=timedelta(milliseconds=500),
    backoff_coefficient=2.0,
    maximum_interval=timedelta(seconds=10),
    maximum_attempts=5,
)


@dataclass
class AchievementInput:
    user_id: str
    bird_rarity: str = ""  # rarity of the most recently identified bird


@dataclass
class AchievementOutput:
    achievements_unlocked: list[str] = field(default_factory=list)
    total_xp_awarded: int = 0
    errors: list[str] = field(default_factory=list)


@workflow.defn
class AchievementProcessingWorkflow:
    """Evaluates and awards achievements for a user.

    Implements the saga pattern: each achievement unlock is a separate
    step. If a notification fails, the achievement is still recorded
    (notification is non-critical). If the unlock itself fails, the
    error is recorded but processing continues for other achievements.
    """

    def __init__(self) -> None:
        self._unlocked: list[str] = []

    @workflow.query
    def unlocked_achievements(self) -> list[str]:
        return self._unlocked

    @workflow.run
    async def run(self, input: AchievementInput) -> AchievementOutput:
        output = AchievementOutput()

        # ---- Fetch current user profile ----
        profile = await workflow.execute_activity(
            get_user_profile,
            input.user_id,
            start_to_close_timeout=timedelta(seconds=10),
            retry_policy=_DB_RETRY,
        )

        if not profile:
            output.errors.append("User profile not found")
            return output

        # ---- Check which achievements are newly earned ----
        new_achievements = await workflow.execute_activity(
            check_achievements,
            args=[profile, input.bird_rarity],
            start_to_close_timeout=timedelta(seconds=10),
            retry_policy=_DB_RETRY,
        )

        # ---- Process each unlock as a saga step ----
        for ach in new_achievements:
            ach_key = ach["achievement_key"]
            ach_name = ach["achievement_name"]
            xp_reward = ach.get("xp_reward", 0)

            # Step A: Record the unlock
            try:
                await workflow.execute_activity(
                    unlock_achievement,
                    args=[input.user_id, ach_key],
                    start_to_close_timeout=timedelta(seconds=10),
                    retry_policy=_DB_RETRY,
                )
            except ActivityError as err:
                output.errors.append(f"Failed to unlock {ach_key}: {err}")
                continue  # Skip this achievement, try next

            self._unlocked.append(ach_key)
            output.achievements_unlocked.append(ach_key)

            # Step B: Award XP bonus (non-critical — log error if fails)
            if xp_reward > 0:
                try:
                    await workflow.execute_activity(
                        award_xp,
                        args=[input.user_id, xp_reward],
                        start_to_close_timeout=timedelta(seconds=10),
                        retry_policy=_DB_RETRY,
                    )
                    output.total_xp_awarded += xp_reward
                except ActivityError as err:
                    output.errors.append(f"Failed to award XP for {ach_key}: {err}")

            # Step C: Send notification (fire-and-forget, non-critical)
            try:
                await workflow.execute_activity(
                    send_achievement_notification,
                    args=[input.user_id, ach_name],
                    start_to_close_timeout=timedelta(seconds=10),
                    retry_policy=_DB_RETRY,
                )
            except ActivityError:
                # Notification failure is non-critical, silently continue
                pass

        return output
