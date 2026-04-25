# DogQuest — Project Intelligence

## Project Overview

DogQuest is a Flutter-based dog breed identification app forked from AviQuest. The deployed model identifies **150 dog breeds** (v5.1 EfficientNetB2); the in-training v6 EfficientNetV2-S targets **294 breeds**. Features include TFLite visual ML identification, deep gamification (XP, combos, streaks, mastery, daily challenges, flash challenges, mystery rewards, achievements), a social layer (dog profiles, activity feed, dogs nearby, breed communities, playdate matcher), Pack (family co-ownership), Dog Friendships, a Neighborhood Map with Live Map (OSM tiles), Lost Dog reports, shareable Dog Passport cards, and Demo mode. Local-first with Hive; Supabase backend planned for social features.

## Tech Stack

- **Framework**: Flutter (Dart)
- **Platform**: Android (iOS untested)
- **State Management**: Riverpod (ConsumerWidget pattern)
- **Navigation**: go_router with auth gate & StatefulShellRoute
- **Storage**: Hive (local NoSQL), boxes prefixed `dogquest_`, AES-encrypted sightings box
- **Auth**: Local Hive-based (Supabase Auth planned)
- **Backend**: None yet — Supabase planned (real-time, auth, PostgreSQL, storage)
- **ML Model (deployed)**: EfficientNetB2 v5.1, uint8 quantized, 260x260 input, **150 breeds** (matches `assets/dog_labels.txt`), 10.8 MB, 87.2% accuracy
- **ML Model (training target, v6)**: EfficientNetV2-S, 300x300 input, **294 breeds** target. A 296-output v6 checkpoint was trained but not shipped — see `assets/dog_labels.txt.bak` (296 lines) for the prior export. Current deployed `dog_labels.txt` is the 150-label v5.1.
- **Analytics**: Firebase Analytics (aviquest-508a6), Sentry (wired, needs DSN)
- **Key Libraries**: flutter_riverpod, go_router, flutter_animate, camera, cached_network_image, tflite_flutter 0.11.0, image_picker, permission_handler, geolocator, flutter_map, latlong2, sentry_flutter, firebase_core, firebase_analytics, hive, hive_flutter, flutter_secure_storage

## Project Structure

```
dogquest/
├── CLAUDE.md                  ← You are here
├── Makefile                   ← 30+ targets (build, deploy, lint, test, ML, menu, etc.)
├── vision.json                ← PLAID product vision intake
├── docs/                      ← PLAID-generated strategy docs
├── lib/
│   ├── main.dart              ← App entry, provider init, 20+ service wiring
│   ├── constants.dart         ← Rarity enum, colors, achievements, breed sets
│   ├── router.dart            ← go_router with auth gate & StatefulShellRoute
│   ├── models/                ← 6 models (Dog, Sighting, Player, Pack, MyDogProfile, LostDogReport, etc.)
│   ├── screens/               ← 32 screens (identify, kennel, profile, quiz, map, social, pack, passport, etc.)
│   ├── services/              ← 57 services (player, dog, kennel, sighting, ML, pack, friendship, social, sync, etc.)
│   ├── helpers/               ← 3 helpers (date_helpers, game_helpers, ui_helpers)
│   └── widgets/               ← 92 .dart files across `widgets/`, `widgets/identify/`, `widgets/lost_dog/`, `widgets/map/`, `widgets/pack/`, `widgets/profile/`, `widgets/quiz/` (post 2026-04-25 god-class extraction)
├── test/                      ← 22 test files (unit, widget, integration, performance)
├── assets/
│   ├── dogs.json              ← 147 breed database entries (working toward 294 with v6)
│   ├── dog_labels.txt         ← 150 breed labels (matches deployed v5.1 model output order)
│   └── dog_model.tflite       ← Currently deployed: v5.1 (150 breeds, 10.8 MB). Pending v6 retrain → 294 breeds.
├── supplemental_dogs/         ← 181 breed folders, 37,511 training images (post 2026-04-25 quarantine audit; 5,082 images removed)
├── train_model_v6.py          ← v6 training (EfficientNetV2-S, 294 breeds, progressive 224→300)
├── train_model_v5.py          ← v5 training (EfficientNetB2, RandAug, progressive resize)
├── audit_supplemental.py      ← TFLite image quality auditor (auto-detects model input size)
├── download_more_images.py    ← Multi-query breed image downloader
├── generate_dogs.py           ← dogs.json breed generator (294 breeds)
├── enrich_dogs.py             ← dogs.json field enrichment (fun facts, temperament, etc.)
└── .mcp.json                  ← MCP server configuration
```

## Key Features

### Gamification
- XP system with leveling and player titles
- Combos (24h discovery window), streaks, mastery per breed
- Daily challenges, flash challenges, mystery rewards
- 294-breed target collection with 4 rarity tiers: 173 common / 77 uncommon / 34 rare / 10 legendary (deployed v5.1 surfaces 150 of these; v6 retrain unlocks the remaining 144)
- 18 themed breed sets (Snow Pack, Tiny Titans, etc.)
- Achievements including "collect all 294 breeds" (target — gates on v6 deployment)
- Demo mode with 26 pre-seeded breeds and 42 sightings (activate in Settings)

