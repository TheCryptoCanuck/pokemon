# DogQuest Sprint Plan — Post-Review Execution
**Generated:** 2026-04-25  
**Source:** Comprehensive Code Review Final Report (`.full-review/05-final-report.md`)  
**Sprint window:** 4 weeks (quality-first posture, per 2026-04-25 pivot)  
**Sprint goal:** Get from today's pre-closed-beta state to public Play Store submission with full test coverage and GDPR compliance

---

## Effort Gates Summary

| Gate | Effort | Steps |
|------|--------|-------|
| Closed-beta sign-off | ~9–11 hr | Sprint 0 + 1 |
| Public Play Store hard gates | ~30–40 hr more | Sprint 2 + 3 |
| Comfortable public launch | ~70–90 hr total | Sprint 4 + 5 |
| Architectural follow-ups | ~50–100 hr | Post-launch |

---

## Capacity

| Person/Agent | Role | Availability | Notes |
|---|---|---|---|
| Jesse | Owner / gatekeeper | As available | Owns all Jesse-only tasks below; no agent substitution |
| Claude Code (agent) | Primary implementer | On-demand | All code tasks tagged `[CC]` |
| Security Auditor agent | GDPR / sec review | Sprint 2 | Use `comprehensive-review:security-auditor` |
| Test Automator agent | Test pyramid | Sprint 3A | Use `backend-development:test-automator` |
| architect-review agent | ADR writing | Sprint 4 | Use `comprehensive-review:architect-review` |

---

## Sprint 0 — Drift Resolution (Jesse-only, ~30 min, MUST RUN BEFORE ANYTHING ELSE)

These are verification tasks. No agent can substitute for Jesse running these on Windows.

| # | Task | Owner | Effort | Command |
|---|------|-------|--------|---------|
| DRIFT-1 | Verify `.github/workflows/` actually exists on working tree | Jesse | 10 min | `git log --all --oneline -- .github/` + `git branch -av` |
| DRIFT-3 | Verify `android/key.properties` points to new keystore | Jesse | 5 min | `type android\key.properties` on Windows |
| DRIFT-2 | Confirm Supabase schema files exist (positive correction) | Jesse | 5 min | Already confirmed — downgrade OPS-M-003 to ~2 hr CI task |

**Gate:** Sprint 1 cannot start until DRIFT-1 outcome is known (determines whether OPS-001 CI is recovered or needs redo).

---

## Sprint 1 — Quick-Win Criticals (~3–4 hr, run immediately after Sprint 0)

**Goal:** Clear all 5 code-side Criticals. Closed-beta is shippable after this + Sprint 2.

All tasks: `[CC]` = Claude Code agent. Run sequentially (each is independent but small enough to chain).

| # | Finding | Task | Agent | Effort | Files |
|---|---------|------|-------|--------|-------|
| C1 | Stream subscription leak (remaining 2 files) | Convert `lost_dog_hub_screen` + `help_find_tab` subscriptions to `ref.watch` or ChangeNotifier controller pattern (Phase 4a pattern already applied to map screen) | `[CC]` | 20 min | `lib/screens/lost_dog_hub_screen.dart`, `lib/widgets/lost_dog/help_find_tab.dart` |
| C2 | Dual TFLite model load (+800–1200ms cold start) | Create `SharedTfliteService` singleton; wire both `TfliteIdentificationService` and `DogEmbeddingService` to share one `Interpreter.fromAsset` call | `[CC]` | 1 hr | `lib/main.dart:596,668`, `lib/services/tflite_identification_service.dart`, `lib/services/dog_embedding_service.dart` |
| C3 | Swallowed geolocator exceptions | Replace all `catch (_)` / bare `catch (e)` in lost-dog location paths with `_log.warning(…, e, st)` + `FirebaseCrashlytics.instance.recordError` + user-visible `SnackBar` | `[CC]` | 30 min | `lib/screens/lost_dog_map_screen.dart:77`, `lib/widgets/lost_dog/help_find_tab.dart:57-62`, ~10 other geolocator catch sites |
| C4 | `prefer_const_*` lint rules disabled | Re-enable in `analysis_options.yaml`, run `dart fix --apply`, add per-line `// ignore:` for the 3–5 true positives (e.g. `RenderRepaintBoundary`) | `[CC]` | 1–2 hr | `lib/analysis_options.yaml:5-6`, scattered widget files |
| C5 | Unawaited fire-and-forget at `identify_screen.dart:73` | Wrap with `unawaited()` | `[CC]` | 15 min | `lib/screens/identify_screen.dart:73` |

