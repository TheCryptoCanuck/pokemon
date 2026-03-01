"""End-to-end training pipeline orchestration.

Coordinates dataset preparation, model training, evaluation,
optimization, and model registration in a single workflow.
"""

from __future__ import annotations

import logging
import time
from dataclasses import dataclass
from pathlib import Path

import yaml

from src.models.bird_classifier import BirdClassifier, ModelConfig
from src.models.model_registry import ModelRegistry, ModelStage
from src.models.optimization import export_onnx, quantize_dynamic
from src.training.dataset import create_data_loaders
from src.training.evaluation import ModelEvaluator
from src.training.trainer import Trainer, TrainingConfig

logger = logging.getLogger(__name__)


@dataclass
class PipelineConfig:
    """Configuration for the training pipeline."""

    train_dir: str
    val_dir: str
    test_dir: str | None = None
    config_path: str = "config/model_config.yaml"
    output_dir: str = "outputs"
    registry_dir: str = "model_registry"
    model_name: str = "aviquest-bird-classifier"
    export_onnx: bool = True
    export_quantized: bool = True
    auto_promote: bool = False
    min_accuracy_threshold: float = 0.7


class TrainingPipeline:
    """Orchestrates the end-to-end model training workflow.

    Pipeline stages:
    1. Load configuration
    2. Prepare data loaders
    3. Initialize model
    4. Train with early stopping
    5. Evaluate on test set
    6. Export optimized models (ONNX, quantized)
    7. Register model in registry
    8. Optionally promote to production
    """

    def __init__(self, config: PipelineConfig) -> None:
        self.config = config
        self.output_dir = Path(config.output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.registry = ModelRegistry(config.registry_dir)

    def run(self) -> dict:
        """Execute the full training pipeline.

        Returns:
            Dictionary with pipeline results including metrics and model paths.
        """
        start_time = time.time()
        results: dict = {"status": "started", "stages": {}}

        # Stage 1: Load config
        logger.info("=== Stage 1: Loading configuration ===")
        model_config, training_config = self._load_configs()
        results["stages"]["config"] = "completed"

        # Stage 2: Prepare data
        logger.info("=== Stage 2: Preparing data loaders ===")
        aug_config = None
        config_path = Path(self.config.config_path)
        if config_path.exists():
            with open(config_path) as f:
                full_config = yaml.safe_load(f)
                aug_config = full_config.get("training", {}).get("augmentation")

        train_loader, val_loader = create_data_loaders(
            train_dir=self.config.train_dir,
            val_dir=self.config.val_dir,
            image_size=model_config.image_size,
            batch_size=training_config.batch_size,
            augmentation_config=aug_config,
        )
        results["stages"]["data_preparation"] = "completed"
        results["num_classes"] = len(train_loader.dataset.class_names)

        # Stage 3: Initialize model
        logger.info("=== Stage 3: Initializing model ===")
        model_config.num_classes = len(train_loader.dataset.class_names)
        model = BirdClassifier(model_config)
        model.class_names = train_loader.dataset.class_names
        params = model.count_parameters()
        logger.info("Model: %s, params: %s", model_config.backbone, params)
        results["stages"]["model_init"] = "completed"
        results["model_parameters"] = params

        # Stage 4: Train
        logger.info("=== Stage 4: Training ===")
        trainer = Trainer(model, training_config)
        metrics = trainer.train(train_loader, val_loader)
        results["stages"]["training"] = "completed"
        results["training_metrics"] = {
            "epochs_trained": metrics.epoch,
            "best_val_accuracy": metrics.best_val_accuracy,
            "final_train_loss": metrics.train_loss,
            "final_val_loss": metrics.val_loss,
        }

        # Stage 5: Evaluate
        logger.info("=== Stage 5: Evaluation ===")
        test_dir = self.config.test_dir or self.config.val_dir
        evaluator = ModelEvaluator(
            model,
            device=str(trainer.device),
            class_names=train_loader.dataset.class_names,
        )
        eval_report = evaluator.evaluate(val_loader)
        eval_report.save(self.output_dir / "evaluation_report.json")
        results["stages"]["evaluation"] = "completed"
        results["evaluation"] = eval_report.to_dict()

        # Stage 6: Export
        logger.info("=== Stage 6: Exporting models ===")
        model_path = self.output_dir / "bird_classifier.pt"
        model.save(model_path)
        results["model_path"] = str(model_path)

        if self.config.export_onnx:
            onnx_path = self.output_dir / "bird_classifier.onnx"
            export_onnx(model, onnx_path)
            results["onnx_path"] = str(onnx_path)

        if self.config.export_quantized:
            quantized = quantize_dynamic(model)
            quantized_path = self.output_dir / "bird_classifier_quantized.pt"
            import torch
            torch.save(quantized.state_dict(), quantized_path)
            results["quantized_path"] = str(quantized_path)

        results["stages"]["export"] = "completed"

        # Stage 7: Register
        logger.info("=== Stage 7: Registering model ===")
        model_version = self.registry.register_model(
            name=self.config.model_name,
            model_path=model_path,
            metrics={
                "top1_accuracy": eval_report.top1_accuracy,
                "top5_accuracy": eval_report.top5_accuracy,
                "macro_f1": eval_report.macro_f1,
            },
            parameters={
                "backbone": model_config.backbone,
                "epochs": str(metrics.epoch),
                "lr": str(training_config.learning_rate),
            },
            description=f"Trained on {results['num_classes']} classes",
        )
        results["stages"]["registration"] = "completed"
        results["model_version"] = model_version.version

        # Stage 8: Auto-promote (optional)
        if self.config.auto_promote:
            if eval_report.top1_accuracy >= self.config.min_accuracy_threshold:
                self.registry.promote_model(
                    self.config.model_name,
                    model_version.version,
                    ModelStage.PRODUCTION,
                )
                results["promoted_to"] = "production"
                logger.info("Model auto-promoted to production")
            else:
                results["promoted_to"] = "staging"
                self.registry.promote_model(
                    self.config.model_name,
                    model_version.version,
                    ModelStage.STAGING,
                )
                logger.warning(
                    "Model accuracy %.4f below threshold %.4f — promoted to staging only",
                    eval_report.top1_accuracy,
                    self.config.min_accuracy_threshold,
                )

        results["status"] = "completed"
        results["total_time_seconds"] = round(time.time() - start_time, 1)

        logger.info(
            "Pipeline completed in %.1f seconds. Best accuracy: %.4f",
            results["total_time_seconds"],
            metrics.best_val_accuracy,
        )

        return results

    def _load_configs(self) -> tuple[ModelConfig, TrainingConfig]:
        """Load model and training configurations."""
        config_path = Path(self.config.config_path)

        if config_path.exists():
            with open(config_path) as f:
                full_config = yaml.safe_load(f)
            model_config = ModelConfig.from_dict(full_config)
            training_config = TrainingConfig.from_dict(full_config)
        else:
            logger.warning("Config not found at %s, using defaults", config_path)
            model_config = ModelConfig()
            training_config = TrainingConfig()

        return model_config, training_config
