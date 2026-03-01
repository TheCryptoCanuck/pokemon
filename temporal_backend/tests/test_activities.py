"""Tests for Temporal activities.

Uses ActivityEnvironment for unit testing activities in isolation.
"""

from __future__ import annotations

import pytest
from dataclasses import asdict
from temporalio.testing import ActivityEnvironment

from activities.identification import analyze_image, analyze_audio, lookup_bird_details
from activities.user import (
    get_user_profile,
    save_user_profile,
    add_species_to_collection,
    award_xp,
    update_streak,
    _USER_STORE,
)
from activities.achievement import check_achievements, unlock_achievement
from activities.daily_challenge import (
    generate_daily_challenge,
    update_challenge_progress,
    _CHALLENGE_STORE,
    _PROGRESS_STORE,
)
from models.user import UserProfile, UserStats


@pytest.fixture(autouse=True)
def _clear_stores():
    """Clear in-memory stores between tests."""
    _USER_STORE.clear()
    _CHALLENGE_STORE.clear()
    _PROGRESS_STORE.clear()
    yield
    _USER_STORE.clear()
    _CHALLENGE_STORE.clear()
    _PROGRESS_STORE.clear()


@pytest.fixture
def env():
    return ActivityEnvironment()


@pytest.fixture
def sample_profile() -> dict:
    profile = UserProfile(
        user_id="test-user",
        display_name="Tester",
        stats=UserStats(level=1, xp=0, streak=0, total_identifications=0, species_collected=0),
    )
    data = asdict(profile)
    _USER_STORE["test-user"] = data
    return data


# ---- Image identification ----

class TestAnalyzeImage:
    async def test_identifies_eagle(self, env: ActivityEnvironment):
        result = await env.run(analyze_image, "photo_of_eagle_in_sky")
        assert result["bird_key"] == "bald_eagle"
        assert result["confidence"] > 0.8

    async def test_identifies_owl(self, env: ActivityEnvironment):
        result = await env.run(analyze_image, "snowy_owl_perched")
        assert result["bird_key"] == "snowy_owl"

    async def test_default_identification(self, env: ActivityEnvironment):
        result = await env.run(analyze_image, "unknown_bird_photo")
        assert result["bird_key"] == "american_robin"
        assert result["confidence"] > 0


# ---- Audio identification ----

class TestAnalyzeAudio:
    async def test_empty_audio(self, env: ActivityEnvironment):
        result = await env.run(analyze_audio, "")
        assert result["bird_key"] == ""
        assert result["confidence"] == 0.0

    async def test_identifies_eagle_audio(self, env: ActivityEnvironment):
        result = await env.run(analyze_audio, "eagle_call_recording")
        assert result["bird_key"] == "bald_eagle"


# ---- Bird lookup ----

class TestLookupBirdDetails:
    async def test_known_bird(self, env: ActivityEnvironment):
        result = await env.run(lookup_bird_details, "american_robin")
        assert result["name"] == "American Robin"
        assert result["rarity"] == "common"

    async def test_unknown_bird(self, env: ActivityEnvironment):
        result = await env.run(lookup_bird_details, "nonexistent_bird")
        assert result == {}


# ---- User profile ----

class TestUserActivities:
    async def test_save_and_get_profile(self, env: ActivityEnvironment):
        profile = asdict(UserProfile(user_id="u1", display_name="Alice"))
        saved = await env.run(save_user_profile, profile)
        assert saved is True

        loaded = await env.run(get_user_profile, "u1")
        assert loaded["display_name"] == "Alice"

    async def test_get_nonexistent_profile(self, env: ActivityEnvironment):
        result = await env.run(get_user_profile, "nonexistent")
        assert result == {}

    async def test_save_empty_user_id(self, env: ActivityEnvironment):
        result = await env.run(save_user_profile, {"user_id": ""})
        assert result is False


# ---- Species collection ----

class TestAddSpeciesToCollection:
    async def test_add_new_species(self, env: ActivityEnvironment, sample_profile):
        result = await env.run(add_species_to_collection, "test-user", "American Robin")
        assert result["is_new_species"] is True
        assert "American Robin" in result["collected_species"]

    async def test_add_duplicate_species(self, env: ActivityEnvironment, sample_profile):
        await env.run(add_species_to_collection, "test-user", "American Robin")
        result = await env.run(add_species_to_collection, "test-user", "American Robin")
        assert result["is_new_species"] is False
        # Should still count identification
        assert result["stats"]["total_identifications"] == 2

    async def test_add_species_nonexistent_user(self, env: ActivityEnvironment):
        result = await env.run(add_species_to_collection, "nobody", "Robin")
        assert result == {}


