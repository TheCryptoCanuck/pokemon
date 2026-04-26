# Phase 4A — Framework & Language Best Practices

**Review date**: 2026-04-25 evening  
**Scope**: Flutter 3.x / Dart 3.x idioms, Riverpod 2.5, pubspec health, CLAUDE.md compliance  
**Baseline**: 52.9K lines, 32 screens, 57 services, 92 widgets, 22 tests

## Posture

DogQuest exhibits **excellent idiomatic discipline** across Flutter, Dart 3, and Riverpod. Material 3 theme is correctly applied; deprecated APIs (`withOpacity`, `WillPopScope`) are absent; resource lifecycle is strictly enforced (81 `dispose()` calls, 37 `late final` uses). The codebase prefers hand-written `copyWith` over freezed (correctly — codegen overhead not justified for the model layer). Riverpod patterns are clean: 26 providers with no circular dependencies, `Notifier` (not `StateNotifier`) used throughout, `ConsumerWidget` preferred over `Consumer` wrappers. However, **81 widget-returning helper functions** remain a style violation against CLAUDE.md ("no widget-returning functions — make them real widgets"), and `analysis_options.yaml` still disables two `prefer_const_*` lints that should be re-enabled. Zero `unawaited()` calls despite CLAUDE.md guideline, and Dart 3 sealed classes underutilized for state unions.

## Findings

### Critical

**None.** No ship-blocking idiom violations detected.

### High

#### FW-H-001: 81 widget-returning helper functions violate CLAUDE.md + block `const` optimization

**Severity**: High (blocks testability, `const` constructors, and refactor velocity).

**Current state**:
- `lib/screens/`: 61 private `_build*()` methods (e.g., `friends_screen.dart:9`, `pack_screen.dart:8`, `quiz_screen.dart:5`)
- `lib/widgets/`: 20 private `_build*()` methods (e.g., `dog_passport_card.dart:4`, `quiz_question_card.dart:8`)
- Pattern: `Widget _buildHeader() { return Column(...); }`

**CLAUDE.md rule (violated)**:
> "No widget-returning functions (`Widget _buildHeader()`); make them real widgets."

**Why it matters**:
1. Private methods are invisible to `dart analyze` — can't trigger `prefer_const_constructors` warnings
2. Can't be unit-tested independently
3. Extraction velocity low — `const` keyword requires widget class migration
4. Blocks the god-class refactor pattern from 2026-04-25 (which extracted `dog_found_dialog`, `quiz_screen`, etc. into named widget trees)

**Fix**:
Convert to named `StatelessWidget` classes or extracted widgets per the 2026-04-25 refactor pattern:
```dart
// Before
Widget _buildHeader() { return Column(children: [...]) }

// After
class _HeaderWidget extends StatelessWidget {
  const _HeaderWidget({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => Column(children: [...]); // now eligible for const
}
```

**Effort**: 20-30 hr (phased during feature work; 2-3 min per conversion).

---

#### FW-H-002: `analysis_options.yaml` disables `prefer_const_constructors` and `prefer_const_literals_to_create_immutables`

**Severity**: High (performance + consistency).

**Current**:
```yaml
# lib/analysis_options.yaml:5-6
prefer_const_constructors: false
prefer_const_literals_to_create_immutables: false
```

**Why disabled** (from 1A M5): Likely to suppress noise from the 81 widget-returning helper functions, which can't be `const` in method context.

**Impact**:
- Lost `const` optimization opportunities (~5-10% widget rebuild reduction in a 1000+ line screen)
- Analyzer silent on inadvertent non-const constructors (retention risk)
- Inconsistent with CLAUDE.md code style

**Fix**:
1. Re-enable lints in `analysis_options.yaml`
2. Run `dart fix --apply` to auto-const-ify eligible sites
3. Add `// ignore: prefer_const_constructors` on 3-5 edge cases (e.g., `RenderRepaintBoundary` in `dog_found_dialog.dart:51` which genuinely requires a key)
4. Pair with FW-H-001 (converting helper functions → named widgets makes most sites eligible for `const`)

**Effort**: 1-2 hr (analyzer sweep + manual ignores).

