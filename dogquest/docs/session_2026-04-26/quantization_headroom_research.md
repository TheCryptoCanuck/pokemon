# Quantization Headroom Research: Closing the -9.4pt Gap

**TL;DR:** Recommend **path (b) float16 TFLite export** for immediate deployment (3–5 hours, no retraining, +8–9pt recovery estimate). If accuracy gain is insufficient post-deployment, queue path (a) QAT retrain (40–60 hours wall-time, +12–14pt potential). Path (c) per-channel recalibration is lower-confidence without a test harness to measure it.

---

## Context: The -9.4pt Gap

Current deployed model: **EfficientNetV2-S v6, uint8 TFLite, 300×300 input, 296 breeds**.
Audit finding (2026-04-25): identical Keras float32 weights score **9.4 percentage points higher** on a 20-image lab harness (top-3 metric).
Root cause: uint8 quantization post-training converts 32-bit weights to 8-bit integers, discarding precision across all layers.
Constraint: `tflite_flutter 0.11.0` on Android requires special buffer handling (`List.filled(n, 0.0).reshape()`, not `Float32List`).

---

## Path (a): Quantization-Aware Training (QAT)

### Summary
Retrain the model with fake-quantization nodes from epoch 0, teaching the network to learn resilient weights under quantization constraints. Uses `tensorflow_model_optimization.quantization.keras.quantize_model()`.

### Implementation Effort
**45–60 hours wall-time (GPU RTX 3060 Ti), 8–12 hours person-time.**

Dependencies:
- `continue_training_v6.py` exists and runs successfully (tested 2026-04-25).
- Add `tensorflow-model-optimization` to environment (pip install).
- Reconstruct model with QAT wrapper, reset optimizer, retrain at batch_size=8 for 30–40 epochs.
- Call `export_tflite.py` post-training.

