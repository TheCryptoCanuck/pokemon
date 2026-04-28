# Hound Rebrand Runbook

## Status

| Phase | Owner | Status | Commit |
|-------|-------|--------|--------|
| 1–3 (code changes) | Agent | ✓ Complete | 6-agent sweep + final fixes |
| 4 (Firebase/Supabase verification) | Jesse | Pending | — |
| 5 (Windows toolchain) | Jesse | Pending | — |
| 6 (on-device smoke) | Jesse | Pending | — |

## Phase 4 — Off-codebase verification (Jesse, manual, ~15 min)

### Firebase Console

**Path:** [Firebase Console](https://console.firebase.google.com/) → `aviquest-508a6` → Project Settings → Apps

**Verify:**
- Android app `com.hound.app` exists in the app list
- SHA-256 fingerprint matches: `88:17:48:BA:CB:9B:19:D2:48:5E:17:10:BF:24:3A:94:7C:FD:A4:73:77:B6:43:F2:DD:27:C3:13:39:F3:E6:E9`
- Download `google-services.json`; compare against `android/app/google-services.json` in repo — should be identical

**Expected state:** no DogQuest app entry remains; only `com.hound.app` registered.

---

### Supabase Dashboard

**Path:** [Supabase Dashboard](https://app.supabase.com/) → aviquest-508a6-supabase-project → Authentication → URL Configuration

**Verify Deep Link Callback:**
- Redirect URLs includes `com.hound.app://login-callback`
- No `com.dogquest.app://` or `com.aviquest.app://` URLs remain

**Verify Email Templates:**
- **Path:** Authentication → Email Templates (magic link, confirmation, etc.)
- Search email body + subject for "DogQuest" — should be zero results
- Verify "Hound" or app-agnostic wording ("your app", "the app") is used instead

---

### Firebase Crashlytics

**Path:** Firebase Console → aviquest-508a6 → Crashlytics (or Analytics)

**Verify:**
- Android app selector lists `com.hound.app`
- No `com.dogquest.app` or `com.aviquest.app` entries remain
- (Will remain empty until first crash; this just confirms the app is wired and visible)

---

### Firebase Cloud Messaging (if configured)

**Path:** Firebase Console → aviquest-508a6 → Cloud Messaging → Manage Topics

**Verify:**
- No subscription to `dogquest_*` topics
- Notification channels use `hound_streak`, `hound_daily_dog`, `hound_smart` (not `dogquest_*`)
- Sender ID matches the Firebase project's server key

---

### Google Play Console

**Deferred:** Wait until production-ready. Note for future:
- App bundle upload → package name `com.hound.app`
- Icon + screenshots reference Hound branding
- Privacy Policy URL → verify it resolves and shows correct contact email

---

## Phase 5 — Windows toolchain verification (Jesse, PowerShell 5, ~5 min)

### Residual grep

Run from `C:\Users\Administrator\AviQuest-\` (repo root):

```powershell
rg -n "DogQuest|DOGQUEST|Dog Quest|dogquest_streak|dogquest_daily_dog|dogquest_smart|support@dogquest" .\dogquest\lib .\dogquest\test .\dogquest\android .\dogquest\assets
```

**Expected:** zero results (except deferred items listed in the "Open follow-ups" section below).

---

### Dart format

From `C:\Users\Administrator\AviQuest-\dogquest\`:

```powershell
dart format .\lib\services\tflite_identification_service.dart .\lib\services\notification_service.dart .\lib\services\smart_notification_service.dart .\lib\screens\privacy_policy_screen.dart
```

Then full suite:

```powershell
dart format .\lib .\test .\android
```

**Expected:** no changes (already formatted in sandbox).

---

### Dart analyze

```powershell
dart analyze .\lib .\test
```

**Expected:** 0 errors, 0 warnings.

---

### Flutter test

```powershell
flutter test
```

**Expected:** all tests pass (no channel-ID or email assertions in test suite; tests verify logic).

---

### Flutter build debug APK

```powershell
flutter build apk --debug
```

**Expected:** build succeeds, APK at `build\app\outputs\flutter-apk\app-debug.apk` (~50 MB).

---

## Phase 6 — On-device smoke (Jesse, ~10 min)

### Install & launch

```powershell
adb install -r build\app\outputs\flutter-apk\app-debug.apk
adb shell am start -n com.hound.app/.MainActivity
```

Wait ~3 sec for app to load.

---

### 1. Launcher label verification

**What to do:** Open Android Launcher (home screen). Find the app icon.

**Expected:** app name reads "Hound" (not "DogQuest" or "DogQuest: Hound").

---

### 2. Log tag verification

Identify a dog (hit `/identify`, take a photo or pick from gallery).

```powershell
adb logcat -d | findstr "HOUND_ID"
```

**Expected:** logs include `I/HOUND_ID: Model inference took X ms` or similar (NOT `DOGQUEST_ID`).

---

### 3. Notification channel verification

**Path:** Device Settings → Apps → Hound (or Permissions) → Notifications

**Expected channels:**
- "Streak Reminders" (formerly `dogquest_streak`)
- "Daily Dog Alerts" (formerly `dogquest_daily_dog`)
- "Smart Reminders" (formerly `dogquest_smart`)
- Each has a new channel ID (Android doesn't migrate old channel IDs if the name changes)

**Trigger a notification (optional):** In app, go to Settings → Debug/Notifications → "Send test streak notification" (or wait for a real streak).

---

### 4. Privacy Policy email verification

**Path:** In app, open Settings → Privacy Policy (or About → Privacy)

**Expected:** contact email reads `jesseg.8899@gmail.com` (not `support@dogquest.app`).

---

### 5. Firebase Crashlytics (force-crash test)

**What to do:** In app, go to Settings → Debug → "Crash me" (or intentionally trigger a runtime exception).

**Wait ~10 sec for Crashlytics to upload.**

```powershell
adb logcat -d | findstr "Crashlytics"
```

**Expected:** 
- Dashboard [Firebase Console → Crashlytics] shows the crash under `com.hound.app` Android app
- NO crash logged under `com.dogquest.app` or `com.aviquest.app`

---

### 6. Deep link (Supabase magic link) verification

**What to do:**
1. In app, go to Login → Magic Link
2. Enter test email
3. Check email for link (e.g., `https://aviq...supabase.co/auth/v1/callback?code=...&type=signup`)
4. On-device, open the link (or copy it to browser on device)

**Expected:** deep link handler intercepts the callback and returns control to the app (not browser error or "app not found").

---

### 7. Dog Passport share verification

**What to do:** In app, go to Kennel → pick a dog → open its profile → Share Dog Passport card.

**Expected:** Share sheet text includes "Hound" not "DogQuest" (e.g., "Check out my Hound: [breed name]").

---

## Rollback plan

If any Phase 6 step fails:

1. **Identify the failing change** (note the file and log tag or channel name).

2. **Revert the commit:**

From `C:\Users\Administrator\AviQuest-\` (repo root):

```powershell
git log --oneline -n 20
```

Find the rebrand commit SHA. Then:

```powershell
git revert <commit-sha> --no-edit
git push origin phase-1/social-backend-realtime
```

3. **Rebuild and re-install:**

```powershell
cd .\dogquest
flutter clean
flutter build apk --debug
adb uninstall com.hound.app
adb install build\app\outputs\flutter-apk\app-debug.apk
```

**Note on notification channels:** Once a channel is created in Android, uninstalling the app doesn't remove the channel from Settings. Testers who installed the new build will see the old channels (e.g., "Streak Reminders" instead of "Daily Dog Alerts"). If you rollback, they'll need to manually delete the app's notification channels in Settings → Apps → Hound → Notifications, or uninstall + reinstall.

---

## Sign-off criteria

Jesse can tick each box:

- [ ] Phase 4: Firebase & Supabase verification all green
- [ ] Phase 5: `dart analyze` → 0 errors / 0 warnings
- [ ] Phase 5: `flutter test` → all tests pass
- [ ] Phase 5: `flutter build apk --debug` → builds successfully
- [ ] Phase 6.1: Launcher label = "Hound"
- [ ] Phase 6.2: Log tag = `HOUND_ID`
- [ ] Phase 6.3: Notification channels named "Streak Reminders", "Daily Dog Alerts", "Smart Reminders"
- [ ] Phase 6.4: Privacy Policy email = `jesseg.8899@gmail.com`
- [ ] Phase 6.5: Crashlytics logs to `com.hound.app` app entry
- [ ] Phase 6.6: Deep link callback handler works (Supabase magic link)
- [ ] Phase 6.7: Dog Passport share text says "Hound"
- [ ] Residual grep: zero results (excluding deferred items below)

---

## Open follow-ups (deferred — track elsewhere)

**User-facing branding:**
- Domain registration: `hound.app` (currently using personal email in privacy/ToS)
- Email forwarding: forward `support@hound.app` → personal email once domain is live
- Logo refinement: remove "Quest spark" decorative element from `assets/logo_icon.svg` (cosmetic)

**Data migration:**
- Hive box prefixes: `dogquest_*` → `hound_*` (user data; deferred to separate migration sprint)

**Build artifacts:**
- `pubspec.yaml` `name: dogquest` → `name: hound` (cosmetic; affects Dart package name only, no user surface)
- `key.properties` `keyAlias=dogquest` and keystore filename (deferred; rotate keystore password before public Play Store anyway)
- `lib/widgets/dogquest_banner_ad.dart` filename (deferred; non-critical)
- `.github/workflows/dogquest-ci.yml` filename (deferred; rename during quiet CI window)

**ML scripts:**
- `train_model_v5.py` and `train_model_v6.py` banner comments (deferred; no user surface)
- `docs/prd.md` and roadmap brainstorms (deferred)

**Platform-specific:**
- iOS rebrand (deferred; `ios/` directory does not exist yet; action when iOS build is enabled)

---

## Links

- Git repo root: `C:\Users\Administrator\AviQuest-\`
- Project root: `C:\Users\Administrator\AviQuest-\dogquest\`
- Firebase Console: https://console.firebase.google.com/
- Supabase Dashboard: https://app.supabase.com/
- Play Console (future): https://play.google.com/console/
