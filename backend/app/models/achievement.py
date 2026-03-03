from datetime import datetime, timezone

from sqlalchemy import DateTime, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


# Achievement definitions — mirrors Flutter _achievements map
ACHIEVEMENT_DEFS: dict[str, tuple[str, str, str]] = {
    "first_bird": ("\U0001f426", "First Feather", "Identify your first bird"),
    "five_species": ("\U0001f33f", "Nature Curious", "Collect 5 different species"),
    "ten_species": ("\U0001f3c6", "Avid Birder", "Collect 10 different species"),
    "twenty_species": ("\U0001f985", "Wing Watcher", "Collect 20 different species"),
    "rare_find": ("\U0001f48e", "Rare Encounter", "Identify a rare bird"),
    "legendary_find": ("\u2728", "Legend Spotter", "Identify a legendary bird"),
    "level_5": ("\u2b50", "Rising Birder", "Reach level 5"),
    "level_10": ("\U0001f31f", "Expert Nester", "Reach level 10"),
    "level_20": ("\U0001f320", "Sky Master", "Reach level 20"),
}


class UserAchievement(Base):
    __tablename__ = "user_achievements"
    __table_args__ = (
        UniqueConstraint("user_id", "key", name="uq_user_achievement"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    key: Mapped[str] = mapped_column(String(40), nullable=False)
    unlocked_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    user = relationship("User", back_populates="achievements")