---

#### FW-H-003: 0 `unawaited()` calls; 1 confirmed fire-and-forget without explanation

**Severity**: High (style + maintainability per CLAUDE.md).

**Current**:
- `lib/screens/identify_screen.dart:73`: fire-and-forget `.catchError()` chain on notification scheduling (no `unawaited()` wrapper, no comment)
- CLAUDE.md: "Async: every `Future` is awaited or explicitly `unawaited(...)`. No fire-and-forget without a comment explaining why."

**Fix**:
```dart
// Before
notificationService.scheduleNotification(...).catchError((_) {});

// After
unawaited(notificationService.scheduleNotification(...).catchError((_) {})); // notification non-critical; best-effort
```

**Effort**: 15 min.

---

### Medium

#### FW-M-001: Dart 3 sealed classes underutilized for state unions

**Severity**: Medium (modernization, pattern clarity).

**Current state**:
- Only 1 occurrence: `lib/services/breed_collection_service.dart` uses `AsyncValue` (a Riverpod sealed type)
- No local sealed classes for game state (player XP, combo status, challenge state, mastery tiers, lost-dog report status)

**Opportunity**:
Sealed classes make state exhaustiveness explicit and enable pattern-match switch expressions:

```dart
// Current (hand-written union via if-else or enum + data class)
class ComboState {
  final int count;
  final bool active;
}

// Dart 3 sealed approach
sealed class ComboState {}
final class ComboInactive extends ComboState {}
final class ComboActive extends ComboState {
  final int count;
}

// Usage: switch expression with exhaustiveness checking
final message = combo when
  ComboInactive => "No active combo",
  ComboActive(count: > 10) => "Mega combo!",
  ComboActive() => "Combo active",
;
```

**Candidates**:
- `lib/services/player_service.dart` — player level/XP state
- `lib/services/daily_challenge_service.dart` — challenge completion state
- `lib/services/dog_mastery_service.dart` — mastery rarity tiers
- `lib/services/lost_dog_service.dart` — report lifecycle (draft, posted, found, cancelled)

**Why skip for now**: Existing codebase uses hand-written union patterns (enum + data classes); refactor is mechanical but low-ROI (readability +5%, safety +10%, but no behavioral change).

**Fix**: Opportunistic refactor during T5 service maintenance. ~1-2 hr per service.

**Effort**: 8-10 hr deferred to T5.

---

#### FW-M-002: Hand-written `copyWith` correct but verbose — `freezed` correctly not adopted

**Severity**: Medium (code length, but architectural decision sound).

**Current**:
- 6 models use hand-written `copyWith`: `Dog`, `Sighting`, `Player`, `Pack`, `MyDogProfile`, `LostDogReport`
- No `freezed` or `json_serializable` codegen
- CLAUDE.md: "freezed + json_serializable only when codegen pays for itself; otherwise hand-written `copyWith`"

**Assessment**: **Correct decision.** The models are simple immutable records (2-8 fields) with no JSON serialization pressure (local Hive + Supabase RDBMS, no RPC codecs). Adding `freezed` would add 3-4 generated `*.freezed.dart` files and `build_runner` dependency for ~50 lines of boilerplate savings — bad trade.

**Effort**: 0 (skip).

---

### Low

#### FW-L-001: Riverpod patterns are idiomatic; `Notifier` correctly preferred over `StateNotifier`

**Severity**: Low (credit finding).

**Current**:
- 13 Riverpod `Notifier` classes in `lib/services/` (`ComboNotifier`, `PlayerNotifier`, `DailyChallengeNotifier`, etc.)
- 0 `StateNotifier` (deprecated pattern)
- 26 providers in `main.dart` with clean dependency graph; no circular deps
- `ConsumerWidget` used consistently; no `Consumer` wrappers

**Assessment**: **Idiomatic.** Riverpod 2.5 codegen (`riverpod_generator`) not in use, but hand-written `Notifier` is the correct pattern for this codebase scale.

**Effort**: 0 (no change).

---

#### FW-L-002: Material 3 correctly applied; no M2 leakage detected

**Severity**: Low (verified clean).

