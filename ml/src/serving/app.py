"""FastAPI model serving application for bird classification.

Production-ready API with health checks, batched inference, caching,
monitoring, and A/B testing support.
"""

from __future__ import annotations

import logging
import time
import uuid
from contextlib import asynccontextmanager
from pathlib import Path

import torch
import yaml
from fastapi import FastAPI, File, HTTPException, Query, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from src.features.feature_store import InMemoryFeatureStore
from src.features.preprocessing import ImagePreprocessor, PreprocessingConfig
from src.models.bird_classifier import BirdClassifier, ModelConfig
from src.monitoring.metrics_collector import MetricsCollector
from src.serving.middleware import LatencyMiddleware, RateLimitMiddleware, RequestIdMiddleware
from src.serving.schemas import (
    HealthResponse,
    ModelInfoResponse,
    PredictionResponse,
    PredictionResult,
)

logger = logging.getLogger(__name__)

# Global state
_model: BirdClassifier | None = None
_preprocessor: ImagePreprocessor | None = None
_feature_store: InMemoryFeatureStore | None = None
_metrics: MetricsCollector | None = None
_model_version: str = "unknown"
_start_time: float = 0.0
_device: torch.device = torch.device("cpu")


def _load_config(config_path: str = "config/serving_config.yaml") -> dict:
    """Load serving configuration from YAML."""
    path = Path(config_path)
    if path.exists():
        with open(path) as f:
            return yaml.safe_load(f)
    return {}


