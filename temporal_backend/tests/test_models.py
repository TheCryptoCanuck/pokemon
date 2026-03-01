"""Tests for data models."""

from models.bird import Bird, Rarity, RARITY_XP
from models.user import UserProfile, UserStats
from models.identification import IdentificationResult, IdentificationStatus
from models.achievement import ACHIEVEMENT_REGISTRY, AchievementType
from models.daily_challenge import DailyChallenge, ChallengeType


class TestBird:
    def test_rarity_enum_values(self):
        assert Rarity.COMMON.value == "common"
        assert Rarity.LEGENDARY.value == "legendary"

    def test_rarity_xp_mapping(self):
        assert RARITY_XP[Rarity.COMMON] == 50
        assert RARITY_XP[Rarity.UNCOMMON] == 120
        assert RARITY_XP[Rarity.RARE] == 300
        assert RARITY_XP[Rarity.LEGENDARY] == 750

    def test_bird_xp_value(self):
        bird = Bird(
            name="Test Bird",
            scientific_name="Testus birdus",
            image_url="",
            audio_url="",
            habitat="Test",
            conservation_status="Least Concern",
            rarity=Rarity.RARE,
            base_xp=300,
        )
        assert bird.xp_value == 300

    def test_bird_xp_value_fallback(self):
        bird = Bird(
            name="Test",
            scientific_name="T",
            image_url="",
            audio_url="",
            habitat="",
            conservation_status="",
            rarity=Rarity.UNCOMMON,
            base_xp=0,
        )
        # base_xp is 0, so falls back to RARITY_XP
        assert bird.xp_value == RARITY_XP[Rarity.UNCOMMON]


class TestUserStats:
    def test_default_stats(self):
        stats = UserStats()
        assert stats.level == 1
        assert stats.xp == 0
        assert stats.streak == 0

    def test_xp_for_next_level(self):
        stats = UserStats(level=1)
        assert stats.xp_for_next_level() == 1000  # 1000 * 1^1.4 = 1000

    def test_xp_for_next_level_scales(self):
        stats = UserStats(level=5)
        xp_needed = stats.xp_for_next_level()
        assert xp_needed > 1000  # Should scale with level

    def test_level_titles(self):
        assert UserStats(level=1).level_title() == "Fledgling"
        assert UserStats(level=5).level_title() == "Nestling"
        assert UserStats(level=9).level_title() == "Sparrow"
        assert UserStats(level=10).level_title() == "Warbler"
        assert UserStats(level=15).level_title() == "Songweaver"
        assert UserStats(level=20).level_title() == "Falconer"
        assert UserStats(level=30).level_title() == "Eagle Scout"
        assert UserStats(level=50).level_title() == "Master Birder"


class TestUserProfile:
    def test_default_profile(self):
        profile = UserProfile(user_id="u1", display_name="Test")
        assert profile.stats.level == 1
        assert profile.collected_species == []
        assert profile.unlocked_achievements == []


class TestIdentificationResult:
    def test_default_result(self):
        result = IdentificationResult()
        assert result.status == IdentificationStatus.PENDING
        assert result.bird_name == ""
        assert result.xp_awarded == 0
        assert result.achievements_unlocked == []


class TestAchievementRegistry:
    def test_registry_not_empty(self):
        assert len(ACHIEVEMENT_REGISTRY) > 0

    def test_all_achievements_have_keys(self):
        keys = [a.key for a in ACHIEVEMENT_REGISTRY]
        assert len(keys) == len(set(keys))  # No duplicates

    def test_first_bird_achievement_exists(self):
        keys = {a.key for a in ACHIEVEMENT_REGISTRY}
        assert "first_bird" in keys
        assert "rare_find" in keys
        assert "legendary_find" in keys

    def test_achievement_types(self):
        types = {a.achievement_type for a in ACHIEVEMENT_REGISTRY}
        assert AchievementType.COLLECTION_MILESTONE in types
        assert AchievementType.RARITY_FIND in types
        assert AchievementType.LEVEL_MILESTONE in types


class TestDailyChallenge:
    def test_challenge_types(self):
        assert ChallengeType.IDENTIFY_COUNT.value == "identify_count"
        assert ChallengeType.HABITAT_EXPLORER.value == "habitat_explorer"
