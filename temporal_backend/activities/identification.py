"""Activities for bird identification via image and audio analysis.

These activities wrap external service calls (ML inference, database lookups)
and are designed to be retried safely by Temporal on transient failures.
"""

from __future__ import annotations

from dataclasses import asdict

from temporalio import activity

from models.bird import Bird, Rarity, RARITY_XP

# Simulated bird database — in production this would query a real data store.
_BIRD_DB: dict[str, Bird] = {
    "american_robin": Bird(
        name="American Robin",
        scientific_name="Turdus migratorius",
        image_url="https://upload.wikimedia.org/wikipedia/commons/b/b8/Turdus-migratorius-002.jpg",
        audio_url="https://xeno-canto.org/sounds/uploaded/ZNCDXTUOFL/XC274155-American_Robin.mp3",
        habitat="Forests, gardens, parks",
        conservation_status="Least Concern",
        rarity=Rarity.COMMON,
        base_xp=50,
    ),
    "bald_eagle": Bird(
        name="Bald Eagle",
        scientific_name="Haliaeetus leucocephalus",
        image_url="https://upload.wikimedia.org/wikipedia/commons/1/1a/About_to_Launch_%2826075320352%29.jpg",
        audio_url="",
        habitat="Near large bodies of open water",
        conservation_status="Least Concern",
        rarity=Rarity.RARE,
        base_xp=300,
    ),
    "snowy_owl": Bird(
        name="Snowy Owl",
        scientific_name="Bubo scandiacus",
        image_url="https://upload.wikimedia.org/wikipedia/commons/f/fd/Snowy_Owl_-_Bubo_scandiacus.jpg",
        audio_url="",
        habitat="Arctic tundra, open fields",
        conservation_status="Vulnerable",
        rarity=Rarity.LEGENDARY,
        base_xp=750,
    ),
    "house_sparrow": Bird(
        name="House Sparrow",
        scientific_name="Passer domesticus",
        image_url="https://upload.wikimedia.org/wikipedia/commons/6/6e/Passer_domesticus_male_%2815%29.jpg",
        audio_url="",
        habitat="Urban areas, farmland",
        conservation_status="Least Concern",
        rarity=Rarity.COMMON,
        base_xp=50,
    ),
    "peregrine_falcon": Bird(
        name="Peregrine Falcon",
        scientific_name="Falco peregrinus",
        image_url="https://upload.wikimedia.org/wikipedia/commons/9/9a/Falco_peregrinus_good_-_Christopher_Watson.jpg",
        audio_url="",
        habitat="Cliffs, tall buildings, open country",
        conservation_status="Least Concern",
        rarity=Rarity.UNCOMMON,
        base_xp=120,
    ),
}


@activity.defn
async def analyze_image(image_data: str) -> dict:
    """Simulate ML-based image classification of a bird photo.

    In production, this would call an external ML service (e.g. a TensorFlow
    Serving endpoint or cloud Vision API). The activity is async because the
    external call is non-blocking I/O.

    Returns a dict with bird_key and confidence score.
    """
    activity.logger.info("Analyzing bird image (data length: %d)", len(image_data))
    activity.heartbeat("Starting image analysis")

    # Simulated inference — deterministic for testing.
    # Real implementation would POST image_data to an ML endpoint.
    if "eagle" in image_data.lower():
        return {"bird_key": "bald_eagle", "confidence": 0.92}
    if "owl" in image_data.lower():
        return {"bird_key": "snowy_owl", "confidence": 0.88}
    if "falcon" in image_data.lower():
        return {"bird_key": "peregrine_falcon", "confidence": 0.85}
    if "sparrow" in image_data.lower():
        return {"bird_key": "house_sparrow", "confidence": 0.90}

    # Default identification
    return {"bird_key": "american_robin", "confidence": 0.78}


@activity.defn
async def analyze_audio(audio_data: str) -> dict:
    """Simulate ML-based audio classification of a bird call recording.

    Returns a dict with bird_key and confidence score, or empty if
    audio analysis is inconclusive.
    """
    activity.logger.info("Analyzing bird audio (data length: %d)", len(audio_data))
    activity.heartbeat("Starting audio analysis")

    if not audio_data:
        return {"bird_key": "", "confidence": 0.0}

    # Simulated audio analysis
    if "eagle" in audio_data.lower():
        return {"bird_key": "bald_eagle", "confidence": 0.75}
    if "owl" in audio_data.lower():
        return {"bird_key": "snowy_owl", "confidence": 0.80}

    return {"bird_key": "american_robin", "confidence": 0.60}


@activity.defn
async def lookup_bird_details(bird_key: str) -> dict:
    """Look up full bird details from the database.

    Returns bird data as a dict, or an empty dict if the bird is not found.
    """
    activity.logger.info("Looking up bird details for key: %s", bird_key)

    bird = _BIRD_DB.get(bird_key)
    if bird is None:
        return {}

    result = asdict(bird)
    result["rarity"] = bird.rarity.value
    return result
