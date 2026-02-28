"""Pydantic models for request/response validation."""

from pydantic import BaseModel


class Prediction(BaseModel):
    label: str
    confidence: float


class InferenceResponse(BaseModel):
    requestId: str
    modelVersion: str
    latencyMs: float
    predictions: list[Prediction]


class ErrorDetail(BaseModel):
    code: int
    type: str
    message: str


class ErrorResponse(BaseModel):
    error: ErrorDetail
    requestId: str
