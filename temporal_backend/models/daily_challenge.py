from __future__ import annotations

import enum
from dataclasses import dataclass


class ChallengeType(str, enum.Enum):
    IDENTIFY_COUNT = "identify_count"       # Identify N birds today
    IDENTIFY_RARITY = "identify_rarity"     # Identify a bird of given rarity
    HABITAT_EXPLORER = "habitat_explorer"   # Identify birds from N habitats


@dataclass
class DailyChallenge:
    challenge_id: str
    challenge_type: ChallengeType
    description: str
    target: int
    xp_reward: int
    date: str  # ISO date string YYYY-MM-DD


@dataclass
class ChallengeProgress:
    challenge_id: str
    user_id: str
    current: int = 0
    completed: bool = False
