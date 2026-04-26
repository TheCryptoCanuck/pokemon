# Phase 4 — Best Practices & Standards (Consolidated)

**Review date**: 2026-04-25 evening
**Mode**: strict, security-focus
**Method**: 4A framework idiom review + 4B CI/CD ops review in parallel

## Executive read

Framework health is **excellent** — Material 3 clean, no deprecated APIs, Riverpod patterns correct, resource lifecycle disciplined, dependencies modern with one acceptable stale-but-no-alternative (`tflite_flutter 0.11.0`). 2 High idiom violations carry over from Phase 1: 81 widget-returning helper functions and disabled `prefer_const_*` lints.

CI/CD posture is **far less mature than the vault implies** — and this is the most material drift surfaced this entire review. The vault and Active_Tasks claim OPS-001 closed (`.github/workflows/dogquest-ci.yml` shipped, 5 yml files in `.github/workflows/`), but **disk verification shows `.github/` does not exist in the working tree**. Either the OPS-001 commits are on a branch that isn't checked out, were never pushed, or the vault entry is inaccurate. This needs Jesse-side verification before any reliance on CI. Conversely, `supabase/` directory exists with 4 SQL files (`00_foundation_schema.sql`, `01_social_schema.sql`, `02_social_rls_policies.sql`, `03_rpc_functions.sql`) — partial Supabase IaC is in place. The 4B agent missed this; OPS-M-003 should be downgraded.

## CRITICAL DRIFT — vault vs. disk reality

### DRIFT-1 — `.github/workflows/` does not exist on the current working tree
**Severity**: Critical (vault inaccuracy + ops gap).
- `Active_Tasks.md` reports OPS-001 CLOSED with commits `c949c92` + `d859f81` shipping `dogquest-ci.yml`.
- `Decisions.md` describes 5 yml files in `.github/workflows/` including 3 pre-existing from 2026-03-03.
- **Disk verification (sandbox bash + bash on direct path):** `.github/` directory does not exist anywhere in `dogquest/`. Zero `.yml` files outside `node_modules/`.
- **Possible explanations**: (a) OPS-001 commits on a branch not currently checked out, (b) commits were `git commit`-ed but never `git push`-ed, working tree was cleaned/reset and the in-progress files lost, (c) Active_Tasks is wrong, (d) sandbox virtiofs cache lag (unlikely — the lag pattern is short-window after-write, not 8+ hour stale).
- **Cannot be confirmed from sandbox** — no `.git` directory accessible, can't check branch or log.
- **Action needed from Jesse**: run `git status` and `git log --all --oneline -- .github/` on Windows side. Verify whether the OPS-001 work is recoverable or needs to be redone.

This drift propagates: every Phase 4B finding that assumes CI exists is actually a "needs to be created" item, not a "needs to be improved" item. The 4B effort estimates roughly hold (the YAML still needs to be written) but the framing changes.

### DRIFT-2 — `supabase/` schema directory exists; 4B agent missed it
**Severity**: Low (positive correction).
- 4 SQL files: `00_foundation_schema.sql` (TASK-002+003 — users, dog_profiles, sightings + indexes + RLS), `01_social_schema.sql` (TASK-013-015 — Phase 1 social tables), `02_social_rls_policies.sql` (TASK-016 — RLS), `03_rpc_functions.sql` (TASK-017 — `get_feed`, `get_dogs_nearby`, `get_active_lost_dogs`, `sync_sightings`, `get_leaderboard`).
- 4B's OPS-M-003 ("No infrastructure-as-code for Supabase migrations") is partially wrong. The schema is version-controlled. What's missing is automation (CI applies migrations, dev/staging/prod separation).

