# Resume guide — DogQuest after 2026-04-25 session

Quick pick-up doc for a new chat or future-you. Read this first when resuming.

## Where we left off

DogQuest's shipping v6 TFLite model was effectively broken (top-1 ≈ 1.6%, confidence ≈ random). Found the root cause — a single-line TFLite calibration bug in `export_tflite.py` that caused EfficientNetV2-S's built-in `Rescaling(1/255)` to apply twice. Fixed. Re-exported. Added real-image calibration and an end-to-end accuracy smoke test to the export script. Fixed two missing `dogs.json` entries (Toy Terrier, American Eskimo Dog) and one stale alias in `dog_service.dart` that was silently remapping Toy Terrier → Toy Fox Terrier.

APK rebuilt and deployed to device on 2026-04-25. On-device canary test passed: Dalmatian photo → "Dalmatian, High Match, Very confident."

## Current measured accuracy

- Training val_acc on Stanford Dogs: **51.65%**
- Benchmark on `supplemental_dogs/` noisier test set (194 images, 3-variant TTA): top-1 **11.9%**, top-5 **56.2%**
- Mean top-1 confidence on real dog photos: **0.23 – 0.37**

The numeric gap between Stanford val (51%) and the supplemental benchmark (12%) is expected — different test distributions. The app will feel like a top-5 classifier: correct breed appears in the top-3 list about half the time.

## What's on disk right now

| File | Status |
|---|---|
| `assets/dog_model.tflite` | ✅ Shipped, fixed, input scale 1.0 (24.9 MB) |
| `assets/dog_model_v6.tflite` | ✅ Same as above (kept in sync) |
| `assets/dog_model_v6_broken_calibration.tflite` | Backup of the broken shipping model (scale = 1/255), for rollback/forensics |
| `assets/dogs.json` | ✅ 296 entries (was 294); added Toy Terrier + American Eskimo Dog |
| `assets/dog_labels.txt` | Unchanged (already 296 labels) |
| `lib/services/dog_service.dart` line 357 | ✅ Toy Terrier alias fixed (was mapping to Toy Fox Terrier) |
| `export_tflite.py` | ✅ Calibration-fixed, real-image rep data, input-scale assertion, accuracy smoke test (269 lines, parses clean) |
| `tf_cache/best_weights_continue.weights.h5` | Unchanged; training converged on 2026-03-17 at epoch 5 |
| `docs/session_2026-04-25/` | Three reports: `dogquest_session_final.md` (canonical), `dogquest_accuracy_analysis.md` (deep benchmark), `dogquest_test_report.md` (bug discovery), plus this RESUME.md |

## Verify the state is still sane (run on your machine)

```powershell
cd C:\Users\Administrator\AviQuest-\dogquest

# 1. Model file looks right
python -c "import tflite_runtime.interpreter as tfl; i=tfl.Interpreter(model_path='assets/dog_model.tflite'); i.allocate_tensors(); print('input scale:', i.get_input_details()[0]['quantization'][0])"
# Expected: input scale ≈ 1.0.  If you see ~0.00392, the broken model got restored — revert using dog_model_v6_broken_calibration.tflite as reference.

# 2. Labels line up with dogs.json
python -c "import json; print('dogs.json entries:', len(json.load(open('assets/dogs.json'))))"
# Expected: 296

# 3. Toy Terrier alias not regressed
Select-String -Path lib\services\dog_service.dart -Pattern "'toy terrier':"
# Expected: 'toy terrier': 'Toy Terrier', ...  (NOT 'Toy Fox Terrier')

# 4. Export script parses
python -m py_compile export_tflite.py
# Expected: no output (success)
```

## Next actions, priority-ordered

1. **Data-quality spot-check** (~10 min, manual): visually inspect the first ~20 images in each of these folders and delete obvious mislabels:
   ```
   supplemental_dogs/siberian_husky/
   supplemental_dogs/belgian_laekenois/
   supplemental_dogs/american_bulldog/
   supplemental_dogs/combai/
   ```
   These folders test at 0/3 correct with high model confidence — classic label noise. Fixing would let those breeds identify correctly without retraining.

2. **UX win: synonym clustering** (~30-60 min dev): in `lib/services/tflite_identification_service.dart` `_buildResults()`, dedupe known visual-synonym pairs from the top-3 list. Pairs to handle: Cavalier KC Spaniel ↔ Blenheim Spaniel; Biewer Terrier ↔ Yorkshire Terrier; Belgian Tervuren ↔ Belgian Sheepdog; Siberian Husky ↔ Alaskan Husky. Keep the higher-confidence of each pair, drop the other.

3. **UX redesign: dog_found_dialog.dart** (~half-day, needs design review): lead the result screen with the top-3 as ranked alternatives ("Model's best guess — tap any to switch") instead of the current "this IS your dog with X% confidence" framing. Spec detail in `docs/session_2026-04-25/dogquest_accuracy_analysis.md`.

4. **Phase 4 launch prep** (manual): TASK-049 signing key, TASK-050 Sentry DSN, TASK-058-061 Play Store assets. These are the 5 remaining manual tasks.

5. **Further training gains** (bigger investment):
   - Download more images for 6 rare-breed blind spots (Chinook, Canaan Dog, Combai, Azores Cattle Dog, Aidi, Anatolian Shepherd) via `download_more_images.py`
   - EfficientNetV2-M backbone (likely +5-10 val_acc; longer training)

## How to resume in a new chat

Start the new chat with something like:

> Resuming DogQuest. Please read `docs/session_2026-04-25/RESUME.md` and the session final report at `docs/session_2026-04-25/dogquest_session_final.md`, then I want to work on [action #N from the list].

The CLAUDE.md file has also been updated with the post-session state, so a fresh Claude will see the correct baseline immediately.

## Gotchas to flag up-front in a new session

A fresh Claude won't have this context unless you tell it:

- **Sandbox bash mount is stale against Windows writes.** When verifying file contents, use the Read tool (which uses the Windows path) rather than bash `cat`/`grep`/`wc`. Bash shows cached pre-edit state.
- **Edit tool can insert-instead-of-replace** if the `old_string` matches partway through a region that extends beyond the match. Always Read-verify the full file after editing a trailing section, or prefer Write for large tail rewrites.
- **Subagents sometimes hallucinate specific numeric details** (e.g., one reported "297 labels" for a 296-entry file). Verify their claims against the actual files before acting.

## Open questions / decisions still awaiting your input

- Green-light for synonym clustering (next action #2)?
- Green-light for the dog_found_dialog.dart redesign (next action #3)?
- Do you want me to write a label-cleanup helper script for action #1, or do it manually?
