"""Tests for the AviQuest inference API."""

import pytest


# ------------------------------------------------------------------
# Health
# ------------------------------------------------------------------

@pytest.mark.asyncio
async def test_health(client):
    resp = await client.get("/health")
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "ok"
    assert body["modelMode"] == "stub"


# ------------------------------------------------------------------
# Image inference — happy path
# ------------------------------------------------------------------

@pytest.mark.asyncio
async def test_infer_image_stub(client):
    # 1x1 white JPEG (smallest valid JPEG).
    jpeg_bytes = (
        b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00"
        b"\xff\xdb\x00C\x00\x08\x06\x06\x07\x06\x05\x08\x07\x07\x07\t\t"
        b"\x08\n\x0c\x14\r\x0c\x0b\x0b\x0c\x19\x12\x13\x0f\x14\x1d\x1a"
        b"\x1f\x1e\x1d\x1a\x1c\x1c $.\' \",#\x1c\x1c(7),01444\x1f\'9=82<.342"
        b"\xff\xc0\x00\x0b\x08\x00\x01\x00\x01\x01\x01\x11\x00"
        b"\xff\xc4\x00\x1f\x00\x00\x01\x05\x01\x01\x01\x01\x01\x01\x00"
        b"\x00\x00\x00\x00\x00\x00\x00\x01\x02\x03\x04\x05\x06\x07\x08\t\n\x0b"
        b"\xff\xc4\x00\xb5\x10\x00\x02\x01\x03\x03\x02\x04\x03\x05\x05\x04"
        b"\x04\x00\x00\x01}\x01\x02\x03\x00\x04\x11\x05\x12!1A\x06\x13Qa\x07"
        b"\x22q\x142\x81\x91\xa1\x08#B\xb1\xc1\x15R\xd1\xf0$3br\x82\t\n\x16"
        b"\x17\x18\x19\x1a%&\'()*456789:CDEFGHIJSTUVWXYZcdefghijstuvwxyz"
        b"\x83\x84\x85\x86\x87\x88\x89\x8a\x92\x93\x94\x95\x96\x97\x98\x99"
        b"\x9a\xa2\xa3\xa4\xa5\xa6\xa7\xa8\xa9\xaa\xb2\xb3\xb4\xb5\xb6\xb7"
        b"\xb8\xb9\xba\xc2\xc3\xc4\xc5\xc6\xc7\xc8\xc9\xca\xd2\xd3\xd4\xd5"
        b"\xd6\xd7\xd8\xd9\xda\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xf1"
        b"\xf2\xf3\xf4\xf5\xf6\xf7\xf8\xf9\xfa"
        b"\xff\xda\x00\x08\x01\x01\x00\x00?\x00T\xdb\xc1\xa4 \xa5\x03\xff\xd9"
    )
    resp = await client.post(
        "/infer/image",
        files={"file": ("bird.jpg", jpeg_bytes, "image/jpeg")},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["requestId"]
    assert body["modelVersion"] == "aviquest-v1.0.0-stub"
    assert isinstance(body["latencyMs"], (int, float))
    preds = body["predictions"]
    assert len(preds) == 3
    assert preds[0]["label"] == "Black-capped Chickadee"
    assert preds[0]["confidence"] == 0.91


# ------------------------------------------------------------------
# Audio inference — happy path
# ------------------------------------------------------------------

@pytest.mark.asyncio
async def test_infer_audio_stub(client):
    # Minimal WAV header (44 bytes) — enough to pass content-type check.
    wav_bytes = (
        b"RIFF$\x00\x00\x00WAVEfmt \x10\x00\x00\x00"
        b"\x01\x00\x01\x00\x44\xac\x00\x00\x88X\x01\x00"
        b"\x02\x00\x10\x00data\x00\x00\x00\x00"
    )
    resp = await client.post(
        "/infer/audio",
        files={"file": ("bird.wav", wav_bytes, "audio/wav")},
    )
    assert resp.status_code == 200
    body = resp.json()
    preds = body["predictions"]
    assert len(preds) == 3
    assert preds[0]["label"] == "American Robin"
    assert preds[0]["confidence"] == 0.85


# ------------------------------------------------------------------
# Error: unsupported content type
# ------------------------------------------------------------------

@pytest.mark.asyncio
async def test_infer_image_bad_content_type(client):
    resp = await client.post(
        "/infer/image",
        files={"file": ("doc.pdf", b"%PDF-1.4", "application/pdf")},
    )
    assert resp.status_code == 400
    body = resp.json()
    assert body["error"]["type"] == "INVALID_REQUEST"
    assert body["requestId"]


@pytest.mark.asyncio
async def test_infer_audio_bad_content_type(client):
    resp = await client.post(
        "/infer/audio",
        files={"file": ("song.mp4", b"\x00\x00", "video/mp4")},
    )
    assert resp.status_code == 400
    assert resp.json()["error"]["type"] == "INVALID_REQUEST"


# ------------------------------------------------------------------
# Error: payload too large
# ------------------------------------------------------------------

@pytest.mark.asyncio
async def test_infer_image_too_large(client):
    from app import config
    old_max = config.MAX_IMAGE_BYTES
    config.MAX_IMAGE_BYTES = 100  # 100 bytes

    try:
        resp = await client.post(
            "/infer/image",
            files={"file": ("big.jpg", b"\xff" * 200, "image/jpeg")},
        )
        assert resp.status_code == 413
        assert resp.json()["error"]["type"] == "PAYLOAD_TOO_LARGE"
    finally:
        config.MAX_IMAGE_BYTES = old_max


@pytest.mark.asyncio
async def test_infer_audio_too_large(client):
    from app import config
    old_max = config.MAX_AUDIO_BYTES
    config.MAX_AUDIO_BYTES = 100

    try:
        resp = await client.post(
            "/infer/audio",
            files={"file": ("big.wav", b"\x00" * 200, "audio/wav")},
        )
        assert resp.status_code == 413
        assert resp.json()["error"]["type"] == "PAYLOAD_TOO_LARGE"
    finally:
        config.MAX_AUDIO_BYTES = old_max


# ------------------------------------------------------------------
# Error: missing file
# ------------------------------------------------------------------

@pytest.mark.asyncio
async def test_infer_image_missing_file(client):
    resp = await client.post("/infer/image")
    assert resp.status_code == 400
    assert resp.json()["error"]["type"] == "INVALID_REQUEST"


# ------------------------------------------------------------------
# Error: unauthorized (when API_KEY is set)
# ------------------------------------------------------------------

@pytest.mark.asyncio
async def test_infer_image_unauthorized(client):
    from app import config
    old_key = config.API_KEY
    config.API_KEY = "secret-key-123"

    try:
        # No key
        resp = await client.post(
            "/infer/image",
            files={"file": ("bird.jpg", b"\xff\xd8\xff", "image/jpeg")},
        )
        assert resp.status_code == 401
        assert resp.json()["error"]["type"] == "UNAUTHORIZED"

        # Wrong key
        resp = await client.post(
            "/infer/image",
            files={"file": ("bird.jpg", b"\xff\xd8\xff", "image/jpeg")},
            headers={"X-API-Key": "wrong-key"},
        )
        assert resp.status_code == 401

        # Correct key
        resp = await client.post(
            "/infer/image",
            files={"file": ("bird.jpg", b"\xff\xd8\xff", "image/jpeg")},
            headers={"X-API-Key": "secret-key-123"},
        )
        assert resp.status_code == 200
    finally:
        config.API_KEY = old_key


# ------------------------------------------------------------------
# Error: real model not loaded (500)
# ------------------------------------------------------------------

@pytest.mark.asyncio
async def test_infer_image_real_model_not_loaded(client):
    from app import config
    old_mode = config.MODEL_MODE
    config.MODEL_MODE = "real"

    try:
        resp = await client.post(
            "/infer/image",
            files={"file": ("bird.jpg", b"\xff\xd8\xff", "image/jpeg")},
        )
        assert resp.status_code == 500
        assert resp.json()["error"]["type"] == "INTERNAL_ERROR"
    finally:
        config.MODEL_MODE = old_mode


# ------------------------------------------------------------------
# Error: unauthorized on audio endpoint
# ------------------------------------------------------------------

@pytest.mark.asyncio
async def test_infer_audio_unauthorized(client):
    from app import config
    old_key = config.API_KEY
    config.API_KEY = "audio-secret"

    try:
        resp = await client.post(
            "/infer/audio",
            files={"file": ("bird.wav", b"\x00" * 44, "audio/wav")},
        )
        assert resp.status_code == 401
        assert resp.json()["error"]["type"] == "UNAUTHORIZED"

        resp = await client.post(
            "/infer/audio",
            files={"file": ("bird.wav", b"\x00" * 44, "audio/wav")},
            headers={"X-API-Key": "audio-secret"},
        )
        assert resp.status_code == 200
    finally:
        config.API_KEY = old_key


# ------------------------------------------------------------------
# Error: real model not loaded on audio endpoint (500)
# ------------------------------------------------------------------

@pytest.mark.asyncio
async def test_infer_audio_real_model_not_loaded(client):
    from app import config
    old_mode = config.MODEL_MODE
    config.MODEL_MODE = "real"

    try:
        resp = await client.post(
            "/infer/audio",
            files={"file": ("bird.wav", b"\x00" * 44, "audio/wav")},
        )
        assert resp.status_code == 500
        assert resp.json()["error"]["type"] == "INTERNAL_ERROR"
    finally:
        config.MODEL_MODE = old_mode


# ------------------------------------------------------------------
# Error: missing file on audio endpoint
# ------------------------------------------------------------------

@pytest.mark.asyncio
async def test_infer_audio_missing_file(client):
    resp = await client.post("/infer/audio")
    assert resp.status_code == 400
    assert resp.json()["error"]["type"] == "INVALID_REQUEST"