### DRIFT-3 — `key.properties` mtime predates OPS-002 closure claim
**Severity**: Medium (verification needed; possibly sandbox cache lag).
- `android/key.properties` mtime is 2026-03-14. OPS-002 closure (per `Decisions.md`) happened 2026-04-25 with the new keystore at `C:\Users\Administrator\dogquest-release.jks`.
- The vault says key.properties was updated to point to the new keystore, but the file mtime suggests it wasn't.
- Could be sandbox virtiofs cache (per Failure_Patterns) — needs Windows-side verification.
- **Action needed from Jesse**: confirm `key.properties` actually points to the new keystore path with the new (weak) password, not the March one.

## Critical findings (excluding drift)

**None new** beyond the carry-forward Phase 1-3 Criticals. Framework idioms are clean.

## High findings

### Framework / Language (3)
- **FW-H-001** — 81 widget-returning helper functions violate CLAUDE.md "no widget-returning functions" rule. Blocks `const` optimization + testability. ~20-30 hr phased; pairs with T5 god-class refactor work.
- **FW-H-002** — `analysis_options.yaml:5-6` disables `prefer_const_constructors` and `prefer_const_literals_to_create_immutables`. Re-enable + `dart fix --apply` + per-line ignores for true positives. 1-2 hr.
- **FW-H-003** — 0 `unawaited()` calls; 1 fire-and-forget at `lib/screens/identify_screen.dart:73` without comment. CLAUDE.md guideline violated. 15 min.

### CI/CD / DevOps (5)
*These all assume the DRIFT-1 worst case — `.github/workflows/` truly empty/missing. If OPS-001 commits exist on a branch, downgrade these by 1 severity tier.*

- **OPS-C-001** — No GitHub Actions CI on working tree. Format/analyze/test/build all manual via Makefile. **3 hr** to write `dogquest-ci.yml`. Critical if drift confirmed; closed if `git checkout` recovers.
- **OPS-C-002** — Weak keystore password (sequential digits). Public Play Store gate. Rotate to 32+ char random + put in GitHub Secrets. 1.5 hr. Hard gate before public launch.
- **OPS-C-003** — No GitHub Secrets wiring for Supabase URL / anon key / Sentry DSN / signing credentials. 1 hr to set up the Secrets in repo settings + reference in workflow.
- **OPS-H-001** — No version automation. `pubspec.yaml` 0.1.0+1 is static; manual edit per release. 2 hr to wire git-tag → version bump → CI release build.
- **OPS-H-002** — No automated Play Store / Console upload pipeline. Signed APK builds locally; upload is manual. 3-4 hr to wire `r0adkll/upload-google-play@v1` (or AAB build + upload action). Public launch hard gate.
- **OPS-H-003** — Branch protection not enforced (already known T1 phone-bound item). 1 hr.
- **OPS-H-004** — `dart pub audit` not in CI (Phase 2 SEC-L-2). 1 hr.
- **OPS-H-005** — No hotfix pathway / runbook. 2-3 hr.

## Medium findings

### Framework (2)
- **FW-M-001** — Dart 3 sealed classes underutilized for state unions (combo, mastery, lost-dog status). 8-10 hr deferred to T5.
- **FW-M-002** — Hand-written `copyWith` correctly used over freezed. **No action** — assessment is positive.

### Ops (3, after DRIFT-2 correction)
- **OPS-M-001** — Pre-commit hook installable but not auto-installed. Document in setup. 30 min.
- **OPS-M-002** — No widget-coverage gate in CI. Pairs with Phase 3 test backlog. 2 hr.
- **OPS-M-003** ~~No Supabase IaC~~ → **PARTIAL** — schema is version-controlled in `supabase/*.sql`. Still missing: CI applies migrations on push, `supabase db pull/push` automation, dev/staging/prod separation. ~2 hr to wire CI; the schema work is already done.
- **OPS-M-004** — No environment separation (dev/staging/prod). Single Firebase project shared with AviQuest (`aviquest-508a6`). 3-4 hr if pursued.

## Low findings

- **OPS-L-001** — No `make doctor` Makefile target (matches Phase 3B DOC-M-Makefile-Setup). 30 min.
- **OPS-L-002** — Makefile `menu` target hardcoded options. 1 hr if pursued.
- **FW-L-***  — Riverpod idioms / Material 3 / deprecated APIs all clean. Credit findings; no action.

