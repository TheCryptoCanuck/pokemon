from datetime import datetime, timezone

from sqlalchemy import DateTime, ForeignKey, Integer, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class UserBird(Base):
    """A bird in a user's aviary (collection). Allows duplicates via count."""

    __tablename__ = "user_birds"
    __table_args__ = (
        UniqueConstraint("user_id", "bird_id", name="uq_user_bird"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    bird_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("birds.id", ondelete="CASCADE"), nullable=False
    )
    count: Mapped[int] = mapped_column(Integer, default=1)
    first_seen: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    user = relationship("User", back_populates="collection")
    bird = relationship("Bird", lazy="joined")