**Verification step:** After all 5 land — `dart format .` + `dart analyze` → 0 errors. Run `flutter test` → confirm no new failures.

**Also in Sprint 1 (T5 quick wins — run in parallel with C1–C5):**

| # | Task | Agent | Effort | Files |
|---|------|-------|--------|-------|
| T5-A | `test/sync_services_test.dart` — fix `null as dynamic` Ref hack (13 test failures) | `[CC]` | 30 min | `test/sync_services_test.dart:165,277,321,345`, `lib/services/conflict_resolution_service.dart` |
| T5-B | `test/supabase_social_test.dart` — rewire mocks for current SDK API (30 analyze errors) | `[CC]` | 1 hr | `test/supabase_social_test.dart` |

---

## Sprint 2 — Closed-Beta Gate (~5–7 hr after Sprint 0+1)

**Goal:** Sign and distribute to 5–10 friends/family.

| # | Finding | Task | Agent | Effort | Notes |
|---|---------|------|-------|--------|-------|
| OPS-C-002 | Keystore password is sequential digits | Rotate to 32+ char random alphanumeric; store in 1Password + GitHub Secrets; regenerate keystore; re-verify signed APK | Jesse + `[CC]` | 1.5 hr | Jesse generates new password; CC rewires `key.properties` |
| OPS-C-001 | CI YAML (conditional on DRIFT-1) | If DRIFT-1 shows `.github/` doesn't exist: redo `dogquest-ci.yml` (4 jobs: format/analyze/test/build-debug-apk). If it exists: just verify the 5 workflows are current | `[CC]` | 0–3 hr | Conditional on Sprint 0 outcome |
| OPS-H-003 | Branch protection not enforced | Enable "Require status checks to pass" on `main` + `phase-1/social-backend-realtime` in GitHub UI; select `dart format` + `flutter analyze` as required checks | Jesse | 1 hr | GitHub UI only; no code |
| C8/TEST-CRIT-2 | Auth session guard integration never exercised | Write `test/integration/auth_offline_state_machine_test.dart` — 5-step state machine (no session → offline → mid-app auth → sync proceeds → signout) using real Hive + go_router + mocked Supabase auth stream | `[CC]` | 3 hr | `lib/router.dart:89-100`, `lib/services/sighting_sync_service.dart:117,174` |
| TEST-CRIT-1 | Stream-leak integration test | Write integration test confirming `LostDogMapController._sightingSub` cancels on dispose; and that hub/help-find-tab subscriptions don't leak | `[CC]` | 1 hr | After C1 lands |
| — | Verify signed APK with new keystore | `flutter build apk --release` → `apksigner verify` → confirm SHA-256 matches new key | `[CC]` | 20 min | Gate before distribution |

**Agent to use for Sprint 2 test tasks:** `backend-development:tdd-orchestrator` for TEST-CRIT-2 integration test planning, then `[CC]` for implementation.

---

## Sprint 3 — Public Play Store Hard Gates (~30–40 hr total)

Run Sprint 3A and 3B in parallel where possible.

### Sprint 3A — GDPR / Privacy (~12–20 hr) — Security Auditor agent

**Agent:** `comprehensive-review:security-auditor` for spec review; `[CC]` for implementation.

