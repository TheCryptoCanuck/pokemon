"""Seed the database with the full bird catalog from the Flutter app.

Usage:
    python -m scripts.seed_birds
"""

import asyncio
import json
import re
import sys
from pathlib import Path

from sqlalchemy import select

# Add backend to path so imports work when run as script
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.db.base import Base
from app.db.session import async_session, engine
from app.models.bird import Bird


# Parse bird data from the Flutter main.dart
def parse_birds_from_dart(dart_path: str) -> list[dict]:
    """Extract bird data from the Flutter main.dart Bird(...) constructors."""
    content = Path(dart_path).read_text()

    # Match Bird(...) constructor calls
    pattern = re.compile(
        r"Bird\(\s*"
        r"name:\s*'([^']*)',\s*"
        r"scientificName:\s*'([^']*)',\s*"
        r"imageUrl:\s*'([^']*)',\s*"
        r"audioUrl:\s*'([^']*)',\s*"
        r"lore:\s*'((?:[^'\\]|\\.)*)',\s*"
        r"habitat:\s*'([^']*)',\s*"
        r"conservationStatus:\s*'([^']*)',\s*"
        r"rarity:\s*'([^']*)',\s*"
        r"baseXp:\s*(\d+)",
        re.DOTALL,
    )

    birds = []
    for m in pattern.finditer(content):
        birds.append({
            "name": m.group(1),
            "scientific_name": m.group(2),
            "image_url": m.group(3),
            "audio_url": m.group(4),
            "lore": m.group(5).replace("\\'", "'"),
            "habitat": m.group(6),
            "conservation_status": m.group(7),
            "rarity": m.group(8),
            "base_xp": int(m.group(9)),
        })

    return birds


async def seed():
    dart_path = Path(__file__).resolve().parent.parent.parent / "aviquest" / "lib" / "main.dart"
    if not dart_path.exists():
        print(f"ERROR: Flutter source not found at {dart_path}")
        sys.exit(1)

    birds_data = parse_birds_from_dart(str(dart_path))
    print(f"Parsed {len(birds_data)} birds from Flutter source")

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with async_session() as db:
        # Check existing count
        result = await db.execute(select(Bird))
        existing = len(result.scalars().all())
        if existing > 0:
            print(f"Database already has {existing} birds. Skipping seed.")
            return

        for data in birds_data:
            db.add(Bird(**data))

        await db.commit()
        print(f"Seeded {len(birds_data)} birds into database")


if __name__ == "__main__":
    asyncio.run(seed())