## Pubspec health (from 4A)

| Package | Health | Note |
|---------|--------|------|
| flutter_riverpod 2.5 | ✓ Current | Modern, Notifier-based |
| go_router 14 | ✓ Current | Right scale |
| flutter_animate 4.5 | ✓ Current | Maintained |
| camera 0.10.5 | ✓ Current | Identify-critical |
| **tflite_flutter 0.11.0** | ⚠ Stale 2+ yr | No alternative; accept risk; v6 GPU quantization fallback path exists |
| hive_flutter 1.1.0 | ✓ Current | hive_ce community fork preferred per CLAUDE.md but hive_flutter still active |
| image 4.0.17 | ✓ Current | EXIF + preprocessing |
| dio 5.4.0 | ✓ Current | No cert pinning (Phase 2 SEC-M-4) |
| firebase_core 4.5.0 | ✓ Current | Crashlytics + Analytics |
| firebase_crashlytics 5.0.0 | ✓ Current | OBS-001 closed |
| supabase_flutter 2.0.0 | ✓ Current | Auth + RPC + Realtime |
| flutter_lints 3.0.0 | ✓ Current | Recommended baseline |
| All others | ✓ Current | No abandoned packages |

No abandoned. Add `dart pub audit` to CI (OPS-H-004).

## CLAUDE.md compliance (from 4A)

| Rule | Status | Note |
|------|--------|------|
| No native iOS/Android tooling edits w/o permission | ✓ Pass | None detected |
| Don't touch generated files | ✓ Pass | No generated files; build_runner not in use |
| No print, no commented-out code, no orphan TODOs | ⚠ Partial | 1 print in logging service guarded with `// ignore: avoid_print` — acceptable |
| 2-space indent, trailing commas | ✓ Pass | Consistent |
| Null safety | ✓ Pass | Bangs justified, 37 `late final` |
| 81 dispose() calls | ✓ Pass | Lifecycle disciplined |
| `late final` over nullable-then-assigned | ✓ Pass | 37 idiomatic uses |
| No fire-and-forget without `unawaited()` | ✗ Fail (1 instance) | FW-H-003 |
| **No widget-returning functions** | **✗ Fail (81)** | FW-H-001 |
| Dart 3 sealed classes fair game | ⚠ Underutilized | FW-M-001 |
| `prefer_const_constructors` enabled | **✗ Disabled** | FW-H-002 |

2 explicit violations (widget-returning functions, const lint disabled), 2 low-severity gaps, 1 acceptable exception.

## Multi-workflow inventory (under DRIFT-1 uncertainty)

If `.github/workflows/` IS missing (worst case):
| Action | Required |
|--------|----------|
| Create `dogquest-ci.yml` | Yes — ~3 hr |
| Restore/recreate `aviquest-ci.yml` if needed for sibling project | Ask Jesse |
| Determine fate of `flutter-ci.yml`, `infrastructure-ci.yml`, `release.yml` | Ask Jesse — vault says these are 2026-03-03 pre-existing; if so, recover from git history |

If `.github/workflows/` EXISTS on a non-checked-out branch:
| Action | Required |
|--------|----------|
| Verify branch state | Jesse, ~5 min |
| Audit older 3 workflows for overlap | Per OPS-001 closure note in Active_Tasks — still pending |

Either way, **Jesse needs to confirm git state from Windows side** before further CI scheduling.

## Closed-beta launch readiness (revised under DRIFT-1)

| Item | Status | Effort |
|------|--------|--------|
| Local Makefile gates | ✓ Done | 0 |
| GitHub Actions CI | ⚠ **Drift unresolved** | 0 if recovered, 3 hr if redone |
| Branch protection on main | ✗ Missing | 1 hr |
| Signed APK + keystore config | ✓ Done (mtime drift unresolved) | 0 if vault claim is accurate |
| Keystore password rotation | ✗ Missing | 1.5 hr |
| Pre-commit hook | ✓ Available, not auto-installed | 0 if `make hooks-install` runs |
| Play Console internal-test upload | ✗ Missing | 3 hr |
| Hotfix runbook | ✗ Missing | 2-3 hr |
| **Subtotal under worst-case drift** | | **10-12 hr** |
| **Subtotal if drift is recovery-only** | | **5-7 hr** |

