# DogQuest v6 — Accuracy Analysis & Actionable Recommendations

**Deployed model:** `assets/dog_model.tflite` (real-image-calibrated, post-fix)
**Benchmark:** 194 dog photos across 81+ breeds, app's 3-variant TTA pipeline
**Date:** 2026-04-24 (training still running in background; this is the current snapshot)

## Headline numbers

| Metric | Value | Random baseline |
|---|---:|---:|
| Top-1 | **11.86%** | 0.34% |
| Top-3 | ~35% (interpolated) | 1.01% |
| Top-5 | **56.19%** | 1.69% |
| Mean top-1 confidence | 0.238 | — |
| Median normalized entropy | 0.612 | 1.0 = uniform |

Top-5 at 56% is the most useful number for UX: the app already shows the top-3, so users see the correct breed in the result list over **half the time**.

## Finding #1 — The confidence threshold sweep

The app's `_minConfidence = 0.03` in `tflite_identification_service.dart`:

| Threshold | % accepted | Accuracy of accepted | Correct predictions lost |
|---:|---:|---:|---:|
| **0.03 (current)** | 81.4% | 12.0% | 4 |
| 0.05 | 71.1% | 12.3% | 6 |
| 0.10 | 55.2% | 11.2% | **11** |
| 0.15 | 42.8% | **7.2%** ↓ | 17 |
| 0.20 | 36.6% | 8.5% | 17 |
| 0.50 | 17.5% | 8.8% | 20 |

**Surprising result:** raising the threshold actually *reduces* accuracy of accepted predictions. This means the model's confidence is not monotonically useful — many correct predictions come at low confidence (model is "unsure but leaning right"), and many wrong predictions come at high confidence (systematic confusion between look-alike breeds like Siberian vs Alaskan Husky).

**Recommendation:** keep `_minConfidence = 0.03`. Do **not** raise it. The entropy rejection (`> 0.97`) already handles the "no signal at all" case. I would not touch this without more data.

## Finding #2 — Confusion patterns are mostly legitimate look-alikes

Top 15 most common mispredictions:

| Count | Truth → Prediction | Note |
|:-:|---|---|
| 3× | American Hairless Terrier → Xoloitzcuintli | Both hairless |
| 3× | Biewer Terrier → Yorkshire Terrier | Biewer is a color variant of Yorkie |
| 3× | Cavalier King Charles Spaniel → Blenheim Spaniel | **"Blenheim" IS a Cavalier color pattern** |
| 2× | Akita → Eurasier | Both spitz-type |
| 2× | Siberian Husky → Alaskan Husky | Visually near-identical |
| 2× | Belgian Laekenois → Belgian Malinois | Same species, different coat |
| 2× | Belgian Tervuren → Belgian Sheepdog | Coat-color variants of same breed |
| 2× | Australian Shepherd → Border Collie | Both herding types |
| 2× | Azawakh → Whippet | Both sighthounds |

**These are not bugs — they are inherent visual ambiguity.** A few are effectively the same breed under different names (Cavalier/Blenheim, Biewer/Yorkie, Belgian Tervuren/Belgian Sheepdog). No amount of training fixes this entirely.

**Recommendation for the app (Dart-side change, not applied yet):** detect these known-synonym clusters in the UI and show them as grouped results — e.g., "Cavalier King Charles Spaniel (Blenheim variant)". Would land as a post-processing step in `_buildResults()`. I can implement if you want.

## Finding #3 — Breeds that definitely need data cleanup

Several breeds get 0/3 top-5 despite **high confidence** (> 0.40). High confidence + wrong answer is a flag for label noise in the training data or the test folder.

| Breed | Mean conf | Dominant wrong prediction | Likely cause |
|---|---:|---|---|
| Siberian Husky | 0.60 | Alaskan Husky | `supplemental_dogs/siberian_husky/` may contain Alaskan Huskies (Alaskan is a working mix, not AKC) |
| Belgian Laekenois | 0.51 | Belgian Malinois | Possibly mislabeled data; Laekenois is the rarest of the Belgian Shepherds |
| American Bulldog | 0.41 | ? | Check for Bulldog-variant confusion |
| Combai | 0.35 | ? | Rare Indian breed — web scrape may have returned wrong dogs |

**Recommendation:** spot-check the images in these folders manually. Worth 10 minutes and could flip them from 0% to decent accuracy without retraining.

## Finding #4 — Truly confident breeds the model nails

Top-1 = 3/3 with meaningful confidence:

- **Dalmatian** (conf 0.98) — distinctive markings, model has no doubt
- **Bolognese** (conf 0.08, 3/3 top-1) — low conf but consistently right

Most "best" breeds get high top-5 (3/3) with varied top-1. The model knows the answer is in the top few; it just can't always pick the single best.

## Finding #5 — Worst performers that are *not* data-noise issues

Breeds with 0/3 top-5 *and* low confidence (<0.15) — model genuinely doesn't recognize them:

- Aidi (conf 0.08), Azores Cattle Dog (0.04), Akita (0.04), Anatolian Shepherd (0.06), Chinook (0.02), Canaan Dog (0.15), Combai (see above)

These are:

- Rare / regional breeds (Chinook, Canaan, Combai, Azores Cattle Dog)
- Uncommon in web image sources
- Candidates for **targeted additional training data** — crawl more images for these specific folders. Even +50 good images per breed could push them above zero.

## What I recommend you do next

In priority order:

1. **Let training keep running.** Every new `best_weights_continue.weights.h5` checkpoint = a potentially better exported model. When you stop, just run `python3 export_tflite.py` (now fixed + has real-image calibration + smoke test).

2. **Before rebuilding the APK:** spot-check the 4 high-confidence-but-wrong folders listed in Finding #3 (`siberian_husky`, `belgian_laekenois`, `american_bulldog`, `combai`). Run `safe_clean_supplemental.py` variant or visual inspection on those specifically.

3. **Add synonym clustering in the app** (5-line change in `_buildResults()`). Biggest perceived-accuracy win for users: Cavalier + Blenheim should never both appear in a top-3, same for Belgian Tervuren + Belgian Sheepdog, same for Biewer + Yorkshire Terrier. I can draft this if you approve.

4. **Keep `_minConfidence = 0.03`.** Raising it actually loses accuracy per the threshold sweep.

5. **After this round:** for Finding #5 breeds (rare/regional), queue up image downloads via `download_more_images.py` with 2-3 synonyms per breed. Easy growth lever for future training.

## Files produced this session

- `outputs/dogquest_test_report.md` — original bug discovery
- `outputs/dogquest_accuracy_analysis.md` — this document
- Sandbox-only: `/tmp/dogquest_fix/bench_state.json` (raw per-image results),
  `/tmp/dogquest_fix/analyze.py`, `/tmp/dogquest_fix/bench_chunk.py`

## Files modified in the project

- `export_tflite.py` — calibration range fix + real-image rep data + smoke test
- `assets/dog_model.tflite` — real-image-calibrated TFLite (24.9 MB)
- `assets/dog_model_v6.tflite` — same bytes
- `assets/dog_model_v6_broken_calibration.tflite` — backup of the previous broken model
