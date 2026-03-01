"""Weighted random bird encounter — server-authoritative version of Flutter logic."""

import random

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.bird import Bird


async def weighted_random_encounter(db: AsyncSession) -> Bird:
    """Select a random bird using rarity weights."""
    roll = random.random()
    cumulative = 0.0
    selected_rarity = "common"

    for rarity, weight in settings.RARITY_WEIGHTS.items():
        cumulative += weight
        if roll < cumulative:
            selected_rarity = rarity
            break

    result = await db.execute(
        select(Bird).where(Bird.rarity == selected_rarity)
    )
    pool = result.scalars().all()

    if not pool:
        # Fallback to any bird if rarity pool is empty
        result = await db.execute(select(Bird))
        pool = result.scalars().all()

    return random.choice(pool)
