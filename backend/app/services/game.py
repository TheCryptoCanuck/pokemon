"""Game mechanics — mirrors the Flutter logic so server is authoritative."""

from math import pow

from app.core.config import settings


def xp_for_next_level(level: int) -> int:
    return round(settings.XP_LEVEL_BASE * pow(level, settings.XP_LEVEL_EXPONENT))


def level_title(level: int) -> str:
    if level < 3:
        return "Fledgling"
    if level < 6:
        return "Nestling"
    if level < 10:
        return "Sparrow"
    if level < 15:
        return "Warbler"
    if level < 20:
        return "Songweaver"
    if level < 30:
        return "Falconer"
    if level < 40:
        return "Eagle Scout"
    return "Master Birder"


def compute_level_and_xp(current_level: int, current_xp: int, gained_xp: int) -> tuple[int, int, list[int]]:
    """Apply XP gain and handle level-ups. Returns (new_level, new_xp, levels_gained)."""
    xp = current_xp + gained_xp
    level = current_level
    levels_gained: list[int] = []

    while xp >= xp_for_next_level(level):
        xp -= xp_for_next_level(level)
        level += 1
        levels_gained.append(level)

    return level, xp, levels_gained


def check_achievements(
    species_count: int,
    rarity: str,
    level: int,
    existing: set[str],
) -> list[str]:
    """Return list of newly unlocked achievement keys."""
    candidates: list[tuple[bool, str]] = [
        (species_count >= 1, "first_bird"),
        (species_count >= 5, "five_species"),
        (species_count >= 10, "ten_species"),
        (species_count >= 20, "twenty_species"),
        (rarity in ("rare", "legendary"), "rare_find"),
        (rarity == "legendary", "legendary_find"),
        (level >= 5, "level_5"),
        (level >= 10, "level_10"),
        (level >= 20, "level_20"),
    ]
    return [key for condition, key in candidates if condition and key not in existing]
