from __future__ import annotations

import enum
from dataclasses import dataclass, field


class IdentificationStatus(str, enum.Enum):
    PENDING = "pending"
    PROCESSING = "processing"
    IDENTIFIED = "identified"
    FAILED = "failed"


@dataclass
class IdentificationRequest:
    user_id: str
    image_data: str  # base64-encoded image or storage key
    latitude: float = 0.0
    longitude: float = 0.0
    audio_data: str = ""  # optional audio recording key


@dataclass
class IdentificationResult:
    status: IdentificationStatus = IdentificationStatus.PENDING
    bird_name: str = ""
    scientific_name: str = ""
    confidence: float = 0.0
    rarity: str = ""
    xp_awarded: int = 0
    is_new_species: bool = False
    achievements_unlocked: list[str] = field(default_factory=list)
    error_message: str = ""
