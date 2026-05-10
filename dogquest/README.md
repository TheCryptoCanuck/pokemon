# Hound

Flutter-based dog breed identification and collection game for Android. Point your camera at any dog (yours, a stranger's, a photo) and Hound's on-device TFLite model identifies the breed, awards XP, and adds it to your collection.

The deployed model identifies **150 dog breeds** (v5.1 EfficientNetB2, ~10.8 MB, 87.2% accuracy on the Stanford val set). The in-training v6 (EfficientNetV2-S) targets **294 breeds**.

Layered on top of breed ID: gamification (XP, combos, streaks, mastery, daily/flash challenges, mystery rewards, achievements), a social layer (Pack family co-ownership, Dog Friendships, Neighborhood Map, breed communities, playdate matcher), shareable Dog Passport cards, Lost Dog reporting with map heat-view, and a Demo mode for store screenshots. Local-first with Hive; Supabase planned for real-time social.

## Quick start

```bash
git clone <repo-url> && cd dogquest
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Or use the Makefile (30+ targets, run `make help` or `make menu` for an interactive picker):

```bash
make build       # debug APK
make install     # build + adb install + launch
make logs        # tail filtered logcat
make test        # flutter test
make analyze     # static analysis
make screenshots # capture per-screen via adb
```

## Tech stack

- **Framework**: Flutter (Dart 3.x), Android (iOS untested)
- **State**: Riverpod (`ConsumerWidget` / `ConsumerStatefulWidget`)
- **Routing**: go_router with auth gate + StatefulShellRoute
- **Storage**: Hive (NoSQL, AES-encrypted sightings box, prefix `dogquest_`)
- **Auth**: Hive-local (Supabase Auth migration in progress)
- **ML**: tflite_flutter 0.11.0, uint8-quantized EfficientNetB2 v5.1
- **Maps**: flutter_map + OSM tiles, latlong2, geolocator
- **Observability**: Firebase Analytics, Sentry (DSN wiring is T1 work)
- **Backend**: Supabase planned (real-time, auth, PostgreSQL, storage)

## Project structure

```
dogquest/
├── lib/
│   ├── main.dart              # Entry, provider init, ~20 services wired
│   ├── router.dart            # go_router with auth gate
│   ├── constants.dart         # Rarity enum, colors, achievements, breed sets
│   ├── models/                # 6 models (Dog, Sighting, Pack, etc.)
│   ├── screens/               # 32 screens
│   ├── services/              # 57 services
│   ├── helpers/               # date/game/ui helpers
│   └── widgets/               # 92 widgets across feature subfolders
│       ├── identify/          # camera/capture UI
│       ├── lost_dog/          # report card, map view, tabs
│       ├── map/               # neighborhood, sightings, friends list
│       ├── pack/              # pack header, members, dogs sections
│       ├── profile/           # user greeting, mastery, achievements
│       └── quiz/              # question card, result view, timer
├── test/                      # 22 test files (unit, performance, quiz)
├── assets/
│   ├── dogs.json              # 147 breed db entries (working toward 294)
│   ├── dog_labels.txt         # 150 labels (deployed v5.1 output order)
│   └── dog_model.tflite       # Deployed: v5.1 (150 breeds, 10.8 MB)
├── supplemental_dogs/         # 181 breed folders, 37,511 training images
├── train_model_v6.py          # v6 training (EfficientNetV2-S, progressive 224→300)
├── audit_supplemental.py      # TFLite-driven image quality auditor
├── CLAUDE.md                  # Full project intelligence (start here for AI/contributors)
└── Makefile                   # Build/deploy/lint/test/ML targets
```

## Documentation

- **`CLAUDE.md`** — full project intelligence: tech stack, conventions, build pipeline, ML pipeline, known issues, AKC group taxonomy. Primary onboarding doc for any contributor (human or AI).
- **`docs/`** — strategy docs, business-case writeups, session-by-session ML/audit/redesign specs (`docs/session_2026-04-25/`, `docs/session_2026-04-26/`).
- **`.full-review/`** — comprehensive multi-axis code review output (security, architecture, performance, testing, docs, CI/CD). Final report at `.full-review/05-final-report.md`.
- **`.second_brain/`** — internal vault: project context, active tasks, decisions log, failure patterns, prompt templates. Not for external readers; the working source-of-truth across Claude/Cowork sessions.

## Build target

- **App ID**: `com.hound.app`
- **Min Android**: 21 (Android 5.0)
- **Target Android**: 34 (Android 14)
- **Flutter SDK**: `>=3.0.0 <4.0.0`

## ML pipeline notes

- TFLite expects **uint8 input** (0-255), not float32. uint8 output divided by 255.0 for confidence.
- Image preprocessing: EXIF bake → scale → 5-crop → resize (260x260 v5; 300x300 v6).
- v5 TTA: 5-crop × flip = 10 variants averaged.
- ML inference offloaded to isolate via `compute()`.
- Camera must fully dispose + reinitialize after `takePicture()` (controller reuse causes hangs).

For v6 retraining, see `TRAIN_ON_GPU.md` and `train_model_v6.py`. Audit pipeline at `audit_supplemental.py` (auto-detects model input size from TFLite metadata).

## Status

Pre-closed-beta. Posture is quality-first with closed beta as the feedback loop (locked 2026-04-25). T1 surface: CI/CD wiring, signing key, Sentry DSN, README/CLAUDE.md hygiene. See `.second_brain/03_Projects/Active_Tasks.md` for the live task list.

## License

Not yet licensed. All rights reserved by the owner pending license selection.
