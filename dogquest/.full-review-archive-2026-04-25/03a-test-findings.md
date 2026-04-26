# Phase 3A — Test Coverage Findings

**Status**: Complete. **10 substantive findings** across unit, integration, and acceptance test coverage gaps, calibrated for closed-beta and pre-launch.

---

## Severity inventory
- Critical: 2 | High: 5 | Medium: 3 | Low: 0

---

## Findings

### TEST-001 — SightingSyncService.init() dormancy assertion missing
- **Severity**: High
- **What's untested**: `SightingSyncService.init()` unconditionally throws `StateError` per sec-C2 remediation. No unit test asserts the throw; no production caller scan verifies zero calls in `lib/`.
- **Why it matters**: If the service is mistakenly wired into a code path before the UUID migration is complete, the app crashes at startup. A simple precondition test + static call-site verification would catch this early.
- **Recommendation**: Add a test case `test('init unconditionally throws StateError — dormancy guard')` in `test/services/sighting_sync_service_test.dart` (new file). Then use grep to verify zero non-test callers of `sightingSyncService.init()` in `lib/`. Document why the service is wired into providers but never initialized.
- **File(s)**: `lib/services/sighting_sync_service.dart:65-69`, `lib/main.dart` (sighting_sync_service provider wiring)

### TEST-002 — v1 telemetry emission in dog_found_dialog untested
- **Severity**: High
- **What's untested**: `dog_found_dialog.dart:55-130` implements v1 analytics instrumentation: `_v1MaybeEmitOpen()`, `_v1HandleAdd()`, `_v1HandleAlt()`, `_v1HandleManualSearch()`, and dismiss-time emission in `dispose()`. The `_v1ActionEmitted` double-emission guard (line 61) is code-critical but has zero test coverage. Mock analytics calls never fire in the test suite.
- **Why it matters**: The event series (`dog_found_dialog_v1_open`, `dog_found_dialog_v1_pick`, `dog_found_dialog_v1_manual_search`, `dog_found_dialog_v1_dismissed`) feeds the T2 redesign spec (per line 56). If the guard logic fails, dashboard metrics will double-count user actions, breaking the redesign feedback loop. Widget tests are absent entirely.
- **Recommendation**: Create `test/widgets/dog_found_dialog_test.dart` with widget tests for each state path:
  - **Test 1**: Dialog opens → `_v1MaybeEmitOpen()` fires once, not twice on rebuild (idempotency). Mock `analyticsProvider` and verify `track('dog_found_dialog_v1_open')` called exactly once.
  - **Test 2**: User taps "Add" → `_v1ActionEmitted` flips true; subsequent action callbacks ignored. Verify only one `'dog_found_dialog_v1_pick'` event fires, not multiple if button is tapped twice (defensive).
  - **Test 3**: User dismisses → `dispose()` emits `'dog_found_dialog_v1_dismissed'` only if `!_v1ActionEmitted` (i.e., no prior action). Build/dispose flow tests.
  - **Test 4**: Stopwatch elapsed times are captured (validate `time_to_pick_ms`, `time_to_dismiss_ms` keys present).
  - Note: use `ConsumerStatefulWidgetTest` harness + Riverpod mock providers (cf. similar pattern in `test/ad_service_test.dart` and `test/supabase_auth_test.dart`).
- **File(s)**: `lib/widgets/dog_found_dialog.dart:50-133`

