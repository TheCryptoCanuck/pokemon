import pytest

from app.models.bird import Bird


@pytest.mark.asyncio
async def test_list_birds_empty(client):
    resp = await client.get("/api/v1/birds")
    assert resp.status_code == 200
    data = resp.json()
    assert data["birds"] == []
    assert data["total"] == 0


@pytest.mark.asyncio
async def test_list_birds_with_data(client, db):
    db.add(Bird(
        name="Test Robin",
        scientific_name="Turdus test",
        rarity="common",
        base_xp=40,
    ))
    await db.commit()

    resp = await client.get("/api/v1/birds")
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 1
    assert data["birds"][0]["name"] == "Test Robin"
    assert data["birds"][0]["xp"] == 40


@pytest.mark.asyncio
async def test_search_birds(client, db):
    db.add(Bird(name="Blue Jay", scientific_name="Cyanocitta cristata", rarity="uncommon", base_xp=60))
    db.add(Bird(name="Red Cardinal", scientific_name="Cardinalis cardinalis", rarity="common", base_xp=45))
    await db.commit()

    resp = await client.get("/api/v1/birds?search=blue")
    data = resp.json()
    assert data["total"] == 1
    assert data["birds"][0]["name"] == "Blue Jay"


@pytest.mark.asyncio
async def test_filter_birds_by_rarity(client, db):
    db.add(Bird(name="Common Bird", scientific_name="Test common", rarity="common", base_xp=30))
    db.add(Bird(name="Rare Bird", scientific_name="Test rare", rarity="rare", base_xp=80))
    await db.commit()

    resp = await client.get("/api/v1/birds?rarity=rare")
    data = resp.json()
    assert data["total"] == 1
    assert data["birds"][0]["name"] == "Rare Bird"
    assert data["birds"][0]["xp"] == 160  # rare = 2x multiplier


@pytest.mark.asyncio
async def test_get_bird_by_id(client, db):
    bird = Bird(name="Eagle", scientific_name="Aquila chrysaetos", rarity="legendary", base_xp=100)
    db.add(bird)
    await db.commit()
    await db.refresh(bird)

    resp = await client.get(f"/api/v1/birds/{bird.id}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["name"] == "Eagle"
    assert data["xp"] == 500  # legendary = 5x


@pytest.mark.asyncio
async def test_get_bird_not_found(client):
    resp = await client.get("/api/v1/birds/99999")
    assert resp.status_code == 404
