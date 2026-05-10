# Hound: Google Play Closed Beta Launch Guide

**Date:** 2026-05-10
**App:** Hound (com.hound.app)
**Branch:** phase-1/social-backend-realtime
**Version:** 0.1.0+2

This guide takes you from current state to a live closed beta on Google Play's internal testing track.

---

## Phase 1: Commit Working Tree (PowerShell, from AviQuest-\)

Your working tree has ~180+ uncommitted changes spanning Sprints 8-15 plus hotfixes. First, check what's there:

```powershell
cd C:\Users\Administrator\AviQuest-
git status --short | Measure-Object -Line   # count of changed files
git status --short | head -30               # preview
```

### Recommended commit sequence

Commit in logical chunks. Run `dart format .` and `dart analyze` from `dogquest\` FIRST to catch any issues before committing:

```powershell
cd C:\Users\Administrator\AviQuest-\dogquest
flutter pub get
dart format .
dart analyze   # must be 0 errors
```

Then from repo root:

```powershell
cd C:\Users\Administrator\AviQuest-

# 1. Android manifest + build config
git add dogquest/android/app/src/main/AndroidManifest.xml
git add dogquest/android/app/build.gradle
git add dogquest/android/app/proguard-rules.pro
git commit -m "fix(android): AdMob APPLICATION_ID meta-data, build config hardening"

# 2. Security audit fixes (Sprint 12)
git add dogquest/lib/main.dart
git add dogquest/lib/services/api_client.dart
git add dogquest/lib/services/sync_queue_service.dart
git add dogquest/lib/screens/breed_community_screen.dart
git add dogquest/lib/services/photo_upload_service.dart
git add dogquest/lib/services/playdate_service.dart
git add dogquest/lib/services/identification_orchestrator.dart
git add dogquest/lib/services/social_post_generator.dart
git add dogquest/lib/services/notification_service.dart
git add dogquest/lib/services/smart_notification_service.dart
git commit -m "fix(security): assert->throw, null-safe auth, unawaited wraps, logger migration"

# 3. Navigation redesign (Sprint 11)
git add dogquest/lib/screens/home_shell.dart
git add dogquest/lib/router.dart
git add dogquest/lib/screens/kennel_screen.dart
git commit -m "feat(nav): 5-tab bottom nav, Field Guide demoted to Kennel AppBar"

# 4. Kennel grid hotfix
git add dogquest/lib/widgets/breed_ghost_card.dart
git commit -m "fix(kennel): card aspect ratio, BoxFit.contain, ghost visibility, animate fix"

# 5. Config validation (Sprint 10)
git add dogquest/pubspec.yaml dogquest/pubspec.lock
git add dogquest/.gitignore
git commit -m "chore(config): flutter_lints 5.0, gitignore cleanup, env guards"

# 6. Breed group exams (Sprint 15)
git add dogquest/lib/models/exam_result.dart
git add dogquest/lib/services/exam_service.dart
git add dogquest/lib/widgets/exam_group_cta.dart
git add dogquest/lib/widgets/exam_badge_grid.dart
git add dogquest/test/exam_service_test.dart
git add dogquest/lib/constants.dart
git add dogquest/lib/services/quiz_engine.dart
git add dogquest/lib/screens/quiz_screen.dart
git add dogquest/lib/screens/profile_screen.dart
git add dogquest/lib/screens/leaderboard_screen.dart
git add dogquest/lib/screens/field_guide_screen.dart
git commit -m "feat(exams): breed group certification exams with bronze/silver/gold tiers"

# 7. Design + UX fixes (Sprint 9 Phase 3 + dog_found_dialog)
git add dogquest/lib/screens/identify_screen.dart
git add dogquest/lib/widgets/dog_found_dialog.dart
git commit -m "feat(ux): camera overlay extraction, context pills, dispose-race fix"

# 8. Privacy policy + Play Store assets
git add dogquest/lib/screens/privacy_policy_screen.dart
git add dogquest/docs/privacy_policy.html
git add dogquest/docs/play_store_listing.md
git add dogquest/docs/feature_graphic.png
git add dogquest/docs/play_store_icon_512.png
git add dogquest/Makefile
git commit -m "chore(beta): privacy policy update, Play Store assets, AAB Makefile target"

# 9. Everything else (vault, screenshots, remaining widget/test changes)
git add -A
git status   # review what's staged
git commit -m "chore: working tree cleanup -- vault updates, widget polish, test fixes"

# Push everything
git push
```

**Important:** If `dart analyze` shows errors, fix them before committing. The per-commit granularity above is a suggestion -- if you want to go faster, `git add -A && git commit -m "chore: commit working tree for beta"` works too.

---

## Phase 2: Build Signed AAB

Play Store requires Android App Bundle (.aab), not APK.

```powershell
cd C:\Users\Administrator\AviQuest-\dogquest

# Set environment variables (use placeholders if Supabase isn't live yet)
$env:SUPABASE_URL = "https://your-project.supabase.co"
$env:SUPABASE_ANON_KEY = "your-anon-key-here"
$env:API_BASE_URL = "https://placeholder.example.com"
$env:SENTRY_DSN = ""

# Build AAB
flutter build appbundle --release `
  --dart-define=ENV=production `
  --dart-define=SUPABASE_URL=$env:SUPABASE_URL `
  --dart-define=SUPABASE_ANON_KEY=$env:SUPABASE_ANON_KEY `
  --dart-define=API_BASE_URL=$env:API_BASE_URL `
  --dart-define=SENTRY_DSN=$env:SENTRY_DSN

# Or use the new Makefile target (from WSL/bash):
# make build-aab
```

Output: `build/app/outputs/bundle/release/app-release.aab`

