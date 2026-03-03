# AviQuest Architecture Refactor Analysis

**Date:** 2026-02-28
**Scope:** Full architecture assessment of the AviQuest Flutter application
**Status:** Proposal — no code changes included

---

## Table of Contents

1. [Current Pain Points (Measurable)](#1-current-pain-points-measurable)
2. [Architecture Options](#2-architecture-options)
3. [Pros, Cons, Migration Cost, Risk](#3-pros-cons-migration-cost-risk)
4. [Failure Modes](#4-failure-modes)
5. [Recommendation with Rationale](#5-recommendation-with-rationale)
6. [Incremental Migration Plan](#6-incremental-migration-plan)

---

## 1. Current Pain Points (Measurable)

### 1.1 Monolithic Single-File Architecture

| Metric | Value | Industry Guideline |
|--------|-------|--------------------|
| Total lines in `main.dart` | **5,397** | < 300–500 per file |
| Number of Dart source files | **1** | 20–40+ for app of this scope |
| Classes defined | **3** (Bird, AviQuest, HomeScreen) | 15–25+ |
| Lines of hardcoded data | **~4,350** (393 Bird entries) | 0 (externalized) |
| Lines of application logic + UI | **~1,050** | Should be split across 15+ files |

**Impact:** Every change to any part of the app — data, UI, logic — requires
editing the same 5,397-line file. Code review diffs are meaningless when the
entire app is one file. IDE navigation, find-and-replace, and merge conflicts
all scale poorly.

### 1.2 Zero Separation of Concerns

All responsibilities live in `_HomeScreenState`:

| Responsibility | Lines (approx.) | Should Be |
|----------------|-----------------|-----------|
| Hive persistence | 4569–4574 | Dedicated repository class |
| Camera management | 4576–4598 | Dedicated service |
| Audio playback | 4729–4731 | Dedicated service |
| XP/level calculation | 4736–4743 | Domain/business logic layer |
| Achievement tracking | 4762–4799 | Domain/business logic layer |
| Bird identification (simulated) | 4601–4624 | Service/use-case layer |
| UI rendering (5 tabs) | ~800 lines | 5+ separate widget files |
| Dialog construction | ~150 lines | Reusable widget components |

**Impact:** Cannot test business logic without instantiating the entire widget
tree. Cannot reuse any component. A bug in the XP formula requires touching
the same class that renders the camera preview.

### 1.3 Data Integrity and Persistence Gaps

| Issue | Measurement | Risk |
|-------|-------------|------|
| Achievements stored in-memory only | `Set<String> unlockedAchievements` | **Lost on every app restart** |
| XP/level stored in-memory only | `int level`, `int xp`, `int streak` | **Lost on every app restart** |
| Bird data stored as name strings | `Box<String>` in Hive | Breaks if bird names change |
| No data validation | 0 assertions, 0 schema checks | Silent corruption possible |
| `firstWhere` without fallback guard | Used in aviary rebuild | Crash if bird removed from list |

**Impact:** Users lose all progression (level, XP, achievements, streak) every
time they close and reopen the app. This is a critical functional bug, not
just an architecture issue.

### 1.4 Error Handling

| Pattern | Count | Consequence |
|---------|-------|-------------|
| `catchError((_) {})` (silent swallow) | 2 | Failures invisible to user and developer |
| `catch (_) {}` (silent swallow) | 2 | Camera/photo failures silently ignored |
| Missing `try/catch` on async operations | 3+ | Potential unhandled exceptions |
| No logging framework | 0 log calls | Zero observability in production |

**Impact:** When audio fails to load, the network is down, or the camera
throws — the user sees nothing. Debugging production issues is impossible
without crash analytics or logs.

### 1.5 Test Coverage

| Metric | Value |
|--------|-------|
| Unit tests | **0** |
| Widget tests | **0** |
| Integration tests | **0** |
| Test directory | **Does not exist** |
| CI/CD pipeline | **None** |

**Impact:** Every change is a gamble. No regression safety net. Refactoring
without tests is significantly riskier — which is why Step 0 of any migration
plan must establish baseline tests first.

### 1.6 Performance Concerns

| Issue | Detail |
|-------|--------|
| Full widget rebuild on `setState()` | 9 `setState()` calls rebuild entire 5-tab scaffold |
| Bird list filtered every frame | `_buildFieldGuideTab()` filters 393 birds on each build |
| No list virtualization | Grid/list renders all collected birds, not just visible |
| 393 `const Bird(...)` objects in memory | ~40 KB of string data always resident |
| `CachedNetworkImage` without memory cap | No `memCacheHeight`/`memCacheWidth` set |

**Impact:** Jank on lower-end devices, especially when the aviary grows large
or during rapid tab switching.

---

## 2. Architecture Options

### Option A: Layered Feature-First (Provider + Repository Pattern)

```
lib/
├── main.dart                     # App entry, theme, routing
├── core/
│   ├── constants.dart            # Colors, magic numbers, strings
│   ├── theme.dart                # ThemeData extraction
│   └── utils.dart                # Level titles, XP formulas
├── data/
│   ├── bird_data.dart            # 393 Bird entries (or JSON loader)
│   ├── models/
│   │   ├── bird.dart
│   │   ├── player_progress.dart  # Level, XP, streak, achievements
│   │   └── achievement.dart
│   └── repositories/
│       ├── aviary_repository.dart
│       └── progress_repository.dart
├── services/
│   ├── audio_service.dart
│   ├── camera_service.dart
│   └── identification_service.dart
├── providers/
│   ├── aviary_provider.dart
│   ├── progress_provider.dart
│   └── field_guide_provider.dart
└── ui/
    ├── screens/
    │   ├── home_screen.dart
    │   ├── aviary_tab.dart
    │   ├── identify_tab.dart
    │   ├── field_guide_tab.dart
    │   ├── achievements_tab.dart
    │   └── profile_tab.dart
    ├── widgets/
    │   ├── bird_card.dart
    │   ├── rarity_badge.dart
    │   ├── bird_detail_dialog.dart
    │   ├── found_dialog.dart
    │   └── network_image.dart
    └── dialogs/
        └── level_up_snackbar.dart
```

**State management:** `provider` package (or `flutter_riverpod`)
**Persistence:** Hive with typed adapters (or migrate to `isar`)
**Data source:** Bird data stays in-code initially, extractable to JSON asset later

### Option B: BLoC Architecture (bloc + flutter_bloc)

```
lib/
├── main.dart
├── core/                          # Same as Option A
├── data/                          # Same as Option A
├── blocs/
│   ├── aviary/
│   │   ├── aviary_bloc.dart
│   │   ├── aviary_event.dart
│   │   └── aviary_state.dart
│   ├── identification/
│   │   ├── identification_bloc.dart
│   │   ├── identification_event.dart
│   │   └── identification_state.dart
│   ├── progress/
│   │   ├── progress_bloc.dart
│   │   ├── progress_event.dart
│   │   └── progress_state.dart
│   └── field_guide/
│       └── ...
├── services/                      # Same as Option A
└── ui/                            # Same as Option A
```

**State management:** `flutter_bloc`
**Persistence:** Same as Option A
**Distinguisher:** Strict event-driven state transitions, high boilerplate, excellent traceability

### Option C: Minimal Refactor (Extract + Riverpod Lite)

```
lib/
├── main.dart                     # Entry point only (~50 lines)
├── constants.dart                # Colors, theme, magic numbers
├── bird.dart                     # Bird model
├── bird_data.dart                # 393 entries
├── services.dart                 # Audio, camera, Hive wrappers
├── game_state.dart               # Riverpod providers for XP, level, aviary
├── screens/
│   ├── home_screen.dart
│   ├── aviary_tab.dart
│   ├── identify_tab.dart
│   ├── field_guide_tab.dart
│   ├── achievements_tab.dart
│   └── profile_tab.dart
└── widgets/
    ├── bird_card.dart
    └── rarity_badge.dart
```

**State management:** `flutter_riverpod` (lightweight)
**Persistence:** Keep Hive `Box<String>`, add a second box for progress
**Distinguisher:** Minimum viable refactor. Fewest new concepts, fastest to complete.

---

## 3. Pros, Cons, Migration Cost, Risk

### Option A: Layered Feature-First (Provider + Repository)

| Dimension | Assessment |
|-----------|------------|
| **Pros** | Clean separation of concerns; repository pattern makes swapping Hive for another DB trivial; Provider is the most widely adopted Flutter state solution; testable at every layer; scales well to 50+ screens |
| **Cons** | More boilerplate than Option C; Provider has known limitations with complex dependency graphs; `ChangeNotifier` can cause unnecessary rebuilds if not scoped carefully |
| **Migration cost** | **Medium** — ~15–20 new files, ~2–3 days of focused work; requires understanding Provider lifecycle |
| **Risk** | **Low-Medium** — Provider is battle-tested; main risk is introducing bugs during extraction since there are no existing tests |
| **New dependencies** | `provider` (or `flutter_riverpod`), potentially `freezed` for models |

### Option B: BLoC Architecture

| Dimension | Assessment |
|-----------|------------|
| **Pros** | Most rigorous state management; event/state separation creates perfect audit trail; built-in testing utilities (`blocTest`); forced unidirectional data flow prevents state bugs; excellent DevTools integration |
| **Cons** | Highest boilerplate (event + state + bloc per feature = 3 files minimum); steeper learning curve; overkill for an app with only 5 screens and simple state transitions; 12+ new files just for BLoCs |
| **Migration cost** | **High** — ~25–35 new files, ~3–5 days; requires learning BLoC patterns if unfamiliar |
| **Risk** | **Medium** — Over-engineering risk; the app's state is simple (collect bird, add XP, check achievements) and BLoC's ceremony adds friction without proportional benefit |
| **New dependencies** | `flutter_bloc`, `bloc`, `equatable`, potentially `freezed` |

### Option C: Minimal Refactor (Riverpod Lite)

| Dimension | Assessment |
|-----------|------------|
| **Pros** | Fastest to complete; fewest new files (~12–15); Riverpod is type-safe and compile-time checked; minimal learning curve; good enough for current app scale; easiest to review and validate |
| **Cons** | Less structured than A or B; may need further refactoring if app grows significantly; `services.dart` could become a new "god file" if not disciplined; no repository abstraction means Hive is harder to swap later |
| **Migration cost** | **Low** — ~12–15 new files, ~1–2 days of focused work |
| **Risk** | **Low** — Smallest delta from current code; each extraction step is independently verifiable; Riverpod is well-maintained and widely used |
| **New dependencies** | `flutter_riverpod` |

### Comparison Matrix

| Criteria | Option A | Option B | Option C |
|----------|----------|----------|----------|
| Testability | High | Highest | Medium |
| Boilerplate | Medium | High | Low |
| Learning curve | Low | Medium-High | Low |
| Scalability (50+ screens) | High | Highest | Medium |
| Migration effort (days) | 2–3 | 3–5 | 1–2 |
| New files created | 15–20 | 25–35 | 12–15 |
| Risk of introducing bugs | Medium | Medium-High | Low |
| Appropriate for app size | Yes | Over-engineered | Yes |

---

## 4. Failure Modes

### 4.1 Data Loss During Migration

**Scenario:** Changing the Hive box name, schema, or storage format breaks
existing users' saved aviary data.

**Likelihood:** Medium
**Severity:** Critical (users lose their bird collection)
**Mitigation:**
- Keep the `aviary_v2` box name and `Box<String>` format in the first migration phase
- Only change the storage format in a later phase with an explicit migration function
- Write a migration test that opens an existing box and verifies data integrity

### 4.2 State Synchronization Bugs

**Scenario:** Extracting state into providers/blocs introduces timing issues
where the UI shows stale XP, level, or achievement data after adding a bird.

**Likelihood:** Medium
**Severity:** Medium (visual glitch, not data loss)
**Mitigation:**
- Write unit tests for the state update flow (add bird -> XP increases -> level check -> achievement check) before extracting
- Use integration tests to verify the full flow works end-to-end after extraction

### 4.3 "Big Bang" Extraction Breaks Everything

**Scenario:** Attempting to extract all 5 tabs, all services, and all state
management in a single PR creates an unreviewable diff that introduces
multiple regressions simultaneously.

**Likelihood:** High (if migration is not incremental)
**Severity:** High (days of debugging)
**Mitigation:**
- Follow the incremental migration plan (Section 6)
- Each step must compile and run before proceeding to the next
- Commit after every successful extraction

### 4.4 Achievement/Progress State Still Not Persisted

**Scenario:** Refactoring is completed but nobody addresses the fundamental
bug — achievements, XP, level, and streak are still in-memory and lost on
restart.

**Likelihood:** Medium (easy to forget when focused on architecture)
**Severity:** Critical (core functionality broken)
**Mitigation:**
- The migration plan explicitly includes persisting progress state as a
  dedicated step (Step 4)
- Add an integration test that verifies progress survives an app restart cycle

### 4.5 Camera/Audio Service Extraction Breaks Platform-Specific Behavior

**Scenario:** Extracting `CameraController` and `AudioPlayer` into service
classes changes initialization timing or lifecycle, causing crashes on
specific Android versions.

**Likelihood:** Low-Medium
**Severity:** Medium
**Mitigation:**
- Extract services last, after the safer extractions (data, UI, state) are proven stable
- Test on physical devices, not just emulators
- Keep the same initialization order (`initState` -> `_initHive()` -> `_initCamera()`)

### 4.6 Performance Regression from Provider/Riverpod Overhead

**Scenario:** Wrapping state in providers adds listener overhead, causing
more rebuilds than the current `setState()` approach.

**Likelihood:** Low (Riverpod/Provider are optimized for this)
**Severity:** Low
**Mitigation:**
- Use `select` (Riverpod) or `Selector` (Provider) to scope rebuilds
- Profile before and after with Flutter DevTools
- The current `setState()` already rebuilds the entire scaffold, so scoped
  providers should actually improve performance

---

## 5. Recommendation

### Recommended: Option C (Minimal Refactor with Riverpod), evolving toward Option A

**Rationale:**

1. **Right-sized for the app.** AviQuest has 5 screens, 1 data model, and
   simple state transitions (identify -> collect -> gain XP -> check
   achievements). BLoC's ceremony (Option B) is disproportionate. Option A's
   full repository pattern is solid but adds abstractions the app doesn't yet
   need.

2. **Lowest risk.** Option C has the smallest diff from current code. Each
   extraction step can be verified independently. With zero existing tests,
   minimizing the surface area of change is critical.

3. **Fixes the critical bugs.** The migration plan includes persisting
   achievement/progress state, which is currently lost on restart. This is the
   highest-value change.

4. **Evolutionary path.** Option C's file structure is a subset of Option A.
   If the app grows (more screens, a backend API, user accounts), you can add
   a `repositories/` layer and more granular providers without throwing away
   work. Riverpod supports this evolution natively.

5. **Riverpod over Provider.** Riverpod is compile-time safe, doesn't depend
   on `BuildContext` for reads, supports async providers natively, and is the
   recommended successor to Provider by the same author. For a new
   architecture, starting with Riverpod avoids the known Provider pain points.

6. **Fastest to ship.** 1–2 days of focused work vs. 3–5 for BLoC. The
   sooner the refactor lands, the sooner the team can build features on a
   stable foundation.

---

## 6. Incremental Migration Plan (Safe Steps)

Each step is a **standalone, shippable commit**. The app must compile and run
correctly after every step. Steps are ordered by risk (lowest first).

### Step 0: Establish Baseline Tests

**Goal:** Create a minimal safety net before touching any code.
**Files created:** `test/bird_test.dart`, `test/game_logic_test.dart`
**What to test:**
- Bird XP calculation for each rarity tier
- `xpForNextLevel()` formula
- `levelTitle()` mapping
- Achievement unlock logic (mock the collection count)
- Bird weighted random distribution (statistical test)

**Risk:** None — additive only, no code changes.
**Commit message:** `test: add baseline unit tests for game logic`

### Step 1: Extract Constants and Bird Model

**Goal:** Move non-logic code out of `main.dart`.
**Files created:**
- `lib/constants.dart` — colors, rarity map, achievement definitions
- `lib/models/bird.dart` — Bird class, `xpForNextLevel()`, `levelTitle()`
- `lib/bird_data.dart` — the 393-entry `birds` list

**Changes to `main.dart`:** Replace inline definitions with imports.
**Validation:** App compiles, runs identically, existing tests still pass.
**Risk:** Very low — pure extraction, no behavior change.
**Commit message:** `refactor: extract Bird model, constants, and bird data into separate files`

### Step 2: Extract UI into Tab Screens

**Goal:** Break the 5 tab builder methods into standalone widget files.
**Files created:**
- `lib/screens/home_screen.dart`
- `lib/screens/aviary_tab.dart`
- `lib/screens/identify_tab.dart`
- `lib/screens/field_guide_tab.dart`
- `lib/screens/achievements_tab.dart`
- `lib/screens/profile_tab.dart`

**Changes to `main.dart`:** App entry point only (~30 lines). State
temporarily passed via constructor parameters (will be replaced by providers
in Step 3).
**Validation:** All 5 tabs render correctly, navigation works.
**Risk:** Low — UI extraction doesn't change logic.
**Commit message:** `refactor: extract tab screens into separate widget files`

### Step 3: Introduce Riverpod for State Management

**Goal:** Replace `setState()` with Riverpod providers.
**Files created:**
- `lib/providers/game_state_provider.dart` — XP, level, streak, achievements
- `lib/providers/aviary_provider.dart` — collected birds, Hive interaction
- `lib/providers/field_guide_provider.dart` — search, filter state

**Changes:**
- Wrap `AviQuest` app in `ProviderScope`
- Convert `HomeScreen` from `StatefulWidget` to `ConsumerWidget`
- Replace `setState()` calls with `ref.read(provider.notifier).method()`
- Tab screens become `ConsumerWidget` and read from providers

**Dependency added:** `flutter_riverpod` in `pubspec.yaml`
**Validation:** Full manual test of all flows (identify, collect, level up, achievement unlock, search, filter).
**Risk:** Medium — this is the highest-risk step. Providers must replicate exact `setState()` behavior.
**Commit message:** `refactor: introduce Riverpod state management, replace setState`

### Step 4: Persist Progress State (Bug Fix)

**Goal:** Fix the critical bug where XP, level, streak, and achievements are
lost on app restart.
**Changes:**
- Open a second Hive box: `Box('player_progress')`
- Serialize `PlayerProgress` (level, xp, streak, unlockedAchievements) to the box
- Load on startup, save on every state change
- Add migration logic for existing users (default to level 1 / 0 XP)

**Tests added:** Integration test that writes progress, "restarts" (closes and
reopens box), and verifies data survives.
**Risk:** Low-Medium — new persistence, but additive (doesn't change existing aviary box).
**Commit message:** `fix: persist player progress and achievements across app restarts`

### Step 5: Extract Services

**Goal:** Encapsulate platform dependencies behind clean interfaces.
**Files created:**
- `lib/services/audio_service.dart` — wraps `AudioPlayer`, handles errors
- `lib/services/camera_service.dart` — wraps `CameraController`, lifecycle
- `lib/services/identification_service.dart` — bird identification logic

**Changes:**
- Services registered as Riverpod providers (enables mocking in tests)
- `HomeScreen` no longer manages `AudioPlayer` or `CameraController` directly
- Error handling added: user-visible messages on failure instead of silent swallow

**Tests added:** Unit tests with mocked services.
**Risk:** Low-Medium — changing initialization order could affect Android lifecycle.
**Commit message:** `refactor: extract audio, camera, and identification services`

### Step 6: Extract Reusable Widgets

**Goal:** DRY up repeated UI patterns.
**Files created:**
- `lib/widgets/bird_card.dart` — used in aviary grid and field guide
- `lib/widgets/rarity_badge.dart` — rarity chip with color
- `lib/widgets/network_image.dart` — `CachedNetworkImage` wrapper with shimmer
- `lib/widgets/bird_detail_dialog.dart` — bird detail bottom sheet

**Validation:** Visual regression check — UI must be pixel-identical.
**Risk:** Very low — pure UI extraction.
**Commit message:** `refactor: extract reusable widget components`

### Step 7: Externalize Bird Data (Optional, Future)

**Goal:** Move 393 bird entries from code to a JSON asset file.
**Files created:**
- `assets/birds.json`
- `lib/data/bird_loader.dart` — JSON deserialization

**Changes:**
- `bird_data.dart` replaced by runtime JSON parsing
- `pubspec.yaml` updated with asset declaration
- Bird model gains `fromJson()` factory

**Benefit:** Bird data becomes editable without recompilation. Enables future
server-side bird database.
**Risk:** Low — JSON parsing is well-understood; add schema validation.
**Commit message:** `refactor: externalize bird data to JSON asset`

---

### Migration Summary

| Step | Description | Risk | New Files | Est. Effort |
|------|-------------|------|-----------|-------------|
| 0 | Baseline tests | None | 2 | 2–3 hours |
| 1 | Extract constants + model + data | Very Low | 3 | 1–2 hours |
| 2 | Extract tab screens | Low | 6 | 2–3 hours |
| 3 | Riverpod state management | Medium | 3 | 3–5 hours |
| 4 | Persist progress (bug fix) | Low-Medium | 1 | 2–3 hours |
| 5 | Extract services | Low-Medium | 3 | 2–3 hours |
| 6 | Extract reusable widgets | Very Low | 4 | 1–2 hours |
| 7 | Externalize bird data (optional) | Low | 2 | 1–2 hours |
| **Total** | | | **~24 files** | **~14–21 hours** |

### Rollback Strategy

Each step is a separate commit. If any step introduces a regression:

1. `git revert <commit>` to undo the problematic step
2. Investigate the issue on a branch
3. Re-apply with fixes

Because each step is independently functional, rolling back one step never
requires rolling back subsequent steps — they build on each other but each
leaves the app in a working state.

---

*This document is a living analysis. Update it as decisions are made and steps
are completed.*
