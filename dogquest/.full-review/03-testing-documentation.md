# Phase 3 — Testing & Documentation (Consolidated)

**Review date**: 2026-04-25 evening
**Mode**: strict, security-focus
**Method**: 3A test-automator + 3B docs-architect in parallel

## Executive read

DogQuest's test suite has a **healthy unit-test layer (530+ cases across 22 files) but an inverted pyramid** — zero widget tests across 34 screens, weak integration coverage, and ZERO test guardrails on the Phase 2 Critical paths (stream lifecycle, auth gate, dual TFLite load, geolocator error path). 2 known-broken test files block T5 work.

Documentation is **strong-but-uneven**: CLAUDE.md is exceptional for a solo project, the vault is a real knowledge asset, security-critical inline docs (SightingSyncService sec-C2 dartdoc, dog_found_dialog v1 telemetry) are excellent. But there are **zero ADRs**, no Supabase API contract doc, no published privacy policy (DOC-C-Privacy = SEC-C-Lost-2 from another angle), and the auth state machine + synonym cluster rationale live in commit messages and the vault rather than in durable repo docs.

## Critical findings

### T1 — Stream subscription leaks have ZERO test coverage
**Source**: 3A TEST-CRIT-1. **Same root as Phase 2 Critical Q1.**
- `lost_dog_map_screen.dart:41,52,83,87,934`, `lost_dog_hub_screen.dart`, `widgets/lost_dog/help_find_tab.dart` + 1 binary match.
- Recommended test: `test/integration/lost_dog_map_lifecycle_test.dart` — verify subscription assigned on init, canceled on dispose, no double-cancel under rapid build/dispose cycles.
- **Effort**: 2 hr.

### T2 — Auth session guard integration NEVER exercised
**Source**: 3A TEST-CRIT-2. **Closes the test gap on the sec-C1 fix.**
- `router.dart:89-100` redirect logic untested. `sync_services_test.dart:381-422` documents the contract but doesn't exercise it (per CLAUDE.md the test is "documented post-condition", not behavioral).
- Risk: offline_mode flag doesn't clear when session materializes → sightings created offline attribute to wrong account.
- Recommended test: `test/integration/auth_offline_state_machine_test.dart` — 5-step state machine (no session, offline_mode=true, mid-app auth, sync proceeds, signout, etc.) using real Hive + real go_router + mocked Supabase auth stream.
- **Effort**: 3 hr.

### D1 / DOC-C-Privacy — Standalone privacy policy missing
**Source**: 3B. **Same as SEC-C-Lost-2 (Phase 2A) but viewed as a doc deliverable.**
- An in-app privacy screen exists at `lib/screens/privacy_policy_screen.dart` but is not a substitute for a web-accessible document Google Play requires (Policy 5.2).
- Fix: create `docs/PRIVACY_POLICY.md` (or hosted on dogquest.app once registered). Sections: Information Collection, Use, Retention, GDPR Rights, Contact.
- **Effort**: 1-2 hr (extract + enrich from in-app screen).

## High findings

### Test (5)

- **TEST-H-1** — `SightingSyncService.init()` dormancy assertion missing. `lib/services/sighting_sync_service.dart:65-69` throws `StateError`; no unit test asserts the throw, no callsite scan verifies zero production callers. Fix: 30-min unit test + grep verification.
- **TEST-H-2** — `dog_found_dialog` v1 telemetry double-emission guard untested. `_v1ActionEmitted` line 61 prevents double-count on `dog_found_dialog_v1_pick`; no widget test verifies. Risk: corrupted T2 redesign feedback metrics. 2 hr.
- **TEST-H-3** — Identification error paths untested. TFLite Interpreter throw, image preprocessing fail, empty results, label cache miss. Current tests mock success only. 3 hr.
- **TEST-H-4** — Social layer (dog_social_service, dog_feed_screen, dogs_nearby_screen, breed_community_screen) has zero widget tests; `supabase_social_test.dart` 30 broken mocks. 4 hr.
- **TEST-H-5** — Lost-dog feature minimal coverage on a 1390-line map screen. 6 service tests on lost_dog_service; nothing on map/widget/distance-alert flows. 3 hr.

### Documentation (5)

