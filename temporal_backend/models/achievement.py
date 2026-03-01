from __future__ import annotations

import enum
from dataclasses import dataclass


class AchievementType(str, enum.Enum):
    COLLECTION_MILESTONE = "collection_milestone"
    RARITY_FIND = "rarity_find"
    LEVEL_MILESTONE = "level_milestone"
    STREAK_MILESTONE = "streak_milestone"
    IDENTIFICATION_COUNT = "identification_count"


@dataclass
class Achievement:
    key: str
    name: str
    description: str
    achievement_type: AchievementType
    threshold: int  # e.g. 5 species, level 10, etc.
    xp_reward: int = 0


@dataclass
class AchievementUnlock:
    user_id: str
    achievement_key: str
    achievement_name: str
    xp_reward: int


# Registry mirroring Flutter client achievements
ACHIEVEMENT_REGISTRY: list[Achievement] = [
    Achievement("first_bird", "First Discovery", "Identify your first bird",
                AchievementType.COLLECTION_MILESTONE, 1, xp_reward=100),
    Achievement("five_species", "Budding Birder", "Collect 5 species",
                AchievementType.COLLECTION_MILESTONE, 5, xp_reward=250),
    Achievement("ten_species", "Avid Watcher", "Collect 10 species",
                AchievementType.COLLECTION_MILESTONE, 10, xp_reward=500),
    Achievement("twenty_species", "Bird Brain", "Collect 20 species",
                AchievementType.COLLECTION_MILESTONE, 20, xp_reward=1000),
    Achievement("fifty_species", "Feathered Expert", "Collect 50 species",
                AchievementType.COLLECTION_MILESTONE, 50, xp_reward=2500),
    Achievement("rare_find", "Rare Sight", "Identify a rare bird",
                AchievementType.RARITY_FIND, 1, xp_reward=300),
    Achievement("legendary_find", "Legend Spotter", "Identify a legendary bird",
                AchievementType.RARITY_FIND, 1, xp_reward=750),
    Achievement("level_5", "Rising Star", "Reach level 5",
                AchievementType.LEVEL_MILESTONE, 5, xp_reward=200),
    Achievement("level_10", "Seasoned Birder", "Reach level 10",
                AchievementType.LEVEL_MILESTONE, 10, xp_reward=500),
    Achievement("level_20", "Master Watcher", "Reach level 20",
                AchievementType.LEVEL_MILESTONE, 20, xp_reward=1000),
    Achievement("streak_7", "Week Warrior", "Maintain a 7-day streak",
                AchievementType.STREAK_MILESTONE, 7, xp_reward=350),
    Achievement("streak_30", "Monthly Maven", "Maintain a 30-day streak",
                AchievementType.STREAK_MILESTONE, 30, xp_reward=1500),
]
