"""Bird inference models — stub and real (placeholder)."""

from __future__ import annotations

from app.schemas import Prediction


# ---------------------------------------------------------------------------
# Stub model — deterministic outputs for testing
# ---------------------------------------------------------------------------

_STUB_IMAGE_PREDICTIONS: list[Prediction] = [
    Prediction(label="Black-capped Chickadee", confidence=0.91),
    Prediction(label="Carolina Chickadee", confidence=0.06),
    Prediction(label="Mountain Chickadee", confidence=0.02),
]

_STUB_AUDIO_PREDICTIONS: list[Prediction] = [
    Prediction(label="American Robin", confidence=0.85),
    Prediction(label="Hermit Thrush", confidence=0.09),
    Prediction(label="Wood Thrush", confidence=0.04),
]


def predict_image_stub(image_bytes: bytes) -> list[Prediction]:
    """Return fixed top-3 predictions regardless of input."""
    return _STUB_IMAGE_PREDICTIONS


def predict_audio_stub(audio_bytes: bytes) -> list[Prediction]:
    """Return fixed top-3 predictions regardless of input."""
    return _STUB_AUDIO_PREDICTIONS


# ---------------------------------------------------------------------------
# Real model placeholder — swap in actual ML inference here
# ---------------------------------------------------------------------------

def predict_image_real(image_bytes: bytes) -> list[Prediction]:
    raise NotImplementedError(
        "Real image model not loaded. Set MODEL_MODE=stub for testing."
    )


def predict_audio_real(audio_bytes: bytes) -> list[Prediction]:
    raise NotImplementedError(
        "Real audio model not loaded. Set MODEL_MODE=stub for testing."
    )
