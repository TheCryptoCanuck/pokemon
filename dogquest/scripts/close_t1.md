# T1 Closure — Claude Code Automation Prompt

**Usage:** Open Claude Code at the DogQuest repo root. Say:
> Read `scripts/close_t1.md` and execute it end-to-end. Halt and report on any ambiguity or failure. Do not skip phases.

---

## Pre-flight

Before any code change, run:

```bash
git status
flutter test test/ 2>&1 | tail -20
```

**Halt if:** uncommitted changes exist (ask Jesse to stash or commit), OR full test suite has any failure (baseline must be green).

Read `.second_brain/03_Projects/Active_Tasks.md` Tier 1 sections (Critical + Other quality wins). The entries marked Active in those sections are the working set. C3, C1, and the heavy-flag spot-check are reported as substantially done — verify each before continuing.

---

## Phase 1 — C3 git verification (5 min)

```bash
git ls-files backend/                                      # expected: empty
git log --all --oneline -- backend/ | head                 # confirm an archive commit OR identify gap
```

**Decision tree:**
- Empty `ls-files` AND log shows an archive commit (e.g. `Archive vestigial FastAPI backend (sec-C3)`) → **Phase 1 done.** Proceed.
- Empty `ls-files` AND no archive commit in log:
  ```bash
  git rm -rf backend/ 2>/dev/null || true   # no-op on disk, cleans index if anything is there
  git diff --cached --name-only            # if non-empty, the index had stale entries
  if git diff --cached --quiet; then
    echo "Nothing to commit — backend/ already absent from index."
  else
    git commit -m "Archive vestigial FastAPI backend (sec-C3)"
  fi
  ```
- Non-empty `ls-files backend/` → **HALT.** Filesystem-vs-index inconsistent with what Cowork observed. Surface the discrepancy and ask Jesse before any commits.

Update `.second_brain/03_Projects/Active_Tasks.md` C3 entry → `Status: Closed`. Note the commit SHA if one was made this session.

---

## Phase 2 — C2 reduced-scope close (5 min)

The dormant-marker edit is already in `lib/services/sighting_sync_service.dart` (Cowork session, 2026-04-25). Verify and commit:

```bash
dart format lib/services/sighting_sync_service.dart
dart analyze lib/services/sighting_sync_service.dart
flutter test test/sync_services_test.dart
```

**Halt if:** `dart analyze` reports any error (not just info/warning). Test failures here would mean the throw-on-init broke a test that wasn't surfaced in the Cowork grep — surface and pause.

If clean:
```bash
git add lib/services/sighting_sync_service.dart
git commit -m "Mark SightingSyncService dormant pending sec-C2 (sec-C2-defer)"
```

Update Active_Tasks C2 entry → `Status: Closed (reduced-scope)`.

---

## Phase 3 — C1 test-depth decision (5 min, default = skip upgrade)

Read `test/sync_services_test.dart` lines 381+ (sec-C1 group). Tests are contract-documentation-style.

**Default action:** keep as-is for closed-beta scope. Update Active_Tasks C1 → "C1 closed pending Jesse-side Supabase RLS verification (separate item)." Skip to Phase 4.

**If Jesse explicitly requests upgrade:** add behavioral integration tests:
- Instantiate `SightingSyncService` with a mocked `SupabaseClient` whose `auth.currentSession` returns `null`.
- Assert `syncAll()` returns `0` and never calls `client.rpc`.
- Assert `syncSingle(sighting)` returns `false`.
- Pattern from existing mockito setups in the same file.

Run:
```bash
dart format test/sync_services_test.dart
dart analyze test/
flutter test test/sync_services_test.dart
git commit -am "Upgrade sec-C1 guards to behavioral tests"
```

---

## Phase 4 — Sentry DSN wiring (15 min, requires `SENTRY_DSN` env var)

**Halt if:** `SENTRY_DSN` is not set in the environment AND not provided by Jesse via `--dart-define`. Surface and ask.

