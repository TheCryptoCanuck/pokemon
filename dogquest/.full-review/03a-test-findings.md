# Phase 3A — Test Coverage & Quality Findings

**Date**: 2026-04-25 (post-review)  
**Scope**: 22 test files covering 52,995 lines of lib/, ~0.04% code coverage  
**Mode**: Strict, security-focus (pre-closed-beta)

---

## Posture

DogQuest's test suite is **unit-heavy but UI-light**, with 530+ unit tests across 22 files providing solid coverage of service logic (breed collection, mastery, combo, sync, analytics). However, **zero widget tests** leave 34 screens unexercised, and **critical security-sensitive paths have no unit guards** (auth_service, photo_upload, lost_dog integration, embedding extraction, router auth gate). Two known test suites are broken pending T5 fixes (`supabase_social_test.dart` ~30 mock mismatches, `sync_services_test.dart` 13 runtime errors). The pyramid is inverted for a mobile app: integration and UI-level regressions will ship undetected into closed-beta.

---

## Coverage map

### What's tested (solid)
- **Models**: Dog, Player, Sighting, Pack (serialization, equality)
- **Core services**: breed_collection, combo, dog_mastery, dog_service, demo, dog_friendship, kennel, pack, player, sighting, quiz_engine, mystery_reward
- **Sync infrastructure**: ConflictResolution, SyncQueue (backoff, serialization, retry logic)
- **Identification**: tflite_identification_service (model load, preprocessing, confidence thresholding)
- **Analytics**: analytics_service, ad_service (event tracking, consent gates)
- **Performance**: perf_benchmark_test (20 micro-benchmarks: softmax, label lookup, breed matching)

### What's untested or broken (high-risk)
- **Screens** (0 widget tests): identify, kennel, profile, quiz, map, social (feed, nearby, community), pack, lost_dog, report_lost, etc. → 34 screens, <2% coverage
- **Auth**: auth_service, supabase_auth_service, router auth gate (lines 65-104), offline-mode fallback
- **Photo upload**: photo_upload_service (EXIF stripping, image validation)
- **Embedding extraction**: dog_embedding_service (isolate-based inference, preprocessing)
- **Lost-dog integration**: supabase_lost_dog_service (contact_info RPC, real-time listeners), lost_dog_alert_service (distance-based triggers)
- **Social layer**: dog_social_service, dog_feed_screen, dogs_nearby_screen, breed_community_screen (no widget tests; supabase_social_test broken)
- **Stream lifecycle**: 5 confirmed leaks (lost_dog_map_screen:41,52,83,87,934; lost_dog_hub_screen, help_find_tab +1 more)
- **Error paths**: ML identification failures, network timeouts, Hive corruption, permission revocation mid-operation

---

## Critical findings

### TEST-CRIT-1 — Stream subscription leaks + disposal race (Phase 2 carry-forward Q1/Q2)
**Severity**: Critical  
**What's untested**: `lost_dog_map_screen.dart:41,52,83,87,934` assigns `_sightingSub` during build/initState but disposes race-condition-prone. `_sightingSub?.cancel()` in dispose() may fire during subscription-assignment window. Similar leaks in `lost_dog_hub_screen.dart`, `widgets/lost_dog/help_find_tab.dart` +1 binary match.  
**Risk**: Heap pressure 1–2 MB cumulative per long session; CPU wake-ups on disposed subscribers causes jank. User notices frame drops during map interaction.  
**Recommended test**: Integration test `test/integration/lost_dog_map_lifecycle_test.dart`:
- Build screen → verify `_sightingSub` assigned.
- Dispose screen → verify `cancel()` called exactly once (use `Spy<StreamSubscription>`).
- Rapid build/dispose cycles (10 iterations) → verify no double-cancels or exception.
**Effort**: 2 hours (requires test harness for real Riverpod providers + mock Supabase streams)  
**File(s)**: `lib/screens/lost_dog_map_screen.dart`, `lib/screens/lost_dog_hub_screen.dart`, `lib/widgets/lost_dog/help_find_tab.dart`

