from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.achievement import ACHIEVEMENT_DEFS, UserAchievement
from app.models.bird import Bird
from app.models.user import User
from app.models.user_bird import UserBird
from app.schemas.bird import BirdOut, EncounterOut
from app.schemas.user import (
    AchievementOut,
    CollectionBirdOut,
    CollectionOut,
    UserProfileOut,
)
from app.services.encounter import weighted_random_encounter
from app.services.game import (
    check_achievements,
    compute_level_and_xp,
    level_title,
    xp_for_next_level,
)

router = APIRouter(tags=["collection"])


# ── Profile ──────────────────────────────────────────────────────────────────


@router.get("/profile", response_model=UserProfileOut)
async def get_profile(user: User = Depends(get_current_user)):
    return UserProfileOut(
        id=user.id,
        username=user.username,
        email=user.email,
        level=user.level,
        xp=user.xp,
        xp_for_next_level=xp_for_next_level(user.level),
        level_title=level_title(user.level),
        streak=user.streak,
        species_collected=len(user.collection),
        achievements_unlocked=len(user.achievements),
        created_at=user.created_at,
    )


# ── Collection (aviary) ─────────────────────────────────────────────────────


@router.get("/collection", response_model=CollectionOut)
async def get_collection(user: User = Depends(get_current_user)):
    birds = [
        CollectionBirdOut(
            bird_id=ub.bird.id,
            name=ub.bird.name,
            scientific_name=ub.bird.scientific_name,
            image_url=ub.bird.image_url,
            rarity=ub.bird.rarity,
            count=ub.count,
            first_seen=ub.first_seen,
        )
        for ub in user.collection
    ]
    return CollectionOut(birds=birds, total_species=len(birds))


# ── Encounter ────────────────────────────────────────────────────────────────


@router.post("/encounter", response_model=EncounterOut)
async def trigger_encounter(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Server-authoritative bird encounter. Returns a weighted-random bird."""
    bird = await weighted_random_encounter(db)
    bird_out = BirdOut.model_validate(bird)

    # Check if this is a new species for the user
    existing = next((ub for ub in user.collection if ub.bird_id == bird.id), None)
    is_new = existing is None

    return EncounterOut(bird=bird_out, xp_earned=bird.xp, is_new=is_new)


@router.post("/collection/{bird_id}", status_code=status.HTTP_201_CREATED)
async def add_to_collection(
    bird_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Add a bird to the user's aviary, award XP, check achievements."""
    # Verify bird exists
    result = await db.execute(select(Bird).where(Bird.id == bird_id))
    bird = result.scalar_one_or_none()
    if not bird:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Bird not found")

    # Add or increment collection
    existing = await db.execute(
        select(UserBird).where(
            UserBird.user_id == user.id, UserBird.bird_id == bird.id
        )
    )
    user_bird = existing.scalar_one_or_none()

    if user_bird:
        user_bird.count += 1
    else:
        db.add(UserBird(user_id=user.id, bird_id=bird.id))

    # Award XP and handle level-ups
    new_level, new_xp, levels_gained = compute_level_and_xp(
        user.level, user.xp, bird.xp
    )
    user.level = new_level
    user.xp = new_xp

    # Check achievements
    species_count_result = await db.execute(
        select(UserBird).where(UserBird.user_id == user.id)
    )
    species_count = len(species_count_result.scalars().all()) + (1 if not user_bird else 0)

    existing_keys = {a.key for a in user.achievements}
    new_achievements = check_achievements(
        species_count, bird.rarity, new_level, existing_keys
    )
    for key in new_achievements:
        db.add(UserAchievement(user_id=user.id, key=key))

    await db.commit()

    return {
        "bird_name": bird.name,
        "xp_earned": bird.xp,
        "new_level": new_level,
        "new_xp": new_xp,
        "xp_for_next_level": xp_for_next_level(new_level),
        "level_title": level_title(new_level),
        "levels_gained": levels_gained,
        "new_achievements": [
            {
                "key": key,
                "emoji": ACHIEVEMENT_DEFS[key][0],
                "title": ACHIEVEMENT_DEFS[key][1],
                "description": ACHIEVEMENT_DEFS[key][2],
            }
            for key in new_achievements
        ],
    }


# ── Achievements ─────────────────────────────────────────────────────────────


@router.get("/achievements", response_model=list[AchievementOut])
async def get_achievements(user: User = Depends(get_current_user)):
    unlocked_map = {a.key: a.unlocked_at for a in user.achievements}
    return [
        AchievementOut(
            key=key,
            emoji=emoji,
            title=title,
            description=desc,
            unlocked=key in unlocked_map,
            unlocked_at=unlocked_map.get(key),
        )
        for key, (emoji, title, desc) in ACHIEVEMENT_DEFS.items()
    ]