Read `lib/main.dart` first 100 lines to identify `_guardedStartup` and the `runApp` call.

Add Sentry wrapping around `runApp`:

```dart
// At top:
import 'package:sentry_flutter/sentry_flutter.dart';

// Replace `runApp(...)` with:
await SentryFlutter.init(
  (options) {
    options.dsn = const String.fromEnvironment('SENTRY_DSN');
    options.environment = kReleaseMode ? 'production' : 'debug';
    options.tracesSampleRate = 0.1;
  },
  appRunner: () => runApp(/* existing root widget */),
);
```

Verify pubspec.yaml has `sentry_flutter` (CLAUDE.md says "wired, needs DSN" — package should already be present). If missing, add via `flutter pub add sentry_flutter` and run `flutter pub get`.

Build + smoke test:
```bash
flutter build apk --debug --dart-define=SENTRY_DSN=$SENTRY_DSN
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.hound.app/.MainActivity
```

**Manual smoke test step (Jesse needs to confirm):** open the debug build, trigger any uncaught error path (one option: temporary `throw Exception('sentry-canary')` behind an unused button, removed after test), verify the event lands in Sentry → DogQuest project within ~30 seconds. After verification, remove the canary throw.

```bash
git add lib/main.dart pubspec.yaml pubspec.lock
git commit -m "Wire Sentry DSN (TASK-050)"
```

Update Active_Tasks: TASK-050 → Closed.

---

## Phase 5 — v1 telemetry instrumentation (30 min)

Read `lib/widgets/dog_found_dialog.dart` to identify:
- The existing analytics import (Firebase Analytics is wired per CLAUDE.md `aviquest-508a6` project).
- Where alternatives are tapped (`onSelectAlternative` callback).
- Where manual search opens (`onManualSearch`).
- Where the dialog dismisses without pick.
- Where `Add to Kennel` fires.

Add a `Stopwatch _dialogStopwatch` to the State class, started in `initState()`.

Emit four analytics events. Treat the analytics service as `ref.read(analyticsServiceProvider)` if there's a Riverpod-style wrapper, OR direct `FirebaseAnalytics.instance.logEvent` if not.

```dart
// On dialog open (after results computed; in initState or first build):
_emit('dog_found_dialog_v1_open', {
  'top1_breed': widget.dogName,
  'top1_confidence': widget.confidence,
  'has_alternatives': widget.alternatives.isNotEmpty,
  'is_mock': isMock,
});

// On Add to Kennel CTA:
_emit('dog_found_dialog_v1_pick', {
  'picked_index': 0, // 0 = top-1 default; if alternative-tap path, pass the alt index
  'top1_confidence': widget.confidence,
  'time_to_pick_ms': _dialogStopwatch.elapsedMilliseconds,
});

// In onSelectAlternative wrapper, before delegating:
_emit('dog_found_dialog_v1_pick', {
  'picked_index': widget.alternatives.indexOf(alt) + 1,
  'top1_confidence': widget.confidence,
  'time_to_pick_ms': _dialogStopwatch.elapsedMilliseconds,
});

// On manual search tap:
_emit('dog_found_dialog_v1_manual_search', {
  'top1_confidence': widget.confidence,
  'time_to_action_ms': _dialogStopwatch.elapsedMilliseconds,
});

// On dismiss without pick (Skip button + back gesture + outside tap):
_emit('dog_found_dialog_v1_dismissed', {
  'top1_confidence': widget.confidence,
  'time_to_dismiss_ms': _dialogStopwatch.elapsedMilliseconds,
});
```

Define `_emit(String name, Map<String, Object?> params)` as a thin wrapper that does the actual `logEvent` call. Drop nullable params before sending if the analytics SDK rejects them.

Verify:
```bash
dart format lib/widgets/dog_found_dialog.dart
dart analyze lib/widgets/dog_found_dialog.dart
flutter test test/  # if any widget tests cover this dialog
```

