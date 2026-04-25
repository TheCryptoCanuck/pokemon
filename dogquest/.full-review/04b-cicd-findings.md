# Phase 4B — CI/CD & DevOps Practices

**Status**: complete. **2 Critical**, 4 High, 5 Medium, 2 Low findings.

## Severity inventory

- **Critical**: 2 | **High**: 4 | **Medium**: 5 | **Low**: 2

---

## Findings

### OPS-001 — No automated CI/CD pipeline
- **Severity**: Critical
- **Operational risk**: All pre-commit gates are manual. No enforcement of `dart format`, `flutter analyze`, or `flutter test` before merge. Formatted code drifts, lints are skipped, test failures land on main. For a closed-beta → public Play Store transition, this is a blocker.
- **Current state**: 
  - `.github/workflows/`, `.gitlab-ci.yml`, `.circleci/` do not exist.
  - GitHub remote is configured (`https://github.com/TheCryptoCanuck/boring.git`), but no Actions workflows are wired.
  - `Makefile` has a `hooks-install` target that generates a pre-commit hook (`dart format --set-exit-if-changed` + `flutter analyze --no-fatal-infos`), but the hook is not installed in the local `.git/hooks/pre-commit` (verified: glob found no pre-commit hook on disk).
  - Pre-commit enforcement is opt-in; no gatekeeper prevents unformatted commits from reaching main.
- **Recommendation**: 
  1. Create `.github/workflows/lint-and-test.yml` (GitHub Actions — zero cost for public repo):
     - Trigger: push to `main`, PRs
     - Steps: `flutter pub get`, `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test`
     - Fail if any step errors. Add branch protection rule: "Require status checks to pass before merging."
  2. Document pre-commit hook setup in `README.md` or a `CONTRIBUTING.md`: `make hooks-install` before first commit.
  3. Estimated effort: 45 min (workflow boilerplate + branch rule config).
- **File(s)**: `.github/workflows/` (create), `Makefile` (already has hooks-install), `pubspec.yaml` (lock the SDK version to match CI environment)

---

### OPS-002 — No signed APK release pipeline
- **Severity**: Critical
- **Operational risk**: Release builds are manual (TASK-049 in Active_Tasks: "Generate release signing key" is still pending). App cannot be published to Play Store without a signed APK. Signing must happen on a secure machine, not ad-hoc. No automated build → sign → artifact-upload flow means each release is a ceremony, prone to key-management errors.
- **Current state**: 
  - `Makefile` has `build-release` target (builds unsigned release APK).
  - `android/app/build.gradle` lines 62–69 define a `signingConfigs.release` block that reads from `android/key.properties` (not in repo, expected to exist locally).
  - `key.properties` is `.gitignore`'d (correct security posture).
  - No `deploy-release` orchestration beyond "install and launch locally" — no cloud signing, no artifact repository, no Play Store integration.
- **Recommendation**: 
  1. Generate signing key (TASK-049): `keytool -genkey -v -keystore dogquest-release.keystore -alias dogquest -keyalg RSA -keysize 2048 -validity 10000` → store in a secure location (e.g., 1Password, encrypted external drive, not Git).
  2. Document key-setup in `CONTRIBUTING.md`: "Place `android/key.properties` locally before running release builds. File should NOT be committed."
  3. In CI, retrieve the signing key from a secret (GitHub Actions: `secrets.SIGNING_KEY_BASE64` → decode and write to disk during the build step).
  4. Add release workflow: `.github/workflows/build-release.yml` (manual trigger or tagged commit). Steps: build with signing config, upload APK to GitHub Releases or internal artifact repository.
  5. Estimated effort: 2–3 hours (key generation, CI secret setup, release-workflow boilerplate).
- **File(s)**: `android/key.properties` (gitignored, local setup), `.github/workflows/build-release.yml` (create), `CONTRIBUTING.md` (document), `Makefile` (possibly add release orchestration target)

---

