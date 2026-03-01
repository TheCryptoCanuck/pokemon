"""Inference pipeline for batch and single-image prediction.

Provides a high-level API for running bird classification predictions
with preprocessing, caching, and post-processing.
"""

from __future__ import annotations

import logging
import time
from dataclasses import dataclass
from pathlib import Path

import torch
from PIL import Image

from src.features.feature_store import InMemoryFeatureStore
from src.features.preprocessing import ImagePreprocessor, PreprocessingConfig
from src.models.bird_classifier import BirdClassifier

logger = logging.getLogger(__name__)


@dataclass
class PredictionResult:
    """Result of a bird classification prediction."""

    species: str
    confidence: float
    rank: int
    class_index: int


@dataclass
class InferenceResult:
    """Full inference result including metadata."""

    predictions: list[PredictionResult]
    inference_time_ms: float
    model_version: str
    cached: bool = False


class InferencePipeline:
    """Production inference pipeline for bird identification.

    Combines model loading, preprocessing, inference, and post-processing
    into a simple high-level interface.
    """

    def __init__(
        self,
        model_path: str | Path,
        device: str = "auto",
        compile_model: bool = False,
        enable_cache: bool = True,
        cache_size: int = 1000,
    ) -> None:
        if device == "auto":
            if torch.cuda.is_available():
                device = "cuda"
            elif hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
                device = "mps"
            else:
                device = "cpu"

        self.device = device
        self.model = BirdClassifier.load(model_path, device=device, compile_model=compile_model)
        self.model_version = Path(model_path).stem

        self.preprocessor = ImagePreprocessor(
            PreprocessingConfig(image_size=self.model.config.image_size)
        )

        self.cache = InMemoryFeatureStore(max_size=cache_size) if enable_cache else None

        logger.info(
            "Inference pipeline initialized: model=%s, device=%s",
            model_path,
            device,
        )

    def predict(
        self,
        image: Image.Image | bytes | str | Path,
        top_k: int = 5,
    ) -> InferenceResult:
        """Run inference on a single image.

        Args:
            image: PIL Image, raw bytes, or file path.
            top_k: Number of top predictions to return.

        Returns:
            InferenceResult with predictions and metadata.
        """
        # Handle file path input
        if isinstance(image, (str, Path)):
            image = Image.open(image)

        start_time = time.perf_counter()

        # Preprocess
        input_tensor = self.preprocessor.preprocess(image).to(self.device)

        # Inference
        result = self.model.predict(input_tensor, top_k=top_k)
        inference_time = (time.perf_counter() - start_time) * 1000

        # Build predictions
        predictions = []
        probs = result["probabilities"][0].tolist()
        indices = result["class_indices"][0].tolist()
        class_names = result.get("class_names", [[]])[0] if result.get("class_names") else None

        for rank, (prob, idx) in enumerate(zip(probs, indices), start=1):
            species = class_names[rank - 1] if class_names else f"class_{idx}"
            predictions.append(
                PredictionResult(
                    species=species,
                    confidence=round(prob, 4),
                    rank=rank,
                    class_index=idx,
                )
            )

        return InferenceResult(
            predictions=predictions,
            inference_time_ms=round(inference_time, 2),
            model_version=self.model_version,
        )

    def predict_batch(
        self,
        images: list[Image.Image | bytes],
        top_k: int = 5,
    ) -> list[InferenceResult]:
        """Run inference on a batch of images.

        Args:
            images: List of PIL Images or raw bytes.
            top_k: Number of top predictions per image.

        Returns:
            List of InferenceResult, one per image.
        """
        start_time = time.perf_counter()

        # Preprocess batch
        input_tensor = self.preprocessor.preprocess_batch(images).to(self.device)

        # Inference
        result = self.model.predict(input_tensor, top_k=top_k)
        total_time = (time.perf_counter() - start_time) * 1000
        per_image_time = total_time / len(images)

        # Build results
        results = []
        batch_probs = result["probabilities"].tolist()
        batch_indices = result["class_indices"].tolist()
        batch_names = result.get("class_names", [None] * len(images))

        for i in range(len(images)):
            predictions = []
            for rank, (prob, idx) in enumerate(
                zip(batch_probs[i], batch_indices[i]), start=1
            ):
                species = batch_names[i][rank - 1] if batch_names[i] else f"class_{idx}"
                predictions.append(
                    PredictionResult(
                        species=species,
                        confidence=round(prob, 4),
                        rank=rank,
                        class_index=idx,
                    )
                )

            results.append(
                InferenceResult(
                    predictions=predictions,
                    inference_time_ms=round(per_image_time, 2),
                    model_version=self.model_version,
                )
            )

        logger.info(
            "Batch inference: %d images in %.1fms (%.1fms/image)",
            len(images),
            total_time,
            per_image_time,
        )

        return results
