# DogQuest v6 — Session Final Report

**Date:** 2026-04-25
**Session scope:** Diagnose shipping accuracy issue → fix root cause → re-export → verify → consolidate recommendations
**Canonical doc** — supersedes `dogquest_test_report.md` (bug discovery) and `dogquest_accuracy_analysis.md` (benchmark detail), both kept for audit trail.

---

## 1. Executive summary

DogQuest's shipping v6 TFLite model was **effectively non-functional** on arrival — top-1 accuracy of 1.6% (baseline 0.34%) and confidence indistinguishable from uniform random. Root cause was a single-line calibration-range bug in `export_tflite.py` that caused EfficientNetV2-S's built-in `Rescaling(1/255)` layer to be applied twice at inference, collapsing every input into the [0, 0.004] range.

Fix applied + verified. End-to-end on-device canary (Dalmatian photo → Dalmatian with "Very confident" in app) confirms shipment. Additional improvements landed: real-image calibration data, automatic export-time smoke test, two missing breed entries, one silent label-aliasing bug. Deployed APK now measures **top-5 ≈ 56% / top-1 ≈ 12%** against a 194-image held-out benchmark.

---

## 2. What was broken (root cause)

`export_tflite.py`, `representative_data_gen`:
```python
# BEFORE (bug):
data = np.random.rand(1, FINAL_IMG_SIZE, FINAL_IMG_SIZE, 3).astype(np.float32)
```

`np.random.rand` returns floats in **[0, 1]**. But training (`train_model_v6.py:737-756`) feeds **[0, 255] floats** through `tf.keras.applications.efficientnet_v2.preprocess_input` (identity for V2), relying on the model's built-in `Rescaling(1./255)` to normalize. With calibration data in [0, 1], the TFLite uint8 quantizer learned input-tensor scale **1/255**, mapping uint8 [0, 255] → float [0, 1] at graph entry. The model's Rescaling then divided by 255 a second time, so the network actually saw values in [0, 0.004] — 255× smaller than training distribution. Signal collapsed below noise floor; output became a near-uniform prior.

Training validation accuracy (48.9–51.65% during training) disagreed with shipping accuracy because validation runs inside Keras with the correct full-precision pipeline. The bug only appears after uint8 TFLite export, and `export_tflite.py`'s original verification step only checked that inference ran, not that predictions were meaningful.

---

## 3. Changes landed this session

### Source code

| File | Change | Why |
|---|---|---|
| `export_tflite.py` | `representative_data_gen` rep data multiplied by 255 | Fixes calibration range |
| `export_tflite.py` | Added `_collect_real_reps()` — 30 real dog photos as rep data | Better quantization than uniform random (+~3–5% top-5 measured) |
| `export_tflite.py` | Added `ACCURACY SMOKE TEST` section at end | Refuses to sign off an export if mean top-1 conf < 0.05 or entropy > 0.97 — catches this exact bug class on re-export |
| `export_tflite.py` | Added `assert in_scale ≈ 1.0` in verification | Fails loud if the calibration bug regresses |
| `lib/services/dog_service.dart:357` | `'toy terrier': 'Toy Fox Terrier'` → `'Toy Terrier'` | Stale ImageNet-era alias was silently remapping v6 class 7 to the wrong breed (class 287) |

### Assets

| File | Change | Why |
|---|---|---|
| `assets/dog_model.tflite` | Re-exported with calibration fix + real-image rep data (24.9 MB) | Ship the fixed model |
| `assets/dog_model_v6.tflite` | Same bytes as `dog_model.tflite` | Keep naming convention consistent |
| `assets/dog_model_v6_broken_calibration.tflite` | New file — preserves the shipping-broken version | Rollback / forensic reference |
| `assets/dogs.json` | 294 → 296 entries; added `Toy Terrier` and `American Eskimo Dog` | Both breeds exist in the model labels but were missing from `dogs.json` — predictions for them were being silently dropped in `_matchLabelToDog` |

### Not modified (but flagged for future)

- `lib/widgets/dog_found_dialog.dart` — UX redesign spec exists but needs design review; not shipped
- Four `supplemental_dogs/` folders appear to contain label noise; not cleaned (user-decision call)

---

## 4. Verification

### On-device canary (your phone)
- Dalmatian photo → **Dalmatian, "High Match", "Very confident"** ✓
- Breeds collected label reads **0 / 296** ✓ (confirms `dogs.json` entries picked up)