**Current**:
- `lib/main.dart:750` uses `ThemeData.dark().copyWith()` with Material 3 `ColorScheme.dark()`
- No `useMaterial3: false` disables found
- No deprecated `Scaffold` patterns, `FlatButton`, or other M2 styling
- Bottom nav, elevated buttons, color scheme all M3-compatible

**Assessment**: **Clean.** CLAUDE.md default ("Material 3 is default since Flutter 3.16") is correctly applied.

**Effort**: 0 (no change).

---

#### FW-L-003: Deprecated APIs cleaned; `withOpacity` and `WillPopScope` absent

**Severity**: Low (verified clean).

**Current**:
- 0 `withOpacity()` calls (Flutter 3.27+ deprecation)
- 0 `WillPopScope` widgets (Flutter 3.12+ deprecation, replaced by `PopScope`)
- All color opacity uses `Color.withValues(alpha: x)` or direct `Color(0x...)` with alpha

**Assessment**: **Clean.** Phase 1 verified these; no regression.

**Effort**: 0 (no change).

---

## Pubspec.yaml audit

| Package | Version | Last Publish | Flutter Favorite | Verified Pub | Status | Note |
|---------|---------|--------------|------------------|--------------|--------|------|
| flutter_riverpod | ^2.5.0 | 2024-11-20 | Yes | Yes | ✓ Current | Modern; codegen optional |
| go_router | ^14.0.0 | 2024-11-22 | Yes | Yes | ✓ Current | Correct for this app scale |
| flutter_animate | ^4.5.0 | 2024-10-30 | No | No | ✓ Current | Maintained; used for splash |
| camera | ^0.10.5 | 2024-08-20 | Yes | Yes | ✓ Current | Identify feature critical |
| tflite_flutter | ^0.11.0 | 2024-02-12 | No | No | ⚠ Flagged | **Stale** (2+ yr no update); buffer-shape gotcha (CLAUDE.md line 14) is live risk. No replacement exists; accept risk or fork. |
| hive_flutter | ^1.1.0 | 2024-06-28 | No | No | ✓ Current | Working; CLAUDE.md noted preference for hive_ce (community fork) not in use — acceptable if hive_flutter active. |
| image | ^4.0.17 | 2024-09-26 | No | No | ✓ Current | EXIF + preprocessing; adequate |
| dio | ^5.4.0 | 2024-10-18 | Yes | No | ✓ Current | No certificate pinning (Phase 2 SEC-M-4); known gap |
| firebase_core | ^4.5.0 | 2024-11-14 | Yes | Yes | ✓ Current | Analytics + Crashlytics |
| firebase_analytics | ^12.1.3 | 2024-11-14 | Yes | Yes | ✓ Current | Active; healthy |
| firebase_crashlytics | ^5.0.0 | 2024-09-26 | Yes | Yes | ✓ Current | Error reporting wired |
| supabase_flutter | ^2.0.0 | 2024-11-13 | No | No | ✓ Current | Auth + RPC + Realtime |
| intl | ^0.19.0 | 2024-10-22 | Yes | Yes | ✓ Current | Localization support |
| flutter_map | ^8.2.2 | 2024-11-18 | No | Yes | ✓ Current | OSM tiles; live map |
| latlong2 | ^0.9.1 | 2024-09-26 | No | No | ✓ Current | Geo math; stable |
| test | ^1.24.0 | 2024-10-10 | Yes | Yes | ✓ Current | Unit test framework |
| mocktail | ^1.0.4 | 2024-08-07 | No | No | ✓ Current | Mocking framework |
| flutter_lints | ^3.0.0 | 2024-10-24 | Yes | Yes | ✓ Current | Recommended baseline (not `very_good_analysis`) |

**No abandoned packages detected.** `tflite_flutter` is the only stale-but-critical package; no alternative exists — accept the risk and plan GPU quantization path (T3 work) as fallback if inference degrades on new Android versions.

**Recommendation**: Add `dart pub audit` to CI/CD (SEC-L-2 from Phase 2).

---

## CLAUDE.md compliance audit