- **DOC-H-API** — Supabase API contract undocumented. `sync_sightings` RPC wire format only in code; sec-C1 server-side ownership enforcement docs only in vault Decisions.md. Risk: schema drift between Dart client + Postgres function silently breaks sync. Fix: `docs/SUPABASE_API.md`. 1-2 hr.
- **DOC-H-ML-TTA** — TFLite preprocessing + TTA strategy has stale comment at `tflite_identification_service.dart:20` referencing 5-crop+flip 10-variant approach (the OLD v5); deployed v5.1 uses 3-variant. 30 min to update comment + class dartdoc.
- **DOC-H-Synonym-Clusters** — 6 hardcoded synonym clusters in `tflite_identification_service.dart` have no justification or validation criteria documented. The "downgrade Very confident when same cluster appears twice" rule mentioned in Active_Tasks doesn't exist in code. Fix: `docs/SYNONYM_CLUSTERS.md` + reference test data. 1 hr.
- **DOC-H-Auth-SM** — Offline auth state machine never formally specified. States, transitions, sec-C1 safety net all live in commit messages. 1-2 hr to write.
- **DOC-H-ADR-Backlog** — `docs/adr/` empty. 5-8 ADRs worth writing: Riverpod choice, lost-dog UUID approach, Hive encryption strategy, backend posture, synonym clusters, 3-crop TTA, Sentry→Crashlytics swap, planned float16 export. 3-4 hr (~30 min each).

## Medium findings

### Test (3)

- **TEST-M-1** — Hive box corruption / missing-key paths untested. Risk: real-world device corruption mid-write → app crashes on next read. 2 hr — `test/services/hive_resilience_test.dart`.
- **TEST-M-2** — Gamification widgets (mastery_badge, combo_counter, achievement_unlock_overlay) have no widget tests. Retention-critical UI shipping unverified. 3 hr.
- **TEST-M-3** — Quiz engine edge cases (concurrent starts, hint diversity, difficulty distribution over 100 runs). 2 hr.

### Documentation (5)

- **DOC-M-Quiz-Engine** — 13 quiz question types in `quiz_engine.dart` undocumented. Active T2 quiz redesign work would benefit. 1-2 hr.
- **DOC-M-Vault-Index** — `.second_brain/` 40+ files lack a master index. 1-2 hr to create `.second_brain/00_System/INDEX.md`.
- **DOC-M-CLAUDE-Model-Drift** — `CLAUDE.md:93-94` still references "5-crop + 10-variant TTA" — actually deployed v5.1 uses 3-crop. 15 min — small text edit.
- **DOC-M-Makefile-Setup** — 30+ Makefile targets and required `--dart-define` env vars not documented. No `make doctor`. 1-2 hr to write `docs/SETUP.md` + add doctor target.
- **DOC-M-Quantization-Impl** — `docs/session_2026-04-26/quantization_headroom_research.md` is excellent research but lacks a step-by-step implementation checklist for the T3 float16 export. 30 min to append.

## Low findings (3)

- **DOC-L-README-GDPR** — README docs section doesn't link the privacy policy. 5 min.
- **DOC-L-SEC-C3-Comment** — already closed in archived review.
- **TEST-Pyramid-Inversion** — Strategic note: 530+ unit / 0 widget / 1 partial integration is wrong shape for a mobile app. Phase 4 should set CI gate for new screens.

## Critical-path test gaps mapped from Phase 2

| Phase 2 Critical | Test gap | Recommended file | Effort |
|---|---|---|---|
| **S1 SEC-C-Lost-1** (contact_info broadcast) | No RPC test verifying contact_info gating/stripping | `test/services/supabase_lost_dog_service_test.dart` | 1 hr |
| **S2 SEC-C-Lost-2** (no consent/policy) | Not automatable; goes to closed-beta checklist | manual | 0 |
| **Q1/Q2** (stream leaks) | TEST-CRIT-1 / T1 above | `test/integration/lost_dog_map_lifecycle_test.dart` | 2 hr |
| **P1 FW-001** (dual TFLite load) | No regression test for dual-load detection | new `test/services/shared_tflite_test.dart` | 1.5 hr |
| **Q2 SEC-O** (swallowed geolocator) | No error-path test | expand `test/widgets/help_find_tab_test.dart` | 1 hr |

## Test pyramid summary

| Layer | Count | Health |
|-------|-------|--------|
| Unit | 530+ across 22 files | Strong |
| Widget | 0 files | **Broken** (34 screens unexercised) |
| Integration | 1 partial (supabase_auth) + 1 broken | **Weak** |
| Performance | 20 micro-benchmarks | Adequate |
| Known broken | 2 files | `supabase_social_test` 30 mocks; `sync_services_test` 13 runtime errors. T5 tasks. |

