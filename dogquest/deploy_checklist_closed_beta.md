# Deploy Checklist: Hound Closed Beta (5-10 testers)

**Date:** 2026-05-01 | **Deployer:** Jesse Garside
**Branch:** `phase-1/social-backend-realtime` — **VERIFIED on disk**
**Last green CI:** #16 | **Commits ahead of origin:** 0
**App version:** 0.1.0+2 | **App ID:** `com.hound.app`
**Last commit:** `9cda604c fix(kennel): correct card aspect ratio, BoxFit, ghost visibility, owned-breed animation`

---

## BLOCKER — Working Tree Uncommitted Changes

**VERIFIED: ~180+ modified/deleted/untracked files** in working tree that are NOT on origin. 0 unpushed commits. All changes are unstaged. The release APK will NOT contain any of these unless committed first.

Uncommitted work (cross-referenced from vault + live `git status`):

- [ ] Sprint 8: `AndroidManifest.xml` AdMob test APPLICATION_ID meta-data
- [ ] Sprint 8: `dog_found_dialog.dart` dispose-race fix
- [ ] Sprint 10: ENV-001/002/003 (Supabase + API_BASE_URL + AdMob dart-define guards)
- [ ] Sprint 10: DEPS-001, GIT-001/002, CI-001 config validation fixes
- [ ] Sprint 11: `home_shell.dart` 5-tab nav, `router.dart` Lost Dogs reroute, `kennel_screen.dart` Field Guide AppBar
- [ ] Sprint 12: Security audit fixes (assert→throw, auth null-safe, unawaited, logging)
- [ ] Hotfix: Kennel grid (childAspectRatio, BoxFit.contain, ghost visibility, animate removal)

