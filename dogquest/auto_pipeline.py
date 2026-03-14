"""
Automated ML pipeline for DogQuest — monitors training, evaluates results,
and iterates until 90%+ accuracy is achieved.

Usage:
    python auto_pipeline.py              # monitor running v5 training
    python auto_pipeline.py --retrain    # start fresh v5 training
    python auto_pipeline.py --evaluate   # just evaluate existing model
"""

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
ASSETS_DIR = SCRIPT_DIR / "assets"
TARGET_ACCURACY = 0.90
V5_REPORT = SCRIPT_DIR / "train_v5_report.json"
V5_MODEL = ASSETS_DIR / "dog_model_v5.tflite"
V5_SCRIPT = SCRIPT_DIR / "train_model_v5.py"
DOWNLOAD_SCRIPT = SCRIPT_DIR / "download_more_images.py"


def is_training_running():
    """Check if train_model_v5.py is currently running."""
    try:
        result = subprocess.run(
            ["tasklist", "/FI", "IMAGENAME eq python.exe", "/FO", "CSV"],
            capture_output=True, text=True, timeout=10
        )
        # Also check the command line
        result2 = subprocess.run(
            ["wmic", "process", "where", "name='python.exe'", "get", "CommandLine"],
            capture_output=True, text=True, timeout=10
        )
        return "train_model_v5" in result2.stdout
    except Exception:
        return False


def wait_for_training():
    """Wait for v5 training to complete, checking every 60 seconds."""
    print("=" * 65)
    print("MONITORING v5 TRAINING")
    print("=" * 65)

    check_interval = 60  # seconds
    elapsed = 0

    while is_training_running():
        hours = elapsed // 3600
        mins = (elapsed % 3600) // 60
        print(f"  [{hours:02d}:{mins:02d}] Training still running... "
              f"(checking every {check_interval}s)")

        # Check if report file exists yet (training finished writing it)
        if V5_REPORT.exists():
            print("  Training report found! Training may have just finished.")
            time.sleep(5)  # Brief wait for file to finish writing
            break

        time.sleep(check_interval)
        elapsed += check_interval

    print(f"\n  Training process completed after ~{elapsed // 60} minutes of monitoring.")
    return True


def evaluate_model():
    """Read the v5 training report and evaluate results."""
    print("\n" + "=" * 65)
    print("EVALUATING MODEL")
    print("=" * 65)

    if not V5_REPORT.exists():
        print(f"  ERROR: No report found at {V5_REPORT}")
        return None

    with open(V5_REPORT) as f:
        report = json.load(f)

    test_acc = report.get("test_accuracy", 0)
    model_size = report.get("model_size_mb", 0)
    training_time = report.get("training_time_minutes", 0)
    low_breeds = report.get("low_accuracy_breeds", [])

    print(f"  Test Accuracy:    {test_acc * 100:.1f}%")
    print(f"  Model Size:       {model_size:.1f} MB")
    print(f"  Training Time:    {training_time:.0f} min")
    print(f"  Target:           {TARGET_ACCURACY * 100:.0f}%")
    print(f"  Gap:              {(TARGET_ACCURACY - test_acc) * 100:.1f}%")

    if low_breeds:
        print(f"\n  Low-accuracy breeds ({len(low_breeds)}):")
        for breed in low_breeds[:10]:
            name = breed.get("breed", "?")
            acc = breed.get("accuracy", 0)
            count = breed.get("count", 0)
            print(f"    {name:<35s} {acc * 100:5.1f}%  ({count} samples)")

    passed = test_acc >= TARGET_ACCURACY
    print(f"\n  {'PASSED' if passed else 'BELOW TARGET'}: "
          f"{test_acc * 100:.1f}% {'≥' if passed else '<'} {TARGET_ACCURACY * 100:.0f}%")

    return report