### TEST-003 — sec-C1 auth session guard integration not exercised
- **Severity**: High
- **What's untested**: `test/sync_services_test.dart:381-422` documents the contract for `SightingSyncService` auth session guard (`return 0 when no session`, `return false when no session`) and router offline-mode clearing logic. However, these are **contract-doc tests** (mock assertions only; the actual service is dormant per TEST-001). No integration test wires the guard into a real offline→online→offline state machine on a real app instance.
- **Why it matters**: The offline-mode flag bypass (C1) is a pre-beta blocker per Phase 2 findings. The router safety net (line 405-422) is the fallback, but the test only asserts mock state, not actual code flow. An attacker (or user in an edge-case state) could remain offline while session exists if this guard fails silently.
- **Recommendation**: Write an integration test `test/integration/auth_offline_state_test.dart` covering the full state machine:
  1. App starts with no session and offline_mode=false → user sees /login.
  2. User taps "Continue Offline" → offline_mode=true, router allows /identify.
  3. User authenticates mid-app → session appears. Router redirect should clear offline_mode=false on next frame.
  4. Verify: on next sync trigger, `SightingSyncService.syncAll()` / `syncSingle()` checks session and returns early (0 / false) when session is null, or proceeds when session is live.
  5. User signs out → offline_mode remains false until user explicitly taps "Continue Offline" again.
  - Use real Hive boxes (or `HiveTestHelper` fixture) for player preferences. Use real `go_router` redirect logic. Mock only the Supabase auth client + RPC endpoints.
- **File(s)**: `lib/router.dart` (auth gate), `lib/services/auth_service.dart` (offline_mode flag), `lib/services/sighting_sync_service.dart` (session checks)

### TEST-004 — Identification error paths untested
- **Severity**: High
- **What's untested**: `lib/services/identification_service.dart` and `lib/screens/identify_screen.dart` handle ML inference errors (model load failure, TFLite runtime exception, image preprocessing failure, empty confidence results). Current tests mock successful inference only; zero tests cover:
  - `tflite_flutter` throws exception during interpret
  - Image preprocessing (resize, crop, EXIF) fails
  - Label cache lookup returns null (unmapped breed)
  - Network timeout on image download
  - Camera permission revoked mid-identification
- **Why it matters**: Closed-beta users will hit edge cases: bad camera, network blips, corrupted model state. Silent failures or uncaught exceptions crash the app. Phase 1 found "error handling lacks categorization" (M1); error-path testing would validate fixes.
- **Recommendation**: Expand `test/services/tflite_identification_service_test.dart` to cover error branching:
  - **Test 1**: `_buildResults()` receives all-zero logits (no valid breed) → returns empty list (rejection gate).
  - **Test 2**: Label cache lookup for a valid index returns null (unmapped breed) → skips silently or logs warning without crashing.
  - **Test 3**: Create a new error test group `test('identification error handling')` that directly tests the error categories from `identification_service.dart`:
    - TFLite runtime exception → caught, logged, returns `IdentificationFailure`.
    - Image preprocessing exception (e.g., invalid image format) → graceful error message, not a crash.
    - Network timeout on image load → retry logic (if any) or clear error message to UI.
  - Mock the Interpreter + File I/O to throw at strategic points.
- **File(s)**: `lib/services/identification_service.dart`, `lib/services/tflite_identification_service.dart`, `lib/screens/identify_screen.dart`

### TEST-005 — Dog social layer (social_service, feed_screen, nearby_screen) has zero widget tests
- **Severity**: High
- **What's untested**: `lib/services/dog_social_service.dart`, `lib/screens/dog_feed_screen.dart`, `lib/screens/dogs_nearby_screen.dart` implement the social layer (activity feed, nearby players, breed community, playdate matching). `test/supabase_social_test.dart` tests the post-generation service only; zero tests for:
  - Feed screen rendering of 10+ sightings (pagination, error states)
  - Nearby users detection (geolocation filter, no results edge case)
  - Playdate matcher card state (loading, match success, no matches)
  - Real-time listener unsubscribe on screen close (memory leak risk)
  - Network error handling (pull failure, socket timeout)
- **Why it matters**: Social is a pre-launch feature (PLAID phase 4 roadmap). UI regressions or state leaks will impact user retention. Widget tests would validate correct provider integration, error UI, and lifecycle cleanup.
- **Recommendation**: Create `test/screens/dog_feed_screen_test.dart`, `test/screens/dogs_nearby_screen_test.dart` with widget tests covering:
  - Feed loads and displays 5+ sightings (mock `dogSocialProvider.feed()` using Riverpod container).
  - Empty state: "No activity yet" message when feed is empty.
  - Error state: "Connection failed" message when fetch throws, with retry button.
  - Nearby users: shows cards sorted by distance; "No one nearby" when list is empty.
  - Cleanup: verify `StreamSubscription.cancel()` called on widget dispose (frame a Mockito spy).
  - Use `WidgetTester.pumpWidget()` with `ProviderContainer` override for Riverpod state control.
