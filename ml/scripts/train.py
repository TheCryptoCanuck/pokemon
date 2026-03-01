#!/usr/bin/env python3
"""Training script for AviQuest bird classifier.

Usage:
    python scripts/train.py --train-dir data/train --val-dir data/val
    python scripts/train.py --config config/model_config.yaml --train-dir data/train --val-dir data/val
"""

import argparse
import logging
import sys
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from src.pipeline.training_pipeline import PipelineConfig, TrainingPipeline


def main():
    parser = argparse.ArgumentParser(description="Train AviQuest bird classifier")
    parser.add_argument("--train-dir", required=True, help="Training data directory")
    parser.add_argument("--val-dir", required=True, help="Validation data directory")
    parser.add_argument("--test-dir", default=None, help="Test data directory")
    parser.add_argument(
        "--config", default="config/model_config.yaml", help="Model config path"
    )
    parser.add_argument("--output-dir", default="outputs", help="Output directory")
    parser.add_argument(
        "--model-name",
        default="aviquest-bird-classifier",
        help="Model name for registry",
    )
    parser.add_argument(
        "--auto-promote",
        action="store_true",
        help="Auto-promote to production if accuracy meets threshold",
    )
    parser.add_argument(
        "--min-accuracy",
        type=float,
        default=0.7,
        help="Minimum accuracy for auto-promotion",
    )
    parser.add_argument(
        "--no-onnx", action="store_true", help="Skip ONNX export"
    )
    parser.add_argument(
        "--no-quantize", action="store_true", help="Skip quantized export"
    )

    args = parser.parse_args()

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )

    pipeline_config = PipelineConfig(
        train_dir=args.train_dir,
        val_dir=args.val_dir,
        test_dir=args.test_dir,
        config_path=args.config,
        output_dir=args.output_dir,
        model_name=args.model_name,
        export_onnx=not args.no_onnx,
        export_quantized=not args.no_quantize,
        auto_promote=args.auto_promote,
        min_accuracy_threshold=args.min_accuracy,
    )

    pipeline = TrainingPipeline(pipeline_config)
    results = pipeline.run()

    print("\n" + "=" * 60)
    print("TRAINING PIPELINE RESULTS")
    print("=" * 60)
    print(f"Status: {results['status']}")
    print(f"Model version: {results.get('model_version', 'N/A')}")
    print(f"Total time: {results.get('total_time_seconds', 0):.1f}s")

    if "training_metrics" in results:
        tm = results["training_metrics"]
        print(f"\nTraining:")
        print(f"  Epochs: {tm['epochs_trained']}")
        print(f"  Best val accuracy: {tm['best_val_accuracy']:.4f}")

    if "evaluation" in results:
        ev = results["evaluation"]
        print(f"\nEvaluation:")
        print(f"  Top-1 accuracy: {ev['top1_accuracy']:.4f}")
        print(f"  Top-5 accuracy: {ev['top5_accuracy']:.4f}")
        print(f"  Macro F1: {ev['macro_f1']:.4f}")


if __name__ == "__main__":
    main()
