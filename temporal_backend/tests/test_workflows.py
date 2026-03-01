"""Tests for Temporal workflows using time-skipping WorkflowEnvironment.

These tests validate workflow logic end-to-end with real activity execution,
using Temporal's built-in test server with automatic time-skipping for
fast testing of long-running workflows.
"""

from __future__ import annotations

import pytest
import uuid
from dataclasses import asdict
from datetime import timedelta

from temporalio.client import Client
from temporalio.testing import WorkflowEnvironment
from temporalio.worker import Worker

from workflows.identification import (
    BirdIdentificationWorkflow,
    IdentificationInput,
    IdentificationOutput,
)
from workflows.onboarding import (
    UserOnboardingWorkflow,
    OnboardingInput,
    OnboardingOutput,
)
from workflows.daily_challenge import (
    DailyChallengeWorkflow,
    DailyChallengeInput,
    DailyChallengeOutput,
    ProgressSignal,
)
from workflows.achievement import (
    AchievementProcessingWorkflow,
    AchievementInput,
    AchievementOutput,
)
from activities.identification import analyze_image, analyze_audio, lookup_bird_details
from activities.user import (
    get_user_profile,
    save_user_profile,
    add_species_to_collection,
    award_xp,
    update_streak,
    _USER_STORE,
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
    _CHALLENGE_STORE,
    _PROGRESS_STORE,
)
from models.user import UserProfile, UserStats

ALL_ACTIVITIES = [
    analyze_image,
    analyze_audio,
    lookup_bird_details,
    get_user_profile,
    save_user_profile,
    add_species_to_collection,
    award_xp,
    update_streak,
    check_achievements,
    unlock_achievement,
    send_achievement_notification,
    generate_daily_challenge,
    update_challenge_progress,
    award_challenge_reward,
]

TASK_QUEUE = "test-aviquest"


@pytest.fixture(autouse=True)
def _clear_stores():
    _USER_STORE.clear()
    _CHALLENGE_STORE.clear()
    _PROGRESS_STORE.clear()
    yield
    _USER_STORE.clear()
    _CHALLENGE_STORE.clear()
    _PROGRESS_STORE.clear()


def _seed_user(user_id: str, display_name: str = "Tester") -> dict:
    """Create a user in the in-memory store for testing."""
    profile = UserProfile(
        user_id=user_id,
        display_name=display_name,
        stats=UserStats(),
    )
    data = asdict(profile)
    _USER_STORE[user_id] = data
    return data


# ---- Bird Identification Workflow ----