def diagnose_failures(report):
    """Analyze low-accuracy breeds and suggest improvements."""
    print("\n" + "=" * 65)
    print("DIAGNOSIS")
    print("=" * 65)

    test_acc = report.get("test_accuracy", 0)
    gap = TARGET_ACCURACY - test_acc
    low_breeds = report.get("low_accuracy_breeds", [])

    recommendations = []

    if gap > 0.05:
        recommendations.append("MAJOR: Consider EfficientNetV2-S backbone (bigger model, higher ceiling)")
        recommendations.append("MAJOR: Add iNaturalist pretrained weights")
        recommendations.append("MAJOR: Download more training data (target 400+ per breed)")

    if gap > 0.02:
        recommendations.append("Download more images for low-accuracy breeds")
        recommendations.append("Increase fine-tune epochs (15 → 25 for final stage)")
        recommendations.append("Try SAM optimizer (Sharpness-Aware Minimization)")
        recommendations.append("Add supervised contrastive loss pre-training")

    if low_breeds:
        # Find breeds that might have data quality issues
        very_low = [b for b in low_breeds if b.get("accuracy", 1.0) < 0.5]
        if very_low:
            names = [b["breed"] for b in very_low[:5]]
            recommendations.append(f"Audit/clean training images for: {', '.join(names)}")

    if recommendations:
        print("  Recommendations:")
        for i, rec in enumerate(recommendations, 1):
            print(f"    {i}. {rec}")
    else:
        print("  No specific recommendations — model meets target!")

    return recommendations


def start_training():
    """Start v5 training in background."""
    print("\n" + "=" * 65)
    print("STARTING v5 TRAINING")
    print("=" * 65)

    if is_training_running():
        print("  Training is already running!")
        return False

    # Remove old report
    if V5_REPORT.exists():
        os.rename(V5_REPORT, V5_REPORT.with_suffix(".json.bak"))
        print("  Backed up old report")

    log_file = SCRIPT_DIR / "train_v5_output.log"
    print(f"  Starting: python {V5_SCRIPT}")
    print(f"  Log: {log_file}")

    with open(log_file, "w") as log:
        proc = subprocess.Popen(
            [sys.executable, str(V5_SCRIPT)],
            stdout=log, stderr=subprocess.STDOUT,
            cwd=str(SCRIPT_DIR)
        )
    print(f"  PID: {proc.pid}")
    print("  Training started in background!")
    return True


def deploy_model():
    """Copy v5 model to assets as the production model."""
    print("\n" + "=" * 65)
    print("DEPLOYING MODEL")
    print("=" * 65)

    if not V5_MODEL.exists():
        print(f"  ERROR: {V5_MODEL} not found")
        return False

    prod_model = ASSETS_DIR / "dog_model.tflite"
    size_mb = V5_MODEL.stat().st_size / (1024 * 1024)

    import shutil
    shutil.copy2(V5_MODEL, prod_model)
    print(f"  Deployed {V5_MODEL.name} → {prod_model.name} ({size_mb:.1f} MB)")
    return True


def main():
    parser = argparse.ArgumentParser(description="DogQuest ML Automation Pipeline")
    parser.add_argument("--retrain", action="store_true",
                        help="Start fresh v5 training")
    parser.add_argument("--evaluate", action="store_true",
                        help="Just evaluate existing model")
    parser.add_argument("--deploy", action="store_true",
                        help="Deploy v5 model as production")
    args = parser.parse_args()

    print("=" * 65)
    print("DogQuest — Automated ML Pipeline")
    print(f"Target: {TARGET_ACCURACY * 100:.0f}% accuracy")
    print("=" * 65)

    if args.evaluate:
        report = evaluate_model()
        if report:
            diagnose_failures(report)
        return

    if args.deploy:
        deploy_model()
        return

    if args.retrain:
        start_training()

    # Monitor if training is running
    if is_training_running():
        wait_for_training()

    # Evaluate
    report = evaluate_model()
    if report is None:
        print("\n  No report available. Training may not have finished.")
        print("  Run with --retrain to start training, or wait for current training.")
        return

    test_acc = report.get("test_accuracy", 0)

    if test_acc >= TARGET_ACCURACY:
        print(f"\n  TARGET REACHED: {test_acc * 100:.1f}% ≥ {TARGET_ACCURACY * 100:.0f}%")
        deploy_model()
    else:
        recommendations = diagnose_failures(report)
        print(f"\n  BELOW TARGET: {test_acc * 100:.1f}% < {TARGET_ACCURACY * 100:.0f}%")
        print("  Review recommendations above and re-run with --retrain after adjustments.")


if __name__ == "__main__":
    main()
