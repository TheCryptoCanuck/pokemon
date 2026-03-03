"""Server configuration loaded from environment variables."""

import os


# Model mode: "stub" returns deterministic fake predictions; "real" would load a model.
MODEL_MODE: str = os.getenv("MODEL_MODE", "stub")

# Optional API key authentication.  Set to enable; leave empty to disable.
API_KEY: str = os.getenv("API_KEY", "")

# Upload size limits (bytes).
MAX_IMAGE_BYTES: int = int(os.getenv("MAX_IMAGE_BYTES", str(10 * 1024 * 1024)))   # 10 MB
MAX_AUDIO_BYTES: int = int(os.getenv("MAX_AUDIO_BYTES", str(25 * 1024 * 1024)))   # 25 MB

# Request timeout (seconds) — enforced at the ASGI layer by uvicorn's --timeout-keep-alive.
REQUEST_TIMEOUT_S: int = int(os.getenv("REQUEST_TIMEOUT_S", "30"))

# Allowed MIME types.
ALLOWED_IMAGE_TYPES: set[str] = {"image/jpeg", "image/png", "image/webp"}
ALLOWED_AUDIO_TYPES: set[str] = {
    "audio/wav", "audio/x-wav", "audio/mpeg", "audio/mp3",
    "audio/flac", "audio/ogg", "audio/x-flac",
}

MODEL_VERSION: str = os.getenv("MODEL_VERSION", "aviquest-v1.0.0-stub")

# Server host/port.
HOST: str = os.getenv("HOST", "0.0.0.0")
PORT: int = int(os.getenv("PORT", "8000"))
