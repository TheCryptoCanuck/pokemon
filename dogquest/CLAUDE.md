# DogQuest — Project Intelligence

## Project Overview

DogQuest is a Flutter-based dog breed identification app. The deployed model identifies **150 dog breeds** (v5.1 EfficientNetB2); the in-training v6 EfficientNetV2-S targets **294 breeds**. Features include TFLite visual ML identification, deep gamification (XP, combos, streaks, mastery, daily challenges, flash challenges, mystery rewards, achievements), a social layer (dog profiles, activity feed, dogs nearby, breed communities, playdate matcher), Pack (family co-ownership), Dog Friendships, a Neighborhood Map with Live Map (OSM tiles), Lost Dog reports, shareable Dog Passport cards, and Demo mode. Local-first with Hive; Supabase backend planned for social features.

## Repo layout (monorepo)

DogQuest is a subproject of the **`TheCryptoCanuck/boring`** monorepo (private). Sibling subprojects under the same root include `backend/`, `infrastructure/terraform/`, `ml/`, `docs/`, `agents/`, and `.ui-design/`.

- **Git root:** the monorepo root, one directory above `dogquest/` — NOT `dogquest/` itself.
- **CI workflows:** live at the repo root in `<repo-root>/.github/workflows/`, NOT `dogquest/.github/`. The DogQuest CI yml scopes flutter commands via `defaults.run.working-directory: ./dogquest`.
- **Run git from the repo root.** From `dogquest/`, `git log -- PATH` resolves PATH cwd-relative and silently misses repo-root paths like `.github/workflows/`. Use absolute paths or `cd $(git rev-parse --show-toplevel)` first. (See `.second_brain/01_Memory/Failure_Patterns.md → git-log-cwd-relative-path-arguments`.)
- **Active branch:** `phase-1/social-backend-realtime`.

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
- **Analytics**: Firebase Analytics, Sentry (wired, needs DSN)
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
│   ├── services/              ← 59 services (player, dog, kennel, sighting, ML, pack, friendship, social, sync, lost_dog_map_controller, lost_dog_sync_service, etc.)
│   ├── helpers/               ← 3 helpers (date_helpers, game_helpers, ui_helpers)
│   └── widgets/               ← 94 .dart files across `widgets/`, `widgets/identify/`, `widgets/lost_dog/`, `widgets/map/`, `widgets/pack/`, `widgets/profile/`, `widgets/quiz/` (post 2026-04-25 god-class extraction; +lost_dog_stats_panel, +lost_dog_detail_sheet)
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
- Hive boxes prefixed `dogquest_` for namespace isolation
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
adb shell am start -n com.hound.app/.MainActivity
```

- **App ID**: `com.hound.app`
- **Makefile**: 30+ targets — run `make help` or `make menu` for interactive selection
- Key targets: `make build`, `make install`, `make logs`, `make test`, `make lint`, `make screenshots`

## Known Issues (from audit)

- Offline login accepts any password if email matches (`auth_service.dart:71-80`) — will be replaced by Supabase Auth
- PII (username, email) in unencrypted Hive box while JWT is encrypted (`auth_service.dart:27-30`)
- `API_BASE_URL` is now MANDATORY via `--dart-define=API_BASE_URL=https://...`. The old `10.0.2.2` default has been removed and `api_client.dart:14-23` asserts non-empty at app startup. Pass a placeholder URL (e.g. `https://example.com`) for smoke tests where API calls aren't exercised. (Hardened 2026-04-28 — supersedes the prior "default ships in release" issue.)
- `SUPABASE_URL` and `SUPABASE_ANON_KEY` are now MANDATORY via `--dart-define`. Hard-coded defaults removed from `lib/main.dart:109-117`; `_assertSupabaseEnv()` guards startup. Same hardening pattern as `API_BASE_URL`. Pass placeholders for unconfigured local builds (e.g. `--dart-define=SUPABASE_URL=https://example.supabase.co --dart-define=SUPABASE_ANON_KEY=placeholder`). (Hardened 2026-04-30 / ENV-001.)
- AdMob ad-unit IDs (`ADMOB_INTERSTITIAL_ID`, `ADMOB_BANNER_ID`) follow the same pattern: empty default in release, debug-only fallback to Google's documented test units. Release builds without dart-defines short-circuit ad loads with an info log instead of serving test placeholders to real users (AdMob policy risk). `lib/services/ad_service.dart:40-50` + `lib/widgets/dogquest_banner_ad.dart:21-26`. (Hardened 2026-04-30 / ENV-002.)
- 10 files over 800 lines remain (down from earlier; `quiz_screen.dart` 1,648 → 1,042 via TASK-046; `lost_dog_hub_screen.dart` 1,665 → 127 via 2026-04-25 god-class extraction; `lost_dog_map_screen.dart` 1,390 → 870 via Phase 4a 2026-04-25). Largest remaining: `profile_screen.dart` 1,268, `pack_screen.dart` 1,253. T5 polish queue.
- **Config validation backlog (Sprint 10, 2026-04-30)** — see `outputs/config_validate_findings.md` and `outputs/next_steps_plan.md`. 7 fixes shipped to working tree (ENV-001/002/003, DEPS-001, GIT-001/002, CI-001) awaiting commit. Critical deferred items: SUPA-001 (RPC functions trust `p_user_id`), CI-002 (release.yml targets aviquest), magic-link auth path. All three are week-1 must-land per the 23-day closed-beta plan.

