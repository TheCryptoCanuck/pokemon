# Phase 4: Best Practices & Standards

## Framework & Language Findings (4A)

Detail: `04a-framework-findings.md`. 9 findings — 0 Critical, 1 High, 6 Medium, 2 Low.

### Highlights

- **FW-001 (High)**: Dual TFLite model loads at startup. `tflite_identification_service` and `dog_embedding_service` each load the same 23.8 MB model independently. 0.5–1.0 s startup waste. Lazy-load fix: 30–45 min.
- **FW-002 (Medium)**: Riverpod code-gen adoption sparse — 2 of 50+ services use `@riverpod` annotations.
- **FW-003 (Medium)**: Python ML scripts lack type hints. `train_model_v6.py`, `export_tflite.py` zero PEP-484 annotations.
- **FW-004 (Medium)**: Material 3 theming incomplete. `useMaterial3: true` but hard-coded `Colors.green/.amber/.red` persist.
- **FW-006 (Medium)**: AutoDispose pattern underutilized — 2 of 50+ providers.

### Modernization scores (4A's assessment)

| Category | Score |
|---|---|
| Flutter 3.41 compliance | 9/10 |
| Dart 3 adoption | 8/10 |
| Riverpod modernization | 6/10 |
| go_router patterns | 9/10 |
| Async / null-safety | 8/10 |
| Package management | 8/10 |
| Python ML scripts | 5/10 |
| Android build config | 9/10 |

## CI/CD & DevOps Findings (4B)

Detail: `04b-cicd-findings.md`. 12 findings — 2 Critical, 4 High, 5 Medium, 2 Low.

### Highlights

- **OPS-001 (Critical)**: No GitHub Actions or any CI/CD pipeline. All quality gates are manual (Makefile targets exist but unenforced). Branch protection absent.
- **OPS-002 (Critical)**: Release signing is entirely manual. TASK-049 (signing key generation) still pending. No artifact repository or Play Store integration.
- **OPS-003 (High)**: Sentry wired in code but DSN empty. TASK-050 still open. Crash observability is offline.
- **OPS-004 (High)**: Environment config hardcoded as defaults in `lib/main.dart`. No `.env.example`. Dev builds risk hitting production.
- **OPS-005 (High)**: Supabase schema (RLS, RPC) not version-controlled. All config lives in the dashboard.
- **OPS-006 (Medium)**: Widget tests absent (0 files). CI can only gate unit tests. (Echoes 3A TEST-002.)
- **OPS-007 (Medium)**: Firebase Performance Monitoring not wired. TTA inference latency (1.2–1.5 s) unverified on real devices.

### Pipeline maturity

- CI: **none**
- CD: **none**
- Monitoring: **partial** (Firebase Analytics + Sentry stub; performance monitoring missing)
- Incident response: **none** (no runbooks, no rollback plan formalized)

## Critical Issues for Phase 5 Final Report

- **OPS-001 + OPS-002 are the closed-beta blockers from a DevOps lens.** Without a signing pipeline, no APK can be distributed. Without CI, no quality gate enforces the testing/lint/format standards.
- **OPS-003 (Sentry DSN) closes when Jesse signs up.** TASK-050. ~30 min.
- **OPS-005 (Supabase IaC) is a recurring tax** — every schema change has to be remembered + reapplied manually. Move `supabase/` into version control.
- **FW-001 (dual TFLite load) is a 30-min win** with measurable user-facing payoff (faster cold start).