### TEST-CRIT-2 — Auth session guard integration never exercised (Phase 2 carry-forward sec-C1)
**Severity**: Critical  
**What's untested**: `router.dart:89–100` implements the offline-mode safety net (sec-C1): when session materializes, redirect clears `offline_mode=false`. `test/sync_services_test.dart:381–422` documents the contract with mock assertions only; no real app-state flow tested. Router redirect logic is untested.  
**Risk**: User remains in offline mode even after authentication if redirect logic fails. Sightings created offline attribute to wrong account on multi-user devices.  
**Recommended test**: Integration test `test/integration/auth_offline_state_machine_test.dart`:
1. App starts → no session, offline_mode=false → router blocks, redirects to /login.
2. User continues offline → offline_mode=true → /identify allowed.
3. User authenticates mid-app (mocked Supabase.instance.client.auth.currentSession materializes) → router redirect executes → verify playerBox.get('offline_mode') becomes false on next frame.
4. Sync triggers → verify SightingSyncService.syncAll() checks session and proceeds (not blocked).
5. User signs out → offline_mode remains false until user re-taps "Continue Offline".
- Use real Hive boxes (HiveTestHelper for temp directory) + real go_router redirect + mock Supabase auth stream.
**Effort**: 3 hours (harness setup + state machine verification)  
**File(s)**: `lib/router.dart:65–104`, `lib/services/auth_service.dart`, `lib/services/sighting_sync_service.dart`

---

## High findings

### TEST-H-1 — SightingSyncService.init() dormancy assertion missing (from Phase 3 prior pass)
**Severity**: High  
**What's untested**: `lib/services/sighting_sync_service.dart:65–69` unconditionally throws `StateError` per sec-C2 (dormancy marker). No unit test asserts the throw; no grep scan verifies zero production callers in lib/.  
**Risk**: Service mistakenly called before UUID migration complete → app crash at startup, silent production failure.  
**Recommended test**: Unit test `test/services/sighting_sync_service_test.dart` (new file):
```dart
test('init() unconditionally throws StateError', () {
  final service = SightingSyncService(mockBox, mockSupabase);
  expect(() => service.init(), throwsStateError);
});
```
Then: `grep -r 'sightingSyncService.init()' lib/` → verify zero matches.  
**Effort**: 0.5 hours  
**File(s)**: `lib/services/sighting_sync_service.dart:65–69`