## Hound rebrand status (2026-04-28)

- **CI #16 GREEN** on `phase-1/social-backend-realtime` — first green CI run since CI #6, ~4 weeks of broken CI cleared via Phase 7 T5 fixes (Offset cast, Provider import, _PhotoPlaceholder.build conflict, kDeployedBreedCount inline, 6 unused-symbol cleanups).
- **6 commits shipped** to origin: rebrand finalization (4 strings) + 5 supporting CI-unblockers (T5 god-class fix, Phase 7 logic fixes, mechanical cleanup, F2 fallout, kDeployedBreedCount inline). See `.second_brain/03_Projects/Active_Tasks.md` Sprint 7.
- **Working-tree-only fixes** awaiting commit alongside the larger rebrand pile (Sprint 9): `AndroidManifest.xml` AdMob APPLICATION_ID meta-data (test ID `ca-app-pub-3940256099942544~3347511713`), `dog_found_dialog.dart` dispose-race fix (cache `_analytics` in initState), `smoke_channels.ps1` verification utility.
- **Verified on-device:** launcher icon = "Hound", `HOUND_ID:` log tag, privacy email = `jesseg.8899@gmail.com`. Source-verified: 4 notification channel IDs (`hound_streak`/`hound_daily_dog`/`hound_smart`/`hound_lost_dog_alerts`), 8+ share text strings ("Join my pack on Hound!", "I found a ... on Hound!", etc.).
- **Deferred items** (out of scope for the rebrand smoke): Hive box prefixes (`dogquest_*` 32+ refs), pubspec `name: dogquest`, `key.properties` (`keyAlias=dogquest`, keystore filename), `dogquest_banner_ad.dart` filename (class is `HoundBannerAd`), `dogquest-ci.yml` workflow filename, real AdMob production App ID, `hound.app` domain + email forwarding, iOS rebrand (no `ios/` exists). All tracked in Active_Tasks Sprint 9.

## Notable Conventions

- No audio identification (visual ML only)
- No backend sync (local-first; Supabase backend planned)
- Firebase Analytics wired via `firebase_core` + `firebase_analytics` in pubspec
- 7 AKC breed groups
- Primary routes: `/identify`, `/kennel`, `/profile`, `/quiz`, `/map`, `/social`, `/pack`, `/passport`
- Dog-themed achievements, player titles, avatars
- Headline features: Pack, Dog Friendships, Neighborhood Map, Dog Passport, Lost Dog, Social Layer, Demo Mode

---

## Cowork Skills Reference

Load the skill(s) listed for the task type before writing any code. Multiple skills can be active simultaneously — load all that apply.

### UI / Design

