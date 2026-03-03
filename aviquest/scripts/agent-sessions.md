# AviQuest — Parallel Agent Session Prompts

Copy-paste these into separate Claude Code sessions to run validation in parallel.

---

## Session 1 — Unit Tests (date_helpers + aviary_collected_birds)

```
You are the Reliability Lead for AviQuest.
Branch: claude/master-orchestrator-v3-hxAOM

git pull origin claude/master-orchestrator-v3-hxAOM

Run ONLY these test files and report results:
  cd aviquest
  flutter test test/date_helpers_test.dart
  flutter test test/aviary_collected_birds_test.dart

If any test fails:
1. Read the failing test and the source file it tests
2. Determine if the bug is in the test or the source
3. Fix ONLY the file that has the bug
4. Re-run the test to confirm green
5. Commit and push

You own ONLY these files (do not edit any others):
  - test/date_helpers_test.dart
  - test/aviary_collected_birds_test.dart
  - lib/helpers/date_helpers.dart
  - lib/services/aviary_service.dart
```

---

## Session 2 — Unit Tests (existing test suite)

```
You are the Reliability Lead for AviQuest.
Branch: claude/master-orchestrator-v3-hxAOM

git pull origin claude/master-orchestrator-v3-hxAOM

Run the full existing test suite and report results:
  cd aviquest
  flutter test

If any test fails:
1. Read the failing test and the source file it tests
2. Determine if the bug is in the test or the source
3. Fix ONLY the file that has the bug
4. Re-run the failing test to confirm green
5. Commit and push

You own ONLY these files (do not edit any others):
  - test/**  (any test file)
  - lib/helpers/date_helpers.dart
  - lib/helpers/ui_helpers.dart

Do NOT edit any service or screen files.
```

---

## Session 3 — Static Analysis (lint)

```
You are the Code Quality Guardian for AviQuest.
Branch: claude/master-orchestrator-v3-hxAOM

git pull origin claude/master-orchestrator-v3-hxAOM

Run static analysis and fix any issues:
  cd aviquest
  dart analyze lib/

For each error or warning:
1. Read the flagged file
2. Fix the issue (unused imports, type mismatches, etc.)
3. Re-run analysis to confirm clean

You own ONLY files in lib/ that have analysis issues.
Do NOT change test/ files or build files.

Commit and push when analysis is clean.
```

---

## Session 4 — Android Debug Build

```
You are the Build Engineer for AviQuest.
Branch: claude/master-orchestrator-v3-hxAOM

git pull origin claude/master-orchestrator-v3-hxAOM

Build the Android debug APK:
  cd aviquest
  flutter pub get
  flutter build apk --debug

If the build fails:
1. Read the error output carefully
2. Identify the failing file
3. Fix ONLY compilation errors (do not refactor)
4. Re-run the build
5. Commit and push

Report the final APK path and size when successful.

You own ONLY files required to fix build errors.
Do NOT change tests, scripts, or agent definitions.
```

---

## Run Order

These sessions can run in parallel (Sessions 1-4 simultaneously):

```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ Session 1    │  │ Session 2    │  │ Session 3    │  │ Session 4    │
│ New Tests    │  │ Full Tests   │  │ Lint/Analyze │  │ Android APK  │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                 │                 │
       └─────────────────┴─────────────────┴─────────────────┘
                                   │
                          All green? ──→ Install on device
```

If all 4 pass, you're safe to install:
```
cd aviquest
flutter install --debug
```

Or transfer the APK manually:
```
adb install build/app/outputs/flutter-apk/app-debug.apk
```
