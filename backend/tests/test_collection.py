import pytest

from app.models.bird import Bird


async def _register_and_get_token(client) -> str:
    resp = await client.post(
        "/api/v1/auth/register",
        json={"username": "collector", "email": "col@test.com", "password": "secret123"},
    )
    return resp.json()["access_token"]


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


@pytest.mark.asyncio
async def test_profile(client):
    token = await _register_and_get_token(client)
    resp = await client.get("/api/v1/profile", headers=_auth(token))
    assert resp.status_code == 200
    data = resp.json()
    assert data["username"] == "collector"
    assert data["level"] == 1
    assert data["level_title"] == "Fledgling"
    assert data["species_collected"] == 0


@pytest.mark.asyncio
async def test_add_bird_to_collection(client, db):
    token = await _register_and_get_token(client)

    bird = Bird(name="Chickadee", scientific_name="Poecile", rarity="common", base_xp=50)
    db.add(bird)
    await db.commit()
    await db.refresh(bird)

    resp = await client.post(f"/api/v1/collection/{bird.id}", headers=_auth(token))
    assert resp.status_code == 201
    data = resp.json()
    assert data["bird_name"] == "Chickadee"
    assert data["xp_earned"] == 50
    assert "first_bird" in [a["key"] for a in data["new_achievements"]]


@pytest.mark.asyncio
async def test_collection_listing(client, db):
    token = await _register_and_get_token(client)

    bird = Bird(name="Owl", scientific_name="Strix", rarity="rare", base_xp=80)
    db.add(bird)
    await db.commit()
    await db.refresh(bird)

    await client.post(f"/api/v1/collection/{bird.id}", headers=_auth(token))

    resp = await client.get("/api/v1/collection", headers=_auth(token))
    assert resp.status_code == 200
    data = resp.json()
    assert data["total_species"] == 1
    assert data["birds"][0]["name"] == "Owl"


@pytest.mark.asyncio
async def test_achievements_listing(client):
    token = await _register_and_get_token(client)
    resp = await client.get("/api/v1/achievements", headers=_auth(token))
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) == 9  # All 9 achievements defined
    assert all(not a["unlocked"] for a in data)  # None unlocked yet


@pytest.mark.asyncio
async def test_encounter(client, db):
    token = await _register_and_get_token(client)

    # Need at least one bird in the DB for encounter
    db.add(Bird(name="Sparrow", scientific_name="Passer", rarity="common", base_xp=25))
    await db.commit()

    resp = await client.post("/api/v1/encounter", headers=_auth(token))
    assert resp.status_code == 200
    data = resp.json()
    assert "bird" in data
    assert "xp_earned" in data
    assert "is_new" in data