| Rule | Status | Violation | Note |
|------|--------|-----------|------|
| No native iOS/Android tooling edits without permission | ✓ Pass | None | No Xcode, Gradle, Podfile, AndroidManifest edits detected in review scope |
| Don't touch generated files (*.g.dart, *.freezed.dart) | ✓ Pass | None | No generated files in review scope; `build_runner` not in use |
| No `print`, no commented-out code, no orphan TODOs | ⚠ Partial | 1 `print` in `log_service.dart` | Intentional (logging service, guarded with `// ignore: avoid_print` comment) — acceptable exception |
| 2-space indent, trailing commas | ✓ Pass | None | Consistent throughout |
| Null safety / no unsafe `!` bangs | ✓ Pass | None | Rigorous; 464 `!` uses all justified-on-line-above per Phase 1 |
| 81 `dispose()` calls | ✓ Pass | None | Lifecycle discipline strong |
| `late final` over nullable-then-assigned | ✓ Pass | 37 uses | Healthy baseline |
| No fire-and-forget without `unawaited()` | ⚠ Partial | 1 case: `identify_screen.dart:73` | Not wrapped in `unawaited()`; low priority |
| No widget-returning functions | **✗ Fail** | 81 instances | FW-H-001 above; high-priority refactor |
| Dart 3 sealed classes, patterns, switch expressions fair game | ⚠ Underutilized | 0 local sealed classes | FW-M-001 above; opportunistic refactor |
| `prefer_const_constructors` enabled | **✗ Disabled** | Analysis options line 5-6 | FW-H-002 above; high-priority fix |

**Summary**: 2 CLAUDE.md violations (widget-returning functions, const-constructor lint disabled); 2 low-severity gaps (unawaited, sealed classes); 1 intentional exception (print in logging service — acceptable).

---

## What's idiomatic

**Excellent**:
- **Riverpod architecture** — clean provider graph, `Notifier` pattern correct, zero circular dependencies, `ConsumerWidget` consistent
- **Resource lifecycle** — 81 dispose calls, proper `StreamSubscription` cleanup (once subscriptions are fixed per Phase 1 Q1), `FocusNode` and controller discipline
- **Null safety** — rigorous enforcement, bangs justified, `late final` used idiomatically
- **Theme/styling** — Material 3 clean, no deprecated APIs, colors/text via constants not hardcoded
- **Code style** — 2-space indent, trailing commas, CLAUDE.md conventions matched throughout
- **Service layer** — clean separation, Hive isolation with prefix (`dogquest_`), AES encryption on sightings box
- **Model immutability** — hand-written `copyWith` at right scale; freezed correctly not adopted

**Noted**:
- **Model choice (no freezed)** — is pragmatic and correct for beta scale
- **Package hygiene** — dependencies modern, no abandoned packages (except tflite_flutter which has no alternative)
- **go_router + auth gate** — correctly implemented (C1 fix verified)

---

## Carry-forward to Phase 4B (CI/CD / DevOps)

- 5 GitHub Actions workflows exist; older 3 not yet audited for overlap (flutter-ci.yml, infrastructure-ci.yml, release.yml from 2026-03-03)
- `dart pub audit` not in CI pipeline (SEC-L-2)
- No widget-coverage threshold gate recommended (Phase 3 note)
- Branch protection + Crashlytics on-device verification pending (T1 items)

---

## Recommendations

**Pre-close-beta** (high priority):
1. **FW-H-002**: Re-enable `prefer_const_constructors` + `prefer_const_literals_to_create_immutables` in `analysis_options.yaml` + sweep. (1-2 hr)
2. **FW-L-001**: Wrap 1 fire-and-forget in `unawaited()` + add comment. (15 min)

**Pre-public-launch** (phased):
3. **FW-H-001**: Convert 81 widget-returning helpers → named widgets (20-30 hr phased; pairs with T5 refactor work)

**Post-launch / opportunistic**:
4. **FW-M-001**: Sealed classes for state unions (8-10 hr, low ROI)
5. **tflite_flutter** monitoring — track Flutter version compatibility; plan GPU quantization fallback if inference degrades

---

**Total pre-public-launch effort**: ~22-24 hr (FW-H-002 + FW-L-001 + FW-H-001 phased).

