from sqlalchemy import Float, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Bird(Base):
    __tablename__ = "birds"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(120), unique=True, nullable=False, index=True)
    scientific_name: Mapped[str] = mapped_column(String(120), nullable=False)
    image_url: Mapped[str] = mapped_column(String(500), default="")
    audio_url: Mapped[str] = mapped_column(String(500), default="")
    lore: Mapped[str] = mapped_column(String(1000), default="")
    habitat: Mapped[str] = mapped_column(String(300), default="")
    conservation_status: Mapped[str] = mapped_column(String(60), default="")
    rarity: Mapped[str] = mapped_column(String(20), nullable=False, index=True)  # common|uncommon|rare|legendary
    base_xp: Mapped[int] = mapped_column(Integer, nullable=False, default=50)

    # Computed XP (mirrors Flutter logic)
    @property
    def xp(self) -> int:
        multipliers = {"uncommon": 1.5, "rare": 2.0, "legendary": 5.0}
        return round(self.base_xp * multipliers.get(self.rarity, 1.0))
