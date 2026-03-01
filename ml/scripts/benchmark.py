#!/usr/bin/env python3
"""Benchmark model inference performance.

Usage:
    python scripts/benchmark.py --model-path outputs/bird_classifier.pt
    python scripts/benchmark.py --model-path outputs/bird_classifier.pt --batch-size 16 --iterations 200
"""

import argparse
import json
import logging
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from src.models.bird_classifier import BirdClassifier
from src.models.optimization import benchmark_model


def main():
    parser = argparse.ArgumentParser(description="Benchmark bird classifier")
    parser.add_argument("--model-path", required=True, help="Path to model checkpoint")
    parser.add_argument("--device", default="cpu", help="Device (cpu, cuda)")
    parser.add_argument("--batch-size", type=int, default=1, help="Batch size")
    parser.add_argument("--iterations", type=int, default=100, help="Number of iterations")
    parser.add_argument("--warmup", type=int, default=10, help="Warmup iterations")
    parser.add_argument("--output", default=None, help="Save results to JSON file")

    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO)

    model = BirdClassifier.load(args.model_path, device=args.device)
    params = model.count_parameters()

    print(f"Model: {model.config.backbone}")
    print(f"Parameters: {params['total']:,}")
    print(f"Device: {args.device}")
    print(f"Batch size: {args.batch_size}")
    print(f"Iterations: {args.iterations}")
    print()

    results = benchmark_model(
        model,
        device=args.device,
        num_iterations=args.iterations,
        batch_size=args.batch_size,
        warmup_iterations=args.warmup,
    )

    print(f"Mean latency:  {results['mean_latency_ms']:>8.2f} ms")
    print(f"P50 latency:   {results['p50_latency_ms']:>8.2f} ms")
    print(f"P95 latency:   {results['p95_latency_ms']:>8.2f} ms")
    print(f"P99 latency:   {results['p99_latency_ms']:>8.2f} ms")
    print(f"Throughput:    {results['throughput_qps']:>8.1f} QPS")

    if args.output:
        with open(args.output, "w") as f:
            json.dump(results, f, indent=2)
        print(f"\nResults saved to {args.output}")


if __name__ == "__main__":
    main()
