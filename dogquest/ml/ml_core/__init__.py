"""ml_core — Shared ML utilities for DogQuest model training and evaluation.

Modules:
    tf_setup        TensorFlow environment configuration (CPU/GPU, threading, memory)
    datasets        Stanford Dogs loading, supplemental breed merging, label mapping
    augmentation    RandAugment, CutMix, Mixup, progressive resizing pipelines
    quantization    TFLite conversion, uint8 quantization, representative datasets
    reporting       Metrics computation, confusion matrix, JSON report export
"""

__version__ = "0.1.0"