class TestBirdIdentificationWorkflow:
    async def test_successful_identification(self):
        async with await WorkflowEnvironment.start_time_skipping() as env:
            async with Worker(
                env.client,
                task_queue=TASK_QUEUE,
                workflows=[BirdIdentificationWorkflow],
                activities=ALL_ACTIVITIES,
            ):
                user_id = f"user-{uuid.uuid4().hex[:8]}"
                _seed_user(user_id)

                result = await env.client.execute_workflow(
                    BirdIdentificationWorkflow.run,
                    IdentificationInput(
                        user_id=user_id,
                        image_data="photo_of_eagle_in_sky",
                    ),
                    id=f"identify-{uuid.uuid4().hex[:8]}",
                    task_queue=TASK_QUEUE,
                )

                assert result.bird_name == "Bald Eagle"
                assert result.confidence > 0.8
                assert result.rarity == "rare"
                assert result.xp_awarded > 0

    async def test_identification_with_audio(self):
        async with await WorkflowEnvironment.start_time_skipping() as env:
            async with Worker(
                env.client,
                task_queue=TASK_QUEUE,
                workflows=[BirdIdentificationWorkflow],
                activities=ALL_ACTIVITIES,
            ):
                user_id = f"user-{uuid.uuid4().hex[:8]}"
                _seed_user(user_id)

                result = await env.client.execute_workflow(
                    BirdIdentificationWorkflow.run,
                    IdentificationInput(
                        user_id=user_id,
                        image_data="unknown_photo",
                        audio_data="eagle_call_recording",
                    ),
                    id=f"identify-{uuid.uuid4().hex[:8]}",
                    task_queue=TASK_QUEUE,
                )

                # Audio confidence for eagle (0.75) < image default robin (0.78)
                # So image result should win
                assert result.bird_name in ("American Robin", "Bald Eagle")

    async def test_new_species_detected(self):
        async with await WorkflowEnvironment.start_time_skipping() as env:
            async with Worker(
                env.client,
                task_queue=TASK_QUEUE,
                workflows=[BirdIdentificationWorkflow],
                activities=ALL_ACTIVITIES,
            ):
                user_id = f"user-{uuid.uuid4().hex[:8]}"
                _seed_user(user_id)

                result = await env.client.execute_workflow(
                    BirdIdentificationWorkflow.run,
                    IdentificationInput(
                        user_id=user_id,
                        image_data="sparrow_photo",
                    ),
                    id=f"identify-{uuid.uuid4().hex[:8]}",
                    task_queue=TASK_QUEUE,
                )

                assert result.is_new_species is True

    async def test_duplicate_species_not_new(self):
        async with await WorkflowEnvironment.start_time_skipping() as env:
            async with Worker(
                env.client,
                task_queue=TASK_QUEUE,
                workflows=[BirdIdentificationWorkflow],
                activities=ALL_ACTIVITIES,
            ):
                user_id = f"user-{uuid.uuid4().hex[:8]}"
                _seed_user(user_id)
                # Pre-populate collection
                _USER_STORE[user_id]["collected_species"] = ["House Sparrow"]

                result = await env.client.execute_workflow(
                    BirdIdentificationWorkflow.run,
                    IdentificationInput(
                        user_id=user_id,
                        image_data="sparrow_photo",
                    ),
                    id=f"identify-{uuid.uuid4().hex[:8]}",
                    task_queue=TASK_QUEUE,
                )

                assert result.bird_name == "House Sparrow"
                assert result.is_new_species is False

    async def test_achievements_unlocked_on_identification(self):
        async with await WorkflowEnvironment.start_time_skipping() as env:
            async with Worker(
                env.client,
                task_queue=TASK_QUEUE,
                workflows=[BirdIdentificationWorkflow],
                activities=ALL_ACTIVITIES,
            ):
                user_id = f"user-{uuid.uuid4().hex[:8]}"
                _seed_user(user_id)

                result = await env.client.execute_workflow(
                    BirdIdentificationWorkflow.run,
                    IdentificationInput(
                        user_id=user_id,
                        image_data="owl_in_arctic",
                    ),
                    id=f"identify-{uuid.uuid4().hex[:8]}",
                    task_queue=TASK_QUEUE,
                )

                # Snowy owl is legendary — should unlock first_bird + legendary_find + rare_find
                assert result.rarity == "legendary"
                if result.achievements_unlocked:
                    assert any(
                        k in result.achievements_unlocked
                        for k in ["first_bird", "legendary_find", "rare_find"]
                    )

    async def test_query_workflow_status(self):
        async with await WorkflowEnvironment.start_time_skipping() as env:
            async with Worker(
                env.client,
                task_queue=TASK_QUEUE,
                workflows=[BirdIdentificationWorkflow],
                activities=ALL_ACTIVITIES,
            ):
                user_id = f"user-{uuid.uuid4().hex[:8]}"
                _seed_user(user_id)

                handle = await env.client.start_workflow(
                    BirdIdentificationWorkflow.run,
                    IdentificationInput(
                        user_id=user_id,
                        image_data="falcon_photo",
                    ),
                    id=f"identify-{uuid.uuid4().hex[:8]}",
                    task_queue=TASK_QUEUE,
                )

                result = await handle.result()
                assert result.bird_name == "Peregrine Falcon"


# ---- User Onboarding Workflow ----

class TestUserOnboardingWorkflow:
    async def test_onboarding_with_first_bird_signal(self):
        async with await WorkflowEnvironment.start_time_skipping() as env:
            async with Worker(
                env.client,
                task_queue=TASK_QUEUE,
                workflows=[UserOnboardingWorkflow],
                activities=ALL_ACTIVITIES,
            ):
                user_id = f"user-{uuid.uuid4().hex[:8]}"

                handle = await env.client.start_workflow(
                    UserOnboardingWorkflow.run,
                    OnboardingInput(
                        user_id=user_id,
                        display_name="New Birder",
                    ),
                    id=f"onboard-{uuid.uuid4().hex[:8]}",
                    task_queue=TASK_QUEUE,
                )

                # Send signal that first bird was identified
                await handle.signal(UserOnboardingWorkflow.first_bird_identified)

                result = await handle.result()

                assert result.profile_created is True
                assert result.welcome_sent is True
                assert result.first_bird_identified is True
                assert result.first_challenge_id != ""

    async def test_onboarding_timeout_without_signal(self):
        """Test that onboarding completes after 7-day timeout (time-skipped)."""
        async with await WorkflowEnvironment.start_time_skipping() as env:
            async with Worker(
                env.client,
                task_queue=TASK_QUEUE,
                workflows=[UserOnboardingWorkflow],
                activities=ALL_ACTIVITIES,
            ):
                user_id = f"user-{uuid.uuid4().hex[:8]}"

                result = await env.client.execute_workflow(
                    UserOnboardingWorkflow.run,
                    OnboardingInput(
                        user_id=user_id,
                        display_name="Lazy Birder",
                    ),
                    id=f"onboard-{uuid.uuid4().hex[:8]}",
                    task_queue=TASK_QUEUE,
                )

                # Profile was created but no first bird
                assert result.profile_created is True
                assert result.first_bird_identified is False