| # | Finding | Task | Agent | Effort |
|---|---------|------|-------|--------|
| C6 | Contact info plaintext in `get_active_lost_dogs` RPC | Strip `phone`/`email` from RPC return; add "Request contact" workflow with server-side approval (Option B recommended) | `[CC]` | 3–5 hr |
| C7 | No privacy policy, consent, DPA, or retention | Engineering: privacy policy page (2–3 hr) + consent dialog (1–2 hr) + retention RPC (1 hr) + on-screen consent storage (2–3 hr). Legal/paperwork: Supabase DPA (~1 week wall time — start immediately) | Jesse (DPA) + `[CC]` (engineering) | 8–12 hr eng + ~1 wk wall |
| SEC-H-Lost-1 | Permanent public photo URLs on lost-dog reports | Delete Supabase storage objects on `markFound` / `cancelReport` | `[CC]` | 1–2 hr |
| SEC-M-2 | GPS exposed at full 11cm precision | Fuzz sighting coordinates to ~500m for public display; keep full precision in private user box | `[CC]` | 1–2 hr |
| SEC-M-3 | RLS audit on lost-dog tables | Review `lost_dog_reports`, `lost_dog_sightings`, `friendships`, `packs` RLS in Supabase dashboard | Jesse | 30 min |
| SEC-H-2 | PII in auth logs | Redact `email` from `supabase_auth_service.dart:49,67,90` log calls | `[CC]` | 1 hr |
| SEC-H-3 | Non-secure `Random()` in `_generateId()` | Replace `Random()` with `Random.secure()` in `lost_dog_service.dart:187-191` | `[CC]` | 15 min |
| SEC-H-4 | `network_security_config.xml` not verified | Read + confirm content; ensure no cleartext traffic exceptions beyond localhost | `[CC]` | 30 min |

### Sprint 3B — Ops Pipeline (~8–13 hr)

| # | Finding | Task | Agent | Effort |
|---|---------|------|-------|--------|
| OPS-C-003 | GitHub Secrets not wired | Add `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD` secrets; wire into CI release job | `[CC]` | 1 hr |
| OPS-H-001 | Manual version bumps | Add version automation (tag-triggered `pubspec.yaml` version bump + changelog generation) | `[CC]` | 2 hr |
| OPS-H-002 | No Play Console upload pipeline | Add `fastlane supply` or `google-play` GitHub Action job to CI release workflow | `[CC]` | 3–4 hr |
| OPS-H-004 | No `dart pub audit` in CI | Add `dart pub outdated --json` + fail-on-critical step to `dogquest-ci.yml` | `[CC]` | 1 hr |
| OPS-H-005 | No hotfix runbook | Write `docs/HOTFIX_RUNBOOK.md` covering: cherry-pick to main, emergency release build, Play Console rollout | `[CC]` | 2–3 hr |
| DRIFT-3 | Supabase IaC migration automation | Wire `supabase/` SQL files to CI migration step (`supabase db push` on merge to main) | `[CC]` | 2 hr |

### Sprint 3C — Test Pyramid Phase A (~8 hr, run in parallel with 3A/3B)

**Agent:** `backend-development:test-automator`

| # | Finding | Task | Agent | Effort |
|---|---------|------|-------|--------|
| TEST-H-1 | `SightingSyncService` dormancy assertion missing | Add test asserting `init()` throws `StateError` (confirms dormant guard is wired) | `[CC]` | 30 min |
| TEST-H-2 | `dog_found_dialog` v1 telemetry double-emission guard | Test that opening dialog twice doesn't double-fire `dog_found_dialog_v1_open` | `[CC]` | 1 hr |
| TEST-H-3 | ML identification error paths untested | Tests for: model load failure, image decode failure, all-zero output, timeout | `[CC]` | 2–3 hr |
| TEST-H-4 | Social layer: 0 widget tests + 30 broken mocks | Widget tests for `dog_feed_screen`, `dogs_nearby_screen`, `breed_community_screen`; fix broken `MockPostgrestFilterBuilder` | `[CC]` | 3–4 hr |

---

## Sprint 4 — Medium Findings & Test Phase B (~25–30 hr)

Run opportunistically; can parallel with Sprint 3 where independent.

### Code Quality

