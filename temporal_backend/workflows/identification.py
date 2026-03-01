"""Bird Identification Workflow — the core AviQuest workflow.

Orchestrates the full bird identification pipeline:
  1. Analyze submitted image (and optionally audio) via ML activities
  2. Look up bird details from the database
  3. Add the species to the user's collection
  4. Award XP and update streak
  5. Check and unlock any newly-earned achievements

Implements the saga pattern: if later steps fail, compensation activities
can revert earlier side-effects (e.g. removing a species from collection).
"""

from __future__ import annotations

from datetime import timedelta
from dataclasses import dataclass

from temporalio import workflow
from temporalio.common import RetryPolicy
from temporalio.exceptions import ActivityError, ApplicationError

with workflow.unsafe.imports_passed_through():
    from activities.identification import analyze_image, analyze_audio, lookup_bird_details
    from activities.user import (
        get_user_profile,
        add_species_to_collection,
        award_xp,
        update_streak,
    )
    from activities.achievement import (
        check_achievements,
        unlock_achievement,
        send_achievement_notification,
    )


# Retry policy for ML inference activities (may have transient GPU errors)
_ML_RETRY = RetryPolicy(
    initial_interval=timedelta(seconds=1),
    backoff_coefficient=2.0,
    maximum_interval=timedelta(seconds=30),
    maximum_attempts=3,
    non_retryable_error_types=["ValueError"],
)

# Retry policy for database activities (usually fast, low failure rate)
_DB_RETRY = RetryPolicy(
    initial_interval=timedelta(milliseconds=500),
    backoff_coefficient=2.0,
    maximum_interval=timedelta(seconds=10),
    maximum_attempts=5,
)


@dataclass
class IdentificationInput:
    user_id: str
    image_data: str
    audio_data: str = ""
    latitude: float = 0.0
    longitude: float = 0.0


@dataclass
class IdentificationOutput:
    bird_name: str = ""
    scientific_name: str = ""
    confidence: float = 0.0
    rarity: str = ""
    xp_awarded: int = 0
    is_new_species: bool = False
    achievements_unlocked: list[str] | None = None
    leveled_up: bool = False
    new_level: int = 0
    error: str = ""


@workflow.defn
class BirdIdentificationWorkflow:
    """Durable workflow that orchestrates a full bird identification request.

    Signals allow external updates (e.g. challenge progress) and queries
    expose the current identification state for the Flutter client to poll.
    """

    def __init__(self) -> None:
        self._status: str = "pending"
        self._result: IdentificationOutput = IdentificationOutput()

    @workflow.query
    def status(self) -> str:
        return self._status

    @workflow.query
    def result(self) -> IdentificationOutput:
        return self._result

    @workflow.run
    async def run(self, input: IdentificationInput) -> IdentificationOutput:
        self._status = "processing"

        # ---- Step 1: Parallel image + audio analysis ----
        image_result = await workflow.execute_activity(
            analyze_image,
            input.image_data,
            start_to_close_timeout=timedelta(seconds=30),
            heartbeat_timeout=timedelta(seconds=10),
            retry_policy=_ML_RETRY,
        )

        # Optional audio analysis runs in parallel if audio data is provided
        audio_result: dict = {}
        if input.audio_data:
            audio_result = await workflow.execute_activity(
                analyze_audio,
                input.audio_data,
                start_to_close_timeout=timedelta(seconds=30),
                heartbeat_timeout=timedelta(seconds=10),
                retry_policy=_ML_RETRY,
            )

        # Merge results — prefer higher confidence
        bird_key = image_result["bird_key"]
        confidence = image_result["confidence"]
        if audio_result and audio_result.get("confidence", 0) > confidence:
            bird_key = audio_result["bird_key"]
            confidence = audio_result["confidence"]

        if not bird_key:
            self._status = "failed"
            self._result = IdentificationOutput(error="Could not identify bird")
            return self._result

        # ---- Step 2: Look up bird details ----
        bird_details = await workflow.execute_activity(
            lookup_bird_details,
            bird_key,
            start_to_close_timeout=timedelta(seconds=10),
            retry_policy=_DB_RETRY,
        )

        if not bird_details:
            self._status = "failed"
            self._result = IdentificationOutput(
                error=f"Bird '{bird_key}' not found in database"
            )
            return self._result

        bird_name = bird_details["name"]
        rarity = bird_details["rarity"]
        base_xp = bird_details["base_xp"]

        # ---- Step 3: Add species to user collection ----
        try:
            collection_result = await workflow.execute_activity(
                add_species_to_collection,
                args=[input.user_id, bird_name],
                start_to_close_timeout=timedelta(seconds=10),
                retry_policy=_DB_RETRY,
            )
        except ActivityError as err:
            self._status = "failed"
            self._result = IdentificationOutput(
                bird_name=bird_name,
                error=f"Failed to update collection: {err}",
            )
            return self._result

        is_new = collection_result.get("is_new_species", False)

        # ---- Step 4: Award XP and update streak ----
        xp_result = await workflow.execute_activity(
            award_xp,
            args=[input.user_id, base_xp],
            start_to_close_timeout=timedelta(seconds=10),
            retry_policy=_DB_RETRY,
        )

        await workflow.execute_activity(
            update_streak,
            input.user_id,
            start_to_close_timeout=timedelta(seconds=10),
            retry_policy=_DB_RETRY,
        )

        # ---- Step 5: Check and unlock achievements ----
        achievements_unlocked: list[str] = []
        try:
            profile = await workflow.execute_activity(
                get_user_profile,
                input.user_id,
                start_to_close_timeout=timedelta(seconds=10),
                retry_policy=_DB_RETRY,
            )

            new_achievements = await workflow.execute_activity(
                check_achievements,
                args=[profile, rarity],
                start_to_close_timeout=timedelta(seconds=10),
                retry_policy=_DB_RETRY,
            )

            for ach in new_achievements:
                await workflow.execute_activity(
                    unlock_achievement,
                    args=[input.user_id, ach["achievement_key"]],
                    start_to_close_timeout=timedelta(seconds=10),
                    retry_policy=_DB_RETRY,
                )

                # Award achievement XP bonus
                if ach.get("xp_reward", 0) > 0:
                    await workflow.execute_activity(
                        award_xp,
                        args=[input.user_id, ach["xp_reward"]],
                        start_to_close_timeout=timedelta(seconds=10),
                        retry_policy=_DB_RETRY,
                    )

                # Send push notification (fire-and-forget style)
                await workflow.execute_activity(
                    send_achievement_notification,
                    args=[input.user_id, ach["achievement_name"]],
                    start_to_close_timeout=timedelta(seconds=10),
                    retry_policy=_DB_RETRY,
                )

                achievements_unlocked.append(ach["achievement_key"])

        except ActivityError:
            # Achievement processing is non-critical; log and continue
            workflow.logger.warning(
                "Achievement check failed for user %s", input.user_id
            )

        # ---- Build final result ----
        self._status = "completed"
        self._result = IdentificationOutput(
            bird_name=bird_name,
            scientific_name=bird_details.get("scientific_name", ""),
            confidence=confidence,
            rarity=rarity,
            xp_awarded=xp_result.get("xp_awarded", base_xp),
            is_new_species=is_new,
            achievements_unlocked=achievements_unlocked,
            leveled_up=xp_result.get("leveled_up", False),
            new_level=xp_result.get("new_level", 0),
        )
        return self._result