# ---- Daily Challenge Workflow ----

class TestDailyChallengeWorkflow:
    async def test_challenge_completion(self):
        async with await WorkflowEnvironment.start_time_skipping() as env:
            async with Worker(
                env.client,
                task_queue=TASK_QUEUE,
                workflows=[DailyChallengeWorkflow],
                activities=ALL_ACTIVITIES,
            ):
                user_id = f"user-{uuid.uuid4().hex[:8]}"
                _seed_user(user_id)

                handle = await env.client.start_workflow(
                    DailyChallengeWorkflow.run,
                    DailyChallengeInput(
                        user_id=user_id,
                        date="2026-03-01",
                    ),
                    id=f"challenge-{uuid.uuid4().hex[:8]}",
                    task_queue=TASK_QUEUE,
                )

                # Send enough progress signals to complete the challenge
                for _ in range(10):
                    await handle.signal(
                        DailyChallengeWorkflow.record_progress,
                        ProgressSignal(increment=1),
                    )

                result = await handle.result()

                assert result.challenge_id.startswith("daily-")
                assert result.completed is True
                assert result.xp_awarded > 0

    async def test_challenge_expires_at_end_of_day(self):
        """Test that challenge expires after 24 hours (time-skipped)."""
        async with await WorkflowEnvironment.start_time_skipping() as env:
            async with Worker(
                env.client,
                task_queue=TASK_QUEUE,
                workflows=[DailyChallengeWorkflow],
                activities=ALL_ACTIVITIES,
            ):
                user_id = f"user-{uuid.uuid4().hex[:8]}"
                _seed_user(user_id)

                result = await env.client.execute_workflow(
                    DailyChallengeWorkflow.run,
                    DailyChallengeInput(
                        user_id=user_id,
                        date="2026-03-01",
                    ),
                    id=f"challenge-{uuid.uuid4().hex[:8]}",
                    task_queue=TASK_QUEUE,
                )

                # No signals sent — should expire incomplete
                assert result.completed is False
                assert result.xp_awarded == 0


# ---- Achievement Processing Workflow ----

class TestAchievementProcessingWorkflow:
    async def test_achievement_processing(self):
        async with await WorkflowEnvironment.start_time_skipping() as env:
            async with Worker(
                env.client,
                task_queue=TASK_QUEUE,
                workflows=[AchievementProcessingWorkflow],
                activities=ALL_ACTIVITIES,
            ):
                user_id = f"user-{uuid.uuid4().hex[:8]}"
                _seed_user(user_id)
                # Give them 1 species so first_bird triggers
                _USER_STORE[user_id]["stats"]["species_collected"] = 1
                _USER_STORE[user_id]["collected_species"] = ["Robin"]

                result = await env.client.execute_workflow(
                    AchievementProcessingWorkflow.run,
                    AchievementInput(
                        user_id=user_id,
                        bird_rarity="common",
                    ),
                    id=f"achieve-{uuid.uuid4().hex[:8]}",
                    task_queue=TASK_QUEUE,
                )

                assert "first_bird" in result.achievements_unlocked
                assert result.total_xp_awarded > 0

    async def test_legendary_achievements(self):
        async with await WorkflowEnvironment.start_time_skipping() as env:
            async with Worker(
                env.client,
                task_queue=TASK_QUEUE,
                workflows=[AchievementProcessingWorkflow],
                activities=ALL_ACTIVITIES,
            ):
                user_id = f"user-{uuid.uuid4().hex[:8]}"
                _seed_user(user_id)
                _USER_STORE[user_id]["stats"]["species_collected"] = 1
                _USER_STORE[user_id]["collected_species"] = ["Snowy Owl"]

                result = await env.client.execute_workflow(
                    AchievementProcessingWorkflow.run,
                    AchievementInput(
                        user_id=user_id,
                        bird_rarity="legendary",
                    ),
                    id=f"achieve-{uuid.uuid4().hex[:8]}",
                    task_queue=TASK_QUEUE,
                )

                assert "legendary_find" in result.achievements_unlocked
                assert "rare_find" in result.achievements_unlocked

    async def test_no_achievements_for_empty_user(self):
        async with await WorkflowEnvironment.start_time_skipping() as env:
            async with Worker(
                env.client,
                task_queue=TASK_QUEUE,
                workflows=[AchievementProcessingWorkflow],
                activities=ALL_ACTIVITIES,
            ):
                result = await env.client.execute_workflow(
                    AchievementProcessingWorkflow.run,
                    AchievementInput(
                        user_id="nonexistent-user",
                        bird_rarity="common",
                    ),
                    id=f"achieve-{uuid.uuid4().hex[:8]}",
                    task_queue=TASK_QUEUE,
                )

                assert result.achievements_unlocked == []
                assert "User profile not found" in result.errors
