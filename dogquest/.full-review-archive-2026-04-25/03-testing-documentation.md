# Phase 3: Testing & Documentation Review

## Test Coverage Findings (3A)

Detail: `03a-test-findings.md`. 10 substantive findings — 2 Critical, 5 High, 3 Medium.

### Highlights

- **TEST-001 (High)**: `SightingSyncService` dormancy assertion missing. The unconditional StateError throw (sec-C2 mitigation) has zero test coverage. Nothing prevents accidental wiring.
- **TEST-002 (High)**: v1 telemetry in `dog_found_dialog.dart` untested. The `_v1ActionEmitted` double-emission guard, and the four event types (open/pick/manual_search/dismissed), have no widget tests verifying correct firing sequence. Telemetry without coverage drifts silently.
- **TEST-003 (High)**: sec-C1 auth-session guard is contract-doc-tested only. The `mockAuth.currentSession` assertions in `test/sync_services_test.dart:381+` document the contract but never instantiate `SightingSyncService` and verify the guard short-circuits the RPC call. Pre-public-launch upgrade.
- **TEST-004 (High)**: Identification error paths untested. TFLite exceptions, image preprocessing failures, label cache misses — zero coverage.
- **TEST-005 (High)**: Social layer has zero widget tests.

### Test pyramid (verified)

- Unit: 530+ test cases across 22 files. Models + services strong.
- Widget: 0 widget test files. Critical gap.
- Integration: minimal — auth flow mocks + social mocks only.
- Performance: micro-benchmarks only; no on-device frame-time profiling.

## Documentation Findings (3B)

Detail: `03b-documentation-findings.md`. 12 substantive findings — 1 Critical, 5 High, 4 Medium, 2 Low.

### Highlights

- **DOC-001 (Critical)**: `CLAUDE.md` ML-model specs drift. Documented variants (150 / 294 / 296 breeds) inconsistent across the file. New-contributor onboarding will misread "deployed" vs "training" model state.
- **DOC-002 (High)**: No `README.md` at repo root. GitHub discovery fails; onboarding friction.
- **DOC-003 (High)**: Supabase API contract (`sync_sightings` RPC + `sightings_own` RLS) undocumented in repo. Exists only in code + Jesse's dashboard. Maintenance risk.
- **DOC-004 (High)**: `.gitignore` `backend/` ignore (sec-C3) lacks the rationale comment in-repo. Future cleanup could unknowingly restore the vulnerability.
- **DOC-005 (High)**: TFLite TTA strategy + preprocessing underdocumented.

### Documentation health score (3B's assessment)

- Project intelligence (CLAUDE.md): drifted; needs reconciliation
- Inline code doc on security paths (sec-C1, sec-C2, sec-E5): solid
- API contract: weak (no schema doc)
- Setup/onboarding: weak (no README)
- Vault: coherent; no master index
- Spec docs (`docs/session_2026-04-26/`): comprehensive for T2 work

Overall: 6.3 / 10.

## Critical Issues for Phase 4 Context

- TEST-002, DOC-003 imply CI/CD gaps: telemetry dashboards + RPC contract should be CI-enforceable.
- TEST coverage gaps suggest a CI gate (no widget tests = no widget regressions caught) — Phase 4 should propose enforcement.
- DOC-002 (no README) is a CI/Build phase concern: GitHub repo lacks the standard discovery surface.
- DOC-001 (CLAUDE.md drift) implies the vault refresh ritual isn't being run; consider scheduled CI check that diffs CLAUDE.md against actual lib/services count, asset/dog_labels.txt line count, etc.
