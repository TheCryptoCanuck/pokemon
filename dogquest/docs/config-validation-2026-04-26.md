# DogQuest — Configuration Validation Report
Generated: 2026-04-26

---

## Executive Summary

| Severity | Count |
|---|---|
| 🔴 Critical | 2 |
| 🟠 High | 1 |
| 🟡 Medium | 2 |
| 🔵 Low / Cosmetic | 3 |
| ✅ Positive controls | 7 |

All findings below include the exact file and line. Fixes are listed inline.

---

## 🔴 CRITICAL

### C-CONFIG-1 — Supabase anon key hardcoded in source
**File:** `lib/main.dart:108-109`

```dart
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_lrICH1RprCBAxgQAs8tg4g_eKAXDme4');
```

The real anon key ships in every build that omits `--dart-define=SUPABASE_ANON_KEY=...`, and the key is committed to git history. While Supabase anon keys are *technically* row-level-security-gated, they are still credentials: anyone with the APK or source can call your Supabase project directly.

**Fix:**
```dart
// Remove defaultValue — fail loudly at startup instead
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

// Add a guard in main(), same pattern as ApiClient.assertBaseUrl():
assert(
  _supabaseAnonKey.isNotEmpty,
  'SUPABASE_ANON_KEY must be set via --dart-define=SUPABASE_ANON_KEY=...',
);
```

Add to `android/key.properties` (gitignored) or a `.env.local` file:
```
SUPABASE_ANON_KEY=sb_publishable_lrICH1RprCBAxgQAs8tg4g_eKAXDme4
```

Then rotate the anon key in Supabase dashboard once the old one is no longer in any published APK.

---

### C-CONFIG-2 — Supabase project URL hardcoded in source
**File:** `lib/main.dart:106-107`

```dart
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL',
    defaultValue: 'https://hdcpymjnrbelaawhncep.supabase.co');
```

Lower severity than the key, but the project URL is now permanently in git history. Attackers can correlate the anon key + URL to directly query your database.

**Fix:** Same pattern — remove `defaultValue`, add assertion, inject via `--dart-define`. Both values should come from a local secrets file that is gitignored.

---

## 🟠 HIGH

### H-CONFIG-1 — Keystore password is sequential digits (OPS-C-002)
**File:** `android/key.properties:1-2`

```
storePassword=123456789101112131
keyPassword=123456789101112131
```

The keystore password is trivially weak. Noted as a known pre-production issue (OPS-C-002). The file is gitignored, so this does not leak through source control, but must be rotated before any Play Store submission.

**Fix:** `keytool -storepasswd -keystore C:/Users/Administrator/dogquest-release.jks` and update `key.properties`. Match the password in your secure vault (e.g., Bitwarden).

---

## 🟡 MEDIUM

### M-CONFIG-1 — ENV defaults to `'development'` in release builds
**File:** `lib/main.dart:103`

```dart
const _environment = String.fromEnvironment('ENV', defaultValue: 'development');
```

A `flutter build apk --release` without `--dart-define=ENV=production` will report `environment: development` to Sentry. Errors will be miscategorised in the Sentry dashboard.

**Fix:** Add `--dart-define=ENV=production` to the release build command in your `Makefile` and CI workflow. No code change needed, but document it. Optionally add a debug-mode assertion:
```dart
assert(
  kDebugMode || _environment == 'production',
  'ENV must be set to "production" in release builds.',
);
```

---

### M-CONFIG-2 — `.gitignore` has three duplicate blocks
**File:** `.gitignore:55-65`

`android/.gradle/` and `android/local.properties` appear three times each. No functional impact, but it indicates the file was concatenated carelessly — the same pattern that could lead to a *missing* entry being missed in review.

**Fix:** Deduplicate the three identical blocks. Keep one:
```
# Android Gradle build cache + machine-local paths
android/.gradle/
android/local.properties
```

---

## 🔵 LOW / COSMETIC

### L-CONFIG-1 — CI lint relaxation left in place (C4 sweep pending)
**File:** `.github/workflows/dogquest-ci.yml` (at repo root)

Active_Tasks C4 notes that `flutter analyze --no-fatal-warnings --no-fatal-infos` is a temporary workaround pending the `dart fix --apply` const-promotion sweep. This weakens CI lint gates.

**Action:** Run `dart fix --apply` from `dogquest/`, verify `dart analyze` is clean, then re-tighten CI to `--fatal-warnings --fatal-infos`. Tracked in Active_Tasks as C4 const-promotion sweep.

---

### L-CONFIG-2 — `analysis_options.yaml` is minimal; no additional lint rules
**File:** `analysis_options.yaml`

Only `prefer_const_constructors` and `prefer_const_literals_to_create_immutables` are added on top of `flutter_lints`. The project would benefit from:
- `avoid_print: true` (already in flutter_lints, but explicit is better for enforcement)
- `require_trailing_commas: true` (improves diff quality)
- `always_use_package_imports: true` (prevents relative-import drift across 59 services)

These are not blocking; apply during the C4 sweep.

---

### L-CONFIG-3 — `pubspec.yaml` version not incremented before distribution
**File:** `pubspec.yaml:3`

```yaml
version: 0.1.0+1
```

The closed-beta APK that was built is signed and installable, but versionCode `1` / versionName `0.1.0` means you cannot distinguish between beta builds in crash reports. Before distributing more builds, bump to `0.1.0+2` (or use a CI-injected build number).

---

## ✅ Positive Controls

These are correctly configured and worth preserving:

| Control | Location |
|---|---|
| `android/key.properties` gitignored | `.gitignore:2` |
| `*.jks` / `*.keystore` gitignored | `.gitignore:3-4` |
| `API_BASE_URL` has no default — fails loudly | `lib/services/api_client.dart:14` |
| JWT stored in `FlutterSecureStorage`, not plain Hive | `lib/services/api_client.dart:66` |
| `SENTRY_DSN` has no default — Sentry is opt-in | `lib/main.dart:102` |
| Release build: `minifyEnabled true` + `shrinkResources true` + ProGuard | `android/app/build.gradle:77-79` |
| Hive sightings box AES-encrypted | `lib/main.dart:95` (noted in CLAUDE.md) |

---

## Recommended Action Order

1. **C-CONFIG-1 + C-CONFIG-2** — Remove Supabase hardcoded defaults from `main.dart`. Store real values in `android/key.properties` or a `.dart_defines` file (gitignored). Add assertions. ~30 min.
2. **H-CONFIG-1** — Rotate keystore password before any Play Store submission. ~10 min.
3. **M-CONFIG-1** — Add `--dart-define=ENV=production` to Makefile `release` target and CI release job. ~5 min.
4. **M-CONFIG-2** — Deduplicate `.gitignore`. ~2 min.
5. **L-CONFIG-1** — C4 const sweep → re-tighten CI. Already tracked in Active_Tasks.
6. **L-CONFIG-3** — Bump `pubspec.yaml` version before next APK distribution.

---

*solid — findings verified against actual file content at file:line citations listed above.*
