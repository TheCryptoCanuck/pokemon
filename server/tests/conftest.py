"""Shared test fixtures."""

import os

import pytest
from httpx import ASGITransport, AsyncClient

# Force stub mode for tests.
os.environ["MODEL_MODE"] = "stub"
os.environ["API_KEY"] = ""

from app.main import app  # noqa: E402


@pytest.fixture
async def client():
    """Async HTTP client wired to the FastAPI app."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c