def _select_device(device_config: str) -> torch.device:
    """Select the best available device."""
    if device_config == "auto":
        if torch.cuda.is_available():
            return torch.device("cuda")
        if hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
            return torch.device("mps")
        return torch.device("cpu")
    return torch.device(device_config)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler — loads model on startup."""
    global _model, _preprocessor, _feature_store, _metrics
    global _model_version, _start_time, _device

    config = _load_config()
    inference_cfg = config.get("inference", {})
    _start_time = time.time()

    # Select device
    _device = _select_device(inference_cfg.get("device", "auto"))
    logger.info("Using device: %s", _device)

    # Load model
    model_path = inference_cfg.get("model_path", "models/bird_classifier_v1.pt")
    compile_model = inference_cfg.get("compile_model", False)

    if Path(model_path).exists():
        _model = BirdClassifier.load(model_path, device=_device, compile_model=compile_model)
        _model_version = Path(model_path).stem
        logger.info("Model loaded: %s", model_path)

        # Warmup with dummy inputs
        warmup_count = config.get("health", {}).get("model_warmup_requests", 3)
        dummy = torch.randn(1, 3, _model.config.image_size, _model.config.image_size).to(_device)
        for _ in range(warmup_count):
            _model(dummy)
        logger.info("Model warmup complete (%d requests)", warmup_count)
    else:
        logger.warning("Model not found at %s — serving will return errors", model_path)

    # Initialize preprocessor
    preprocess_cfg = inference_cfg.get("preprocessing", {})
    _preprocessor = ImagePreprocessor(
        PreprocessingConfig(
            image_size=_model.config.image_size if _model else 380,
            max_image_size_mb=preprocess_cfg.get("max_image_size_mb", 10),
            resize_strategy=preprocess_cfg.get("resize_strategy", "center_crop"),
        )
    )

    # Initialize feature store for caching
    cache_cfg = inference_cfg.get("cache", {})
    if cache_cfg.get("enabled", True):
        _feature_store = InMemoryFeatureStore(
            max_size=cache_cfg.get("max_size", 1000),
            default_ttl=cache_cfg.get("ttl_seconds", 3600),
        )

    # Initialize metrics
    _metrics = MetricsCollector()

    yield

    logger.info("Shutting down serving application")


def create_app() -> FastAPI:
    """Create and configure the FastAPI application."""
    app = FastAPI(
        title="AviQuest Bird Classification API",
        description="Production ML API for real-time bird species identification",
        version="1.0.0",
        lifespan=lifespan,
    )

    # Middleware (order matters — outermost first)
    app.add_middleware(RequestIdMiddleware)
    app.add_middleware(LatencyMiddleware)

    config = _load_config()
    server_cfg = config.get("server", {})

    # CORS
    cors_cfg = server_cfg.get("cors", {})
    app.add_middleware(
        CORSMiddleware,
        allow_origins=cors_cfg.get("allow_origins", ["*"]),
        allow_methods=cors_cfg.get("allow_methods", ["GET", "POST"]),
        allow_headers=cors_cfg.get("allow_headers", ["*"]),
    )

    # Rate limiting
    rate_cfg = server_cfg.get("rate_limit", {})
    if rate_cfg.get("enabled", True):
        app.add_middleware(
            RateLimitMiddleware,
            requests_per_minute=rate_cfg.get("requests_per_minute", 60),
            burst_size=rate_cfg.get("burst_size", 10),
        )

    return app


app = create_app()


@app.post("/predict", response_model=PredictionResponse)
async def predict(
    image: UploadFile = File(..., description="Bird image to classify"),
    top_k: int = Query(default=5, ge=1, le=20, description="Number of top predictions"),
):
    """Classify a bird species from an uploaded image.

    Returns top-k species predictions with confidence scores.
    """
    if _model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    request_id = str(uuid.uuid4())
    start_time = time.perf_counter()

    # Read and validate image
    try:
        image_bytes = await image.read()
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to read image: {e}")

    # Check feature store cache
    if _feature_store is not None:
        cache_key = InMemoryFeatureStore.compute_feature_id(image_bytes)
        cached = _feature_store.get(cache_key)
        if cached and cached.metadata.get("predictions"):
            import json

            if _metrics:
                _metrics.record_cache_hit()
            cached_predictions = json.loads(cached.metadata["predictions"])
            return PredictionResponse(
                request_id=request_id,
                predictions=[PredictionResult(**p) for p in cached_predictions],
                model_version=_model_version,
                inference_time_ms=0.0,
            )

    # Preprocess
    try:
        input_tensor = _preprocessor.preprocess(image_bytes).to(_device)
        image_features = _preprocessor.extract_image_features(image_bytes)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    # Inference
    result = _model.predict(input_tensor, top_k=top_k)
    inference_time = (time.perf_counter() - start_time) * 1000

    # Build response
    predictions = []
    probs = result["probabilities"][0].tolist()
    indices = result["class_indices"][0].tolist()
    class_names = result.get("class_names", [[]])[0] if result.get("class_names") else None

    for rank, (prob, idx) in enumerate(zip(probs, indices), start=1):
        species_name = class_names[rank - 1] if class_names else f"class_{idx}"
        predictions.append(
            PredictionResult(
                species=species_name,
                confidence=round(prob, 4),
                rank=rank,
            )
        )

    # Record metrics
    if _metrics:
        _metrics.record_prediction(
            latency_ms=inference_time,
            confidence=probs[0] if probs else 0.0,
            predicted_class=predictions[0].species if predictions else "unknown",
        )
        _metrics.record_image_features(image_features)

    # Cache result
    if _feature_store is not None:
        import json

        _feature_store.put(
            feature_id=cache_key,
            features=image_features,
            metadata={"predictions": json.dumps([p.model_dump() for p in predictions])},
        )

    return PredictionResponse(
        request_id=request_id,
        predictions=predictions,
        model_version=_model_version,
        inference_time_ms=round(inference_time, 2),
        image_features=image_features,
    )


@app.get("/health/live", response_model=HealthResponse)
async def liveness():
    """Liveness probe — checks if the service is running."""
    return HealthResponse(
        status="healthy",
        model_loaded=_model is not None,
        model_version=_model_version if _model else None,
        uptime_seconds=round(time.time() - _start_time, 1),
    )


@app.get("/health/ready", response_model=HealthResponse)
async def readiness():
    """Readiness probe — checks if the service can handle requests."""
    if _model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    return HealthResponse(
        status="healthy",
        model_loaded=True,
        model_version=_model_version,
        uptime_seconds=round(time.time() - _start_time, 1),
    )


@app.get("/model/info", response_model=ModelInfoResponse)
async def model_info():
    """Get information about the currently loaded model."""
    if _model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    params = _model.count_parameters()
    return ModelInfoResponse(
        model_name="aviquest-bird-classifier",
        model_version=_model_version,
        num_classes=_model.config.num_classes,
        backbone=_model.config.backbone,
        image_size=_model.config.image_size,
        total_parameters=params["total"],
        device=str(_device),
    )


@app.get("/metrics")
async def metrics():
    """Prometheus-compatible metrics endpoint."""
    if _metrics is None:
        return {"detail": "Metrics not initialized"}
    return _metrics.get_summary()


@app.get("/cache/stats")
async def cache_stats():
    """Get feature store cache statistics."""
    if _feature_store is None:
        return {"detail": "Cache not enabled"}
    return _feature_store.get_stats()
