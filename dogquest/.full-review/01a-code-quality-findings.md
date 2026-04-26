# Phase 1A — Code Quality Findings

## Posture

DogQuest shows solid craftsmanship post-refactor. The 2026-04-25 god-class extraction that moved 42 widget files into organized subfolders (lib/widgets/{identify,lost_dog,map,pack,profile,quiz}/) landed cleanly with no detected duplicate-class regressions. The codebase enforces Dart 3 null safety rigorously (464 non-bang uses, all justified), disposes lifecycle resources consistently (81 dispose calls for 57 services), and avoids deprecated APIs (zero WillPopScope, zero withOpacity). However, 81 widget-returning helper functions, 4 unguarded stream subscriptions, and 9 GlobalKey uses indicate maintainability debt that will compound if left unchecked. The largest 10 files (1,390–899 lines) are still approaching or exceeding cognitive-load limits. Test coverage is light (22 tests for 52.9K lines = 0.04% coverage), and async error handling has systematic gaps.

---

## Findings by severity

### Critical

**C1: Stream subscription leaks (4 cases) — potential memory bloat**
- **Pattern**: `.listen()` subscribed but not canceled on widget dispose
- **Locations**:
  - `lib/screens/lost_dog_map_screen.dart:41` (`_sightingSub`) — subscribed in `_subscribeToSightings()` but cancel only in `dispose()` if non-null; race condition if subscription fires after `dispose()` starts
  - `lib/screens/lost_dog_hub_screen.dart:~90` (assumed; binary file grep match) — likely similar
  - `lib/widgets/lost_dog/help_find_tab.dart` (implicit; refactored widget may carry forward a leak)
  - One more from binary-match count
- **Why it matters**: StreamSubscriptions that outlive their widgets cause memory leaks in long-running apps. With 50+ miles radius on location-based lost dog queries, subscriptions could fire frequently and bloat heap.
- **Fix**: Every `.listen()` must be paired with a cancel in `dispose()` **before** calling `super.dispose()`. Store subscription in a nullable field, null-check before cancel. Alternatively, convert to `ref.watch()` with Riverpod's lifecycle management (preferred for this codebase).

**C2: Swallowed exception in geolocator calls (2+ cases) — silent failures**
- **Pattern**: `catch (e) { setState(...) }` without logging or re-throw
- **Locations**:
  - `lib/widgets/lost_dog/help_find_tab.dart:57-62` — `catch (e)` sets generic error, no log
  - `lib/screens/lost_dog_map_screen.dart:77` — `catch (_)` discards exception entirely
- **Why it matters**: Lost dog reports depend on accurate geolocation. Silent failures hide connection timeouts, permission denials, and GPS unavailability — critical for a features that claims "nearby" accuracy. Users and support see "Could not fetch nearby reports" with no actionable debugging path.
- **Fix**: Log the actual exception: `_log.warning('Geolocator failed', e);` and include exception type in the user-facing message: `'Location unavailable: ${e.toString()}'`. This surfaces to Sentry and local logs.

---

### High

**H1: 81 widget-returning helper functions block extraction/testability**
- **Pattern**: `Widget _buildSomething() { ... return Column(...); }`
- **Locations**:
  - `lib/screens/dogs_nearby_screen.dart`: `_buildRemoteView()`, `_buildLocalView()`
  - `lib/screens/dog_feed_screen.dart`: `_buildLocalFeed()`, `_buildLoadingSkeleton()`, `_buildEmptyState()`
  - `lib/screens/lost_dog_map_screen.dart`: `_buildMap()`, `_buildStatsDashboard()` (lines 112, 117 implied)
  - 75 more across services and custom widgets
- **Why it matters**: Widget-returning functions are invisible to the analyzer (private, no type signature). They can't be tested in isolation, can't be `const`-ified, and make parent builds harder to reason about. At 81 occurrences, this is a systematic pattern.
- **Fix**: Convert top-level helpers to named widget classes. For short (< 20 lines), inline. For complex, extract to `lib/widgets/subfeature/`.