- **File(s)**: `lib/services/dog_social_service.dart`, `lib/screens/dog_feed_screen.dart`, `lib/screens/dogs_nearby_screen.dart`

### TEST-006 — Hive box corruption / missing-key error paths untested
- **Severity**: Medium
- **What's untested**: Hive is the local-first store for sightings, player profile, kennel, packs, etc. Tests assume boxes exist and keys return valid data. Zero tests cover:
  - `dogquest_sightings_v1` box opened but corrupted (isOpen==true but data garbage).
  - Missing required keys: player box lacks `'player'` key, sightings box is empty when accessed.
  - Hive.clear() called mid-session (affects running services).
  - Migration from v0 to v1 schema fails (old box exists, new box fails to init).
- **Why it matters**: Beta users are on v1.0 first release; if a crash happens mid-write, Hive boxes can be left in a half-corrupted state. A second app launch should gracefully recover or reset, not crash.
- **Recommendation**: Create `test/services/hive_resilience_test.dart`:
  - **Test 1**: Open a `dogquest_sightings_v1` box, manually corrupt a value (write non-JSON), then verify service reads and handles the error gracefully (fallback to default, warn log, don't crash).
  - **Test 2**: Service expects player box key `'player'` to exist. Simulate absence; verify graceful fallback (e.g., initialize with blank player).
  - **Test 3**: Simulate mid-session `Hive.clear()` by manually deleting box, then verify service checks `box.isOpen` before read and reinitializes.
  - Use `HiveTestHelper` (from `hive_test` or a local fixture) to spin up temporary Hive instances in temp directories; clean up after each test.
- **File(s)**: `lib/services/player_service.dart`, `lib/services/sighting_service.dart`, `lib/services/kennel_service.dart`

### TEST-007 — Gamification paths (mastery, combos, daily challenges, mystery rewards) coverage spotty
- **Severity**: Medium
- **What's untested**: Mastery system, combo counter, achievement unlocks, and mystery rewards have unit tests for isolated logic (breed mastery thresholds, XP calculation) but lack integration tests that verify the full chain: sighting → kennel add → combo check → mastery badge display → achievement unlock → analytics. Widget rendering of mastery badges, combo counter animation, and achievement unlock overlay are untested.
- **Why it matters**: Gamification is the core retention hook for closed-beta (PLAID phase 2). If mastery badges don't display after 5 consecutive sightings, or achievements don't pop, users feel disconnected from progress. No widget tests means UI regressions ship undetected.
- **Recommendation**: Add widget test files:
  - `test/widgets/dog_mastery_badge_test.dart` — verify badge appears when mastery tier >= 3 and correct rarity color/glow applied.
  - `test/widgets/combo_counter_test.dart` — verify counter increments, combo aura animates on every sighting within 24h window, resets on miss.
  - `test/widgets/achievement_unlock_overlay_test.dart` — verify overlay shows, plays sound, dismisses after N seconds.
  - Integration test: `test/integration/sighting_to_achievement_test.dart` — add sighting → kennel → verify mastery badge shown + comboProvider updated + achievement fired (if conditions met).
  - Mock Riverpod providers + Hive (use HiveTestHelper).
- **File(s)**: `lib/widgets/` (mastery_badge, combo_counter, achievement_unlock_overlay), `lib/services/dog_mastery_service.dart`, `lib/services/combo_service.dart`

### TEST-008 — Lost-dog feature (report, map, alerts) has minimal coverage
- **Severity**: Medium
- **What's untested**: `lib/services/lost_dog_service.dart`, `lib/services/lost_dog_alert_service.dart`, `lib/screens/lost_dog_map_screen.dart`, and `lib/screens/report_lost_screen.dart` implement a pre-launch feature. `test/services/lost_dog_service_test.dart` has only 6 test cases (basic CRUD). Untested:
  - Real-time listener on lost-dog table (lifecycle, unsubscribe on close).
  - Distance-based alert triggering (user walks within Xkm of lost dog location).
  - Map clustering (10+ lost dogs on screen, cluster rendering, split on zoom).
  - Report validation (required fields, photo upload, geolocation).
  - Permissions (location access for lost dog distance alerts).
- **Why it matters**: Lost dogs are a user-acquisition vector (users search for lost dogs before registering). UI bugs or listener leaks would frustrate the feature and damage adoption.
- **Recommendation**: Expand `test/services/lost_dog_service_test.dart` with integration + widget tests:
  - Test real-time listener subscribes on service init, unsubscribes on dispose.
  - Test distance calculation (mock location, verify alert fires when user within radius).
  - Create `test/screens/lost_dog_map_screen_test.dart` — verify map renders, clusters visible, expand on tap, lost dog detail sheet pops.
  - Create `test/screens/report_lost_screen_test.dart` — verify form validation (name required, photo required), geolocation auto-filled, submit calls service.
- **File(s)**: `lib/services/lost_dog_service.dart`, `lib/services/lost_dog_alert_service.dart`, `lib/screens/lost_dog_map_screen.dart`, `lib/screens/report_lost_screen.dart`

### TEST-009 — Performance benchmark test incomplete; frame-time profiling for TTA inference missing
- **Severity**: Medium
- **What's untested**: `test/performance/perf_benchmark_test.dart` runs micro-benchmarks (softmax, label cache lookup, conflict resolution). Per Phase 2 finding P-H1, TTA inference latency (1.2–1.5s estimated) needs on-device validation on Pixel 5-class hardware. No frame-time instrumentation in `identify_screen.dart` or `identify_screen_test.dart` (which doesn't exist).
- **Why it matters**: If TTA inference blocks the UI thread for >600ms, the camera feed will stutter and frame rate drops will be visible. Users will perceive the app as slow. The beta cohort is tech-savvy and will churn if jank is evident.
- **Recommendation**: 
  - Add a frame-time benchmark to `test/performance/perf_benchmark_test.dart`:
    ```dart
    test('TTA inference latency within budget', () {
      // Load model, prepare 5-crop input, run inference in isolate
      // Measure elapsed time: should be < 1.5s
    });
    ```
  - Add instrumentation to `lib/screens/identify_screen.dart` capture flow:
    ```dart
    final sw = Stopwatch()..start();
    final result = await compute(_runInference, image);
    _log.info('Inference latency: ${sw.elapsedMilliseconds}ms');
    ```
  - Create a manual test doc (not automated): "Frame-time profile TTA on Pixel 5 emulator; confirm 60fps maintained during inference."