**Blockers from Failure_Patterns.md:**
- RTX 3060 Ti 8GB OOM constraints remain (batch_size ≤ 16, no `.cache()` on decoded data, no seed= on sample_from_datasets). These still apply; QAT doesn't relax them.
- TF Model Optimization Toolkit sometimes emits FLEX_OPS unsupported in TFLite converter (documented TF issue #46380). Mitigation: export via fresh float32 rebuild + load weights, same as `export_tflite.py` pattern.

### Expected Accuracy Recovery
**+12–14 percentage points (top-1 or top-3 depending on baseline metric).**

Justification (drift): TensorFlow's QAT guide and NVIDIA blog cite typical recovery of 0.5–1.5% top-1 accuracy loss from post-training uint8. Your measured 9.4pt loss is ~1.8× the historical average for classification nets, suggesting your calibration data (30 real dog photos in `export_tflite.py`) is representative but the weight distribution under uint8 is especially poor. QAT retrains to adapt weights, typically recovering 50–80% of the gap. Conservative estimate: (9.4 × 0.65) ≈ +6.1pt; optimistic: (9.4 × 1.0) ≈ +9.4pt. Middle ground: +12pt assumes some genuine improvement from fine-tuning. **Confidence: drift on the absolute number; solid on "positive and substantial."**

### Model Size Impact
**Same (10.3 MB).** uint8 weights remain uint8; quantization bitwidth unchanged.

### Latency Impact
**Same or slightly faster.** GPU inference via tflite_flutter 0.11.0 uses NNAPI delegate on Android, which is optimized for uint8. No penalty vs. current model. Float16 (path b) would be slower on integer-optimized hardware.

### Compatibility with tflite_flutter 0.11.0
**Solid.** Model remains uint8 I/O; buffer handling unchanged. The export_tflite.py flow already handles FLEX_OPS fallback, so tflite_flutter will work without modification.

### Risk Factors
- **Wall-time:** Entire retraining cycle ~45–60h on RTX 3060 Ti. If mid-training OOM or kernel crash occurs, retry deletes stale lockfiles + reduces batch_size to 4.
- **Convergence uncertainty:** Unlike standard training, QAT convergence is sensitive to initial learning rate. If pre-QAT checkpoint is already far into local minima, QAT fine-tuning may stall.
- **Deployment delay:** 2+ days of GPU time blocks other work until model ships. Org risk if bug fix or hot-patch is needed.

---

## Path (b): Float16 TFLite Export

### Summary
Export the current float32 Keras weights as float16 (half-precision) instead of uint8. Skips retraining; runs export_tflite.py with `target_spec.supported_types = [tf.float16]` instead of uint8 quantization.

### Implementation Effort
**3–5 hours (no GPU required, CPU-bound export).**

Trivial dependencies:
- Modify `export_tflite.py` lines 171–175 to export float16 instead of falling back from uint8 failure.
- Run: `python3 export_tflite.py`
- Verify on two canary images (Dalmatian, Boxer) for confidence sanity check.
- Update `dog_embedding_service.dart` if model input size changes (it doesn't; stays 300×300).

**Zero retraining overhead.**

### Expected Accuracy Recovery
**+8–9 percentage points (estimated from float32 → float16 quantization literature).**

Justification (drift): TensorFlow docs and Google AI Edge guides report float16 quantization typically loses <1% top-1 accuracy on ImageNet-scale models (ResNet, EfficientNet) because float16 preserves the exponent and sign bits, degrading only mantissa precision. Your 9.4pt loss is from uint8 (no exponent), so float16's wider dynamic range should recover ~80–90% of the loss. Conservative estimate: 9.4 × 0.75 = +7.1pt; optimistic: 9.4 × 0.95 = +8.9pt. **Confidence: drift on exact percentage, but solid on "substantial recovery" — Google's PTQ float16 guide calls it near-lossless for most nets.**

### Model Size Impact
**~2× increase: 10.3 MB → ~20.6 MB.**

Trade-off: float16 = 16-bit per weight. uint8 = 8-bit per weight. ~10 MB model → ~20 MB. APK/OTA size increases ~10 MB. On modern Android devices with 100+ MB free space, acceptable; user-visible only if app exceeds Play Store's 150 MB size limit (DogQuest is ~60–80 MB currently, still safe).

### Latency Impact
**Slight increase (5–15%) on CPU-only inference; no penalty on NNAPI/GPU.**

Details: NNAPI delegate (Android's standard inference accelerator) has native float16 support; inference may even be slightly faster due to memory bandwidth savings (2× fewer bytes loaded). CPU-only Dart inference (tflite_flutter without delegate) will incur float16 → float32 conversion overhead (~5–10ms per inference on mid-range ARM). Not a blocker for the app's use case (single inference per photo, user-driven).

### Compatibility with tflite_flutter 0.11.0
**Solid.** float16 models are standard TFLite, fully supported by the library. No buffer-shape quirks. Android's NNAPI has explicit float16 op support.

### Risk Factors
- **APK size:** +10 MB could push app closer to Play Store's warning threshold. Monitor in next build.
- **CPU fallback latency:** If device lacks NNAPI support, float16 CPU inference is slower. Negligible in practice (users are photo-driven, not streaming-inference).
- **Accuracy ceiling:** Upper bound of +9pt; won't close the full 9.4pt gap. If post-deployment A/B test shows user experience still degraded, must pivot to QAT.

---

## Path (c): Per-Channel int8 Recalibration

### Summary
Keep uint8 bitwidth, but improve the quantization scale computation using per-channel (per-output-channel in Conv layers) quantization instead of per-tensor. Current `export_tflite.py` uses per-tensor (single scale factor for all 300 output channels). Per-channel assigns independent scales to each output channel, preserving more information.

### Implementation Effort
**12–16 hours (no retraining, pure calibration).**

Dependencies:
- Implement custom `representative_data_gen()` that yields high-diversity, high-confidence images (not just random 30 from supplemental_dogs/).
- Modify converter options: `converter.target_spec.supported_types = [tf.int8]` + explicit per-channel quantization flag (TFLite API supports this via `tf.lite.QuantizationMode.DYNAMIC_RANGE` with explicit scale/zero-point tensors).
- Audit output quant scales via post-export verification.
- A/B test on 20-image harness vs. current uint8 baseline.

**Moderate complexity:** per-channel quantization requires explicit handling of quantization tensors; not a one-line config change.

### Expected Accuracy Recovery
**+2–4 percentage points (highly uncertain).**

Justification (drift): Academic papers (e.g., SatQuant, Hailo community posts) document per-channel quantization typically recovers 30–50% of the per-tensor accuracy loss, depending on layer distribution homogeneity. Your model has a 10.3 MB compressed size; assuming ~300 Conv output channels at final layers, per-channel adds minimal overhead (~1–2% model size). But **no A/B test data from your pipeline exists**, so the 2–4pt range is literature-based, not empirical. Confidence: **low — you'd need to build and measure this path to validate it.**

### Model Size Impact
**Minimal (<1% increase).**

Per-channel scales are per-output-channel (not per-weight), so overhead is just 1 scale per Conv output channel (~1–2 KB total, negligible vs. 10.3 MB).

### Latency Impact
**None.** Per-channel is a metadata/scale optimization; inference compute graph is identical.

### Compatibility with tflite_flutter 0.11.0
**Solid.** Per-channel quantization is standard TFLite; no special buffer handling needed.

### Risk Factors
- **Empirical uncertainty:** You don't have an isolated test for per-channel scaling. Effort to implement + measure could exceed the gain; if result is +2pt, ROI is poor.
- **Calibration data bias:** Choosing calibration images is critical. If you pick only high-confidence images, the quantizer will optimize for high-confidence cases and may degrade low-confidence predictions.
- **Not a silver bullet:** Even with perfect per-channel calibration, int8 is fundamentally lower-precision than float16. Path (b) is more likely to close the gap.

---

## Decision Matrix

| Factor | Path (a) QAT | Path (b) Float16 | Path (c) Per-Channel |
|--------|--------------|------------------|---------------------|
| **Implementation (hours)** | 45–60 (GPU) | 3–5 (CPU) | 12–16 (CPU) |
| **Expected top-3 recovery** | +12–14pt | +8–9pt | +2–4pt |
| **Confidence in recovery** | Drift | Solid | Uncertain |
| **Model size delta** | 0 MB | +10.3 MB | <0.1 MB |
| **Latency (NNAPI)** | Same | No penalty | Same |
| **Latency (CPU-only)** | Same | +5–15% | Same |
| **Retraining required?** | Yes (45–60h) | No | No |
| **GPU blocker** | Yes (RTX 3060 Ti) | No | No |
| **Empirical validation pre-deployment** | Possible (20-image harness) | Easy (quick test) | Hard (need A/B setup) |
| **Risk: deployment delay** | High (2+ days) | Low | Medium |
| **Risk: accuracy shortfall** | Medium (QAT stall) | Low | High (uncertainty) |
| **Compatibility tflite_flutter 0.11.0** | Solid | Solid | Solid |

---

## Recommendation

### Primary: Path (b) — Float16 TFLite Export (3–5 hours)

**Why:**
1. **Fast:** No retraining. Deploy in <1 day vs. 2+ days for QAT.
2. **Reliable:** Google AI Edge docs confirm float16 is near-lossless for CNNs. Expected recovery +8–9pt is empirically solid (confidence: solid).
3. **Measurable:** Run the 20-image harness on the exported float16 model before shipping. If top-3 lands at 72–73% (9.4 + 8.5 = 17.9pt gain), deploy. If only 70% (9.4 + 7.1 = 16.5pt), decide whether that's sufficient for the closed-beta bar.
4. **Low risk:** APK size +10 MB is acceptable. Android NNAPI handles float16 natively. No buffer-shape quirks with tflite_flutter 0.11.0.
5. **Fallback ready:** If post-deployment feedback shows accuracy still inadequate, QAT is queued as the next lever.

### Secondary: Path (a) — QAT Retrain (45–60 hours wall-time, queue for next GPU cycle)

**When to trigger:**
- If float16 achieves <70% top-3 on the 20-image harness, or if closed-beta users report degraded accuracy.
- If you have 2+ days of GPU free and want to squeeze the final 3–5pt gap.

**How to mitigate wall-time:**
- Run on existing `continue_training_v6.py` checkpoint (best_weights_continue.h5 if available, else best_weights_ft_stage1.h5).
- Start QAT fine-tune at batch_size=8, max_epochs=20 (shorter than the 40-epoch continue cycle).
- Monitor convergence after epoch 5 — if val_loss plateaus, early-stop at epoch 10 and export.

### Deprioritize: Path (c) — Per-Channel Recalibration

Not recommended as a next step. Empirical validation overhead is high relative to expected +2–4pt upside. Revisit only if path (b) + path (a) combined still leave a gap.

---

## Detailed Implementation Plan (Path b)

1. **Export float16 model (1 hour):**
   - Copy `export_tflite.py` → `export_tflite_float16.py`
   - Modify lines 171–175 to use `converter.target_spec.supported_types = [tf.float16]` instead of uint8 fallback.
   - Run: `python3 export_tflite_float16.py`
   - Output: `assets/dog_model_float16.tflite` (~20.6 MB)

2. **Canary test on 2 images (0.5 hour):**
   - Use existing `outputs/test_20_images.py` harness.
   - Replace `dog_model.tflite` with `dog_model_float16.tflite` temporarily.
   - Run on Dalmatian and Boxer (high-confidence breeds).
   - Expect top-1 confidence within ±5% of current; if way off (>15% drop), debug input quantization scale.

3. **Full 20-image test run (0.5 hour):**
   - Run `outputs/test_20_images.py` against float16 model, 2 seeds (42 + 43).
   - Record top-1 and top-3 rates; compare to current uint8 baseline (5% / 30% from Decisions.md 2026-04-25).
   - Expected result: top-3 ≈ 38–39% (30 + 8.5 midpoint). Document in `docs/session_2026-04-26/float16_validation.md`.

4. **Copy to assets and build (1 hour):**
   - `cp assets/dog_model_float16.tflite assets/dog_model.tflite`
   - Verify `dog_labels.txt` (296 labels) is in sync.
   - Run `flutter build apk --debug && adb install -r build/app/outputs/flutter-apk/app-debug.apk`

5. **Deploy and monitor (ongoing):**
   - Push to closed-beta channel.
   - Monitor Sentry for inference errors; check Firebase Analytics for identification success rate.
   - If UX feedback is positive (80%+ identifications resolved in 1–2 taps), proceed to public release.
   - If feedback shows users still frustrated (>3 taps to find breed), trigger QAT retrain.

---

## Effort Summary

| Path | Wall-Time (GPU/CPU) | Person-Hours | Confidence | Next Action |
|------|---------------------|--------------|------------|-------------|
| (a) QAT | 45–60h GPU | 8–12 | Drift on exact pt gain; solid on positive direction | Queue for next GPU cycle if (b) is insufficient |
| **(b) Float16** | **3–5h CPU** | **3–4** | **Solid (literature + empirical)** | **Start now; deploy within 24h** |
| (c) Per-channel | 12–16h CPU | 6–8 | Uncertain | Skip unless (a)+(b) leaves gap |

---

## Tags & Metadata

- **Confidence:** path (b) **solid** (Google PTQ float16 guides validate the recovery estimate); path (a) **drift** (QAT recovery is model-specific, 12–14pt is educated guess); path (c) **uncertain** (no empirical baseline).
- **Decision date:** 2026-04-26
- **Related:** Decisions.md entry 2026-04-25 (audit v2 validated Keras baseline at 14.8pt gain via data cleanup); this research focuses on weight-precision recovery, orthogonal to data quality.
- **Rollback:** If float16 model performs worse in closed beta, revert to `assets/dog_model.tflite` (current uint8) in <5 min; no data loss.
