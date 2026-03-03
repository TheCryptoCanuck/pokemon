from __future__ import annotations

import math
from dataclasses import dataclass, field


@dataclass
class UserStats:
    level: int = 1
    xp: int = 0
    streak: int = 0
    total_identifications: int = 0
    species_collected: int = 0

    def xp_for_next_level(self) -> int:
        """XP required to reach the next level. Mirrors Flutter: 1000 * level^1.4"""
        return round(1000 * math.pow(self.level, 1.4))

    def level_title(self) -> str:
        if self.level < 3:
            return "Fledgling"
        if self.level < 6:
            return "Nestling"
        if self.level < 10:
            return "Sparrow"
        if self.level < 15:
            return "Warbler"
        if self.level < 20:
            return "Songweaver"
        if self.level < 30:
            return "Falconer"
        if self.level < 40:
            return "Eagle Scout"
        return "Master Birder"


@dataclass
class UserProfile:
    user_id: str
    display_name: str
    stats: UserStats = field(default_factory=UserStats)
    collected_species: list[str] = field(default_factory=list)
    unlocked_achievements: list[str] = field(default_factory=list)