**Action:** `git add -A && git status` from repo root (`AviQuest-\`, NOT `dogquest\`). Review diff, commit in logical chunks, push.

**Major categories from live git status:**
- 75+ Dart source files modified (`lib/`, `test/`)
- 26+ vault/second_brain files modified or deleted (Sprint 13 directory audit)
- 20+ Python scripts deleted (moved to `ml/`)
- Android assets (icons, manifest, build.gradle, proguard)
- pubspec.yaml + pubspec.lock modified

---

## Pre-Deploy

### Code Quality Gates (Jesse must run in PowerShell — NOT cmd.exe)

```powershell
cd C:\Users\Administrator\AviQuest-\dogquest
flutter pub get
dart format .
dart format --output=none .   # must show 0 changed files
dart analyze                   # must show 0 errors
flutter test                   # all 22+ test files must pass
```

- [ ] `flutter pub get` — resolves cleanly
- [ ] `dart format .` + `dart format --output=none .` — zero diffs
- [x] `dart analyze` — **1 error + 2 warnings FIXED** (see below); 84 infos remain (style) ✓
- [ ] `flutter test` — 826 passed, 1 skipped, 1 failed → **1 failure FIXED** (see below); re-run to confirm

> **Real `dart analyze` results (PowerShell run, 2026-05-01):**
> - 1 error: `breed_ghost_card_test.dart:118` — `Text.text` → `(widget.data ?? '')` — **FIXED**
> - 2 warnings: `identify_screen.dart` — unused `topPadding` variable removed, dead classes `_DailyDogPill` + `_PriorityContextBanner` removed + 5 orphaned imports cleaned — **FIXED**
> - 84 infos: trailing commas, `const` constructors, `avoid_dynamic_calls`, underscore naming, deprecated `.alpha`, `curly_braces_in_flow_control_structures`, `use_build_context_synchronously` — **not blocking for beta**
>
> **Real `flutter test` results (PowerShell run, 2026-05-01):**
> - 826 passed, 1 skipped, 1 failed
> - Failure: `breed_ghost_card_test.dart` "handles long breed name with ellipsis" — same `.text` → `.data` fix — **FIXED**
> - Re-run needed to confirm all green after fixes.

### Build Configuration

- [x] **key.properties** exists at `android/key.properties` — **VERIFIED** ✓
  - `keyAlias=dogquest` (cosmetic; works, rename is Sprint 9 deferred)
  - `storeFile=C:/Users/Administrator/dogquest-release.jks` — **JKS VERIFIED on disk via File Explorer**
- [ ] **google-services.json** exists at `android/app/` — **VERIFIED** ✓
- [ ] **proguard-rules.pro** covers TFLite, Firebase, Hive, camera, secure storage — **VERIFIED** ✓
- [ ] **R8 shrinking** enabled (`minifyEnabled true`, `shrinkResources true`) — **VERIFIED** ✓

### Environment Variables (dart-defines)

The release build (`make build-release`) requires these env vars set in your shell:

| Variable | Required? | Status |
|----------|-----------|--------|
| `SUPABASE_URL` | **MANDATORY** — app crashes on startup without it | Guard verified: `_assertSupabaseEnv()` throws `ArgumentError` |
| `SUPABASE_ANON_KEY` | **MANDATORY** — same guard | Guard verified |
| `SENTRY_DSN` | Optional (empty = Sentry disabled) | Graceful skip verified |
| `API_BASE_URL` | **MANDATORY** — `ApiClient.assertBaseUrl()` throws | Guard verified |
| `ADMOB_INTERSTITIAL_ID` | Optional (empty = ads disabled in release) | Debug-only test fallback; release skips cleanly |
| `ADMOB_BANNER_ID` | Optional (same pattern) | Same |

- [ ] Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` in shell (or use placeholders if Supabase not live yet)
- [ ] Set `API_BASE_URL` (placeholder OK for beta if backend not deployed)
- [ ] Decide: ship Sentry for beta? If yes, register project at sentry.io and set `SENTRY_DSN`

### Assets

- [ ] `dog_model.tflite` — **VERIFIED** ✓ (10.8 MB, v5.1 EfficientNetB2)
- [ ] `dog_labels.txt` — **VERIFIED** ✓ (150 lines, matches v5.1 output)
- [ ] `dogs.json` — 147 breed entries (covers deployed 150-label model)
- [ ] `aaptOptions { noCompress 'tflite' }` in build.gradle — **VERIFIED** ✓

### Known Issues Accepted for Beta

- [ ] **ACK:** Offline login accepts any password if email matches (replaced by Supabase Auth later)
- [ ] **ACK:** PII in unencrypted Hive box (JWT is encrypted; full fix is Supabase migration)
- [ ] **ACK:** AdMob APPLICATION_ID in manifest is Google's test ID (replace before Play Store public launch)
- [ ] **ACK:** 147/294 breeds in dogs.json (150/294 in model) — v6 retrain unlocks rest
- [ ] **ACK:** SUPA-001 — RPC functions trust `p_user_id` (week-1 closed-beta must-land)

---

## Build & Install

```powershell
# From dogquest\ directory:

# Option A: Makefile
$env:SUPABASE_URL = "https://your-project.supabase.co"
$env:SUPABASE_ANON_KEY = "your-anon-key"
$env:API_BASE_URL = "https://your-api.example.com"
$env:SENTRY_DSN = ""  # empty to skip
make build-release

# Option B: Direct
flutter build apk --release `
  --dart-define=ENV=production `
  --dart-define=SUPABASE_URL=$env:SUPABASE_URL `
  --dart-define=SUPABASE_ANON_KEY=$env:SUPABASE_ANON_KEY `
  --dart-define=API_BASE_URL=$env:API_BASE_URL `
  --dart-define=SENTRY_DSN=$env:SENTRY_DSN
```

- [ ] Release APK builds without errors
- [ ] APK is signed (verify: `jarsigner -verify build/app/outputs/flutter-apk/app-release.apk`)
- [ ] APK size is reasonable (<30 MB expected with R8 + model)

---

## Smoke Test (on-device, before distributing)

- [ ] Install: `adb install -r build/app/outputs/flutter-apk/app-release.apk`
- [ ] App launches without crash
- [ ] Launcher icon shows "Hound"
- [ ] **Identify flow:** camera opens → take photo → breed result returns (TFLite inference works in release build with R8)
- [ ] **Kennel:** breed cards render, ghost cards visible for undiscovered breeds
- [ ] **Profile:** XP bar, stats, settings accessible
- [ ] **Lost Dogs tab:** map loads (OSM tiles), no crash on location permission prompt
- [ ] **Demo mode:** toggle in Settings → 26 pre-seeded breeds + 42 sightings appear
- [ ] **Navigation:** 5-tab bottom nav (Discover/Identify/Kennel/Lost Dogs/Me) all respond
- [ ] No `print()` output in `adb logcat` (should use `dart:developer` log or nothing)
- [ ] Crashlytics: force a test crash (`FirebaseCrashlytics.instance.crash()` or equivalent) → verify it appears in Firebase console

---

## Distribution

- [ ] Collect tester device info (Android version, device model)
- [ ] Distribute APK via secure channel (Google Drive shared link, not public)
- [ ] Send testers install instructions (enable "Install from unknown sources")
- [ ] Share known-issues list (offline auth, test AdMob ID, 150/294 breeds)
- [ ] Set up feedback channel (Discord, email, or Google Form)

---

## Post-Deploy (within 24h of first tester install)

- [ ] Monitor Firebase Crashlytics for new crashes
- [ ] Monitor Sentry (if DSN provided) for unhandled exceptions
- [ ] Check: does the app survive backgrounding + resume on tester devices?
- [ ] Check: camera permission flow on Android 13+ (POST_NOTIFICATIONS separate)
- [ ] Collect first tester feedback

---

## Rollback Plan

**Trigger:** crash-on-launch reported by 2+ testers, or data corruption in Hive boxes.

**Action:**
1. Ask testers to uninstall
2. Identify root cause in Crashlytics/Sentry
3. Fix, rebuild, redistribute

No server-side rollback needed (local-first, no Supabase backend live yet).

---

## Week-1 Must-Lands (post-beta-launch)

These are NOT gates for the initial APK distribution but must ship within the first week:

- [ ] **SUPA-001:** RPC functions must validate auth instead of trusting `p_user_id`
- [ ] **CI-002:** `release.yml` targets correct repo path (currently targets aviquest)
- [ ] **Magic-link auth path:** Supabase Auth flow end-to-end

---

## Audit Trail

| Item | Status | Evidence |
|------|--------|----------|
| key.properties | ✓ Present | `android/key.properties` — alias=dogquest, JKS verified on disk |
| Git branch | ✓ Correct | `phase-1/social-backend-realtime`, 0 commits ahead of origin |
| Working tree | ⚠ BLOCKER | ~180+ uncommitted changes across 75+ Dart files, vault, android assets |
| dart analyze | ✓ Fixed | 1 error + 2 warnings fixed; 84 infos (style, not blocking). Re-run to confirm. |
| google-services.json | ✓ Present | `android/app/google-services.json` |
| proguard-rules.pro | ✓ Complete | TFLite, Firebase, Hive, camera, secure storage, Dio covered |
| Supabase env guard | ✓ Hardened | `_assertSupabaseEnv()` throws ArgumentError in release |
| API_BASE_URL guard | ✓ Hardened | `ApiClient.assertBaseUrl()` throws ArgumentError in release |
| AdMob fallback | ✓ Safe | Empty default in release → ads disabled; debug-only test IDs |
| TFLite model | ✓ Deployed | v5.1, 10.8 MB, 150 labels, uint8 quantized |
| R8/ProGuard | ✓ Enabled | minifyEnabled + shrinkResources + 5 optimization passes |
| Crashlytics | ✓ Wired | `firebase_crashlytics: ^5.0.0`, FlutterError.onError hooked |
| flutter test | ✓ Fixed | 826 passed, 1 skipped, 1 failed → failure fixed. Re-run to confirm. |
| Sentry | ○ Optional | Wired but requires DSN at build time |