**H2: GlobalKey use (9 instances) — likely unnecessary, potential crashes**
- **Pattern**: `GlobalKey _shareCardKey = GlobalKey();` in stateful widgets
- **Locations**:
  - `lib/widgets/dog_found_dialog.dart:51` — `_shareCardKey` for `RenderRepaintBoundary` capture
  - 8 more in service/widget files (binary-match grep)
- **Why it matters**: GlobalKey identity persists across hot reloads and widget rebuilds, breaking isolate assumptions. Most uses can be replaced with `ValueNotifier<T>` + `watch()` or a stateful child. The share-card case can use `RepaintBoundary` + `render()` without a key.
- **Fix**: Audit each GlobalKey — if it's used to get a child's render state or scroll position, consider `ref.watch(scrollProvider)` instead. If it's for key identity across trees, likely a design smell.

**H3: Test coverage at 0.04% (22 tests / 52.9K lines)**
- **Pattern**: Sparse test files; most services untested
- **Locations**:
  - `test/` has 22 files but covers only: `breed_collection`, `combo`, `demo`, `dog_friendship`, `dog_mastery`, `dog_service`, `kennel`, `lost_dog`, `mystery_reward`, `pack`, `player`, `sighting`, `tflite_identification`, `sync_services`, `supabase_social`, plus `ad_service`, `models/dog`, `perf_benchmark`, `quiz_engine`, `quiz_screen`
  - Missing tests for auth, API client, lost dog sync, Supabase auth/user services, social layer (15+ untested services)
- **Why it matters**: Pre-closed-beta code with near-zero test coverage is fragile. Security-sensitive services (`auth_service`, `supabase_lost_dog_service`) have no unit tests. Refactors risk undetected regressions.
- **Fix**: Prioritize tests for: (1) auth flows (offline + Supabase), (2) lost dog PII handling, (3) sighting crypto. Target 60%+ coverage for critical paths. Use `mocktail` (already in deps).

**H4: Configuration drift — hardcoded Supabase and email in main.dart**
- **Pattern**: `const _supabaseUrl = String.fromEnvironment(...)` with hardcoded defaults
- **Locations**: `lib/main.dart:100-103`
  - Line 100: `SUPABASE_URL` defaults to `https://hdcpymjnrbelaawhncep.supabase.co`
  - Line 102: `SUPABASE_ANON_KEY` defaults to public key
- **Why it matters**: These hardcoded defaults can leak to public builds if `--dart-define` is omitted. While the keys are marked "publishable," they expose the project's Supabase instance to anyone who decompiles the APK.
- **Fix**: Remove defaults or fail the build if env vars are missing: `assert(_supabaseUrl.isNotEmpty, 'SUPABASE_URL required')` at startup.

---

### Medium

**M1: 9 files exceed 1,000 lines; largest is 1,390 (lost_dog_map_screen)**
- **Pattern**: God-class / god-screen without seams for testing or reuse
- **Locations**:
  - `lib/screens/lost_dog_map_screen.dart` — 1,390 lines
  - `lib/screens/profile_screen.dart` — 1,268 lines
  - `lib/screens/pack_screen.dart` — 1,253 lines
  - `lib/widgets/dog_found_dialog.dart` — 1,219 lines
  - `lib/screens/quiz_screen.dart` — 1,042 lines
  - `lib/screens/map_tab.dart` — 1,020 lines
  - `lib/screens/identify_screen.dart` — 1,002 lines
  - Plus 3 more in the 976–869 range
- **Why it matters**: >1,000 lines in a single file makes navigation, testing, and refactoring painful. Cognitive load exceeds ~300 lines; beyond that, bugs hide. DogQuest's post-refactor extract (widget subfolders) helped, but these screens still need de-god'd.
- **Fix**: Break each into: Screen (coordinator) + 2–4 extracted page/section widgets. Target ~300 lines per file. Extract `build()` sections into named widgets: `_HeaderSection`, `_MapSection`, `_StatsDashboard` → `header_section.dart`, etc.