## Public-launch readiness (revised)

| Item | Hard gate | Effort |
|------|-----------|--------|
| GitHub Actions CI | YES | 0-3 hr depending on drift |
| Release pipeline (tag → AAB → Play) | YES | 3-4 hr |
| Branch protection | NO | 1 hr |
| Play Console staged rollout config | YES | 1 hr |
| Keystore rotation + GitHub Secrets | YES | 1.5 hr |
| Version bumping automation | YES | 2 hr |
| `dart pub audit` in CI | NO | 1 hr |
| Hotfix runbook | NO | 2-3 hr |
| Supabase IaC migration automation | NO | 2 hr (schema already version-controlled) |
| Env separation dev/staging/prod | NO | 3-4 hr |
| **Hard gates total** | | **8-13 hr** |
| **All items** | | **18-23 hr** |

## What's idiomatic / sound

**Framework**: Riverpod architecture clean (26 providers, no circular deps, `Notifier` correct, `ConsumerWidget` consistent). Resource lifecycle disciplined (81 dispose calls). Null safety rigorous. Material 3 correct, deprecated APIs absent. Service layer clean (Hive isolation, AES sightings encryption). Model immutability via hand-written `copyWith` is the right call at this scale.

**Ops**: Makefile is unusually well-organized (30+ targets, self-documenting, atomic, safe). Android signing config correct (`key.properties` gitignored, absolute path). Firebase wired in Gradle (Crashlytics + Analytics). TFLite model uncompressed in APK. Version pattern (pubspec.yaml + local.properties fallback) is correct — just needs automation.

**Schema**: `supabase/00-03_*.sql` exists in repo. Phase 0 + Phase 1 social schema + RLS + RPCs version-controlled. Bigger ops surface than the 4B agent assumed.

## Carry-forward to Phase 5 (final consolidation)

For the final report:
1. **DRIFT-1 (Critical)** — `.github/workflows/` missing on disk. Either vault claim is wrong, or commits exist on non-checked-out branch. Jesse must verify before scheduling CI work.
2. **DRIFT-3 (Medium)** — `key.properties` mtime predates the OPS-002 keystore claim. Verify file actually references the new keystore.
3. **DRIFT-2 positive** — `supabase/*.sql` schema is version-controlled; 4B agent missed it. Downgrade OPS-M-003 to "needs CI automation only".
4. The pre-public-launch GDPR gate (Phase 2 + Phase 3 Critical) ~12-20 hr.
5. The pre-public-launch ops gate ~8-13 hr (assuming worst-case drift recovery).
6. The widget-test backlog ~25 hr (Phase 3) is the biggest known-correctable gap.

## Recommendations (Phase 5 will reorder)

**Immediate (next 30 min, Jesse-only)**:
- Run `git status` and `git log --all --oneline -- .github/` to resolve DRIFT-1.
- `cat android/key.properties` to verify keystore path matches OPS-002 claim (DRIFT-3).
- Both blocks before any CI scheduling decision.

**Pre-closed-beta**:
- FW-H-002 (re-enable lint rules + sweep): 1-2 hr
- FW-H-003 (`unawaited()` wrap): 15 min
- OPS-C-001 (CI YAML if drift confirmed): 0-3 hr
- OPS-H-003 (branch protection): 1 hr
- Phase 2 quick-win Criticals (stream leaks, dual TFLite, geolocator logging): ~2 hr — already specced

**Pre-public-launch**:
- All Phase 2 GDPR work: 12-20 hr
- All ops hard gates: 8-13 hr
- Widget test backlog: 25 hr (or partial)
- FW-H-001 widget-function refactor: 20-30 hr phased
