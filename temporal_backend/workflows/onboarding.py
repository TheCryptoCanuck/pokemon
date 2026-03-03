"""User Onboarding Workflow — new player setup and welcome sequence.

Orchestrates the full onboarding process:
  1. Create user profile with initial stats
  2. Generate the first daily challenge
  3. Send a welcome notification
  4. Wait for the user's first identification (signal-driven)
  5. Award the "First Discovery" achievement when triggered

Uses Temporal signals to pause the workflow until the user completes their
first identification, demonstrating long-running workflow patterns.
"""

from __future__ import annotations

from datetime import timedelta
from dataclasses import asdict, dataclass, field

from temporalio import workflow
from temporalio.common import RetryPolicy

with workflow.unsafe.imports_passed_through():
    from activities.user import save_user_profile, award_xp
    from activities.achievement import unlock_achievement, send_achievement_notification
    from activities.daily_challenge import generate_daily_challenge
    from models.user import UserProfile, UserStats


_DB_RETRY = RetryPolicy(
    initial_interval=timedelta(milliseconds=500),
    backoff_coefficient=2.0,
    maximum_interval=timedelta(seconds=10),
    maximum_attempts=5,
)


@dataclass
class OnboardingInput:
    user_id: str
    display_name: str


@dataclass
class OnboardingOutput:
    user_id: str = ""
    profile_created: bool = False
    first_challenge_id: str = ""
    welcome_sent: bool = False
    first_bird_identified: bool = False
    error: str = ""


@workflow.defn
class UserOnboardingWorkflow:
    """Long-running workflow that manages new user onboarding.

    The workflow creates the user profile and then waits (up to 7 days)
    for the user to identify their first bird via a signal. This
    demonstrates Temporal's durable timer and signal patterns.
    """

    def __init__(self) -> None:
        self._first_bird_identified = False
        self._status: str = "initializing"

    @workflow.signal
    async def first_bird_identified(self) -> None:
        """Signal sent when the user completes their first identification."""
        self._first_bird_identified = True

    @workflow.query
    def status(self) -> str:
        return self._status

    @workflow.run
    async def run(self, input: OnboardingInput) -> OnboardingOutput:
        output = OnboardingOutput(user_id=input.user_id)

        # ---- Step 1: Create user profile ----
        self._status = "creating_profile"
        profile = UserProfile(
            user_id=input.user_id,
            display_name=input.display_name,
            stats=UserStats(),
        )

        created = await workflow.execute_activity(
            save_user_profile,
            asdict(profile),
            start_to_close_timeout=timedelta(seconds=10),
            retry_policy=_DB_RETRY,
        )

        if not created:
            output.error = "Failed to create user profile"
            self._status = "failed"
            return output

        output.profile_created = True

        # ---- Step 2: Generate first daily challenge ----
        self._status = "generating_challenge"
        today = workflow.now().strftime("%Y-%m-%d")
        challenge = await workflow.execute_activity(
            generate_daily_challenge,
            today,
            start_to_close_timeout=timedelta(seconds=10),
            retry_policy=_DB_RETRY,
        )
        output.first_challenge_id = challenge.get("challenge_id", "")

        # ---- Step 3: Send welcome notification ----
        self._status = "sending_welcome"
        await workflow.execute_activity(
            send_achievement_notification,
            args=[input.user_id, "Welcome to AviQuest!"],
            start_to_close_timeout=timedelta(seconds=10),
            retry_policy=_DB_RETRY,
        )
        output.welcome_sent = True

        # ---- Step 4: Wait for first bird identification ----
        self._status = "waiting_for_first_bird"

        # Wait up to 7 days for the user to identify their first bird.
        # If the signal arrives before the timeout, we proceed immediately.
        try:
            await workflow.wait_condition(
                lambda: self._first_bird_identified,
                timeout=timedelta(days=7),
            )
        except TimeoutError:
            # User didn't identify a bird within 7 days — complete anyway
            self._status = "completed_without_first_bird"
            return output

        # ---- Step 5: Award first bird achievement ----
        self._status = "awarding_first_bird"
        await workflow.execute_activity(
            unlock_achievement,
            args=[input.user_id, "first_bird"],
            start_to_close_timeout=timedelta(seconds=10),
            retry_policy=_DB_RETRY,
        )

        await workflow.execute_activity(
            award_xp,
            args=[input.user_id, 100],  # first_bird achievement XP
            start_to_close_timeout=timedelta(seconds=10),
            retry_policy=_DB_RETRY,
        )

        await workflow.execute_activity(
            send_achievement_notification,
            args=[input.user_id, "First Discovery — Welcome to birding!"],
            start_to_close_timeout=timedelta(seconds=10),
            retry_policy=_DB_RETRY,
        )

        output.first_bird_identified = True
        self._status = "completed"
        return output
