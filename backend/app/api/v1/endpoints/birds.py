from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.models.bird import Bird
from app.schemas.bird import BirdListOut, BirdOut

router = APIRouter(prefix="/birds", tags=["birds"])


@router.get("", response_model=BirdListOut)
async def list_birds(
    rarity: str | None = Query(None, description="Filter by rarity tier"),
    search: str | None = Query(None, description="Search by name or scientific name"),
    offset: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
):
    query = select(Bird)
    count_query = select(func.count(Bird.id))

    if rarity:
        query = query.where(Bird.rarity == rarity)
        count_query = count_query.where(Bird.rarity == rarity)

    if search:
        pattern = f"%{search}%"
        query = query.where(Bird.name.ilike(pattern) | Bird.scientific_name.ilike(pattern))
        count_query = count_query.where(
            Bird.name.ilike(pattern) | Bird.scientific_name.ilike(pattern)
        )

    total = (await db.execute(count_query)).scalar() or 0
    result = await db.execute(query.order_by(Bird.name).offset(offset).limit(limit))
    birds = result.scalars().all()

    return BirdListOut(
        birds=[BirdOut.model_validate(b) for b in birds],
        total=total,
    )


@router.get("/{bird_id}", response_model=BirdOut)
async def get_bird(bird_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Bird).where(Bird.id == bird_id))
    bird = result.scalar_one_or_none()
    if not bird:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Bird not found")
    return BirdOut.model_validate(bird)
