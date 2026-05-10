"""TensorFlow environment configuration — CPU/GPU threading, memory, mixed precision.

Must be called BEFORE any other TensorFlow imports in training scripts.

Usage:
    from ml_core.tf_setup import configure_tf
    tf = configure_tf()
    # ... rest of script uses tf normally
"""

from __future__ import annotations

import os
from typing import Optional


def configure_tf(
    *,
    log_level: int = 2,
    enable_onednn: bool = True,
    kmp_blocktime: int = 0,
    inter_op_threads: Optional[int] = None,
    intra_op_threads: Optional[int] = None,
    gpu_memory_growth: bool = True,
    mixed_precision: bool = False,
) -> "tf":
    """Configure TensorFlow environment and return the tf module.

    Sets environment variables (must happen before TF import), configures
    threading for CPU performance, enables GPU memory growth, and optionally
    enables mixed precision.

    Args:
        log_level: TF_CPP_MIN_LOG_LEVEL (0=all, 1=no INFO, 2=no WARN, 3=no ERROR).
        enable_onednn: Enable oneDNN/MKL-DNN optimizations for CPU.
        kmp_blocktime: KMP_BLOCKTIME (0 = release threads immediately).
        inter_op_threads: Inter-op parallelism threads (default: cpu_count // 4).
        intra_op_threads: Intra-op parallelism threads (default: cpu_count).
        gpu_memory_growth: Enable GPU memory growth (prevent grabbing all VRAM).
        mixed_precision: Enable mixed_float16 policy for faster GPU training.

    Returns:
        The tensorflow module, ready for use.
    """
    cpu_count = os.cpu_count() or 8

    if inter_op_threads is None:
        inter_op_threads = max(2, cpu_count // 4)
    if intra_op_threads is None:
        intra_op_threads = cpu_count

    # Environment variables MUST be set before importing TensorFlow
    os.environ["TF_CPP_MIN_LOG_LEVEL"] = str(log_level)
    if enable_onednn:
        os.environ["TF_ENABLE_ONEDNN_OPTS"] = "1"
    os.environ["KMP_BLOCKTIME"] = str(kmp_blocktime)
    os.environ["KMP_AFFINITY"] = "granularity=fine,verbose,compact,1,0"
    os.environ["OMP_NUM_THREADS"] = str(intra_op_threads)
    os.environ["TF_NUM_INTEROP_THREADS"] = str(inter_op_threads)
    os.environ["TF_NUM_INTRAOP_THREADS"] = str(intra_op_threads)

    import tensorflow as tf

    tf.config.threading.set_inter_op_parallelism_threads(inter_op_threads)
    tf.config.threading.set_intra_op_parallelism_threads(intra_op_threads)

    # GPU memory growth
    if gpu_memory_growth:
        gpus = tf.config.experimental.list_physical_devices("GPU")
        for gpu in gpus:
            tf.config.experimental.set_memory_growth(gpu, True)

    # Mixed precision
    if mixed_precision:
        tf.keras.mixed_precision.set_global_policy("mixed_float16")

    print(f"TF {tf.__version__} configured:")
    print(f"  CPU cores: {cpu_count}")
    print(f"  Inter-op threads: {inter_op_threads}")
    print(f"  Intra-op threads: {intra_op_threads}")

    gpus = tf.config.experimental.list_physical_devices("GPU")
    if gpus:
        print(f"  GPUs: {len(gpus)} (memory_growth={gpu_memory_growth})")
    else:
        print("  GPUs: none (CPU-only)")

    if mixed_precision:
        print("  Mixed precision: float16")

    return tf
