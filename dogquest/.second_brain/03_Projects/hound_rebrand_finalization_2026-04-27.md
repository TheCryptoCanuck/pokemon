# Hound Rebrand Finalization — 2026-04-27

Tags: #rebrand #ops

Cowork-side handoff for the DogQuest → Hound bundle ID rename. Cowork sandbox has no Dart toolchain and no git access (Memory.md), so file edits land here; verification + Firebase Console actions are Jesse's responsibility on Windows.

## Step 1 — Baseline verify (DEFERRED to Windows)

Run from `C:\Users\Administrator\AviQuest-\dogquest`:

```powershell
dart format .
dart analyze
flutter test
```

Expected: dart format = 0 changes (or only the rebrand-touched files reformatted), analyze = clean modulo the known `--no-fatal-warnings --no-fatal-infos` posture, flutter test = same status as origin (T5-B Group 1 still skip-marked). Confidence: `solid` that the cmd sheet is correct; `drift` on actual outputs (cannot run from Cowork).

## Step 2 — Pre-launch evidence (PASS)

Static evidence DogQuest has NOT shipped to Play Store:

- **No fastlane** anywhere in repo (`find -iname "*fastlane*"` returned nothing).
- **No release/launch docs** (`find -iname "*release*.md" -o -iname "*launch*.md" -o -iname "*play_store*"` returned nothing in `dogquest/` first 3 levels).
- **`pubspec.yaml`** version is `0.1.0+2` — debug-grade, no release versionCode bumps.
- **Memory.md** declares closed-beta posture pivot 2026-04-25; Active_Tasks Tier 4 = "distribute existing signed APK to 5–10 friends/family" (still pre-distribution).
- **OPS-C-002** open: password rotation BEFORE Play Store production (current keystore password is sequential digits — that gate hasn't been crossed).
- **`google-services.json`** was bound to project `aviquest-508a6` (Firebase, not Play Store) under the old package.

Verdict: SOLID pre-launch. Bundle ID rename is safe with no Play Store cleanup needed. Firebase Console changes ARE required (see Step 3 manual actions). Confidence: `solid`.

## Step 3 — Bundle ID rename (`com.dogquest.app` → `com.hound.app`)

### Files edited (Cowork-side, this session)

| File | Change |
|---|---|
| `android/app/build.gradle` | `namespace` (line 36), `applicationId` (line 51) |
| `android/app/src/main/AndroidManifest.xml` | deep-link `<data android:scheme>` (line 40) |
| `android/app/src/main/kotlin/com/hound/app/MainActivity.kt` | NEW — `package com.hound.app` |
| `android/app/src/main/kotlin/com/dogquest/app/MainActivity.kt` | STUB — class removed, package decl + cleanup-instruction comments retained (sandbox cannot delete files) |
| `android/app/google-services.json` | `package_name` field (line 12) — **see Firebase Console manual action below** |
| `lib/screens/lost_dog_map_screen.dart` | `userAgentPackageName` (line 354) |
| `lib/screens/map_tab.dart` | `userAgentPackageName` (line 938) |
| `lib/services/supabase_auth_service.dart` | OAuth `redirectTo` (line 102) |
| `Makefile` | header comment, `APP_ID` (line 6), adb start cmd (line 263) |
| `scripts/close_t1.ps1` | adb start cmd (line 148) |
| `scripts/close_t1.md` | adb start cmd (line 121) |
| `CLAUDE.md` | adb start cmd (line 129), `App ID` field (line 132) |
| `README.md` | `App ID` field (line 83) |

### Files explicitly NOT touched (and why)

- **`android/key.properties`** — `keyAlias=dogquest` and `storeFile=...dogquest-release.jks` are bound to the actual `.jks` file at `C:\Users\Administrator\dogquest-release.jks`. Renaming either side would break signing. Per OPS-C-002 the keystore is rotated before Play Store production anyway — defer the rename to that rotation.
- **`android/app/proguard-rules.pro`**, **`android/gradle.properties`** — survey confirmed no `com.dogquest.app` references.
- **`docs/prd.md`** (4 hits at lines 374, 1792, 1798, 1809), **`docs/product-roadmap.md`** (1 hit at line 41) — historical PRD/roadmap narrative; code samples reflect the implementation at the time of writing. Flag for Jesse's call: update for accuracy now, or leave as historical?
- **`.full-review-archive-2026-04-25/`** (2 hits) — dated archive snapshots; immutable per the archive convention.
- **`pubspec.yaml`** `name: dogquest` — Step 4 below.
- **`assets/`**, all sub-second-brain vault files, `.github/workflows/` — none reference the bundle ID.

### Manual cleanup required on Windows (no toolchain needed)

```powershell
cd C:\Users\Administrator\AviQuest-\dogquest
Remove-Item android\app\src\main\kotlin\com\dogquest\app\MainActivity.kt
Remove-Item android\app\src\main\kotlin\com\dogquest\app
Remove-Item android\app\src\main\kotlin\com\dogquest
```

The sandbox couldn't delete the old kotlin file/dirs (operation not permitted on the mount). The build is unaffected because the stub has no class declaration, but the file should be removed before the next commit.

### Firebase Console actions REQUIRED (Jesse, manual)

The local `google-services.json` package_name now reads `com.hound.app`, which is enough for the Firebase Gradle plugin to let the build proceed. **But the `mobilesdk_app_id` `1:303605946397:android:01946f97240882558dcef4` is registered in the Firebase backend under `com.dogquest.app`.** Until you do the steps below, Crashlytics/Analytics events will be rejected at Firebase's edge.

1. Open Firebase Console → project `aviquest-508a6` → Project settings → Your apps → Android.
2. Either:
   - **(a) Add new Android app**: package `com.hound.app`, app nickname "Hound", optional SHA-1 (the closed-beta keystore SHA-256 is in `.second_brain/03_Projects/Active_Tasks.md` under OPS-002 — derive SHA-1 with `keytool -list -v -keystore C:\Users\Administrator\dogquest-release.jks -alias dogquest`). Download the new `google-services.json`. Replace `dogquest/android/app/google-services.json` with it. The new file will have a *new* `mobilesdk_app_id` for the Hound package; old DogQuest app stays under the project for now — delete it once the new one is verified working.
   - **(b) Existing app**: Firebase doesn't allow renaming an Android package on an existing app. (a) is the only path.
3. After replacing the JSON, `flutter clean && flutter build apk --debug` and verify Crashlytics initializes without `App ID not registered` warnings in logcat.
4. **Do NOT delete the old `com.dogquest.app` Firebase app immediately** — keep it for a few days until you're sure the new one is wired correctly and historical events still resolve in the dashboard.

### Supabase Auth redirect URL — manual action required

The Android manifest now declares scheme `com.hound.app`, and `supabase_auth_service.dart` uses `com.hound.app://login-callback` as the OAuth redirect. The Supabase project's allow-list of redirect URLs must be updated:

1. Supabase Dashboard → your project → Authentication → URL Configuration → Redirect URLs.
2. Add `com.hound.app://login-callback`. Optionally remove `com.dogquest.app://login-callback` after verification.

OAuth flows (Google, Apple) will silently fail with "redirect URL not allowed" until this is done.

### Build verify (Windows-side, Step 3 gate)

```powershell
cd C:\Users\Administrator\AviQuest-\dogquest
cd android ; .\gradlew.bat clean ; cd ..
flutter clean
flutter pub get
flutter build apk --debug --no-tree-shake-icons
```

Expected: succeeds. If the Firebase Gradle plugin errors with `No matching client found for package name`, double-check that `google-services.json:12` reads `com.hound.app`. If MainActivity is `not found`, re-check the kotlin path is `android/app/src/main/kotlin/com/hound/app/MainActivity.kt` and the manifest's `<activity android:name=".MainActivity">` resolves under namespace `com.hound.app`.

Confidence on the edits: `solid`. Confidence on the build outcome: `uncertain` (cannot run from Cowork).

## Step 4 — Dart package rename: SKIPPED (deliberate)

Per orchestrator instructions and prior recommendation, `pubspec.yaml` `name: dogquest` is left as-is. No `package:dogquest/...` import is rewritten. Bundle ID and Dart package name are independent — the bundle ID rename above is sufficient to ship as "Hound" on Play Store. The Dart package rename is high-risk-low-reward (touches every internal import, no user-visible benefit) and deferred until explicitly requested. Confidence: `solid`.

## Step 5 — Launcher icon regen (DEFERRED to Windows)

Cowork has no `dart` binary. Run on Windows from `dogquest/`:

```powershell
dart run flutter_launcher_icons
```

This consumes `assets/app_icon.png` (815 KB) + `assets/app_icon_foreground.png` (333 KB) + the `flutter_launcher_icons` block in pubspec.yaml. Output: regenerated mipmap-* densities under `android/app/src/main/res/mipmap-*` (overwrites). After running, eyeball one density (e.g., `mipmap-xxxhdpi/ic_launcher.png`) to confirm the Hound icon renders, not the legacy DogQuest one.

Note: the previous session already wrote new launcher icons. This re-run is the *official* regen via the flutter_launcher_icons tool, which produces the round-icon and adaptive-icon variants in addition to the square ones the previous session wrote. Confidence on the cmd: `solid`. On the output appearance: `drift` (haven't seen the icons).

## Step 6 — Final verification (DEFERRED to Windows)

After steps 3–5 land:

```powershell
cd C:\Users\Administrator\AviQuest-\dogquest
dart format .
dart analyze
flutter test
flutter build apk --debug --no-tree-shake-icons
```

All four must pass. If `dart analyze` flags new issues introduced by the rebrand (most likely candidates: import-order in the touched lib/ files), apply suggested fixes. If `flutter test` fails on tests that exercise the deep-link or OAuth callback string literals, those tests need their fixtures updated to `com.hound.app` (search `test/` for `com.dogquest.app`).

Confirmed: `grep -r "com.dogquest.app" test/` from Cowork returned 0 hits, so test fixtures are clean.

## Step 7 — Trust tags summary

| Step | Status | Trust |
|---|---|---|
| 1 — Baseline | Cmd sheet only (deferred to Windows) | `drift` on outputs |
| 2 — Pre-launch evidence | PASS based on static repo state | `solid` |
| 3 — Bundle ID rename | 13 files edited Cowork-side | `solid` on edits, `uncertain` on Windows build outcome |
| 3 — Firebase Console action | DOCUMENTED, not executed | n/a (manual) |
| 3 — Supabase redirect URL | DOCUMENTED, not executed | n/a (manual) |
| 4 — Dart pkg rename | Deliberately skipped | `solid` |
| 5 — Launcher icon regen | Cmd documented (deferred) | `solid` on cmd |
| 6 — Final verify | Cmd sheet (deferred) | `drift` on outputs |

## Open follow-ups

- Old kotlin file/dirs at `android/app/src/main/kotlin/com/dogquest/...` need manual deletion on Windows (PowerShell cmds in Step 3).
- Firebase Console: add new Android app for `com.hound.app`, replace `google-services.json`.
- Supabase Auth: add `com.hound.app://login-callback` to redirect allow-list.
- `docs/prd.md` (4 hits) and `docs/product-roadmap.md` (1 hit) still reference `com.dogquest.app` — Jesse's call whether to scrub for accuracy or preserve as historical narrative.
- `key.properties` keystore alias + filename still say `dogquest` — defer to OPS-C-002 keystore rotation.
- Update `.second_brain/01_Memory/Memory.md` with the new bundle ID once verified working on a connected device.