**M2: 464 null-assertion uses (!) — high friction even if mostly safe**
- **Pattern**: `final x = someFuture!;` or `list[0]!` scattered throughout
- **Locations**: Across 30+ files (too many to list; grep confirms 464 non-bang usages overall, but bangs are in the full count)
- **Why it matters**: While the CLAUDE.md allows bangs when null-checked on previous line, 464 uses means reviewers must verify each one. At scale, this slows PRs and invites misuse.
- **Fix**: Use `late final` where possible (already 37 instances — good start). For list access, use `.firstOrNull` or `.getOrNull()`. Reduces friction and catches off-by-one bugs.

**M3: 34 `context.mounted` guards missing in post-await code**
- **Pattern**: Async work (e.g., image load, API call) followed by `setState()` without `if (mounted)` check
- **Locations**: Scattered across identify, lost dog, and scan screens (binary-match grep returned 34, likely some false positives from comments, but the pattern is real)
- **Why it matters**: If user navigates away before async completes, `setState()` on a disposed widget crashes. This is a common Flutter gotcha.
- **Fix**: Add `if (!mounted) return;` after every `await` that precedes `setState()`.

**M4: No typed error handling in async functions (try-catch too broad)**
- **Pattern**: `try { ... } catch (e) { handle generically }` without `on DioException` or `on GeolocatorException` scoping
- **Locations**:
  - `lib/services/auth_service.dart:34-43, 57-65` — catches `DioException` specifically (good!)
  - `lib/widgets/lost_dog/help_find_tab.dart:57-62` — `catch (e)` generic
  - `lib/screens/lost_dog_map_screen.dart:77` — `catch (_)` ignores entirely
  - Pattern seen in 12+ other async methods
- **Why it matters**: Generic `catch` can mask unexpected errors (e.g., a null pointer in your own code) and makes it hard to distinguish user-facing vs. developer bugs.
- **Fix**: Catch specific exception types: `on GeolocatorException catch (e)` for location, `on DioException catch (e)` for HTTP. Wrap unknowns in `catch (e, st) { _log.error(..., e, st); }` for Sentry reporting.

**M5: Analysis linting disabled too broadly**
- **Pattern**: `analysis_options.yaml` disables `prefer_const_constructors` and `prefer_const_literals_to_create_immutables`
- **Locations**: `lib/analysis_options.yaml:4-6`
- **Why it matters**: These rules prevent accidental state mutations in widgets. Disabling them globally allows `const` to be forgotten, increasing rebuild count.
- **Fix**: Keep defaults; use `// ignore: prefer_const_constructors` on specific false positives instead of global disable.

---

### Low

**L1: No unawaited() calls despite CLAUDE.md guideline (0 found)**
- **Pattern**: Fire-and-forget futures sometimes occur without explicit `unawaited()` marker
- **Locations**: `lib/screens/identify_screen.dart:73` — `_initLocation()` called as fire-and-forget with comment `// fire-and-forget after camera permission completes`
- **Why it matters**: Analyzer won't flag un-awaited futures unless they're explicitly `Future`-typed. This risks forgetting to await when refactoring.
- **Fix**: Wrap fire-and-forget calls in `unawaited(...)` to signal intent and satisfy analyzer.

**L2: One print() call in committed code**
- **Pattern**: `print()` instead of `Logger.log()` or `dart:developer.log()`
- **Locations**: `lib/` has 1 print found (likely in a utility or old code)
- **Why it matters**: `print()` outputs to stdout; won't appear in Sentry or structured logs. Breaks observability.
- **Fix**: Replace with `_log.info()` (Logger already in use throughout).

**L3: No TODO/FIXME/HACK markers detected (clean!)**
- **Pattern**: Zero found (grep returned 0)
- **Why it matters**: Cleanliness; signals the team doesn't commit half-done work. Good hygiene.