### TEST-H-2 — dog_found_dialog v1 telemetry double-emission guard untested
**Severity**: High  
**What's untested**: `dog_found_dialog.dart:50–133` implements v1 analytics for T2 redesign feedback loop. `_v1ActionEmitted` guard (line 61) prevents double-emission of `dog_found_dialog_v1_pick`. Zero widget tests exercise the event series (`_v1MaybeEmitOpen`, `_v1HandleAdd`, dismiss-time emit, stopwatch capture).  
**Risk**: Guard logic fails → double-count user actions in dashboard → T2 redesign feedback corrupted, decision-making based on false metrics.  
**Recommended test**: Widget test file `test/widgets/dog_found_dialog_test.dart`:
- Test 1: Dialog opens → `_v1MaybeEmitOpen()` fires exactly once (rebuild doesn't re-emit).
- Test 2: User taps "Add" → `_v1ActionEmitted` becomes true → second tap ignored (no second event).
- Test 3: Dismiss without action → `_v1ActionEmitted` is false → `dispose()` emits `'dog_found_dialog_v1_dismissed'`.
- Test 4: Stopwatch elapsed times captured (validate `time_to_pick_ms`, `time_to_dismiss_ms` keys present).
- Use `ConsumerStatefulWidgetTest` harness + mock `analyticsProvider` with Mockito spy for verify-exact-call assertions.  
**Effort**: 2 hours  
**File(s)**: `lib/widgets/dog_found_dialog.dart:50–133`

### TEST-H-3 — Identification error paths untested (ML robustness)
**Severity**: High  
**What's untested**: `identification_service.dart` + `identify_screen.dart` handle TFLite errors (model load failure, runtime exception, image preprocessing failure, empty results, label cache miss). Current tests mock success only.  
**Risk**: Users hit edge case (bad camera, network blip, corrupted model) → silent failure or uncaught exception → app crash, no graceful error message.  
**Recommended test**: Expand `test/services/tflite_identification_service_test.dart`:
- Test 1: `_buildResults()` receives all-zero logits → returns empty list (rejection gate).
- Test 2: Label cache lookup for valid index returns null (unmapped breed) → skips silently, logs warning, doesn't crash.
- Test 3: New error group `test('identification error handling')`:
  - TFLite Interpreter.run() throws exception → caught, logged, returns `IdentificationFailure`.
  - Image preprocessing throws (invalid format) → returns graceful error message, not crash.
  - Network timeout on image download → retry logic or clear user-facing error.
  - Mock Interpreter + File I/O to throw at strategic points.  
**Effort**: 3 hours  
**File(s)**: `lib/services/identification_service.dart`, `lib/services/tflite_identification_service.dart`, `lib/screens/identify_screen.dart`

### TEST-H-4 — Social layer widget tests absent (pre-launch feature)
**Severity**: High  
**What's untested**: `dog_social_service.dart`, `dog_feed_screen.dart`, `dogs_nearby_screen.dart`, `breed_community_screen.dart` implement activity feed, nearby players, breed communities. `supabase_social_test.dart` has ~30 broken mocks (PostgrestFilterBuilder API drift). Zero widget tests for feed rendering, nearby UI, error states, real-time listener lifecycle.  
**Risk**: UI regressions, state leaks, listener unsubscribe failures ship undetected. Users see empty feeds, "Connection failed" loops, or jank. Impacts user acquisition (social is discovery vector).  
**Recommended test**: Create widget test files:
- `test/screens/dog_feed_screen_test.dart`: Feed loads + displays 5+ sightings, empty state, error state w/ retry button, cleanup verifies `StreamSubscription.cancel()` on dispose.
- `test/screens/dogs_nearby_screen_test.dart`: Renders sorted-by-distance cards, empty state, error recovery.
- Use `WidgetTester.pumpWidget()` + `ProviderContainer` override for Riverpod state control.  
**Effort**: 4 hours  
**File(s)**: `lib/services/dog_social_service.dart`, `lib/screens/dog_feed_screen.dart`, `lib/screens/dogs_nearby_screen.dart`, `lib/screens/breed_community_screen.dart`

### TEST-H-5 — Lost-dog feature integration minimal (1,390-line map screen, 6 service tests only)
**Severity**: High  
**What's untested**: `lost_dog_map_screen.dart` (1,390 lines) renders lost-dog clusters, detail sheets, alerts. `lost_dog_service_test.dart` has only 6 cases (basic CRUD). Untested: real-time listener lifecycle, distance-based alert triggering, map clustering (10+ dogs), form validation, permission flows.  
**Risk**: Lost dogs are user-acquisition vector. Map bugs, listener leaks, or validation gaps frustrate the feature and damage adoption.  
**Recommended test**: Expand service tests + add widget tests:
- Real-time listener subscribes on init, unsubscribes on dispose.
- Distance alert fires when user walks within radius (mock location, verify alert triggers).
- Create `test/screens/lost_dog_map_screen_test.dart`: map renders clusters, expand on tap, detail sheet pops.
- Create `test/screens/report_lost_screen_test.dart`: form validation (name, photo required), geolocation auto-filled, submit calls service.  
**Effort**: 3 hours  
**File(s)**: `lib/services/lost_dog_service.dart`, `lib/services/lost_dog_alert_service.dart`, `lib/screens/lost_dog_map_screen.dart`, `lib/screens/report_lost_screen.dart`

---

## Medium findings

### TEST-M-1 — Hive box corruption / missing-key error paths untested
**Severity**: Medium  
**What's untested**: Services assume Hive boxes exist and keys are valid. Zero tests cover corruption (box opened but data garbage), missing keys (player box lacks 'player' key), mid-session clear, or schema migration failure.  
**Risk**: Beta user experiences crash during sighting write → Hive box corrupted. Next app launch crashes on read attempt.  
**Recommended test**: Create `test/services/hive_resilience_test.dart`:
- Corrupt a sighting value (write non-JSON), verify service handles gracefully.
- Player box missing 'player' key → verify fallback (initialize with blank player).
- Simulate mid-session Hive.clear() → verify service checks `box.isOpen` and reinitializes.
- Use HiveTestHelper for temp-directory isolation + cleanup.  
**Effort**: 2 hours  
**File(s)**: `lib/services/player_service.dart`, `lib/services/sighting_service.dart`, `lib/services/kennel_service.dart`

### TEST-M-2 — Gamification paths spotty (mastery, combos, daily challenges, mystery rewards)
**Severity**: Medium  
**What's untested**: Mastery system, combo counter, achievement unlocks, mystery rewards have unit tests for isolated logic but lack integration tests (sighting → kennel → combo → mastery badge display → achievement unlock). Zero widget tests for badge appearance, combo animation, achievement overlay.  
**Risk**: Gamification is core retention hook. If mastery badges don't display or achievements don't pop, users feel disconnected from progress. UI regressions ship undetected.  
**Recommended test**: Add widget tests:
- `test/widgets/dog_mastery_badge_test.dart`: badge appears when mastery >= 3, correct rarity color applied.
- `test/widgets/combo_counter_test.dart`: counter increments, aura animates on sighting within 24h, resets on miss.
- Integration test: add sighting → verify mastery badge shown + combo updated + achievement fired.  
**Effort**: 3 hours  
**File(s)**: `lib/widgets/` (mastery_badge, combo_counter, achievement_unlock_overlay), `lib/services/dog_mastery_service.dart`

### TEST-M-3 — Quiz engine edge cases undertested
**Severity**: Medium  
**What's untested**: `quiz_engine.dart` has 83 test cases (respectable). Undertested: multiple hints in sequence (are they different?), quiz termination cleanup, concurrent quiz starts (only one active?), difficulty weighting distribution over 100 runs.  
**Risk**: Users exploit timer logic or hints to farm XP unnaturally. State cleanup fails → old quiz persists in memory.  
**Recommended test**: Add test cases to `test/services/quiz_engine_edge_cases_test.dart` (new):
- Hint system returns different hints for same question (3 calls, all different or documented as "same").
- Exiting mid-game clears state (no lingering question, timer stopped).
- Starting new quiz while one is active replaces old.
- Difficulty distribution over 100 samples biases correctly (easy > medium > hard).  
**Effort**: 2 hours  
**File(s)**: `lib/services/quiz_engine.dart`, `test/quiz_engine_test.dart`

---

## Critical-path gaps from Phase 2 carry-forward

| Phase 2 Critical | Test gap | Recommended file | Effort |
|---|---|---|---|
| **S1 / SEC-C-Lost-1** (contact_info broadcast) | No RPC-level test verifying contact info gating or stripping | `test/services/supabase_lost_dog_service_test.dart` — test `get_active_lost_dogs` RPC filters contact_info or null-checks on field | 1 hr |
| **S2 / SEC-C-Lost-2** (no consent/privacy policy) | No consent dialog flow test, no privacy policy URL verification | Manual doc test (not automatable); add to closed-beta checklist | 0 (documented) |
| **Q1/Q2** (stream leaks) | TEST-CRIT-1 (above) — integration test for disposal race + cleanup verification | `test/integration/lost_dog_map_lifecycle_test.dart` | 2 hrs |
| **P1 / FW-001** (dual TFLite load) | No regression test for dual-load detection | Unit test `test/main_test.dart` (new): verify both TfliteIdentificationService + DogEmbeddingService use shared singleton, load() called once | 1.5 hrs |
| **Q2 / SEC-O** (swallowed geolocator exceptions) | No error-path test for geolocator failures | Expand help_find_tab error handling test: mock geolocator throw, verify toast/snackbar shown (not silent fail) | 1 hr |

---

## Test pyramid summary

| Layer | Count | Health |
|-------|-------|--------|
| **Unit** | 530+ across 22 files | Strong. Service logic, models, sync infrastructure, analytics well-covered. |
| **Widget** | 0 test files | **Broken**. 34 screens, <2% coverage. Critical UI paths unexercised. |
| **Integration** | 1 partial file (supabase_auth_test; supabase_social_test broken) | **Weak**. No app-state flows tested (offline→online, sighting→kennel→mastery). Stream lifecycle untested. |
| **Performance** | 20 micro-benchmarks | Adequate. TTA frame-time latency (P-H1) never measured on-device. |
| **Known failures** | 2 files | `supabase_social_test.dart` ~30 broken mocks; `sync_services_test.dart` 13 runtime errors. Blocked on T5 fixes. |

**Verdict**: Inverted pyramid for a mobile app. Widget + integration coverage are the gaps.

---

## Recommended test plan (phased)

### Phase 1 (immediate, pre-closed-beta) — Critical + High fixes
**Target**: 8 hours. Blocks launch gate.
- TEST-CRIT-1: Stream lifecycle integration test (`lost_dog_map_lifecycle_test.dart`)
- TEST-CRIT-2: Auth state machine integration test (`auth_offline_state_machine_test.dart`)
- TEST-H-1: SightingSyncService dormancy assertion
- TEST-H-2: dog_found_dialog v1 telemetry widget tests
- **Total**: 8 hours

### Phase 2 (closed-beta) — UI regression prevention
**Target**: 10 hours. Improve pyramid health.
- TEST-H-3: Identification error paths (3 hrs)
- TEST-H-4: Social layer widget tests (4 hrs)
- TEST-H-5: Lost-dog widget tests (3 hrs)
- **Total**: 10 hours

### Phase 3 (pre-public-launch) — Data integrity + edge cases
**Target**: 7 hours. Polish.
- TEST-M-1: Hive resilience (2 hrs)
- TEST-M-2: Gamification widget tests (3 hrs)
- TEST-M-3: Quiz edge cases (2 hrs)
- **Total**: 7 hours

**Grand total**: 25 hours across 3 phases.

---

## Infrastructure notes

### Test helpers available
- `supabase_auth_test.dart` provides MockSupabaseClient + MockGoTrueClient pattern (reusable).
- `supabase_social_test.dart` has fluent-chain stubbing helper `_stubFrom()` (useful for Postgrest).
- `tflite_identification_service_test.dart` mocks Interpreter + shows compute isolate testing pattern.
- **Missing**: HiveTestHelper (will need to implement or use `hive` package's test utilities).

### Mock API drift issues
- `supabase_social_test.dart` mocks `PostgrestFilterBuilder` but SDK evolved to `PostgrestQueryBuilder` in newer supabase_flutter versions. Needs remocking (T5 task).
- `sync_services_test.dart` line 23 mocks `PostgrestFilterBuilder` — same issue pending SDK API audit (T5 task).

---

## What's healthy (credit)

The 22 existing tests demonstrate disciplined unit-testing for services: breed_collection, mastery, combo, player, pack, kennel, sighting, quiz_engine, and demo_service tests are comprehensive, well-structured, and isolate dependencies with mocks. Analytics event tracking, ad consent logic, and sync queue backoff formulas are all verified. Performance micro-benchmarks (softmax, label cache, conflict resolution) establish baselines. The test infrastructure (mocktail, Riverpod test utilities, test harnesses) is modern and clean. The gap is **not** test discipline; it's **coverage scope** — services are tested, screens are not, and critical error paths lack guards.

---

## Phase 4 hand-off (testing strategy)

1. **Widget-test harness template** — establish reusable pattern for Riverpod + Hive fixtures. Require new screens to include widget tests before merge.
2. **CI gate** — block merge if widget/integration coverage drops below 40% for new screens.
3. **Error-path baseline** — all services with error handling (ML, network, Hive, auth) must have unit tests covering at least: timeout, null response, exception thrown.
4. **Real-device smoke test** — pre-release runs offline→online state machine + sighting sync round-trip on Pixel 5 class device.
5. **Regression suite** — post-closed-beta, nightly build runs subset of widget + integration tests; track flakiness and re-baseline TTA latency after each model update.

---

**Summary**: 2 Critical findings (stream leaks, auth gate integration), 5 High findings (error paths, social layer, lost-dog feature), 3 Medium findings (data resilience, gamification UI, quiz edge cases). Current test pyramid is unit-heavy; widget + integration layers are the blocker for closed-beta confidence. Phased plan totals 25 hours to address Critical + High + Medium, prioritizing launch gates first (Phase 1: 8 hours).