### OPS-003 — Sentry DSN not wired in CI builds
- **Severity**: High
- **Operational risk**: Crash observability is gated on TASK-050 (still pending). Without Sentry, runtime errors on closed-beta devices go undetected until users report them. App health is opaque. For a pre-launch beta, this is a quality blocker but not a security issue.
- **Current state**: 
  - `lib/main.dart` lines 92–118 read `SENTRY_DSN` from `--dart-define` at build time. If empty (default), Sentry is skipped, and local error handlers are used instead.
  - Local error handlers log to `dart:developer log()` and console, visible only in logcat (device-side logs).
  - TASK-050 lists "Sentry signup → copy DSN → hand to Claude Code for wiring." Status: Active, not done.
- **Recommendation**: 
  1. TASK-050 step 1: Jesse signs up at `sentry.io`, creates a Flutter project, copies the DSN.
  2. Step 2: Store DSN in GitHub Actions secret (`SENTRY_DSN`).
  3. Step 3: Update CI workflow to pass `--dart-define=SENTRY_DSN=${{ secrets.SENTRY_DSN }}` to `flutter build apk`.
  4. Verify: debug build with Sentry wired; trigger a test crash; confirm it lands in Sentry dashboard within 30 seconds.
  5. Estimated effort: 30 min (signup + CI env-var wiring).
- **File(s)**: `lib/main.dart` (already wired, no changes needed), `.github/workflows/build-release.yml` (add SENTRY_DSN env var), Active_Tasks (update TASK-050 status)

---

### OPS-004 — Environment configuration not versioned
- **Severity**: High
- **Operational risk**: Supabase URL, Supabase anon key, and other `--dart-define` values are hardcoded in `lib/main.dart` lines 98–99 with fallback defaults. These defaults are prod environment values. A dev build accidentally built without `--dart-define` overrides will point to production Supabase, risking data pollution. No env-file `.env.example` or documentation on which defines are required.
- **Current state**: 
  - `SUPABASE_URL` and `SUPABASE_ANON_KEY` default to production endpoints in main.dart.
  - `SENTRY_DSN` defaults to empty (graceful).
  - `ENV` defaults to 'development'.
  - No `.env.example`, `.env.local`, or `build/config/` template to guide new setup.
  - CLAUDE.md references `--dart-define` but does not list all required defines or describe dev vs. prod separation.
- **Recommendation**: 
  1. Create `.env.example` (not gitignored; commit to repo):
     ```
     SUPABASE_URL=https://hdcpymjnrbelaawhncep.supabase.co
     SUPABASE_ANON_KEY=sb_publishable_lrICH1RprCBAxgQAs8tg4g_eKAXDme4
     SENTRY_DSN=
     ENV=development
     ```
  2. Create a build-script wrapper: `scripts/build.sh` or `make build-with-env` that reads `.env.local` (gitignored) and passes each as a `--dart-define`.
  3. Add a `CONTRIBUTING.md` section: "Setup: Copy `.env.example` to `.env.local`, edit for your environment, then `make build-with-env`."
  4. In CI, inject env vars as secrets: `--dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }}` etc.
  5. Estimated effort: 1 hour.
- **File(s)**: `.env.example` (create), `scripts/build.sh` or `Makefile` (add build-with-env target), `CONTRIBUTING.md` (document)

---

