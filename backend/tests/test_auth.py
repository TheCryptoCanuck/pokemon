import pytest


@pytest.mark.asyncio
async def test_register_and_login(client):
    # Register
    resp = await client.post(
        "/api/v1/auth/register",
        json={"username": "birder1", "email": "birder@test.com", "password": "secret123"},
    )
    assert resp.status_code == 201
    data = resp.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"

    # Login
    resp = await client.post(
        "/api/v1/auth/login",
        json={"email": "birder@test.com", "password": "secret123"},
    )
    assert resp.status_code == 200
    assert "access_token" in resp.json()


@pytest.mark.asyncio
async def test_register_duplicate(client):
    await client.post(
        "/api/v1/auth/register",
        json={"username": "dup", "email": "dup@test.com", "password": "secret123"},
    )
    resp = await client.post(
        "/api/v1/auth/register",
        json={"username": "dup", "email": "dup@test.com", "password": "secret123"},
    )
    assert resp.status_code == 409


@pytest.mark.asyncio
async def test_login_wrong_password(client):
    await client.post(
        "/api/v1/auth/register",
        json={"username": "wrong", "email": "wrong@test.com", "password": "secret123"},
    )
    resp = await client.post(
        "/api/v1/auth/login",
        json={"email": "wrong@test.com", "password": "badpass"},
    )
    assert resp.status_code == 401