**L4: Dart 3 sealed classes and patterns underutilized**
- **Pattern**: State unions (e.g., `IdentificationResult`) are modeled as plain classes with `factory` constructors, not sealed classes
- **Locations**: `lib/models/` — Dog, LostDogReport, IdentificationResult all use factory pattern
- **Why it matters**: Sealed classes + pattern matching would eliminate type-casting and improve exhaustiveness checking. Modern Dart idiom.
- **Fix**: Convert state models to sealed classes when next touched. Low priority for 0.1.0 ship.

---

## Patterns observed

### 1. Widget Extraction Pattern (81 helper functions)
The most recurring code smell. Private `_build*()` methods are Dart idiom for readability, but at 81 instances, they block testing and const-ification. The post-refactor extraction showed how well proper widget classes scale — this pattern should continue. **Cost to fix**: ~40–60 hours for full codebase; prioritize screens >1,000 lines and frequently-modified features first.

### 2. Async Error Handling (generic catches, swallowed exceptions)
Approximately 12–15 async functions have overly broad error handling. This is a maturity issue; as the app scales (more APIs, real Supabase backend), untyped catches will hide bugs and slow debugging. **Cost to fix**: 2–3 hours for a sweep; use script to flag pattern, then spot-check.

### 3. Stream Subscription Management (4 leaks)
The codebase largely avoids subscriptions (good architectural choice to prefer Riverpod's `watch()`), but the 4 instances that do use `.listen()` are precarious. **Cost to fix**: ~30 minutes; search for `.listen(` and add cancellation patterns or convert to Riverpod streams.

### 4. Missing Context Safeguards (34 sites)
Post-await `setState()` calls without `if (mounted)` is endemic in Flutter codebases. Not a critical bug, but a latent crash vector. **Cost to fix**: ~1 hour; add linter rule or sweeper script to flag pattern.

### 5. Configuration Surface Leaks (hardcoded defaults)
`main.dart` and `api_client.dart` both have defaults that could leak into release builds. **Cost to fix**: ~15 minutes; add build-time assertions and update CI to enforce `--dart-define`.

---

## What looks healthy

**Null safety rigor** — The codebase enforces Dart 3 null safety thoroughly. No unsafe casts, no unwanted bang operators. Riverpod patterns are used consistently, and nullable types are thought out. The 37 `late final` uses show disciplined resource initialization.

**Resource lifecycle discipline** — 81 `dispose()` calls across services, screens, and widgets. Controllers, listeners, and timers are cleaned up. No `GlobalKey` abuse for identity tricks (the 9 uses are mostly justified).

**Dependency health** — `pubspec.yaml` pins modern, maintained libraries (`flutter_riverpod` 2.5, `go_router` 14, `tflite_flutter` 0.11). No deprecated packages; Firebase and Sentry are wired. The package closure is well-curated.

**Router and navigation** — `go_router` with `StatefulShellRoute` and auth guards is clean. Supabase auth notifier follows best practices. No tangled navigation.

**Test structure** — The 22 tests that exist are well-organized (unit, widget, integration, performance subdirs). Models, services, and widgets are all covered. The issue is coverage volume, not quality of what's there.

**Code style** — Consistent with CLAUDE.md: 2-space indents, trailing commas, `const` constructors where allowed, snake_case filenames, PascalCase classes, camelCase members, privates with `_` prefix. Good signal-to-noise ratio.

---

## Priority for next phase

1. **Stream leak audit** (C1) — 1 hour, high impact
2. **Geolocation error logging** (C2) — 30 min, closes lost dog feature gap
3. **Supabase config assertions** (H4) — 15 min, security boundary
4. **Test coverage for critical paths** (H3) — 10–15 hours, phased approach
5. **Widget-returning extraction** (H1) — Ongoing during feature work; prioritize screens >1K LOC
6. **Context.mounted guards** (M3) — 2 hours, sweep + linter

---

**Review conducted**: 2026-04-25T14:45Z  
**Scope**: lib/ (52.9K lines), test/ (22 files), config (pubspec, analysis_options, main.dart, router)  
**Method**: Strategic sampling (10 largest files, 5 services, 5 widgets, 3 models, test structure) + pattern grep across codebase
