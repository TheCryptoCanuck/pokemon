"""Activities for achievement checking, unlocking, and notifications.

Achievement logic evaluates user state against the achievement registry
and unlocks newly-earned achievements. Designed for idempotent execution.
"""

from __future__ import annotations

from dataclasses import asdict

from temporalio import activity

from models.achievement import (
    ACHIEVEMENT_REGISTRY,
    AchievementType,
    AchievementUnlock,
)
from models.user import UserProfile, UserStats


def _profile_from_dict(data: dict) -> UserProfile:
    stats_data = data.get("stats", {})
    return UserProfile(
        user_id=data["user_id"],
        display_name=data["display_name"],
        stats=UserStats(
            level=stats_data.get("level", 1),
            xp=stats_data.get("xp", 0),
            streak=stats_data.get("streak", 0),
            total_identifications=stats_data.get("total_identifications", 0),
            species_collected=stats_data.get("species_collected", 0),
        ),
        collected_species=data.get("collected_species", []),
        unlocked_achievements=data.get("unlocked_achievements", []),
    )


@activity.defn
async def check_achievements(
    profile_dict: dict, bird_rarity: str
) -> list[dict]:
    """Evaluate which new achievements the user has earned.

    Compares current user state against the achievement registry and returns
    a list of newly-unlocked achievement dicts. Already-unlocked achievements
    are skipped (idempotent).
    """
    activity.logger.info(
        "Checking achievements for user: %s", profile_dict.get("user_id")
    )

    profile = _profile_from_dict(profile_dict)
    already_unlocked = set(profile.unlocked_achievements)
    new_unlocks: list[dict] = []

    for achievement in ACHIEVEMENT_REGISTRY:
        if achievement.key in already_unlocked:
            continue

        earned = False

        if achievement.achievement_type == AchievementType.COLLECTION_MILESTONE:
            earned = profile.stats.species_collected >= achievement.threshold

        elif achievement.achievement_type == AchievementType.RARITY_FIND:
            if achievement.key == "rare_find":
                earned = bird_rarity in ("rare", "legendary")
            elif achievement.key == "legendary_find":
                earned = bird_rarity == "legendary"

        elif achievement.achievement_type == AchievementType.LEVEL_MILESTONE:
            earned = profile.stats.level >= achievement.threshold

        elif achievement.achievement_type == AchievementType.STREAK_MILESTONE:
            earned = profile.stats.streak >= achievement.threshold

        if earned:
            unlock = AchievementUnlock(
                user_id=profile.user_id,
                achievement_key=achievement.key,
                achievement_name=achievement.name,
                xp_reward=achievement.xp_reward,
            )
            new_unlocks.append(asdict(unlock))

    return new_unlocks


@activity.defn
async def unlock_achievement(user_id: str, achievement_key: str) -> bool:
    """Record an achievement as unlocked for the user.

    Idempotent — re-unlocking an already-unlocked achievement is a no-op.
    """
    activity.logger.info(
        "Unlocking achievement '%s' for user: %s", achievement_key, user_id
    )

    from activities.user import _USER_STORE

    data = _USER_STORE.get(user_id, {})
    if not data:
        return False

    unlocked = data.get("unlocked_achievements", [])
    if achievement_key not in unlocked:
        unlocked.append(achievement_key)
        data["unlocked_achievements"] = unlocked
        _USER_STORE[user_id] = data

    return True


@activity.defn
async def send_achievement_notification(
    user_id: str, achievement_name: str
) -> bool:
    """Send a push notification for a newly unlocked achievement.

    In production, this would integrate with FCM/APNs.
    """
    activity.logger.info(
        "Sending achievement notification to user %s: %s",
        user_id,
        achievement_name,
    )
    # Simulated push notification delivery
    return True
