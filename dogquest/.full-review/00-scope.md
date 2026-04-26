# Review Scope

## Target

**Whole DogQuest application** — Flutter/Dart app, pre-closed-beta, post 2026-04-25 evening commits. Forked from AviQuest, deployed model is EfficientNetB2 v5.1 (150 breeds), 294-breed v6 in training. Local-first Hive storage, Supabase backend partially wired.

This review supersedes the earlier comprehensive review (archived at `.full-review-archive-2026-04-25/`) which finished 2026-04-25T09:35Z. Since then 13 commits have landed:
- 5 sec-related (`aaebc5d`, `4da92cf`, `f8eae20`, `b247a4a`, `d1127f2`)
- 5 refactor-recovery (`e1f7a2e`, `55b7317`, `c17643e`, `953bb92`, `5a8d0a3`)
- 5 T1 deck-clearing (`df8b38a`, `88649a8`, `c949c92`, `d859f81`, `3e4f1e3`)

So a fresh pass against current tree.

## Files

- `lib/` — 52,995 lines across 32 screens, 57 services, 92 widgets, 6 models, 1 router, 1 main
- `test/` — 22 test files
- `android/` — Gradle config, `app/build.gradle`, `key.properties` (gitignored)
- `assets/` — `dog_model.tflite` (v5.1 deployed), `dog_labels.txt` (150), `dogs.json` (147 entries)
- `pubspec.yaml`, `analysis_options.yaml`, `Makefile`
- `.github/workflows/` — 5 yml files (`dogquest-ci.yml` new, `aviquest-ci.yml` restored, plus 3 pre-existing from 2026-03-03)
- Project docs — `CLAUDE.md`, `README.md`, `docs/`, `.full-review-archive-2026-04-25/` (prior review for reference)

### Largest files (god-class candidates)

| Lines | File |
|------:|------|
| 1390 | lib/screens/lost_dog_map_screen.dart |
| 1268 | lib/screens/profile_screen.dart |
| 1253 | lib/screens/pack_screen.dart |
| 1219 | lib/widgets/dog_found_dialog.dart |
| 1042 | lib/screens/quiz_screen.dart |
| 1020 | lib/screens/map_tab.dart |
| 1002 | lib/screens/identify_screen.dart |
|  976 | lib/screens/scan_stray_screen.dart |
|  899 | lib/screens/friends_screen.dart |
|  869 | lib/screens/settings_screen.dart |

### Security-relevant services (hot for Phase 2A)
- `lib/services/auth_service.dart` (offline auth gate already partially fixed in C1)
- `lib/services/api_client.dart` (default dev URL ships in release builds — pre-existing concern)
- `lib/services/supabase_*_service.dart` (~10 files — Supabase boundary)
- `lib/services/photo_upload_service.dart`
- `lib/services/sighting_sync_service.dart` (dormant, sec-C2 documented in dartdoc)
- `lib/services/backend_sync_service.dart` (stub)
- `lib/services/lost_dog_service.dart` + `lib/services/supabase_lost_dog_service.dart` (just deeply analyzed; GDPR Criticals)
- `lib/services/dog_embedding_service.dart` (matching algorithm correctness)
- `lib/router.dart` (auth gate)

## Flags

- Security Focus: **yes** (lost-dog GDPR Criticals just surfaced; pre-Play-Store gate)
- Performance Critical: no (not load-bearing yet; pre-beta)
- Strict Mode: **yes** (quality-first posture, locked 2026-04-25)
- Framework: Flutter 3.x / Dart 3.x / Riverpod / go_router / Hive / Supabase / tflite_flutter 0.11.0

## Review Phases

1. Code Quality & Architecture
2. Security & Performance
3. Testing & Documentation
4. Best Practices & Standards
5. Consolidated Report

## Prior-review handoff context

The archived review's 5 Critical findings:
- C1 sync ownership — closed (router redirect + sync-service guards + RLS verified)
- C2 SightingSync UUID — reduced-scope close (dormant marker, init() throws)
- C3 vestigial backend/ — closed (commit `aaebc5d`)
- OPS-001 no CI/CD — closed (GitHub Actions wired)
- OPS-002 no signing pipeline — closed (keystore wired, signed APK builds)
- DOC-001 CLAUDE.md drift — closed (commit `df8b38a`)

This run should NOT re-flag the closed items. Re-flag only if regression detected.
