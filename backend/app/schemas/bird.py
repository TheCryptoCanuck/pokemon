from pydantic import BaseModel


class BirdOut(BaseModel):
    id: int
    name: str
    scientific_name: str
    image_url: str
    audio_url: str
    lore: str
    habitat: str
    conservation_status: str
    rarity: str
    base_xp: int
    xp: int

    model_config = {"from_attributes": True}


class BirdListOut(BaseModel):
    birds: list[BirdOut]
    total: int


class EncounterOut(BaseModel):
    """Result of a bird encounter (weighted random selection)."""
    bird: BirdOut
    xp_earned: int
    is_new: bool
