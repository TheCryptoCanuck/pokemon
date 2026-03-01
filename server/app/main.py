"""AviQuest Bird Inference API — FastAPI application."""

from __future__ import annotations

import time
import uuid
from contextlib import asynccontextmanager

from fastapi import FastAPI, File, Request, UploadFile
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from app import config
from app.models import (
    predict_audio_real,
    predict_audio_stub,
    predict_image_real,
    predict_image_stub,
)
from app.schemas import ErrorDetail, ErrorResponse, InferenceResponse


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _request_id() -> str:
    return str(uuid.uuid4())


def _error(code: int, error_type: str, message: str, request_id: str) -> JSONResponse:
    body = ErrorResponse(
        error=ErrorDetail(code=code, type=error_type, message=message),
        requestId=request_id,
    )
    return JSONResponse(status_code=code, content=body.model_dump())


def _check_api_key(request: Request, request_id: str) -> JSONResponse | None:
    """Return an error response if auth is enabled and key is invalid."""
    if not config.API_KEY:
        return None
    key = request.headers.get("X-API-Key", "")
    if key != config.API_KEY:
        return _error(401, "UNAUTHORIZED", "Missing or invalid API key.", request_id)
    return None


# ---------------------------------------------------------------------------
# App lifecycle
# ---------------------------------------------------------------------------

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: load real model weights here in the future.
    yield
    # Shutdown: release resources.


app = FastAPI(
    title="AviQuest Bird Inference API",
    version=config.MODEL_VERSION,
    lifespan=lifespan,
)


# ---------------------------------------------------------------------------
# Global exception handlers
# ---------------------------------------------------------------------------

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    # Build a clean message from validation errors without leaking server paths.
    details = exc.errors()
    parts = []
    for err in details:
        loc = " -> ".join(str(l) for l in err.get("loc", []))
        parts.append(f"{loc}: {err.get('msg', 'invalid')}")
    message = "; ".join(parts) if parts else "Invalid request."
    return _error(400, "INVALID_REQUEST", message, _request_id())


@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception):
    return _error(500, "INTERNAL_ERROR", "An unexpected error occurred.", _request_id())


# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------

@app.get("/health")
async def health():
    return {"status": "ok", "modelMode": config.MODEL_MODE, "modelVersion": config.MODEL_VERSION}


# ---------------------------------------------------------------------------
# POST /infer/image
# ---------------------------------------------------------------------------

@app.post("/infer/image", response_model=InferenceResponse)
async def infer_image(request: Request, file: UploadFile = File(...)):
    rid = _request_id()

    # Auth
    auth_err = _check_api_key(request, rid)
    if auth_err:
        return auth_err

    # Content-type validation
    ct = file.content_type or ""
    if ct not in config.ALLOWED_IMAGE_TYPES:
        return _error(
            400,
            "INVALID_REQUEST",
            f"Unsupported image type '{ct}'. Allowed: {', '.join(sorted(config.ALLOWED_IMAGE_TYPES))}",
            rid,
        )

    # Read + size check
    data = await file.read()
    if len(data) > config.MAX_IMAGE_BYTES:
        return _error(
            413,
            "PAYLOAD_TOO_LARGE",
            f"Image exceeds maximum size of {config.MAX_IMAGE_BYTES // (1024 * 1024)} MB.",
            rid,
        )

    # Inference
    start = time.monotonic()
    try:
        if config.MODEL_MODE == "stub":
            predictions = predict_image_stub(data)
        else:
            predictions = predict_image_real(data)
    except Exception as exc:
        return _error(500, "INTERNAL_ERROR", f"Model inference failed: {exc}", rid)
    latency = (time.monotonic() - start) * 1000

    return InferenceResponse(
        requestId=rid,
        modelVersion=config.MODEL_VERSION,
        latencyMs=round(latency, 2),
        predictions=predictions,
    )


# ---------------------------------------------------------------------------
# POST /infer/audio
# ---------------------------------------------------------------------------

@app.post("/infer/audio", response_model=InferenceResponse)
async def infer_audio(request: Request, file: UploadFile = File(...)):
    rid = _request_id()

    # Auth
    auth_err = _check_api_key(request, rid)
    if auth_err:
        return auth_err

    # Content-type validation
    ct = file.content_type or ""
    if ct not in config.ALLOWED_AUDIO_TYPES:
        return _error(
            400,
            "INVALID_REQUEST",
            f"Unsupported audio type '{ct}'. Allowed: {', '.join(sorted(config.ALLOWED_AUDIO_TYPES))}",
            rid,
        )

    # Read + size check
    data = await file.read()
    if len(data) > config.MAX_AUDIO_BYTES:
        return _error(
            413,
            "PAYLOAD_TOO_LARGE",
            f"Audio exceeds maximum size of {config.MAX_AUDIO_BYTES // (1024 * 1024)} MB.",
            rid,
        )

    # Inference
    start = time.monotonic()
    try:
        if config.MODEL_MODE == "stub":
            predictions = predict_audio_stub(data)
        else:
            predictions = predict_audio_real(data)
    except Exception as exc:
        return _error(500, "INTERNAL_ERROR", f"Model inference failed: {exc}", rid)
    latency = (time.monotonic() - start) * 1000

    return InferenceResponse(
        requestId=rid,
        modelVersion=config.MODEL_VERSION,
        latencyMs=round(latency, 2),
        predictions=predictions,
    )