# ---- XP and leveling ----

class TestAwardXp:
    async def test_award_xp(self, env: ActivityEnvironment, sample_profile):
        result = await env.run(award_xp, "test-user", 500)
        assert result["xp_awarded"] == 500
        assert result["leveled_up"] is False

    async def test_level_up(self, env: ActivityEnvironment, sample_profile):
        result = await env.run(award_xp, "test-user", 1500)
        assert result["leveled_up"] is True
        assert result["new_level"] >= 2

    async def test_award_xp_nonexistent_user(self, env: ActivityEnvironment):
        result = await env.run(award_xp, "nobody", 100)
        assert result["xp_awarded"] == 0


# ---- Streak ----

class TestUpdateStreak:
    async def test_update_streak(self, env: ActivityEnvironment, sample_profile):
        result = await env.run(update_streak, "test-user")
        assert result["streak"] == 1
        assert result["increased"] is True

    async def test_streak_nonexistent_user(self, env: ActivityEnvironment):
        result = await env.run(update_streak, "nobody")
        assert result["streak"] == 0


# ---- Achievements ----

class TestCheckAchievements:
    async def test_first_bird_achievement(self, env: ActivityEnvironment, sample_profile):
        # Simulate having 1 species collected
        _USER_STORE["test-user"]["stats"]["species_collected"] = 1
        _USER_STORE["test-user"]["collected_species"] = ["Robin"]

        result = await env.run(check_achievements, _USER_STORE["test-user"], "common")
        keys = [a["achievement_key"] for a in result]
        assert "first_bird" in keys

    async def test_rare_find_achievement(self, env: ActivityEnvironment, sample_profile):
        _USER_STORE["test-user"]["stats"]["species_collected"] = 1
        _USER_STORE["test-user"]["collected_species"] = ["Eagle"]

        result = await env.run(check_achievements, _USER_STORE["test-user"], "rare")
        keys = [a["achievement_key"] for a in result]
        assert "rare_find" in keys

    async def test_no_duplicate_achievements(self, env: ActivityEnvironment, sample_profile):
        _USER_STORE["test-user"]["unlocked_achievements"] = ["first_bird"]
        _USER_STORE["test-user"]["stats"]["species_collected"] = 1

        result = await env.run(check_achievements, _USER_STORE["test-user"], "common")
        keys = [a["achievement_key"] for a in result]
        assert "first_bird" not in keys


class TestUnlockAchievement:
    async def test_unlock(self, env: ActivityEnvironment, sample_profile):
        result = await env.run(unlock_achievement, "test-user", "first_bird")
        assert result is True
        assert "first_bird" in _USER_STORE["test-user"]["unlocked_achievements"]

    async def test_unlock_idempotent(self, env: ActivityEnvironment, sample_profile):
        await env.run(unlock_achievement, "test-user", "first_bird")
        await env.run(unlock_achievement, "test-user", "first_bird")
        count = _USER_STORE["test-user"]["unlocked_achievements"].count("first_bird")
        assert count == 1  # Not duplicated


# ---- Daily challenges ----

class TestDailyChallengeActivities:
    async def test_generate_challenge(self, env: ActivityEnvironment):
        result = await env.run(generate_daily_challenge, "2026-03-01")
        assert result["challenge_id"] == "daily-2026-03-01"
        assert result["target"] > 0

    async def test_generate_challenge_idempotent(self, env: ActivityEnvironment):
        r1 = await env.run(generate_daily_challenge, "2026-03-01")
        r2 = await env.run(generate_daily_challenge, "2026-03-01")
        assert r1 == r2

    async def test_update_progress(self, env: ActivityEnvironment):
        await env.run(generate_daily_challenge, "2026-03-01")
        result = await env.run(update_challenge_progress, "user1", "daily-2026-03-01", 1)
        assert result["current"] == 1

    async def test_progress_completion(self, env: ActivityEnvironment):
        challenge = await env.run(generate_daily_challenge, "2026-03-01")
        target = challenge["target"]

        result = None
        for _ in range(target):
            result = await env.run(update_challenge_progress, "user1", "daily-2026-03-01", 1)

        assert result is not None
        assert result["completed"] is True
