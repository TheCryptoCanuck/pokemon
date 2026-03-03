"""Activities for daily challenge generation, progress tracking, and rewards.

Daily challenges provide engagement incentives. Each activity is idempotent
to support safe Temporal retries.
"""

from __future__ import annotations

from dataclasses import asdict

from temporalio import activity

from models.daily_challenge import (
    ChallengeProgress,
    ChallengeType,
    DailyChallenge,
)

# In-memory stores for demonstration
_CHALLENGE_STORE: dict[str, dict] = {}  # challenge_id -> challenge
_PROGRESS_STORE: dict[str, dict] = {}  # "{user_id}:{challenge_id}" -> progress


_CHALLENGE_TEMPLATES: list[dict] = [
    {
        "type": ChallengeType.IDENTIFY_COUNT,
        "description": "Identify {target} birds today",
        "target": 3,
        "xp_reward": 200,
    },
    {
        "type": ChallengeType.IDENTIFY_COUNT,
        "description": "Identify {target} birds today",
        "target": 5,
        "xp_reward": 400,
    },
    {
        "type": ChallengeType.IDENTIFY_RARITY,
        "description": "Identify an uncommon or rarer bird",
        "target": 1,
        "xp_reward": 300,
    },
    {
        "type": ChallengeType.HABITAT_EXPLORER,
        "description": "Identify birds from {target} different habitats",
        "target": 2,
        "xp_reward": 350,
    },
]


@activity.defn
async def generate_daily_challenge(date_str: str) -> dict:
    """Generate (or retrieve) the daily challenge for a given date.

    Deterministic per date — calling multiple times for the same date returns
    the same challenge (idempotent).
    """
    activity.logger.info("Generating daily challenge for: %s", date_str)

    challenge_id = f"daily-{date_str}"

    # Return existing challenge if already generated
    if challenge_id in _CHALLENGE_STORE:
        return _CHALLENGE_STORE[challenge_id]

    # Select template based on date hash for determinism
    idx = hash(date_str) % len(_CHALLENGE_TEMPLATES)
    template = _CHALLENGE_TEMPLATES[idx]

    challenge = DailyChallenge(
        challenge_id=challenge_id,
        challenge_type=template["type"],
        description=template["description"].format(target=template["target"]),
        target=template["target"],
        xp_reward=template["xp_reward"],
        date=date_str,
    )

    result = asdict(challenge)
    _CHALLENGE_STORE[challenge_id] = result
    return result


@activity.defn
async def update_challenge_progress(
    user_id: str, challenge_id: str, increment: int
) -> dict:
    """Update a user's progress toward a daily challenge.

    Returns updated progress dict with current count and completion status.
    """
    activity.logger.info(
        "Updating challenge progress for user %s, challenge %s (+%d)",
        user_id,
        challenge_id,
        increment,
    )

    progress_key = f"{user_id}:{challenge_id}"
    challenge = _CHALLENGE_STORE.get(challenge_id, {})
    target = challenge.get("target", 1)

    existing = _PROGRESS_STORE.get(progress_key)
    if existing and existing.get("completed"):
        return existing

    progress = ChallengeProgress(
        challenge_id=challenge_id,
        user_id=user_id,
        current=(existing or {}).get("current", 0) + increment,
    )
    progress.completed = progress.current >= target

    result = asdict(progress)
    _PROGRESS_STORE[progress_key] = result
    return result


@activity.defn
async def award_challenge_reward(user_id: str, xp_reward: int) -> bool:
    """Award the daily challenge completion reward.

    Delegates to the XP awarding logic. In production, this would also
    log the reward event for analytics.
    """
    activity.logger.info(
        "Awarding challenge reward of %d XP to user: %s", xp_reward, user_id
    )
    # In production, this would call award_xp or a dedicated reward service
    return True