## ADR backlog (from 3B, schedule item)

1. ADR-0001 — State Management (Riverpod over BLoC + ChangeNotifier)
2. ADR-0002 — Lost Dog Sync UUID Architecture (reduced-scope SightingSyncService dormancy)
3. ADR-0003 — Hive Encryption Strategy (FlutterSecureStorage-backed AES, sightings only)
4. ADR-0004 — Backend Posture (local-first; Supabase as planned remote)
5. ADR-0005 — Synonym Clusters (Option B hardcoded mapping)
6. ADR-0006 — Image Preprocessing (3-crop TTA, latency vs. accuracy)
7. ADR-0007 — Sentry → Crashlytics Migration (Firebase alignment)
8. ADR-0008 — Float16 Quantization Path (planned T3 decision gate)

## Recommended test plan (phased, from 3A)

| Phase | Scope | Effort |
|-------|-------|--------|
| 1 (pre-closed-beta) | TEST-CRIT-1, TEST-CRIT-2, TEST-H-1, TEST-H-2 | 8 hr |
| 2 (closed-beta) | TEST-H-3, TEST-H-4, TEST-H-5 | 10 hr |
| 3 (pre-public-launch) | TEST-M-1, TEST-M-2, TEST-M-3 | 7 hr |
| **Total** | | **25 hr** |

## Doc deliverables for public launch

| Deliverable | Hard gate? | Effort |
|-------------|-----------|--------|
| `docs/PRIVACY_POLICY.md` (DOC-C-Privacy) | **YES** | 1-2 hr |
| ADR backlog (DOC-H-ADR-Backlog) | NO | 3-4 hr |
| `docs/SUPABASE_API.md` (DOC-H-API) | NO | 1-2 hr |
| `docs/SETUP.md` + `make doctor` | NO | 1-2 hr |

## What's healthy

**Tests**: 530+ unit cases, well-named, mocktail-based, isolate dependencies cleanly. Service layer (breed_collection, mastery, combo, player, pack, kennel, sighting, quiz_engine) coverage solid. Performance micro-benchmarks (softmax, label cache, conflict resolution) establish baselines. Test infrastructure modern. Issue is **scope**, not discipline.

**Docs**: CLAUDE.md is unusually strong for solo dev (comprehensive tech stack, feature breakdown, known-issues, code conventions). The `.second_brain/` vault is a real knowledge asset (Active_Tasks runbook + Decisions ledger + Failure_Patterns memory). Inline docs on the security-critical paths (SightingSyncService sec-C2, dog_found_dialog telemetry) are excellent. Session-dated docs (lost_dog_improvements_spec, quiz_redesign_spec, quantization_headroom_research) are detailed and specific. README is solid (DOC-002 closed).

## Carry-forward to Phase 4

For Phase 4A (framework/language best practices):
- The 81 widget-returning helper functions (Phase 1 H1) are a Dart/Flutter idiom violation as much as a testability issue.
- Re-enable `prefer_const_*` lint rules (Q11) — fix candidate.
- Sealed classes underutilized (Q-L3) — Dart 3 idiom opportunity.
- `unawaited()` discipline (Q-L1) — analyzer/lint enforcement.
- `withOpacity` / `WillPopScope` — already clean, verify no regression.

For Phase 4B (CI/CD / DevOps):
- 5 .yml workflows in `.github/workflows/` — `dogquest-ci.yml` (4 jobs: format/analyze/test/build-debug-apk, test = continue-on-error pending T5) + restored `aviquest-ci.yml` + 3 pre-existing from 2026-03-03 (`flutter-ci.yml`, `infrastructure-ci.yml`, `release.yml`) — Jesse hasn't audited the older 3 for overlap.
- No `dart pub audit` in CI (SEC-L-2).
- No widget-coverage threshold gate (3A's recommendation).
- Branch protection on `main` and `phase-1/social-backend-realtime` not yet enabled (T1 phone-bound item).
- Crashlytics on-device verification still pending (T1 phone-bound item).
- No release pipeline beyond debug-APK build — Play Store internal track upload not automated.
- Multi-workflow inventory note: I'm not sure what the 3 pre-existing workflows actually cover.
