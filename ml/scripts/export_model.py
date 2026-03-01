#!/usr/bin/env python3
"""Export a trained model to optimized formats.

Usage:
    python scripts/export_model.py --model-path outputs/bird_classifier.pt --output-dir exports/
    python scripts/export_model.py --model-path outputs/bird_classifier.pt --format onnx --benchmark
"""

import argparse
import json
import logging
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from src.models.bird_classifier import BirdClassifier
from src.models.optimization import (
    benchmark_model,
    export_onnx,
    quantize_dynamic,
    validate_onnx,
)


def main():
    parser = argparse.ArgumentParser(description="Export bird classifier model")
    parser.add_argument("--model-path", required=True, help="Path to trained model")
    parser.add_argument("--output-dir", default="exports", help="Export output directory")
    parser.add_argument(
        "--format",
        choices=["onnx", "quantized", "all"],
        default="all",
        help="Export format",
    )
    parser.add_argument(
        "--benchmark", action="store_true", help="Run performance benchmark"
    )
    parser.add_argument(
        "--benchmark-iterations",
        type=int,
        default=100,
        help="Number of benchmark iterations",
    )

    args = parser.parse_args()

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Load model
    model = BirdClassifier.load(args.model_path)
    params = model.count_parameters()
    print(f"Loaded model: {params['total']:,} parameters ({params['trainable']:,} trainable)")

    results = {}

    if args.format in ("onnx", "all"):
        print("\n--- ONNX Export ---")
        onnx_path = output_dir / "bird_classifier.onnx"
        export_onnx(model, onnx_path)
        is_valid = validate_onnx(onnx_path)
        size_mb = onnx_path.stat().st_size / (1024 * 1024)
        print(f"ONNX model: {onnx_path} ({size_mb:.1f} MB, valid: {is_valid})")
        results["onnx"] = {"path": str(onnx_path), "size_mb": round(size_mb, 1), "valid": is_valid}

    if args.format in ("quantized", "all"):
        print("\n--- Dynamic Quantization ---")
        import torch

        quantized = quantize_dynamic(model)
        quantized_path = output_dir / "bird_classifier_quantized.pt"
        torch.save(quantized.state_dict(), quantized_path)
        size_mb = quantized_path.stat().st_size / (1024 * 1024)
        print(f"Quantized model: {quantized_path} ({size_mb:.1f} MB)")
        results["quantized"] = {"path": str(quantized_path), "size_mb": round(size_mb, 1)}

    if args.benchmark:
        print("\n--- Performance Benchmark ---")
        bench = benchmark_model(model, num_iterations=args.benchmark_iterations)
        print(f"Mean latency: {bench['mean_latency_ms']:.2f} ms")
        print(f"P50 latency:  {bench['p50_latency_ms']:.2f} ms")
        print(f"P95 latency:  {bench['p95_latency_ms']:.2f} ms")
        print(f"P99 latency:  {bench['p99_latency_ms']:.2f} ms")
        print(f"Throughput:   {bench['throughput_qps']:.1f} QPS")
        results["benchmark"] = bench

    # Save results
    results_path = output_dir / "export_results.json"
    with open(results_path, "w") as f:
        json.dump(results, f, indent=2)
    print(f"\nResults saved to {results_path}")


if __name__ == "__main__":
    main()
