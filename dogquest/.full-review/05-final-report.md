# Comprehensive Code Review Report — DogQuest

## Review Target

Whole DogQuest project. Flutter 3.41.2 / Dart 3.11 (152 files, ~50,300 LOC) + Python ML pipeline (train_model_v6.py, export_tflite.py, audit harness) + Supabase backend + 21 test files. Branch: `phase-1/social-backend-realtime`.

Strict mode ON. Started 2026-04-25T01:30Z; completed (with mid-session fix-criticals checkpoint) 2026-04-25T09:30Z.

## Executive Summary

DogQuest is in genuinely good shape on the **code-quality / architecture / security** axes after the four sec-related commits landed today (`aaebc5d` C3 archive, `4da92cf` C1 router, `f8eae20` C1+C2 sync service, `b247a4a` E5 telemetry). Server-side ownership is enforced at two independent layers (Supabase RPC `auth.uid()` + RLS `sightings_own`), the offline auth gate clears on every session-producing redirect, the dormant `SightingSyncService` throws on accidental wiring, and v1 telemetry now feeds the T2 redesign baseline window.

**The remaining risk surface is operational, not security.** No CI/CD pipeline, no signed-APK release flow, no IaC for the Supabase schema, no widget-test coverage, and Sentry's DSN is still empty. These don't compromise current deployed users (closed beta hasn't shipped yet), but they're closed-beta blockers and post-launch reliability tax.

Documentation is a mid-tier concern: CLAUDE.md drifted on ML model details (150 vs 294 vs 296 breeds across the file), no README at repo root, and the Supabase RPC contract lives only in the dashboard. None block users; all hurt new-contributor velocity and operational memory.

## Findings by Priority

### Critical Issues (P0 — Must Fix Immediately)

All Phase 1+2 Criticals were resolved during this session:

- **C1 Sync ownership** — RESOLVED. Commits `4da92cf` + `f8eae20`. RLS verified via Supabase dashboard (`sightings_own: auth.uid() = user_id` with `FOR ALL`).
- **C2 SightingSync UUID conflation** — RESOLVED (reduced-scope). Commit `f8eae20`. Service marked dormant; `init()` throws `StateError`. Full UUID-on-model migration deferred to post-beta.
- **C3 Vestigial `backend/`** — RESOLVED. Commit `aaebc5d`. Directory removed; .gitignore line 35-39 enforces.

New Critical findings from Phases 3+4:

- **OPS-001 — No CI/CD pipeline.** No `.github/workflows/`. Pre-commit hooks via `Makefile hooks-install` are local-opt-in. No branch protection. Every quality gate (format, analyze, test) is manual. **Closed-beta blocker.** Effort: 4–8 hr to wire baseline GitHub Actions (build, test, format-check) + branch protection rules.
- **OPS-002 — No signed-APK release pipeline.** TASK-049 (signing key generation) still pending. No artifact repository, no Play Store internal-track integration. Manual-build-and-share only. **Closed-beta blocker.** Effort: 1–2 hr (keystore + Gradle release config + adb install of signed APK), then 2–3 hr for Play Store internal-track upload pipeline.
- **DOC-001 — CLAUDE.md drifts on ML model specs.** Documented variants are inconsistent (150 / 294 / 296 breeds). Materially affects how a contributor reads "deployed" vs "training" model state. **Critical because the project intelligence file is the AI/human onboarding entry point.** Effort: 30 min (audit + reconcile).

### High Priority (P1 — Fix Before Closed Beta)

- **OPS-003 — Sentry DSN empty.** TASK-050. Code wired (`lib/main.dart:101-118`), just needs Jesse to sign up at sentry.io and run `make wire-sentry SENTRY_DSN=...`. Effort: 30 min.
- **OPS-004 — Environment config hardcoded.** `lib/main.dart` has Supabase URL + anon key as `String.fromEnvironment` defaults. Risk: dev builds accidentally hit production. Add `.env.example` + build-wrapper script. Effort: 1 hr.
- **OPS-005 — Supabase schema not version-controlled.** RLS policies, RPCs, migrations all live only in the dashboard. Move to `supabase/migrations/` or equivalent IaC. Effort: 2–3 hr (initial dump + workflow setup).
- **DOC-002 — No README.md at repo root.** GitHub discovery weak; onboarding friction. Effort: 1 hr.
- **DOC-003 — Supabase RPC contract undocumented.** `sync_sightings` body + RLS policies exist only in dashboard. Add `docs/supabase-schema.md` or commit `supabase/` config. Effort: 30 min once OPS-005 lands.
- **DOC-004 — `.gitignore` sec-C3 block lacks rationale.** Future cleanup could unknowingly restore the vulnerability. Add inline comment with rationale. Effort: 5 min.
- **DOC-005 — TFLite TTA strategy + preprocessing underdocumented.** Engineers extending the model will re-invent. Effort: 1 hr.
- **TEST-001 — `SightingSyncService` dormancy assertion missing.** No test asserts the StateError throw or the zero-callers invariant. Effort: 30 min.
- **TEST-002 — v1 telemetry untested.** `_v1ActionEmitted` double-emission guard, four event types — no widget tests. Adds CI surface for the T2 redesign baseline. Effort: 1.5 hr.
- **TEST-003 — sec-C1 contract-doc tests should upgrade to behavioral integration tests.** Currently the guard is documented but not exercised. Effort: 30 min.
- **TEST-004 — Identification error paths untested.** TFLite exceptions, image preprocessing failures, label cache misses — zero coverage. Effort: 2 hr.
- **TEST-005 — Social layer has zero widget tests.** Effort: 4–6 hr to scaffold the harness + cover the first 4 screens.
- **FW-001 — Dual TFLite model load at startup.** Two services each load the same 23.8 MB model. 0.5–1.0 s startup waste. Effort: 30–45 min.

### Medium Priority (P2 — Plan for Post-Beta or Next Sprint)

- **TEST-006 to TEST-010** — Hive corruption, gamification widget gaps, lost-dog feature thin coverage, performance benchmark incomplete, quiz engine edge cases.
- **DOC-006 to DOC-009** — Quiz question type semantic docs, synonym cluster rationale, offline auth state machine doc, vault master index.
- **FW-002 to FW-006** — Riverpod code-gen migration, Python ML type hints, Material 3 color tokens, `.then()`/`.catchError()` cleanup, AutoDispose adoption.
- **OPS-006 — Widget test CI gate** (depends on TEST-005 first).
- **OPS-007 — Firebase Performance Monitoring not wired.** TTA inference latency unverified on real devices.
- **OPS — Rollback plan, model versioning strategy, incident response runbook.**

### Low Priority (P3 — Track in Backlog)

- **DOC-010, DOC-011** — Quantization research checklist, env-var docs.
- **FW-007, FW-008** — Hooks-install enforcement, bang-operator audit (already compliant).
- **OPS — Build cache optimization, Gradle daemon tuning.**

## Findings by Category

| Category | Critical | High | Medium | Low |
|---|---|---|---|---|
| Code Quality (Phase 1A) | (resolved earlier) | | | |
| Architecture (Phase 1B) | (resolved earlier) | | | |
| Security (Phase 2A) | 0 (3 resolved this session) | | | |
| Performance (Phase 2B) | (per phase 2 doc) | | | |
| Test Coverage (Phase 3A) | 2 | 5 | 3 | 0 |
| Documentation (Phase 3B) | 1 | 5 | 4 | 2 |
| Framework / Language (Phase 4A) | 0 | 1 | 6 | 2 |
| CI/CD & DevOps (Phase 4B) | 2 | 4 | 5 | 2 |

## Recommended Action Plan

### Pre-closed-beta gate (~1.5 days)

1. **OPS-002 — Generate signing key + Gradle release config.** TASK-049. ~1.5 hr. Without this, no closed-beta APK ships at all.
2. **OPS-003 — Sentry DSN.** TASK-050. ~30 min. Without this, beta crash data is invisible.
3. **OPS-001 minimum — wire one GitHub Actions workflow** that runs `dart format --set-exit-if-changed && flutter analyze && flutter test`. Branch protection on `main`/`phase-1/...` requires the workflow to pass. ~3–4 hr.
4. **DOC-001 — Reconcile CLAUDE.md ML specs.** ~30 min.
5. **DOC-002 — README.md.** ~1 hr.

### Closed-beta gate (~3–4 days additional)

6. OPS-004 (env config), OPS-005 (Supabase IaC), DOC-003 (RPC contract).
7. TEST-001/002/003 (sec-C1/C2/E5 verification tests).
8. FW-001 (dual TFLite load fix — measurable user win).
9. Resume the deferred T2 dog_found_dialog redesign (spec is at `docs/session_2026-04-26/dog_found_dialog_redesign_spec.md` with the (e) Critic Pass section).

### Post-beta queue (driven by feedback)

10. T3 float16 TFLite export (research at `docs/session_2026-04-26/quantization_headroom_research.md`).
11. TEST-005 widget-test scaffold + per-screen coverage.
12. Full sec-C2 UUID-on-model migration if SightingSyncService gets wired.
13. P2 framework / docs / OPS items.

## Review Metadata

- **Started**: 2026-04-25T01:30Z
- **Checkpoint 1 (Phase 2 → 3)**: paused for fix-criticals; resumed 2026-04-25T09:30Z after C1/C2/C3 closed.
- **Completed**: 2026-04-25T09:30Z (this report).
- **Phases**: 1 Code Quality + Architecture, 2 Security + Performance, 3 Testing + Documentation, 4 Best Practices + DevOps, 5 Consolidated.
- **Flags**: strict_mode=on, framework=auto (Flutter + Python).
- **Total findings (Phase 3+4 only, prior phases not re-counted here)**: 5 Critical, 15 High, 18 Medium, 6 Low.
- **All Phase 1+2 Criticals**: resolved during the mid-session fix-criticals window.

## Output Files

- `00-scope.md` — review scope
- `01-quality-architecture.md` — Phase 1 consolidated
- `01a-code-quality-findings.md` — code-reviewer detail
- `01b-architecture-findings.md` — architect-review detail
- `02-security-performance.md` — Phase 2 consolidated
- `02a-security-findings.md` — security-auditor detail
- `02b-performance-findings.md` — performance-engineer detail
- `03-testing-documentation.md` — Phase 3 consolidated
- `03a-test-findings.md` — test-coverage detail
- `03b-documentation-findings.md` — documentation detail
- `04-best-practices.md` — Phase 4 consolidated
- `04a-framework-findings.md` — framework / language detail
- `04b-cicd-findings.md` — CI/CD / DevOps detail
- `05-final-report.md` — this report