| Task | Skill(s) to Load |
|------|-----------------|
| Review any screen for UX issues before touching it | `ui-design:design-review` |
| Change any color, contrast, or type size | `ui-design:visual-design-foundations` |
| Add or update color/size tokens in `constants.dart` | `ui-design:design-system-patterns` |
| Write or rewrite any user-facing string (labels, CTAs, subtitles) | `ui-design:ux-copy` |
| Fix chip row / filter overflow or any scrollable layout | `ui-design:responsive-design` |
| Move, stage, or animate a gamification reveal | `ui-design:interaction-design` |
| Build a new card, list tile, or grid cell widget | `ui-design:web-component-design` |
| WCAG contrast or screen-reader audit on changed screens | `ui-design:accessibility-compliance` + `ui-design:accessibility-review` |
| Post-phase screenshot accessibility check | `ui-design:accessibility-review` |

### Design Critique Backlog (2026-04-29)

Open fixes from the live-device critique session (Splash, Camera, Kennel, Field Guide, Profile). Full agent briefings in `hound_design_agent_report.docx`.

**Phase 1 — tokens + atoms (parallel, no deps):**
- Kennel stats contrast (`constants.dart` color tokens) → `ui-design:visual-design-foundations` + `ui-design:design-system-patterns`
- Splash: remove duplicate tagline, fix `Ready!` contrast → `ui-design:design-review` + `ui-design:ux-copy`
- Profile header icon contrast (Community / Search / Settings) → `ui-design:accessibility-compliance`
- Field Guide: replace `Canis lupus familiaris` with AKC group + origin tag → `ui-design:ux-copy` + `ui-design:design-review`

**Phase 2 — component layer (after Phase 1 CI green):**
- `BreedGhostCard` widget — ghost-collection pattern for undiscovered breeds → `ui-design:web-component-design`
- `ChipRow` overflow fix — shared Kennel + Field Guide widget → `ui-design:responsive-design`
- `XPBar` hero widget + Pack ring demotion on Profile → `ui-design:design-system-patterns`
- CTA card icon unification on Profile → `ui-design:visual-design-foundations`

**Phase 3 — screen logic + QA (after Phase 2 CI green):**
- Camera: move combo + flash challenge overlays off viewfinder → result screen → `ui-design:interaction-design`
- Profile: engagement gate — suppress onboarding CTAs for level > 5 or sightings > 20 → `engineering:system-design`
- Accessibility audit pass on all 5 changed screens → `ui-design:accessibility-review`
- Widget tests for all new components → `engineering:testing-strategy`

### Engineering

| Task | Skill(s) to Load |
|------|-----------------|
| Add or refactor a Riverpod provider or service | `engineering:system-design` |
| Pre-merge code review (Dart style, Riverpod patterns, CLAUDE.md compliance) | `engineering:code-review` |
| Write widget or unit tests | `engineering:testing-strategy` |
| Debug a regression or unexpected behavior | `developer-essentials:debugging-strategies` + `engineering:debug` |
| Pre-deploy checklist before pushing to CI | `engineering:deploy-checklist` |
| Final multi-dimensional review before merging to main | `comprehensive-review:full-review` |

### Architecture & Backend (Supabase phase)

| Task | Skill(s) to Load |
|------|-----------------|
| Design Supabase schema (users, dogs, social graph) | `database-design:postgresql` |
| Design REST or realtime API surface | `backend-development:api-design-principles` |
| Auth migration — local Hive → Supabase Auth | `developer-essentials:auth-implementation-patterns` |
| Real-time social feed / dogs nearby | `backend-development:microservices-patterns` |
| CI/CD pipeline work (GitHub Actions) | `cicd-automation:github-actions-templates` |

### Agent Orchestration

| Task | Skill(s) to Load |
|------|-----------------|
| Spawn parallel implementer agents for a phase | `agent-teams:parallel-feature-development` |
| Coordinate agents that share a file (e.g. `profile_screen.dart`) | `agent-teams:task-coordination-strategies` — use `team-lead` agent type |
| Multi-dimensional code review across agents | `agent-teams:multi-reviewer-patterns` |
| Debug with competing hypotheses | `agent-teams:parallel-debugging` |

### Verification Checklist (run after every phase)

```bash
cd dogquest
dart analyze                          # zero errors required
dart format --output=none .           # zero changed files required
flutter test test/widgets/            # Phase 3+ only
```

After code checks pass: run `capture_screens.bat`, read the PNG outputs, then invoke `ui-design:accessibility-review` on the screenshots before marking the phase complete and pushing to CI.
