from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


class UserCreate(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    email: EmailStr
    password: str = Field(..., min_length=6, max_length=128)


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"


class UserProfileOut(BaseModel):
    id: int
    username: str
    email: str
    level: int
    xp: int
    xp_for_next_level: int
    level_title: str
    streak: int
    species_collected: int
    achievements_unlocked: int
    created_at: datetime

    model_config = {"from_attributes": True}


class AchievementOut(BaseModel):
    key: str
    emoji: str
    title: str
    description: str
    unlocked: bool
    unlocked_at: datetime | None = None


class CollectionBirdOut(BaseModel):
    bird_id: int
    name: str
    scientific_name: str
    image_url: str
    rarity: str
    count: int
    first_seen: datetime

    model_config = {"from_attributes": True}


class CollectionOut(BaseModel):
    birds: list[CollectionBirdOut]
    total_species: int
