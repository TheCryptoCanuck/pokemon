"""Unit tests for game mechanics service."""

from app.services.game import (
    check_achievements,
    compute_level_and_xp,
    level_title,
    xp_for_next_level,
)


def test_xp_for_next_level():
    assert xp_for_next_level(1) == 1000  # 1000 * 1^1.4 = 1000
    assert xp_for_next_level(2) == 2639  # 1000 * 2^1.4 ≈ 2639
    assert xp_for_next_level(5) == 9518  # 1000 * 5^1.4 ≈ 9518


def test_level_title():
    assert level_title(1) == "Fledgling"
    assert level_title(5) == "Nestling"
    assert level_title(10) == "Warbler"
    assert level_title(19) == "Songweaver"
    assert level_title(20) == "Falconer"
    assert level_title(40) == "Master Birder"


def test_compute_level_and_xp_no_levelup():
    level, xp, gained = compute_level_and_xp(1, 0, 500)
    assert level == 1
    assert xp == 500
    assert gained == []


def test_compute_level_and_xp_with_levelup():
    level, xp, gained = compute_level_and_xp(1, 900, 200)
    # 900 + 200 = 1100, need 1000 for level 1 -> level 2
    assert level == 2
    assert xp == 100
    assert gained == [2]


def test_check_achievements_first_bird():
    new = check_achievements(species_count=1, rarity="common", level=1, existing=set())
    assert "first_bird" in new


def test_check_achievements_legendary():
    new = check_achievements(species_count=1, rarity="legendary", level=1, existing=set())
    assert "rare_find" in new
    assert "legendary_find" in new


def test_check_achievements_no_duplicates():
    existing = {"first_bird", "rare_find"}
    new = check_achievements(species_count=1, rarity="rare", level=1, existing=existing)
    assert "first_bird" not in new
    assert "rare_find" not in new
