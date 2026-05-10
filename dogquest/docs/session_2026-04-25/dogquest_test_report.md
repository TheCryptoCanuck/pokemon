# DogQuest v6 Shipping Model — Sandbox Test Report

**Date:** 2026-04-24
**Environment:** Linux sandbox, Python 3.10, tflite-runtime, NumPy 1.26
**Model:** `assets/dog_model.tflite` (23.8 MB, EfficientNetV2-S, 300×300 uint8 → 296 uint8)
**No files in the project were modified.**

## TL;DR

The shipping v6 TFLite model is **miscalibrated**. End-to-end accuracy on real dog
images is **~1.6%**, barely above the 0.34% random-guess baseline — not the 48.86%
val_accuracy reported during training. The model outputs nearly the same distribution
for any input (black, white, gray, random noise, or a real dog).

This is a **preprocessing mismatch introduced at TFLite export**, not a problem with
the trained weights.

## Test design

- Same preprocessing pipeline the Flutter app uses: EXIF transpose → resize shortest
  side to 300 → center-crop 300×300 → uint8 [0, 255] tensor
- Ground-truth labels derived from `supplemental_dogs/<breed>/` folder names,
  normalized to `assets/dog_labels.txt` entries (plus 3 overrides for known aliases)
- 62 breeds × 1 image, no TTA, same interpreter the tflite_flutter plugin uses
- Additional controlled probe: feed synthetic images (all-black / all-white /
  all-gray / random) and compare to real dog images

## Probe 1 — the model ignores the image

| Input | Top-1 | Confidence | Max prob |
|---|---|---:|---:|
| All-zero (black) | Maltese | 0.043 | 0.043 |
| All-255 (white) | Maltese | 0.035 | 0.035 |
| All-128 (gray) | Maltese | 0.047 | 0.047 |
| Random uniform noise | Bichon Frise | 0.012 | 0.012 |
| Real Akita photo | American Foxhound | 0.008 | 0.008 |

A healthy 296-class model should put a solid dog at >0.3 confidence and synthetic
inputs at ~0.003 (uniform). Here the **model gives black/white/gray the same label
("Maltese") with ~4% confidence**, and a real Akita gets *lower* confidence than a
solid gray square. The network is not processing image content at all — it is
emitting a near-fixed prior tilted by overall pixel variance.

## Probe 2 — accuracy on real images

- Top-1: **1.61% (1/62 breeds)** — random baseline is 0.34%
- Top-5: **1.61% (1/62 breeds)** — random baseline is 1.69% (we're *at* baseline)
- Mean top-1 confidence: 0.020 (median 0.016)
- Raw output stats: min=0, max=2 on a uint8 scale of 255 — meaning max probability
  is ~0.008. Softmax from a working classifier would have max ≫ 0.1 on a dog photo.

## Root cause (high confidence)

The bug is in `export_tflite.py`, line 94:

```python
def representative_data_gen():
    for _ in range(100):
        data = np.random.rand(1, FINAL_IMG_SIZE, FINAL_IMG_SIZE, 3).astype(np.float32)
        yield [data]
```

`np.random.rand` produces floats in **[0, 1]**, but the training pipeline
(`train_model_v6.py` line 756) feeds **[0, 255] floats** into
`tf.keras.applications.efficientnet_v2.preprocess_input` (which is identity for V2),
and EfficientNetV2-S has an internal `Rescaling(1./255)` layer that handles
normalization.

Consequence at export time:
1. The quantizer sees calibration floats in [0, 1] and learns input scale `1/255`.
2. The TFLite input quantization becomes `float = uint8 / 255`, mapping raw uint8
   pixels [0, 255] into [0, 1] at the *entry* of the graph.
3. EfficientNetV2's internal `Rescaling(1./255)` then divides *again*, so the
   network actually receives values in **[0, 1/255] ≈ [0, 0.004]** — 255× smaller
   than what it was trained on.
4. Inputs collapse below the network's useful dynamic range; it emits a learned
   prior regardless of content.

Confirming evidence from the live interpreter:
```
input quantization: scale=0.00392157 (=1/255), zero_point=0
output quantization: scale=0.00390625, zero_point=0
raw output range on real dog: min=0, max=2 (uint8) → probs ∈ [0, 0.008]
```

## Suggested fix (unverified — no files modified)

Either make the representative data match training range:

```python
# export_tflite.py line 94
data = (np.random.rand(1, FINAL_IMG_SIZE, FINAL_IMG_SIZE, 3) * 255.0).astype(np.float32)
```

…which would give the quantizer input scale ≈ 1.0, so uint8 pixels pass through
unchanged and the model's internal Rescaling does its one intended division.

Or, alternatively, build the export model with `include_preprocessing=False` on
EfficientNetV2S and do the `/255` manually in the training pipeline — then the
current representative data would be correct.

Either change requires re-running `export_tflite.py` (training does **not** need
to be redone — the weights are fine, only the uint8-quantized wrapper is wrong).

## Why the training val_accuracy (48.86%) disagreed with this test

Training-time validation runs inside Keras with the full preprocessing chain
correctly applied. The double-rescaling only appears after TFLite uint8 export.
The last time end-to-end inference was validated against ground-truth labels was
apparently before the v6 export — `export_tflite.py` only checks that inference
runs, not that predictions are meaningful (line 152–158: "output shape, sum=…").

## Files produced in this session

- `/tmp/test_dogquest.py` — full 296-class TTA accuracy harness (in sandbox)
- `/tmp/confirm.py` — this report's two probes (in sandbox)
- `/tmp/dogquest_results/results.json` — raw per-image predictions from earlier run
- `outputs/dogquest_test_report.md` — this report

No files in `C:\Users\Administrator\AviQuest-\dogquest` were modified.
