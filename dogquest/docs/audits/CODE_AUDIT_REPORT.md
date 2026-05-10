# DogQuest Code Quality Audit Report
**Date:** 2026-03-14
**Scope:** `lib/` directory — 40,691 lines across ~80 Dart files

---

## 1. Architecture Patterns — GOOD with caveats

**State Management:** Riverpod (`flutter_riverpod` + `ConsumerWidget`/`ConsumerStatefulWidget`) used consistently across all screens. Providers defined per-service and injected via `ProviderScope` overrides in `main.dart`. This is a well-structured approach.

**Separation of Concerns:** Clear layering — `models/`, `services/`, `screens/`, `widgets/`, `helpers/`, `security/`. Services encapsulate business logic; screens handle UI. The `IdentificationOrchestrator` pattern properly separates ML inference from UI.

**Router:** `go_router` with auth-gated redirects in `router.dart`. Clean route definitions.

**Issues:**
- **`main.dart` is 500+ lines** — acts as bootstrap, splash, initialization, and service wiring. The `_initializeServices()` function creates ~20 service instances with manual wiring. Consider extracting a `ServiceLocator` or `AppModule` class.
  - File: `lib/main.dart:350-500` (service initialization block)
- **No dependency injection framework** — all providers are manually overridden in `_initializeServices`. With 20+ services this becomes fragile.

---

## 2. Code Smells — MODERATE concerns

### God Classes (files > 800 lines)
| File | Lines | Concern |
|------|-------|---------|
| `screens/quiz_screen.dart` | 1,648 | 4 AnimationControllers, quiz logic, scoring, confetti, UI all in one class |
| `screens/profile_screen.dart` | 1,454 | Profile + stats + achievements + avatar picker in one file |
| `screens/map_tab.dart` | 1,395 | 4 sub-views (_NeighborhoodView, _SightingLogView, _BreedLocationsView, _LiveMapView) crammed in one file |
| `screens/identify_screen.dart` | 1,241 | Camera + ML + results + gallery + zoom + torch all in one StatefulWidget |
| `screens/lost_dog_hub_screen.dart` | 1,221 | Hub + report flow + scan results combined |
| `widgets/dog_found_dialog.dart` | 1,045 | Dialog with heavy custom painting |
| `screens/scan_stray_screen.dart` | 977 | Scan + results + matching in one file |

**Recommendation:** Extract sub-views in `map_tab.dart` into separate files. Split `quiz_screen.dart` quiz logic into a `QuizController` and separate result/confetti widgets. Break `identify_screen.dart` camera management into a `CameraManager` mixin or service.

### Duplicate Patterns
- `ScaffoldMessenger.of(context).showSnackBar(...)` appears 30+ times across the codebase. Consider a `SnackBarHelper` utility.
- Image picker boilerplate (`pickImage` + error catch + mounted check) duplicated in `scan_stray_screen.dart`, `identify_screen.dart`, `my_dog_wizard_screen.dart`.

---

## 3. Error Handling — GOOD

**Strengths:**
- Global error handlers: `FlutterError.onError`, `PlatformDispatcher.instance.onError`, custom `ErrorWidget.builder` — all properly configured in `main.dart:114-145`.
- Sentry integration wired (DSN via `--dart-define`), with graceful fallback to local logging when no DSN.
- `AuthService` wraps `DioException` into typed `AuthException` with user-facing messages.
- `mounted` checks before `setState` after async operations (consistently applied).
- Camera errors produce user-friendly messages via `_friendlyError()`.

**Issues:**
- **`auth_service.dart:71-80`** — Offline login fallback only checks email match, no password verification. An attacker with physical access could log in with any password if the email is known.
- **`api_client.dart:38-44`** — On 401, the token is cleared and `has_auth_token` set to false, but no user-facing notification or redirect to login. The user may see stale data.
- **`main.dart:476`** — `.catchError((e) { ... })` used instead of try/catch. The `.catchError` pattern can silently swallow errors if the Future type doesn't match.

---

## 4. State Management — GOOD

**Pattern:** Riverpod providers for services, `setState` for local widget state. This is appropriate for the app's complexity.

**Issues:**
- **`quiz_screen.dart:30-56`** — 15+ local state variables managed via `setState`. This widget would benefit from a dedicated `QuizNotifier` (Riverpod `StateNotifier` or `Notifier`) to separate quiz state from UI.
- **`identify_screen.dart:55-80`** — 10+ state variables for camera/zoom/torch/flash. Consider a `CameraState` value object.
- **`map_tab.dart` sub-views** use `ref.read()` inside `build()` — this is correct for fire-and-forget reads but won't trigger rebuilds if data changes. Some should use `ref.watch()` (e.g., `_NeighborhoodView` reading friendship data).

---

## 5. Performance Concerns — MODERATE

**Strengths:**
- ML image preprocessing runs in a separate isolate via `compute()` (`tflite_identification_service.dart:28`).
- Camera lifecycle properly managed — disposed on pause, reinitialized on resume.
- `DogService.load()` parses JSON on main thread but yields with `Future.delayed(Duration.zero)` to let animations tick.

