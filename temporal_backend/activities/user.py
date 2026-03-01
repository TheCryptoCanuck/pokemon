"""Activities for user profile management and progression.

These activities handle persistent state operations (database reads/writes)
and are designed to be idempotent for safe Temporal retries.
"""

from __future__ import annotations

from dataclasses import asdict

from temporalio import activity

from models.user import UserProfile, UserStats

# In-memory store for demonstration. Production would use a real database.
_USER_STORE: dict[str, dict] = {}


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
async def get_user_profile(user_id: str) -> dict:
    """Retrieve user profile from the data store.

    Returns the profile as a dict, or an empty dict if user not found.
    """
    activity.logger.info("Fetching profile for user: %s", user_id)
    return _USER_STORE.get(user_id, {})


@activity.defn
async def save_user_profile(profile_dict: dict) -> bool:
    """Persist user profile to the data store.

    This is idempotent — saving the same profile twice produces the same result.
    """
    user_id = profile_dict.get("user_id", "")
    if not user_id:
        return False

    activity.logger.info("Saving profile for user: %s", user_id)
    _USER_STORE[user_id] = profile_dict
    return True


@activity.defn
async def add_species_to_collection(user_id: str, bird_name: str) -> dict:
    """Add a bird species to the user's collection.

    Returns updated profile dict. Idempotent — adding the same species
    twice does not duplicate it.
    """
    activity.logger.info(
        "Adding species '%s' to collection for user: %s", bird_name, user_id
    )

    data = _USER_STORE.get(user_id, {})
    if not data:
        return {}

    profile = _profile_from_dict(data)
    is_new = bird_name not in profile.collected_species

    if is_new:
        profile.collected_species.append(bird_name)
        profile.stats.species_collected = len(profile.collected_species)

    profile.stats.total_identifications += 1

    result = asdict(profile)
    _USER_STORE[user_id] = result
    return {**result, "is_new_species": is_new}


@activity.defn
async def award_xp(user_id: str, xp_amount: int) -> dict:
    """Award XP to a user and handle level-ups.

    Returns a dict with xp_awarded, new_level, and leveled_up fields.
    """
    activity.logger.info("Awarding %d XP to user: %s", xp_amount, user_id)

    data = _USER_STORE.get(user_id, {})
    if not data:
        return {"xp_awarded": 0, "new_level": 0, "leveled_up": False}

    profile = _profile_from_dict(data)
    old_level = profile.stats.level
    profile.stats.xp += xp_amount

    # Check for level-ups
    while profile.stats.xp >= profile.stats.xp_for_next_level():
        profile.stats.xp -= profile.stats.xp_for_next_level()
        profile.stats.level += 1

    _USER_STORE[user_id] = asdict(profile)

    return {
        "xp_awarded": xp_amount,
        "new_level": profile.stats.level,
        "leveled_up": profile.stats.level > old_level,
    }


@activity.defn
async def update_streak(user_id: str) -> dict:
    """Update the user's daily identification streak.

    Returns a dict with the current streak count and whether it increased.
    """
    activity.logger.info("Updating streak for user: %s", user_id)

    data = _USER_STORE.get(user_id, {})
    if not data:
        return {"streak": 0, "increased": False}

    profile = _profile_from_dict(data)
    old_streak = profile.stats.streak
    profile.stats.streak += 1

    _USER_STORE[user_id] = asdict(profile)

    return {"streak": profile.stats.streak, "increased": True}