**Halt if:** dart analyze flags an issue that's not a pre-existing warning, OR there's no clear analytics service to wire to. Surface and ask Jesse for the analytics service path.

```bash
git add lib/widgets/dog_found_dialog.dart
git commit -m "Instrument dog_found_dialog v1 telemetry (E5)"
```

Update Active_Tasks: telemetry task → Closed. Add a Decisions.md entry: "v1 telemetry baseline window opens [today's date]; D3/D5 thresholds in `dog_found_dialog_redesign_spec.md` validatable from [today + 14 days]."

---

## Phase 6 — T1 closure verify

Re-read `.second_brain/03_Projects/Active_Tasks.md` Tier 1 sections. Every entry should be either:
- `Status: Closed` (with date)
- Or marked as Jesse-blocking (cluster verify on phone, Supabase RLS dashboard, Sentry signup if not done)

If anything still says `Status: Active` and isn't Jesse-blocking → halt and surface.

If only Jesse-blocking items remain → emit a status report:
```
T1 close progress (automated):
  ✓ C3 — git verified, [committed N hours ago | already in history]
  ✓ C2 — reduced-scope dormant-marker shipped, commit <SHA>
  ✓ Heavy-flag spot-check — agent finding accepted (threshold stays 0.40)
  ✓ TASK-050 Sentry — DSN wired, commit <SHA>
  ✓ E5 v1 telemetry — instrumented, commit <SHA>
  ⏳ C1 Supabase RLS — needs Jesse dashboard check (10 min)
  ⏳ On-device cluster verify — needs Jesse phone test (10 min)
  ⏳ Comprehensive review resume — needs C1 close
Total wall-time used: <Nm>
```

---

## Phase 7 — Vault wrap

After T1 close (including the Jesse-side items), run:

```bash
# Move closed entries in Active_Tasks to a "Completed (T1 close YYYY-MM-DD)" section.
# Update DogQuest.md "Current Status" — replace "3 Critical security findings open" with "T1 closed YYYY-MM-DD; comprehensive review resumed; T2 unblocked."
```

Add a Decisions.md entry:

```
- Date: YYYY-MM-DD
  Decision: **T1 closed.** All Critical security findings (C1, C2, C3) resolved or reduced-scoped per documented plan. Comprehensive review resumed at Checkpoint 1. T2 quality work (dog_found_dialog redesign + confidence honesty + quiz fix) unblocked. v1 telemetry baseline window opens today; D3/D5 metrics evaluable from YYYY-MM-DD+14.
  Related project: DogQuest
  Score: 0.95
```

Then:
```
/comprehensive-review:full-review
# choose "Resume from where we left off"
```

End-of-session: run the autonomous memory loop in `.second_brain/07_Prompts/Autonomous_Memory_Agent_Loop.md`.

---

## Constraints (don't drift)

- Do NOT touch native iOS/Android tooling (Gradle, Podfile, Info.plist, build.gradle, *.xcconfig, Swift/Kotlin glue) without explicit Jesse approval.
- Do NOT modify `*.g.dart`, `*.freezed.dart`, `*.gr.dart` directly — re-run build_runner if codegen is needed.
- Do NOT introduce packages without checking pub.dev compatibility (CLAUDE.md package-management rules).
- Do NOT hardcode the Sentry DSN in source — `--dart-define` only.
- Do NOT ship the canary `throw Exception('sentry-canary')` past the smoke-test commit.
- Each commit message follows the format used in this file (no emoji unless Jesse requests).

## On uncertainty

Tag confidence per the CLAUDE.md confidence-audit rule. At end of run, output:
- "solid" — verified via tooling.
- "uncertain" — written but not test-covered.
- "drift" — generated without verifying (e.g. analytics service path inferred without grep, Sentry SDK API recall not checked against pinned version).