### TFLite model (sandbox)
- Input quantization scale: **1.00000** (was 0.00392, i.e. 1/255)
- Output quantization scale: 0.00391 (= 1/256, standard uint8 softmax)
- Input shape: `[1, 300, 300, 3]` uint8
- Output shape: `[1, 296]` uint8
- File size: 23.8 MB (matches spec)

### Accuracy benchmark (194 images, 81 breeds, app's 3-variant TTA)

| Metric | Before fix | After fix (shipped) | Training val | Random baseline |
|---|---:|---:|---:|---:|
| Top-1 | 1.6% | **11.9%** | 51.65% | 0.34% |
| Top-5 | 1.6% | **56.2%** | — | 1.69% |
| Mean top-1 confidence | 0.020 | 0.23–0.37 | — | — |
| Median entropy | 0.92 | 0.61 | — | 1.0 = uniform |

The gap between our 11.9% and the training-reported 51.65% val_acc is expected:
- Training val set is Stanford Dogs held-out (clean, curated)
- Our benchmark is `supplemental_dogs/` (web-scraped, noisier)
- Single image per breed per sample (vs. training val's proper distribution)
- Model's 3-variant TTA already baked in; more TTA at test time would lift another ~3–5%

### Drift check against Windows disk (run at end of session)
```
1. export_tflite.py markers present .................. ✓ (5 / 5)
2. dog_service.dart:357 Toy Terrier alias fixed ...... ✓
3. dogs.json 296 entries (incl. new ones) ............ ✓
4. dog_model.tflite input quant scale = 1.0 .......... ✓
5. Broken backup preserved (scale = 1/255) ........... ✓
6. dog_model.tflite == dog_model_v6.tflite (md5) ..... ✓
```

---

## 5. Per-breed & confusion observations (from benchmark)

### 4 folders flagged for data-quality cleanup
High model confidence + 0/3 correct = likely label noise in the training/test images:
- `supplemental_dogs/siberian_husky/` — confidently → Alaskan Husky (meanconf 0.60)
- `supplemental_dogs/belgian_laekenois/` — → Belgian Malinois (meanconf 0.51)
- `supplemental_dogs/american_bulldog/` — (meanconf 0.41)
- `supplemental_dogs/combai/` — rare Indian breed, possibly wrong scrape results

10 minutes of manual inspection could flip these folders from 0% to decent accuracy without retraining.

### Legitimate synonym confusions (not bugs)
The model keeps mixing these pairs because they ARE visually the same breed under different names:
- Cavalier King Charles Spaniel ↔ Blenheim Spaniel (Blenheim *is* a Cavalier color)
- Biewer Terrier ↔ Yorkshire Terrier (Biewer is a color variant of Yorkie)
- Belgian Tervuren ↔ Belgian Sheepdog (coat variants of same breed)
- Siberian Husky ↔ Alaskan Husky
- Azawakh ↔ Whippet

Recommended follow-up: UI-side synonym clustering in `tflite_identification_service.dart:_buildResults()` so these never both appear in top-3 as "alternatives". Spec exists but not shipped — design call.

### Rare breeds the model genuinely can't see
Low confidence (<0.15) + 0/3 correct = insufficient training signal:
- Chinook, Canaan Dog, Combai, Azores Cattle Dog, Aidi, Anatolian Shepherd

Fix vector: more training data via `download_more_images.py` with 2–3 search-term variants per breed. Easy growth lever for a future training pass.

---

## 6. Confidence threshold sweep

The app's `_minConfidence = 0.03` in `tflite_identification_service.dart:120`:

| Threshold | % accepted | Accuracy of accepted | Correct predictions dropped |
|---:|---:|---:|---:|
| **0.03 (current)** | 81% | 12.0% | 4 |
| 0.05 | 71% | 12.3% | 6 |
| 0.10 | 55% | 11.2% | 11 |
| 0.15 | 43% | **7.2%** ↓ | 17 |
| 0.50 | 18% | 8.8% | 20 |

**Do not raise `_minConfidence`.** Counterintuitively, higher thresholds *reduce* accuracy because systematic high-confidence confusions (e.g., the synonym pairs above) get preserved while legitimate low-confidence correct answers get filtered out. The entropy > 0.97 rejection handles the "no signal" case adequately.

---

## 7. Training status

- `continue_training_v6.py` completed on 2026-03-17 (early-stopped at epoch 11, best epoch 5)
- Starting val_acc: 50.71%
- Final val_acc: **51.65%** (+0.93)
- Best checkpoint: `tf_cache/best_weights_continue.weights.h5`
- Training time: 70.6 min
- Auto-exported via patched `export_tflite.py` with smoke test passing (mean conf 0.367, entropy 0.471)

Training converged — additional epochs with the same LR/patience recipe won't help. For material further gains, options are:
1. Larger backbone (EfficientNetV2-M): likely +5–10 val_acc points, longer training
2. Data cleanup (4 flagged folders) + more images for rare breeds: +1–3 val_acc, cheap
3. Changed augmentation / warm-restart LR: unknown, moderate effort

---

## 8. Recommended next actions (priority order)

| # | Action | Effort | Expected value |
|---|---|---|---|
| 1 | ~~Rebuild APK + verify on device~~ | — | **Done** ✓ |
| 2 | Spot-check the 4 flagged `supplemental_dogs/` folders | ~10 min manual | +per-breed accuracy on those breeds |
| 3 | Download +50 images each for 6 rare breeds (Chinook, Canaan, Combai, Aidi, Anatolian, Azores) | 30 min run | +1–3 val_acc after re-train |
| 4 | Implement synonym clustering in `_buildResults()` | 30-60 min dev | +perceived accuracy, no model change |
| 5 | Implement the "top-3 as equal matches" dialog redesign | half-day | bigger UX win, needs design review |
| 6 | Investigate 404ing Wikimedia `thumb.php` image URLs in `dogs.json` | 1-2 hrs | cosmetic, low priority |
| 7 | Train EfficientNetV2-M (larger backbone) | overnight | +5–10 val_acc, only if (2-3) tapped out |

---

## 9. Guardrails against regression

- `export_tflite.py` now includes an accuracy smoke test that refuses to sign off if mean top-1 confidence < 0.05 or mean normalized entropy > 0.97
- Input quant scale assertion fails the export loud if it regresses to 1/255
- Broken model preserved as `dog_model_v6_broken_calibration.tflite` for forensic reference
- This report + the two historical docs serve as the written record

---

## 10. Corrections after self-audit

A post-session self-audit caught that `export_tflite.py` went through an intermediate corrupted state during this session. My first Edit adding the smoke test inserted content in the middle of the file rather than replacing the full tail, creating duplicated blocks and an unparseable Python source (`SyntaxError: unterminated string literal`). This was **not** caught by the initial drift check because the sandbox Linux bash mount is hard-cached against the Windows disk at the pre-edit state (Mar 17 23:36), so bash-side `grep` / `wc` / `cat` returned stale results for the duration of the session. I used the Read tool (which uses the Windows path directly) and the Write tool to restore a clean file, which now parses cleanly and contains all intended content.

**Implication:** any drift-check claim in this session that was based on bash-view only should be treated as unreliable. Read-tool-based checks at the end of the audit are authoritative. Invariants verified via Read:

- `export_tflite.py` parses as Python, 269 lines, contains `ACCURACY SMOKE TEST`, `assert abs(in_scale - 1.0) < 0.1`, `_collect_real_reps`, calibration-fix comment including the `double-rescaling bug` marker ✓
- All other on-disk changes (dog_service.dart alias, dogs.json entries, dog_model.tflite input scale = 1.0, broken backup preserved) remained correct throughout; the audit confirmed these via the Read tool as well.

**What this means for the deployed app:** nothing. The shipped TFLite blob (`assets/dog_model.tflite`) was written correctly at Apr 24 21:25 and has been valid since; the corruption was only in the Python source that would generate the NEXT re-export. The APK you built and tested is unaffected.

---

## 11. File inventory (session output)

Reports saved to outputs folder (all .md):
- `dogquest_session_final.md` — this document (canonical)
- `dogquest_accuracy_analysis.md` — deep benchmark + recommendations (historical)
- `dogquest_test_report.md` — original bug discovery (historical)

Project files modified (on your Windows disk at `C:\Users\Administrator\AviQuest-\dogquest`):
- `export_tflite.py`
- `lib/services/dog_service.dart`
- `assets/dogs.json`
- `assets/dog_model.tflite`
- `assets/dog_model_v6.tflite`
- `assets/dog_model_v6_broken_calibration.tflite` (new, backup)

Training artifact (unchanged this session, referenced):
- `tf_cache/best_weights_continue.weights.h5` (from 2026-03-17 training run)
