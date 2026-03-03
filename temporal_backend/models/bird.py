from __future__ import annotations

import enum
from dataclasses import dataclass


class Rarity(str, enum.Enum):
    COMMON = "common"
    UNCOMMON = "uncommon"
    RARE = "rare"
    LEGENDARY = "legendary"


# XP multipliers per rarity tier (mirrors Flutter client logic)
RARITY_XP: dict[Rarity, int] = {
    Rarity.COMMON: 50,
    Rarity.UNCOMMON: 120,
    Rarity.RARE: 300,
    Rarity.LEGENDARY: 750,
}


@dataclass
class Bird:
    name: str
    scientific_name: str
    image_url: str
    audio_url: str
    habitat: str
    conservation_status: str
    rarity: Rarity
    base_xp: int

    @property
    def xp_value(self) -> int:
        return self.base_xp or RARITY_XP.get(self.rarity, 50)