- **File(s)**: `test/performance/perf_benchmark_test.dart`, `lib/screens/identify_screen.dart`

### TEST-010 — Quiz engine edge cases (timer expiry, streak reset, hint feedback) undertested
- **Severity**: Medium
- **What's untested**: `lib/services/quiz_engine.dart` has 117 test/group declarations (~83 test cases), covering question generation and XP multipliers. Covered edge cases:
  - Timer expiry (streak resets on timeout).
  - Wrong answer (streak resets).
  - Hint system (returns non-empty hints for all question types).
  - But undertested:
    - Multiple hints requested in sequence (are they different each time? do they get shorter/more specific?).
    - Quiz termination mid-game (user exits; state cleanup verified?).
    - Concurrent quiz starts (only one should be active; second attempt queued or rejected?).
    - Difficulty weighting (does weighted random actually bias toward higher difficulty? verify distribution over 100 runs).
- **Why it matters**: Quiz is a daily engagement driver. If a user can exploit timer logic or hints, they can farm XP unnaturally. If state cleanup fails, old quiz can persist in memory.
- **Recommendation**: Add test cases to `test/quiz_screen_test.dart` (or new `test/services/quiz_engine_edge_cases_test.dart`):
  - **Test 1**: `test('hint system returns different hints for same question')` — call getHint() 3 times, verify all different (or documented as "same" if intentional).
  - **Test 2**: `test('exiting quiz mid-game clears state')` — start quiz, don't finish, verify state is reset (no lingering question, timer stopped, streak not affected).
  - **Test 3**: `test('starting a new quiz while one is active replaces old')` — start Q1, start Q2 without finishing Q1, verify only Q2 is active.
  - **Test 4**: `test('weighted difficulty distribution biases correctly over 100 samples')` — generate 100 questions at random; count frequency of each difficulty; verify easy > medium > hard (or per documented ratios).