Verify signing:

```powershell
jarsigner -verify build\app\outputs\bundle\release\app-release.aab
```

### Also build APK for direct device testing

```powershell
flutter build apk --release `
  --dart-define=ENV=production `
  --dart-define=SUPABASE_URL=$env:SUPABASE_URL `
  --dart-define=SUPABASE_ANON_KEY=$env:SUPABASE_ANON_KEY `
  --dart-define=API_BASE_URL=$env:API_BASE_URL `
  --dart-define=SENTRY_DSN=$env:SENTRY_DSN

# Install on device
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

### On-Device Smoke Test

Before uploading to Play Store, verify on your Sony XQ-CT54:

- App launches without crash
- Launcher shows "Hound"
- Camera opens, takes photo, returns breed result
- 5-tab navigation works (Discover/Identify/Kennel/Lost Dogs/Me)
- Kennel shows ghost cards + owned cards
- Demo mode works (Settings toggle)
- No crash on location permission prompt

---

## Phase 3: Google Play Console Setup

### 3a. Developer Account

If you don't have one yet:
1. Go to https://play.google.com/console
2. Sign in with your Google account
3. Pay $25 one-time registration fee
4. Complete identity verification (can take 24-48h)

### 3b. Create App

1. Play Console > All apps > Create app
2. App name: **Hound**
3. Default language: English (United States)
4. App or game: **App**
5. Free or paid: **Free**
6. Accept declarations

### 3c. Store Listing

In "Main store listing":

- **App name:** Hound - Dog Breed Identifier
- **Short description:** Identify 150 dog breeds instantly with your camera. Collect, learn, and explore.
- **Full description:** (copy from `docs/play_store_listing.md`)
- **App icon:** Upload `docs/play_store_icon_512.png` (512x512)
- **Feature graphic:** Upload `docs/feature_graphic.png` (1024x500)
- **Screenshots:** Capture 2-8 screenshots from your device
  - Recommended: Identify screen (with result), Kennel grid, Field Guide, Profile, Lost Dogs map
  - Use: `adb shell screencap /sdcard/screen.png && adb pull /sdcard/screen.png screenshot_N.png`

### 3d. Content Rating

1. Go to Policy > App content > Content rating
2. Start questionnaire
3. Category: likely "Utility" or "Reference"
4. Answer honestly -- no violence, no user-generated sharing, no gambling
5. Expected result: "Everyone"

### 3e. Data Safety

1. Go to Policy > App content > Data safety
2. Declare:
   - **Location:** Collected (approximate + precise), optional, not shared
   - **Personal info:** Email address, collected for account functionality
   - **Photos:** Accessed but NOT collected/shared (processed on-device only)
   - **App activity:** App interactions (analytics), collected, not shared
   - **Device info:** Crash logs (Crashlytics), collected, not shared
   - **Advertising:** Ad IDs collected by AdMob for ad serving
3. Data encrypted in transit: Yes
4. Users can request deletion: Yes
5. App for children: No (unless you want COPPA compliance burden)

### 3f. Privacy Policy

1. Go to Policy > App content > Privacy policy
2. Enter the URL where you host `docs/privacy_policy.html`
3. Options to host it:
   - **Quickest:** Create a GitHub Gist, make it public, use the raw URL
   - **Cleanest:** Enable GitHub Pages on the repo, push the HTML, use `https://thecryptocanuck.github.io/boring/dogquest/docs/privacy_policy.html`
   - **Simplest:** Copy the text into a Google Doc, publish to web, use that URL

### 3g. Target Audience

1. Target age: 13+
2. Not primarily child-directed

### 3h. Upload AAB to Internal Testing

1. Go to Testing > Internal testing
2. Create a new release
3. Upload `build/app/outputs/bundle/release/app-release.aab`
4. Release name: "0.1.0-beta.1"
5. Release notes: "Initial closed beta. 150 dog breeds, on-device AI identification."
6. Review and roll out

### 3i. Add Testers

1. In Internal testing > Testers
2. Create an email list (e.g., "Hound Beta Testers")
3. Add tester email addresses (up to 100 for internal testing)
4. Each tester gets a link to opt-in and install from Play Store

---

## Post-Upload Checklist

- [ ] Play Console shows "Published" or "In review" status
- [ ] Test link works (install from Play Store on your own device first)
- [ ] Crashlytics shows the new version registering
- [ ] Share tester opt-in link with your 5-10 beta testers
- [ ] Set up feedback channel (Discord, email, or Google Form)

---

## Known Limitations for Beta

These are accepted for closed beta and documented in the deploy checklist:

- Offline auth accepts any password (Supabase Auth replaces this)
- AdMob uses Google test App ID (no real ads served)
- 150/294 breeds (v6 model retrain pending)
- PII in unencrypted Hive box (mitigated by Supabase migration)
- SUPA-001: RPC functions trust client-supplied user_id (week-1 fix)
- No magic-link auth yet (week-1 deliverable)
- Supabase env vars can use placeholders if backend isn't live

---

## Timeline Estimate

| Step | Effort | Who |
|------|--------|-----|
| dart format + dart analyze + fix issues | 15-30 min | Jesse |
| Commit working tree (9 commits above) | 20-30 min | Jesse |
| Build AAB + smoke test on device | 15 min | Jesse |
| Play Console account (if new) | 10 min + 24-48h verification | Jesse |
| Store listing + screenshots | 30-45 min | Jesse |
| Content rating + data safety + privacy | 20 min | Jesse |
| Upload AAB + add testers | 10 min | Jesse |
| **Total hands-on time** | **~2-3 hours** | |

The 24-48h Play Console verification is the longest wait. Everything else can be done in an afternoon.