### Social Layer
- `dog_social_service.dart` — Core social logic
- `dog_feed_screen.dart` — Activity feed
- `dogs_nearby_screen.dart` — Discover nearby users
- `breed_community_screen.dart` — Breed-specific communities
- `playdate_matcher.dart` — Match dogs for playdates
- `map_tab.dart` + `lost_dog_map_screen.dart` — Live Map with flutter_map + OSM tiles

### Dog Management
- Dog Passport cards (shareable)
- Pack (family co-ownership)
- Dog Friendships with Neighborhood Map
- Lost Dog reports and alerts

## Breed Expansion (294-breed target — v6 in training)

- **294 breeds target**: 120 Stanford Dogs + 174 supplemental (181 folders, 37,511 images post-audit)
- **Currently deployed**: 150 breeds (v5.1). The 294-breed gate is the v6 retrain landing.
- `dogs.json`: 147 entries currently populated; full 294 enrichment pending v6 (`enrich_dogs.py`)
- `dog_labels.txt`: 150 deployed labels (matches v5.1 output order). `dog_labels.txt.bak` retains the prior 296-output v6 attempt.
- `dog_service.dart`: 188+ name aliases mapping model labels to breed names
- `dog_group_service.dart`: 7 AKC groups expanded for the full 294 target
- `breed_collection_service.dart`: 18 themed breed sets (some require v6 breeds to be reachable)
- **v6 model training** (EfficientNetV2-S): ~10+ hours on CPU; GPU path validated (RTX 3060 Ti) for ~10× audit-time speedup

## Critical Technical Notes

- TFLite model expects **uint8 input** (0-255), NOT float32
- TFLite uint8 output must be divided by 255.0 for confidence
- Image preprocessing: EXIF bakeOrientation + scale + 5-crop + resize (260x260 for v5, 300x300 for v6)
- v5 TTA: 5-crop (center + 4 corners) x flip = 10 variants averaged
- Camera: must fully dispose + reinitialize after takePicture()
- **tflite_flutter 0.11.0**: output buffers MUST use `List.filled(n, 0.0).reshape()`, NOT `Float32List`
- **LocationFilterService DISABLED** — dog breeds are globally distributed
- Name aliases in `dog_service.dart` map model labels to breed names in `dogs.json`
- Dog images: use `thumb.php` Wikimedia API (CDN `/thumb/` URLs return 429)
- Hive boxes prefixed `dogquest_` to avoid collision with AviQuest
- ML inference offloaded to isolate via `compute()`
- JWT stored in FlutterSecureStorage; Hive sightings box AES-encrypted
- `audit_supplemental.py`: auto-detects model input size from TFLite metadata

## Testing

22 test files covering:
- **Models**: `dog_test.dart`
- **Services**: breed_collection, combo, demo, dog_friendship, dog_mastery, dog_service, kennel, lost_dog, mystery_reward, pack, player, sighting, tflite_identification, sync_services, supabase_social
- **Performance**: `perf_benchmark_test.dart`
- **Quiz**: `quiz_engine_test.dart`, `quiz_screen_test.dart`
- **Other**: `ad_service_test.dart`, `tflite_identification_service_test.dart`

## Build & Deploy

```bash
# Quick build & install (or use Makefile targets)
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.dogquest.app/.MainActivity
```

- **App ID**: `com.dogquest.app`
- **Makefile**: 30+ targets — run `make help` or `make menu` for interactive selection
- Key targets: `make build`, `make install`, `make logs`, `make test`, `make lint`, `make screenshots`

## Known Issues (from audit)

- Offline login accepts any password if email matches (`auth_service.dart:71-80`) — will be replaced by Supabase Auth
- PII (username, email) in unencrypted Hive box while JWT is encrypted (`auth_service.dart:27-30`)
- Default dev API URL ships in release builds if `--dart-define` omitted (`api_client.dart:16`)
- 11 files over 800 lines remain (down from earlier; `quiz_screen.dart` 1,648 → 1,042 via TASK-046; `lost_dog_hub_screen.dart` 1,665 → 127 via 2026-04-25 god-class extraction). Largest remaining: `lost_dog_map_screen.dart` 1,390, `profile_screen.dart` 1,268, `pack_screen.dart` 1,253. T5 polish queue.

## Key Differences from AviQuest

- No audio identification (BirdNET removed)
- No backend sync (local-first; Supabase backend planned)
- Firebase Analytics present (not removed — firebase_core + firebase_analytics in pubspec)
- 7 AKC breed groups replace 14 bird families
- Routes: `/aviary` → `/kennel`
- Dog-themed achievements, player titles, avatars
- Additional features: Pack, Dog Friendships, Neighborhood Map, Dog Passport, Lost Dog, Social Layer, Demo Mode