| # | Finding | Task | Agent | Effort |
|---|---------|------|-------|--------|
| M-1 | 7 remaining god-class screens >1000 lines | Phased extraction: `profile_screen` (1268), `pack_screen` (1253), `dog_found_dialog` (1219 — T2 spec exists), `map_tab` (1020), `identify_screen` (1002), `scan_stray` (976), `friends_screen` (899) | `[CC]` per screen | ~6 hr each |
| M-2 | 464 null assertions + 34 missing `mounted` guards + 12–15 generic catches | Sweep: add `if (!mounted) return;` after every `await` that uses `BuildContext`; replace `!` with null checks where nullable; narrow generic catches | `[CC]` | 3–5 hr |
| M-3 | `KennelService` implicit setter dependency | Add assertion at initialization | `[CC]` | 5 min |
| M-4 | 9 `GlobalKey` uses (most replaceable) | Audit and replace 7 of 9 with proper state management | `[CC]` | 2 hr |
| M-5 | Hardcoded Supabase URL + anon key in `main.dart:100-103` | Move to `--dart-define` with build-time injection; fail loudly in release if not provided | `[CC]` | 1 hr |
| M-6 | `flutter_map` marker redraw without clustering | Add `flutter_map_marker_cluster` for lost-dog and sighting maps | `[CC]` | 2–3 hr |
| M-7 | `cached_network_image` cache cap not configured | Set `maxHeightDiskCache`, `maxWidthDiskCache` globally | `[CC]` | 1 hr |
| M-8 | Camera dispose pattern fragile in `identify_screen` | Tighten dispose → reinit cycle; guard `takePicture()` races | `[CC]` | 1–2 hr |
| M-9 | Input validation missing on text fields | Add validation to lost-dog report form, profile edit, contact fields | `[CC]` | 1–2 hr |
| M-10 | Dio cert pinning missing | Add certificate pin for Supabase domain | `[CC]` | 2–3 hr |

### Test Pyramid Phase B (~10 hr)

| # | Task | Agent | Effort |
|---|------|-------|--------|
| TEST-H-5 | Lost-dog widget tests (map screen, hub, report card) | `[CC]` + `backend-development:test-automator` | 4 hr |
| TEST-M-1 | Hive corruption / missing-key resilience | `[CC]` | 2 hr |
| TEST-M-2 | Gamification widgets (`mastery_badge`, `combo_counter`, `achievement_unlock_overlay`) | `[CC]` | 3 hr |
| TEST-M-3 | Quiz edge cases (concurrent starts, hint diversity, question type docs) | `[CC]` | 2 hr |

### Documentation (~15–20 hr, opportunistic)

**Agent:** `comprehensive-review:architect-review` for ADR writing; `[CC]` for everything else.

| # | Task | Agent | Effort |
|---|------|-------|--------|
| DOC-H-ADR | 8 ADRs: Riverpod, lost-dog UUID, Hive encryption, backend posture, synonym clusters, 3-crop TTA, Sentry→Crashlytics, float16 plan | `comprehensive-review:architect-review` | 3–4 hr |
| DOC-H-API | `docs/SUPABASE_API.md` — full contract for all RPCs and tables | `[CC]` | 1–2 hr |
| DOC-M-Setup | `docs/SETUP.md` + `make doctor` target | `[CC]` | 1–2 hr |
| DOC-H-Synonym | `docs/SYNONYM_CLUSTERS.md` — justify 6 clusters with breed-visual rationale | `[CC]` | 1 hr |
| DOC-H-Auth | `docs/AUTH_STATE_MACHINE.md` — formal diagram of offline/online/session states | `[CC]` | 1–2 hr |
| DOC-M-CLAUDE | CLAUDE.md: fix stale 5-crop reference → 3-crop in TTA notes | `[CC]` | 15 min |
| DOC-M-Quant | Append T3 implementation checklist to quantization research doc | `[CC]` | 30 min |

---

## Sprint 5 — Pre-Launch Widget Refactor (~20–30 hr, opportunistic)

**Goal:** Convert 81 widget-returning helper functions to named `StatelessWidget` classes. Prioritize the 7 god-class files from Sprint 4. This unlocks `const` propagation, tree-shaking, and widget-level testability.

**Agent:** Use `agent-teams:parallel-feature-development` to split by file ownership across parallel `[CC]` agents. Each screen is independent — safe to parallelize.

| Priority | Screen | Est. Lines Extracted | Effort |
|---|---|---|---|
| 1 | `profile_screen.dart` | ~400 | 4–6 hr |
| 2 | `pack_screen.dart` | ~350 | 4–6 hr |
| 3 | `dog_found_dialog.dart` | ~300 | 3–4 hr |
| 4 | `map_tab.dart` | ~280 | 3–4 hr |
| 5 | `identify_screen.dart` | ~250 | 3–4 hr |
| 6 | `scan_stray_screen.dart` | ~200 | 2–3 hr |
| 7 | `friends_screen.dart` | ~180 | 2–3 hr |

**CI gate to add (2 hr):** Widget coverage gate — fail CI if widget test count drops below threshold.

---