### OPS-005 — No infrastructure-as-code (Supabase migrations not versioned)
- **Severity**: High
- **Operational risk**: Supabase schema (RLS policies, RPC functions, tables) is not tracked in Git. All configuration happens via the Supabase dashboard. If a developer needs to replicate prod config in a new environment (dev Supabase project, staging, or another team member's account), they must manually re-create tables, RLS policies, and RPC functions by memory. Risk: config drift, accidental schema changes during manual setup, no audit trail.
- **Current state**: 
  - No `supabase/` directory with migration files.
  - `.full-review/02a-security-findings.md` notes: "Supabase API contract (`sync_sightings` RPC + `sightings_own` RLS) undocumented in repo. Exists only in code + Jesse's dashboard."
  - `sync_sightings` RPC and `sightings_own` RLS are defined in Supabase dashboard; not version-controlled.
- **Recommendation**: 
  1. Initialize Supabase CLI locally: `supabase init` (if not already done).
  2. Pull existing schema: `supabase db pull` → generates `supabase/migrations/` SQL files.
  3. Commit migrations to Git. Add a `.supabaserc` config file (in repo, public).
  4. Document schema in repo: `docs/SUPABASE.md` with tables, RLS policies, RPC signatures.
  5. In CI/deploy: use `supabase db push` to apply pending migrations (gated on schema review).
  6. Estimated effort: 1.5 hours (includes schema documentation).
- **File(s)**: `supabase/` (create), `docs/SUPABASE.md` (create), `.supabaserc` (create + commit), `Makefile` (add db-push, db-pull targets)

---

### OPS-006 — Test gates insufficient for closed beta
- **Severity**: Medium
- **Operational risk**: No widget tests or integration tests in CI. Unit tests (530+ test cases across 22 files) pass, but UI regression detection is absent. A breaking layout change, navigation bug, or state-management error would only surface in manual testing, not CI.
- **Current state**: 
  - `test/` has 21 files, all unit tests. No `*_test.dart` files in `lib/widgets/` or `lib/screens/`.
  - Phase 3 testing review flagged: "Widget: 0 widget test files. Critical gap."
  - CLAUDE.md notes: "No widget tests = no UI regression CI gate."
- **Recommendation**: 
  1. For closed beta: require >80% test coverage on critical paths (identify flow, kennel, profile, social feed). Target: 5–10 widget tests per high-value screen.
  2. Add to CI gate: `flutter test --coverage` + enforce coverage threshold (fail if drops below 50%).
  3. Estimated effort: 2–3 days of widget-test writing (not immediately actionable before beta, but track for post-beta hardening).
- **File(s)**: `test/` (add widget tests), `Makefile` (add coverage target), `.github/workflows/lint-and-test.yml` (add coverage gate)

---

### OPS-007 — No performance monitoring in production
- **Severity**: Medium
- **Operational risk**: Firebase Performance Monitoring is not wired. TTA inference latency is estimated at 1.2–1.5s per identification (Phase 2 finding P-H1), but actual on-device frame-time impact is unverified on closed-beta devices. Hypothesis: frame drops during inference could make the UI feel janky. Without telemetry, this feedback loop doesn't close until users report it.
- **Current state**: 
  - `lib/main.dart` initializes Firebase Analytics but not Firebase Performance.
  - `lib/services/analytics_service.dart` logs events to local Hive + Firebase, but no custom performance traces.
  - Phase 2 performance review recommends: "Instrument `identify_screen.dart` capture flow with a frame-time check on a Pixel 5-class device."
- **Recommendation**: 
  1. Add Firebase Performance Monitoring: `firebase_performance: ^0.x` to pubspec.yaml.
  2. Instrument inference: wrap `compute(_runTFLiteInference, ...)` in a Performance trace (`FirebasePerformance.instance.newTrace('tflite_inference')`), log duration and timestamp.
  3. Add frame-time tracking: use `SchedulerBinding.instance.addPostFrameCallback` in identify_screen to log frame-render time.
  4. Dashboard: set alerts if inference latency exceeds 2s (jank threshold).
  5. Estimated effort: 2 hours.
- **File(s)**: `pubspec.yaml`, `lib/services/tflite_identification_service.dart`, `lib/screens/identify_screen.dart`, `lib/main.dart`

---

### OPS-008 — Pre-commit hook not enforced
- **Severity**: Medium
- **Operational risk**: `make hooks-install` is documented and available, but not mandatory. Developers can skip it. Once it's skipped, unformatted code reaches main. The Makefile target exists but has low visibility.
- **Current state**: 
  - `.git/hooks/pre-commit` does not exist on disk (verified by glob).
  - `Makefile` lines 286–307 define `hooks-install`, which creates the hook and makes it executable.
  - No CI enforcement of formatting (see OPS-001).
  - CLAUDE.md CLAUDE.md drift (DOC-001 in Phase 3 review): "Project intelligence drifted; needs reconciliation."
- **Recommendation**: 
  1. Add a pre-commit enforcement check in CI: `dart format --set-exit-if-changed .` as a separate CI step with a clear error message: "Run `make hooks-install` locally to auto-format on commit."
  2. Document in `CONTRIBUTING.md`: "First-time setup: `make hooks-install` to enable local formatting gate."
  3. Optional: Add GitHub's pre-commit framework config (`.pre-commit-config.yaml`) for multi-language projects (not urgent for Dart-only codebase).
  4. Estimated effort: 30 min.
- **File(s)**: `.github/workflows/lint-and-test.yml`, `CONTRIBUTING.md`, `Makefile` (already done; just needs visibility)

---

### OPS-009 — No rollback plan documented
- **Severity**: Medium
- **Operational risk**: If a release-build APK crashes on closed-beta devices (e.g., a regression in Supabase RLS, offline sync, or TFLite preprocessing), there is no documented procedure to roll back. Developers would have to manually re-tag a commit, rebuild, and reinstall. For a small beta, this is low impact, but formalizing a rollback procedure now prevents ad-hoc mistakes later.
- **Current state**: 
  - `Makefile` has no `rollback` target.
  - No documented version pinning strategy or release process.
  - Active_Tasks notes one rollback mechanism: `audit_supplemental.py rollback` (for data audits), but not for app releases.
- **Recommendation**: 
  1. Document in `docs/RELEASE.md`:
     - Version numbering scheme (e.g., semver: `vX.Y.Z`).
     - How to tag a release: `git tag -a vX.Y.Z -m "Release notes"`.
     - How to revert: `git revert HEAD` (if already merged) or `git reset --hard <commit>` (if on a release branch).
     - How to re-release: increment patch version, rebuild, re-tag.
  2. Add Makefile targets: `make release-tag`, `make release-rollback`.
  3. Estimated effort: 1 hour.
- **File(s)**: `docs/RELEASE.md` (create), `Makefile` (add targets)

---

### OPS-010 — ML model versioning not enforced
- **Severity**: Medium
- **Operational risk**: `assets/dog_model.tflite` is a 23.8 MB binary asset with no version metadata embedded. When v6 is released, there is no mechanism to prevent an older build from being distributed, or to ensure users can identify which model version they're running. Training scripts export models with no commit hash or timestamp embedded.
- **Current state**: 
  - Model is built by `train_model_v6.py` and exported to `assets/dog_model.tflite`.
  - No version file, no metadata JSON alongside the model.
  - `Makefile` target `model-info` (lines 187–209) reads file size and label count, but not model version.
  - CLAUDE.md drift: the field "deployed vs. training models" is inconsistently documented (150 / 294 / 296 breeds across the file — Phase 3 finding DOC-001).
- **Recommendation**: 
  1. Create a model-metadata JSON file alongside the TFLite binary: `assets/dog_model.json` with fields: `version`, `train_date`, `git_commit`, `accuracy_val`, `breeds_count`, `input_size`.
  2. Embed metadata in the app: read `dog_model.json` on startup, expose via a "Model Info" settings screen.
  3. Log model version at startup: `_log.info('Loaded model v${modelVersion}')`.
  4. CI: after training, auto-generate the metadata JSON and commit alongside the model.
  5. Estimated effort: 1.5 hours.
- **File(s)**: `assets/dog_model.json` (create), `lib/services/tflite_identification_service.dart` (add metadata loading), `train_model_v6.py` (add metadata generation), `Makefile` (update model-info target)

---

### OPS-011 — No incident response protocol
- **Severity**: Low
- **Operational risk**: If a production issue surfaces during closed beta (e.g., sighting sync fails, offline mode breaks), there is no documented procedure for triage, communication, or remediation. For a 5–10 person beta, this is low-risk, but formalizing now prevents chaos when the user base grows.
- **Current state**: 
  - No `docs/INCIDENT_RESPONSE.md`.
  - Active_Tasks captures planned work but not incident response.
  - `.second_brain/03_Projects/Active_Tasks.md` notes "Failure Risks" but they are not structured as runbooks.
- **Recommendation**: 
  1. Create `docs/INCIDENT_RESPONSE.md`:
     - Severity levels: Critical (app crash on all devices), High (feature broken for >50% of users), Medium (edge-case issue), Low (cosmetic).
     - Triage: check Sentry for crashes, Supabase logs for RPC failures, logcat for device errors.
     - Escalation: Jesse (project lead) is the incident commander.
     - Communication: Slack / email to closed-beta group within 15 min of discovery.
     - Fix flow: develop on a branch, test locally, deploy hotfix build, coordinate with beta testers.
  2. Add a `Makefile` target: `make incident-logs` (aggregate Sentry + Supabase + local logs).
  3. Estimated effort: 1 hour.
- **File(s)**: `docs/INCIDENT_RESPONSE.md` (create), `Makefile` (add incident-logs target)

---

### OPS-012 — Build cache not optimized for Gradle
- **Severity**: Low
- **Operational risk**: CI builds run `flutter clean && flutter pub get` on every run. Gradle dependency cache is not persisted across CI jobs. For a large monorepo, this adds 2–5 min overhead per build. Currently acceptable, but a bottleneck if CI runs scale (e.g., per-PR builds + nightly regression tests).
- **Current state**: 
  - Makefile `clean` target: `flutter clean && flutter pub get` (lines 36–37).
  - CI workflow (to be created) will likely invoke `clean` before each build.
  - No `.gradle/wrapper/`, `.dart_tool/` caching documented.
- **Recommendation**: 
  1. In CI workflow (`.github/workflows/lint-and-test.yml`), add caching steps:
     ```yaml
     - uses: actions/cache@v3
       with:
         path: |
           ${{ runner.tool_cache }}/flutter/bin
           ~/.gradle/wrapper
           .dart_tool/
         key: ${{ runner.os }}-flutter-${{ hashFiles('pubspec.lock') }}
     ```
  2. Skip `flutter clean` in CI; instead, rely on pubspec.lock exactness.
  3. Estimated effort: 30 min.
- **File(s)**: `.github/workflows/lint-and-test.yml` (when created)

---

## Pipeline maturity assessment

| Dimension | Maturity | Status |
|---|---|---|
| **CI** | None | No automated build/test/lint pipeline. All gates are manual (Makefile targets exist but are not enforced). |
| **CD** | None | No release build pipeline. Signed APK generation is manual. No artifact storage, Play Store integration, or deployment orchestration. |
| **Monitoring** | Partial | Firebase Analytics wired (telemetry events in `dog_found_dialog.dart`). Sentry wired but not configured (DSN empty). Frame-time profiling absent. |
| **Incident Response** | None | No documented runbooks, triage procedures, or communication protocol. Relies on ad-hoc Slack/email. |

---

## Phase 5 hand-off

1. **OPS-001 + OPS-002**: Create GitHub Actions workflows immediately before closed-beta release. These are the blocking-path items.
2. **OPS-003**: TASK-050 (Sentry DSN) is already in Active_Tasks; track to completion.
3. **OPS-004**: Environment config templating should land alongside OPS-001 (1-hour add-on).
4. **OPS-005**: Supabase migrations are good-to-have but not beta-blockers. Schedule for week 1 of post-beta polish.
5. **OPS-006 + OPS-007**: Performance monitoring and widget tests are quality levelers — post-beta priorities.
6. **OPS-008 through OPS-012**: Documentation and optimization — schedule after MVP stability is confirmed.

---

## Key dependencies (for sequence planning)

- **OPS-001 gates OPS-002, OPS-003, OPS-004**: CI pipeline must exist before integrating signing keys and secrets.
- **TASK-050 (Sentry DSN) gates OPS-003**: Jesse must complete Sentry signup first.
- **OPS-005 (Supabase migrations) is independent**: Can run in parallel with other work.
- **OPS-006 + OPS-007 are post-beta**: Don't start until closed-beta stability feedback arrives.
