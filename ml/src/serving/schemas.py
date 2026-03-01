"""Pydantic schemas for the model serving API.

Defines request/response models with validation for the bird
classification inference endpoints.
"""

from __future__ import annotations

from pydantic import BaseModel, Field


class PredictionResult(BaseModel):
    """A single bird species prediction."""

    species: str = Field(description="Predicted bird species name")
    scientific_name: str | None = Field(
        default=None, description="Scientific name if available"
    )
    confidence: float = Field(
        ge=0.0, le=1.0, description="Prediction confidence (0-1)"
    )
    rank: int = Field(ge=1, description="Rank in top-k predictions")


class PredictionResponse(BaseModel):
    """Response from the bird identification endpoint."""

    request_id: str = Field(description="Unique request identifier")
    predictions: list[PredictionResult] = Field(
        description="Top-k species predictions ranked by confidence"
    )
    model_version: str = Field(description="Model version used for inference")
    inference_time_ms: float = Field(
        ge=0, description="Inference latency in milliseconds"
    )
    image_features: dict[str, float] | None = Field(
        default=None, description="Extracted image statistics (for monitoring)"
    )


class HealthResponse(BaseModel):
    """Health check response."""

    status: str = Field(description="Service status: healthy or unhealthy")
    model_loaded: bool = Field(description="Whether the model is loaded")
    model_version: str | None = Field(
        default=None, description="Current model version"
    )
    uptime_seconds: float = Field(ge=0, description="Service uptime in seconds")


class ModelInfoResponse(BaseModel):
    """Model metadata response."""

    model_name: str
    model_version: str
    num_classes: int
    backbone: str
    image_size: int
    total_parameters: int
    device: str


class ExperimentAssignment(BaseModel):
    """A/B test experiment assignment info."""

    experiment_id: str
    variant: str
    model_version: str