- **File(s)**: `lib/services/quiz_engine.dart`, `test/quiz_engine_test.dart`, `test/quiz_screen_test.dart`

---

## Test pyramid summary

| Layer | Count | Coverage |
|-------|-------|----------|
| **Unit** | 530+ test cases across 22 files | Models, services (breed collection, dog mastery, combo, player, pack, demo, lost dog, kennel, sighting, dog friendship, friend, dog service, mystery rewards, tflite identification) well-covered. Analytics, quiz engine, sync services (ConflictResolution, SyncQueue) strong. |
| **Widget** | 0 test files | No `testWidgets()` tests. Critical UI paths (dog_found_dialog telemetry, social feed, lost-dog map, quiz widget state) untested. |
| **Integration** | 1 test file (supabase_auth, supabase_social — RPC mocks only) | No end-to-end app-state flows tested. Auth offline→online, sighting→kennel→mastery→achievement not exercised. |
| **Performance** | 1 benchmark suite (20 cases) | Micro-benchmarks pass. TTA frame-time latency (P-H1) never measured on-device. |
| **Notable absence** | Identify screen, profile screen, kennel screen, settings screen | 34 screens, <2% have tests. No screen navigation tests, state-machine tests, or error-boundary tests. |

**Calibration note**: 530+ unit tests is respectable for a backend/service codebase. But for a mobile app with 34 screens and real-time sync, the widget + integration layers are severely underdeveloped. Closed-beta success depends on UI reliability; current pyramid is inverted (unit-heavy, UI-light).

---

## Phase 4 hand-off

1. **Testing strategy recommendation for Phase 4 (DevOps/best-practices review)**: Establish a widget-test harness template (Riverpod + Hive fixtures) and enforce >70% widget-test coverage for new screens. Add CI gate: block merge if identify_screen, kennel_screen, profile_screen tests drop below coverage floor.

2. **Integration test infrastructure**: Pre-release must include a real-device smoke-test suite covering offline auth state machine, sighting sync round-trip (local → server → local), and at least one social feature (feed load + error handling).

3. **Performance gating**: Embed TTA frame-time check in pre-release checklist. Measure on Pixel 5 class device; document expected latency and jank threshold in release notes.

4. **Critical fixes before closed-beta** (stemming from Phase 3A findings):
   - TEST-001 + TEST-003: Add integration test for sec-C1 offline-mode guard; gate closed-beta launch on passing.
   - TEST-002: Add dog_found_dialog widget tests; gate on zero double-emission of v1 events.
   - TEST-004: Error-path tests for identification service; gate on graceful handling of TFLite exceptions.

5. **Regression detection**: Post-closed-beta, add a regression suite (subset of widget + integration tests) to run on every nightly build, with flakiness tracking. Re-baseline frame-time after each TFLite model update.

---

**Summary**: 10 substantive findings, 2 Critical (sec-C1, SightingSyncService dormancy), 5 High (telemetry, auth guard integration, error paths, social layer, lost-dog feature). Current test pyramid is unit-heavy but lacks widget + integration coverage. Closed-beta success depends on resolving TEST-001–003 (security + observability) and TEST-002 (telemetry verification for T2 redesign feedback loop). Recommend phase-gating as noted in final section.