## Architectural Backlog (Post-Launch)

These are deferred by design — do not schedule until closed beta feedback is in.

| Item | Effort | Notes |
|------|--------|-------|
| Lost-dog full sync architecture (Phase 1+4) | 26–62 hr | See `docs/session_2026-04-26/lost_dog_improvements_spec.md` |
| Embedding model upgrade (pre-softmax 1408-dim or MobileNetV3) | 3–12 hr | Gated on 30-min TFLite multi-output audit |
| Read-modify-write JSON-blob → per-item Hive | 4–8 hr | LostDog, Pack, DogFriendship, DogSocial |
| Sealed classes for state unions | 8–10 hr | Low urgency; pure architecture |
| Environment separation dev/staging/prod | 3–4 hr | — |
| 26-provider eager init reduction (~50ms cold start) | 2–3 hr | Profile first |
| v6 model retrain (EfficientNetV2-S, 294 breeds) | ~10 hr GPU | Overnight run; gate on data pipeline readiness |
| float16 TFLite export (+8–9pt accuracy recovery) | 3–5 hr | See quantization research doc |

---

## Agent Assignment Quick-Reference

| Task Category | Recommended Agent/Plugin |
|---|---|
| Dart/Flutter code fixes (all C1–C5, M-*, T5-*) | Claude Code (`[CC]`) directly |
| GDPR / security spec review | `comprehensive-review:security-auditor` |
| Integration test planning | `backend-development:tdd-orchestrator` |
| Test implementation | `backend-development:test-automator` |
| ADR / architecture docs | `comprehensive-review:architect-review` |
| Parallel widget extraction (Sprint 5) | `agent-teams:parallel-feature-development` + team of `[CC]` agents |
| CI/CD pipeline tasks | `cicd-automation:deployment-engineer` |
| Lost-dog sync architecture (post-launch) | `backend-development:backend-architect` |
| ML model tasks (float16, v6 retrain) | `machine-learning-ops:ml-engineer` |

---

## Key Milestones

| Date | Milestone |
|------|-----------|
| Day 0 (today) | Sprint 0: Jesse resolves DRIFT-1 + DRIFT-3 |
| Day 1 | Sprint 1 complete: all 5 code Criticals closed, T5 test fixes land |
| Day 2–3 | Sprint 2 complete: keystore rotated, CI confirmed, auth integration test written |
| Week 2 | Sprint 3A engineering: GDPR contact flow + privacy policy + consent dialog |
| Week 2 (parallel) | Sprint 3B ops: secrets, version automation, Play Console pipeline |
| Week 2 (parallel) | Sprint 3C tests: Phase A test pyramid |
| Week 2 (wall time) | Supabase DPA paperwork submitted |
| Week 3 | Sprint 4: medium findings sweep + test Phase B + docs |
| Week 4 | Sprint 5: widget refactor (opportunistic) + Play Store listing prep |
| Post-Week 4 | Closed beta launch → collect 2 weeks feedback → architectural backlog |

---

## Definition of Done (per task)

- [ ] `dart format .` → clean
- [ ] `dart analyze` → 0 lib errors (no regressions)
- [ ] `flutter test` → pass count ≥ pre-task baseline
- [ ] No new `!` bangs except immediately after null check
- [ ] No new `print()` — use `dart:developer` `log()`
- [ ] `if (!mounted) return;` guard after every `await` using `BuildContext`
- [ ] All futures either `await`ed or wrapped in `unawaited()`
- [ ] Committed with descriptive message referencing finding ID (e.g. `Fix stream leak in lost_dog_hub_screen (C1-review)`)

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| DRIFT-1: CI YAML doesn't exist → needs redo | +3 hr Sprint 2 | Sprint 0 verification routes correctly |
| Supabase DPA takes >2 weeks approval | Delays public launch | Submit DPA paperwork in Sprint 3A day 1; run engineering in parallel |
| v6 retrain not done before Play Store | Deployed at 150 breeds, not 294 | Ship with 150 breeds; v6 as OTA model update post-launch |
| God-class extraction introduces regressions | UI breaks | Widget tests gate each extraction; run `dart analyze` after each file |
| Float16 model doesn't recover the -9pt gap | Accuracy stays at 87.2% | Fallback: QAT retrain (40–60 hr GPU) or ship as-is |