**Issues:**
- **`main.dart:370-445`** — `_initializeServices` runs ~20 service initializations sequentially. Only two are parallelized (`dailyChallenge` + one other). More services could be parallelized (analytics, notifications, location are independent).
- **`map_tab.dart`** — `_NeighborhoodView` calls `friendSvc.getNeighborhoodDogs()` inside `build()`. If this involves computation, it runs every rebuild. Should be cached or computed outside build.
- **`quiz_screen.dart`** — 4 `AnimationController` instances created in `initState`. While all are properly disposed, the confetti system generates 40 particle objects on init even if the user never completes the quiz.
- **`constants.dart`** — `AvatarOption.isUnlocked` stores closures that get evaluated per-frame in avatar grid. Consider caching unlock states.

---

## 6. Security Issues — LOW-MODERATE

**Strengths:**
- JWT tokens stored in `FlutterSecureStorage` (platform Keychain/Keystore) — not in Hive or SharedPreferences.
- Hive sightings box encrypted with AES key stored in secure storage (`main.dart:40-55`).
- `SecurityManager` class for orientation lock and other protections.
- API base URL injected via `--dart-define`, not hardcoded as a secret.
- Sentry DSN passed via `--dart-define=SENTRY_DSN=...`.
- No hardcoded API keys, secrets, or credentials found in source.

**Issues:**
- **`api_client.dart:16`** — Default API URL is `https://10.0.2.2:8000/api/v1` (Android emulator localhost). This is fine for dev but ships in release builds if `--dart-define` is forgotten. Consider failing loudly in release mode if no URL is configured.
- **`auth_service.dart:71-80`** — Offline login with no password check (see Error Handling above). This is a security gap.
- **`auth_service.dart:37-39`** — Password sent in plaintext JSON body. This is standard for HTTPS but the default URL uses a local IP. Ensure TLS is enforced in production.
- **No certificate pinning** — The Dio client trusts system certificates. For a production app handling user data, consider certificate pinning.
- **`auth_service.dart:27-30`** — Offline registration stores username/email in unencrypted Hive box (`dogquest_player_stats`). The JWT box is encrypted, but PII leaks through Hive.

---

## 7. Dead Code — LOW

- **No TODO/FIXME/HACK comments found** — clean codebase.
- **No obvious commented-out code blocks** detected.
- **Potential unused services:** `dog_social_service.dart` (564 lines) defines a rich social API (follow, feed, playdate, communities) that appears to be demo/mock-only with no backend integration. Verify this is intentional scaffolding vs dead code.

---

## 8. Dependency Health — GOOD

**pubspec.yaml analysis:**

| Package | Version | Status |
|---------|---------|--------|
| `flutter_riverpod` | ^2.5.0 | Current |
| `go_router` | ^14.0.0 | Current |
| `dio` | ^5.4.0 | Current |
| `camera` | ^0.10.5 | Current |
| `tflite_flutter` | ^0.11.0 | Current (note: known quirks with output buffers) |
| `hive_flutter` | ^1.1.0 | Mature but consider migration to Isar for better performance |
| `flutter_map` | ^8.2.2 | Current |
| `sentry_flutter` | ^8.12.0 | Current |
| `firebase_core` | ^4.5.0 | Current |

**Concerns:**
- **`flutter_lints` ^3.0.0** in dev_dependencies — this is the older package. The Flutter team recommends `flutter_lints` has been replaced by the `flutter` analysis options. Consider using `analysis_options.yaml` with `package:flutter_lints/flutter.yaml` or switching to `very_good_analysis` for stricter rules.
- **No `analysis_options.yaml` strict mode** detected — enabling `strict-casts`, `strict-inference`, and `strict-raw-types` would catch type issues at compile time.
- **29 direct dependencies** is moderate but manageable. No obvious unnecessary dependencies.

---

## Summary: Priority Action Items

### Critical (fix before release)
1. ~~**Offline login has no password verification** — `auth_service.dart:71-80`~~ **FIXED (TASK-043)**: offline login/register now rejected
2. ~~**PII stored in unencrypted Hive box** — `auth_service.dart:27-30`~~ **FIXED (TASK-044)**: removed PII storage from Hive
3. ~~**Default API URL ships in release builds** — `api_client.dart:16`~~ **FIXED (TASK-045)**: default is now empty string with `ApiClient.isConfigured` gate

### High (architectural improvements)
4. **Extract `_initializeServices` into a proper DI module** — `main.dart:350+`
5. ~~**Split `quiz_screen.dart` (1,648 lines) into controller + widgets**~~ **FIXED (TASK-046)**: refactored to ~680 lines + 4 extracted widgets
6. **Split `identify_screen.dart` camera logic into reusable mixin/service**
7. ~~**Split `map_tab.dart` sub-views into separate files**~~ **FIXED (TASK-047)**: refactored to ~1,239 lines + 4 extracted widgets

### Medium (code quality)
8. **Create SnackBar helper utility** to eliminate 30+ duplicate patterns
9. **Create image picker helper** to deduplicate camera/gallery boilerplate
10. **Parallelize more service inits** in `_initializeServices`
11. **Add strict analysis options** (`strict-casts`, `strict-inference`)
12. **Cache `AvatarOption.isUnlocked` results** instead of evaluating per-frame

### Low (nice-to-have)
13. **Consider certificate pinning** for production API calls
14. **Evaluate Hive -> Isar migration** for better query performance
15. **Verify `dog_social_service.dart`** is intentional scaffolding
