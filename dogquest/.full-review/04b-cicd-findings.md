# Phase 4B — CI/CD & DevOps Findings

**Review date**: 2026-04-25 evening  
**Scope**: GitHub Actions, build pipeline, deployment strategy, security in CI, operational readiness  
**Baseline**: Makefile-driven local dev; Android signing wired; no GitHub Actions workflows yet deployed

## Posture

DogQuest's CI/CD infrastructure is **foundational but incomplete**. Local build/test/deploy is well-structured (Makefile 30+ targets, format/analyze/test gates, signed APK builds), and critical components are in place: signing keystore configured (`key.properties` gitignored, passwords sequential-weak), Firebase Crashlytics wired in Gradle, version management via `pubspec.yaml` and `local.properties`. However, **no GitHub Actions workflows exist in `.github/workflows/` yet** — the 5 YAML files referenced in scope (dogquest-ci.yml, aviquest-ci.yml, flutter-ci.yml, infrastructure-ci.yml, release.yml) are planned but not implemented. For closed-beta launch, this means manual per-commit testing on a developer machine. For public Play Store, automated CI and a staged rollout pipeline are hard requirements. Branch protection is not yet enabled (T1 item per Phase 3B). Supabase and Firebase secrets are not yet managed in GitHub Secrets. The dual-APK signing (debug via gradle, release via keystore) is correct, but APK versioning (v0.1.0+1 in pubspec) is not automated on release tags. **No rollback procedure, no hotfix pathway for closed beta, no staged rollout configuration in Play Console.** Operationally sound for solo dev on a pinned device; not production-ready.

## Findings

### Critical

#### OPS-C-001 — No GitHub Actions CI/CD pipeline exists
**Severity**: Critical (manual per-commit testing only; no gating).  
**Operational risk**: Each code change requires developer to run `make check` locally (no CI enforcement). Type-squatting or analysis bypass possible. No automated test failure block before push.  
**Locations**: `.github/workflows/` (empty directory exists, no YAML files).  
**Current state**:
- Scope document mentions 5 planned workflows (dogquest-ci.yml, aviquest-ci.yml, flutter-ci.yml, infrastructure-ci.yml, release.yml)
- `.github/workflows/` directory present but empty
- Local Makefile has `check` target (lint + analyze + test), but it's not wired to git hooks by default (`hooks-install` is manual)

**Recommendation**:
1. Create `.github/workflows/dogquest-ci.yml` with 4 jobs (format, analyze, test, build-debug-apk) triggered on `push` to main and PRs
2. Format job: `dart format --set-exit-if-changed` (FAIL if unformatted)
3. Analyze job: `flutter analyze` (FAIL if errors or infos)
4. Test job: `flutter test` (can be `continue-on-error: true` until Phase 5 test backlog is closed per scope notes, then switch to required)
5. Build job: `flutter build apk --debug` (verify APK builds without error)
6. Shared setup: `subosito/flutter-action@v2` with Flutter stable, Java 17, working-directory `./dogquest`
7. Delete the 3 pre-existing workflows (flutter-ci.yml, infrastructure-ci.yml, release.yml from 2026-03-03) unless they have active purpose outside dogquest scope — ask Jesse
8. For aviquest-ci.yml: determine if it should run on the parent AviQuest repo or be deleted; if parent-repo only, add `.gitignore` to exclude dogquest or re-scope

**Effort**: 3 hr (CI YAML setup, testing trigger, matrix optimization if needed).

---

#### OPS-C-002 — Weak keystore password (sequential digits, 123456789101112131)
**Severity**: Critical (pre-public-launch security gate).  
**Operational risk**: Release signing key compromise if keystore stolen or password brute-forced. Google Play Store DSA could be revoked if attacker pushes malicious APK update. Play Store policy violation (security standards).  
**Locations**: `android/key.properties:1-2` (both `storePassword` and `keyPassword` use same weak value).  
**Current state**:
- Keystore file: `C:\Users\Administrator\dogquest-release.jks` (out of repo, gitignored)
- Passwords: sequential digits, ~15 chars but pattern-weak
- No password rotation documented
- File is local dev machine only (risk if machine compromised)

**Recommendation**:
1. **Closed-beta launch**: Rotate keystore password to 32+ random alphanumeric + symbols: `openssl rand -base64 32` → store in 1Password or GitHub Secrets as `KEYSTORE_PASSWORD` and `KEY_PASSWORD`
2. **CI/CD integration**: Update `android/key.properties` to read from environment variables at build time (use GitHub Secrets `KEYSTORE_PASSWORD`, `KEY_PASSWORD`, `KEYSTORE_B64` for base64-encoded keystore file)
3. Add keystore to GitHub Secrets as `DOGQUEST_KEYSTORE_B64` (base64 of .jks file); download at build time in CI
4. Document in Makefile `make wire-sentry` pattern: `wire-release KEYSTORE_PASSWORD=... KEY_PASSWORD=...` for local release builds
5. **Before public Play Store**: Verify Play Console signing certificate matches; consider moving keystore to a hardware security key or managed service (Play Console signing key management for automated updates post-launch)

**Effort**: 1.5 hr (password rotation, env var wiring in Gradle + GitHub Secrets, docs).

---

#### OPS-C-003 — No secrets management in GitHub Actions yet wired
**Severity**: Critical (Supabase keys, Firebase project ID will be needed for CI; hardcoding exposure risk).  
**Operational risk**: Database credentials, analytics keys, Sentry DSN exposed in CI logs or repo. Attacker could use credentials to exfil data or poison backend state.  
**Locations**: `lib/main.dart:100-103` (hardcoded Supabase URL + anon key per Phase 2 SEC-H-1); no CI environment variables used yet.  
**Current state**:
- `firebase_core` and `firebase_analytics` require `google-services.json` (currently auto-downloaded by Gradle plugin)
- Supabase init at `lib/main.dart` uses hardcoded URL + anon key (Phase 2 flagged as High — should be empty defaults + assert)
- Sentry DSN wired via `--dart-define=SENTRY_DSN=` per Makefile `wire-sentry` target (manual, not in CI)

**Recommendation**:
1. Add GitHub Secrets to the repo (Settings → Secrets and variables → Actions):
   - `SUPABASE_URL` (empty for CI tests; or use test project)
   - `SUPABASE_ANON_KEY` (ditto)
   - `SENTRY_DSN` (obtain from sentry.io)
   - `KEYSTORE_PASSWORD`, `KEY_PASSWORD`, `DOGQUEST_KEYSTORE_B64` (from OPS-C-002)
2. Update dogquest-ci.yml to inject Supabase and Sentry via `--dart-define` flags on the build job (test job runs without, or uses empty/test values)
3. Phase 2 follow-up: fix `lib/main.dart:100-103` to use empty defaults + startup assert instead of hardcoding
4. Add a `.github/SECURITY.md` noting "no secrets in PRs; all sensitive config via GitHub Secrets"

**Effort**: 1 hr (YAML env vars, Secrets setup, docs).

---

### High

#### OPS-H-001 — No versioning automation (APK version bumps are manual)
**Severity**: High (closed-beta launch defeatable; public launch blocker).  
**Operational risk**: `pubspec.yaml` version is static (0.1.0+1). Each release requires manual edit + commit; no automated tag → version bump pipeline. Risk: operator error (forgot to bump build number), inconsistent versioning, no rollback anchoring to git tags.  
**Locations**: `pubspec.yaml:3` (version: 0.1.0+1), `android/app/build.gradle:25-32` (versionCode/versionName from local.properties fallback).  
**Current state**:
- `local.properties` is gitignored; dev machines set `flutter.versionCode` / `flutter.versionName` locally
- CI will inherit default "1" / "1.0" if not supplied
- No Git tag → version map

**Recommendation**:
1. Wire version bumping to Git tags: on `push` tag `v0.1.0`, automatically update `pubspec.yaml` and create release APK
2. Use a CI action like `actions/create-release@v1` or `git-tag-release` to:
   - Parse tag (v0.1.0) → extract version
   - Run `flutter pub version 0.1.0` (or manual sed on pubspec.yaml)
   - Build signed APK with `versionName=0.1.0`, `versionCode=<build_number>`
   - Attach APK to GitHub Release
3. Closed-beta: adopt semantic versioning scheme (v0.1.0 → v0.2.0 for internal build, v0.1.0-beta.1 for closed-beta releases to Play Console)
4. Document in docs/SETUP.md: "Releases: tag `git tag -a v0.1.0 -m 'Release 0.1.0'` → `git push origin v0.1.0` → CI builds + uploads to Play Console internal track"

**Effort**: 2 hr (version bump action, tag-triggered workflow, docs).

---

#### OPS-H-002 — No automated Play Store upload pipeline
**Severity**: High (closed-beta defeatable; public launch blocker for scaled rollout).  
**Operational risk**: Signed APK built locally; upload to Play Console is manual adb/web step. Risk: forgot to upload, or uploaded wrong build (debug vs. release). No internal-test track progression or staged rollout for closed beta.  
**Locations**: No CI job for Play Store upload; Makefile `deploy-release` only builds local APK.  
**Current state**:
- Release APK signing via `android/app/build.gradle:63-80` is correct
- No Play Console API integration
- OPS-002 closure (keystore wired) enables signing; Play upload not yet wired

**Recommendation**:
1. Add `.github/workflows/release.yml` job triggered by `push` tag `v*`:
   - Build signed release APK (using secrets from OPS-C-002)
   - Use `r0adkll/upload-google-play@v1` action to upload AAB to Play Console internal test track
   - Or: build AAB instead of APK (Android App Bundle required for Play Store anyway for new apps as of Aug 2021)
2. Create AAB build job: `flutter build appbundle --release` (requires Gradle + signing config)
3. Wire Play Console credentials: `PLAY_CONSOLE_SERVICE_ACCOUNT_JSON` (base64-encoded JSON from Google Cloud)
4. Gate rollout: upload to internal-test first (manual Play Console %–rollout to closed-beta users, then wider)
5. Document: "Closed-beta users receive via internal-test track; public launch uses staged rollout (1%, 5%, 10%, 50%, 100%)"

**Effort**: 3-4 hr (AAB build, Play Store action, Play Console setup, docs).

---

#### OPS-H-003 — No branch protection enforced on main
**Severity**: High (T1 phone-bound item; pre-closed-beta blocker).  
**Operational risk**: Force-push to main, merge without CI gates, accidental deletion. For a solo dev, risk is low but discipline matters for team readiness and audit trail.  
**Locations**: GitHub repo Settings → Branch protection (disabled).  
**Recommendation**:
1. Enable branch protection on `main`:
   - Require status checks to pass before merge: dogquest-ci (format, analyze, test, build jobs)
   - Require PR reviews: 0 for solo dev; 1 for future team
   - Require branches to be up to date before merging (auto-dismiss stale reviews)
   - Restrict push to admins only (prevent force-push unless explicit)
2. Create `.github/pull_request_template.md`:
   ```
   ## Description
   [what changed]
   
   ## Checklist
   - [ ] Local `make check` passed (format + analyze + test)
   - [ ] New tests added for logic changes
   - [ ] No hardcoded secrets or PII
   - [ ] Reviewed Phase 2 security findings if touching auth/sighting/lost_dog
   
   ## Testing
   [devices tested, manual steps]
   ```

**Effort**: 1 hr (GitHub settings, PR template).

---

#### OPS-H-004 — No `dart pub audit` in CI/CD (SEC-L-2 from Phase 2)
**Severity**: High (dependency CVE screening missing).  
**Operational risk**: Vulnerable transitive dependencies shipped in APK. No detection until manual audit or Dependabot scan (GitHub default, but not enforced).  
**Locations**: dogquest-ci.yml (to be created); no `dart pub audit` job.  
**Current state**:
- pubspec.yaml lists 24 top-level deps, all recent and verified-publisher (Phase 2 audit)
- No `dart pub audit` runs on push
- Dependabot not enabled (GitHub native supply-chain scanning)

**Recommendation**:
1. Add job to dogquest-ci.yml:
   ```yaml
   security:
     runs-on: ubuntu-latest
     steps:
       - uses: actions/checkout@v4
       - uses: subosito/flutter-action@v2
         with:
           flutter-version: stable
       - run: dart pub audit
   ```
2. Enable GitHub Dependabot (Settings → Code security → Dependabot → Enable):
   - `dependabot.yml` configured to check pubspec.yaml weekly
   - Auto-create PRs for updates with security fixes
3. Set CI to fail on `dart pub audit` critical findings; warn on medium

**Effort**: 1 hr (audit job, Dependabot config).

---

#### OPS-H-005 — No hotfix pathway for closed beta (multi-branch CI strategy missing)
**Severity**: High (closed-beta defect requires manual revert/reapply cycle).  
**Operational risk**: If a critical issue lands post-beta-build, revert requires manual coordination; no easy way to cherry-pick fix to release branch without rebuilding entire main.  
**Locations**: GitHub Actions triggers (on: push, on: pull_request) — no branch-specific logic.  
**Current state**:
- Single main branch
- Phase 3B notes "no runbook" for post-incident procedures
- Makefile has no revert automation

**Recommendation**:
1. Create a branching strategy once public launch is imminent:
   - `main` — active development
   - `release/*` — closed-beta / public builds (tag-based: v0.1.0-beta.1, v0.1.0-rc.1)
   - Hotfix: `hotfix/issue-description` → merge to release/* → cherry-pick to main
2. Add CI logic: on PR to `release/*`, trigger `test` + `build-release-apk` + gate before merge
3. Document in docs/OPERATIONS.md:
   ```
   Hotfix procedure:
   1. git checkout -b hotfix/critical-xyz release/0.1.0-beta.1
   2. [fix]
   3. git push → wait for CI to pass
   4. gh pr create --base release/0.1.0-beta.1 → merge
   5. git checkout main && git cherry-pick hotfix/critical-xyz
   6. Tag new build: git tag -a v0.1.0-beta.2 -m "Hotfix: ..."
   ```

**Effort**: 2-3 hr (branch strategy docs, CI multi-branch logic, runbook).

---

### Medium

#### OPS-M-001 — No pre-commit hook installed by default (local developer friction)
**Severity**: Medium (developer can bypass checks with `git commit --no-verify`).  
**Operational risk**: Unformatted or unanalyzed code merges; CI catches it, but wastes time.  
**Locations**: `Makefile:286-307` defines `hooks-install` target; not run automatically on `flutter pub get`.  
**Recommendation**:
1. Add post-setup hook: In `.github/workflows/dogquest-ci.yml` or docs/SETUP.md, document:
   ```bash
   git clone ... && cd dogquest
   flutter pub get
   make hooks-install  # Install pre-commit checks
   ```
2. Or: wire `postinstall` in pubspec.yaml to run `make hooks-install` (Dart 3.0+, experimental)
3. Add to Makefile `check` target: also run pre-commit hook manually if not installed

**Effort**: 30 min (hook wiring, setup docs).

---

#### OPS-M-002 — No widget test coverage gate in CI
**Severity**: Medium (Phase 3A flagged 0 widget tests across 34 screens; CI doesn't enforce).  
**Operational risk**: New screens shipped with zero UI tests. Risk is partially mitigated by code review, but systematic.  
**Locations**: dogquest-ci.yml test job (when created); no coverage threshold.  
**Recommendation**:
1. Set a minimum coverage threshold for CI: `flutter test --coverage`
2. Use `lcov` + `codecov-action@v4` to report coverage percentage
3. Gate: fail if coverage drops below current baseline (currently 0.04% per Phase 2; Phase 3 recommends 25 hr of backlog work)
4. For closed-beta: warn if new files have <50% coverage; fail on critical paths (auth, lost_dog, social)

**Effort**: 2 hr (coverage integration, threshold tuning).

---

#### OPS-M-003 — No infrastructure-as-code for Supabase migrations
**Severity**: Medium (Supabase schema not version-controlled in repo).  
**Operational risk**: Schema drift between local dev and production. RLS policies documented only in vault; no deploy automation.  
**Locations**: No `supabase/` or `migrations/` directory in repo.  
**Current state**:
- Phase 2 flagged SEC-M-3: RLS policies on `lost_dog_reports`, `lost_dog_sightings`, `friendships`, `packs` not audited
- Phase 3B noted: "Supabase API contract undocumented"
- Backend is planned but not yet deployed

**Recommendation**:
1. Create `supabase/migrations/` directory in repo:
   - SQL files for each migration (001_init_schema.sql, 002_rls_policies.sql, etc.)
   - Timestamped or sequential numbering
2. Wire Supabase CLI (`supabase db pull` / `supabase db push`) to CI:
   - On PR: `supabase db test` (run migrations against test database, verify schema)
   - On `main`: `supabase db push` (apply to staging, then manual Play Console deploy for prod)
3. Document in docs/SETUP.md: "Supabase local dev: `supabase start`, `supabase db reset`"

**Effort**: 2-3 hr (schema extraction, migration template, CLI wiring).

---

#### OPS-M-004 — No environment separation (dev, staging, prod)
**Severity**: Medium (single Firebase project, single Supabase instance planned).  
**Operational risk**: Closed-beta tests affect production data; production fixes can't be tested without risking beta data.  
**Locations**: `lib/main.dart` hardcoded Supabase URL + Firebase project ID (aviquest-508a6).  
**Current state**:
- Firebase project is shared with AviQuest (aviquest-508a6)
- Phase 2 flagged SEC-H-1: hardcoded project URL discloses instance
- No env-specific build flavors

**Recommendation**:
1. Create build flavors for Flutter (dev, staging, prod):
   - `flutter run -t lib/main_dev.dart` → Firebase dev project, Supabase dev instance
   - `flutter run -t lib/main_staging.dart` → Firebase staging, Supabase staging
   - `flutter run -t lib/main_prod.dart` → Firebase prod, Supabase prod (closed-beta release track)
2. Wire in CI:
   - PR / main branch: build with `-t lib/main_staging.dart`
   - Release tag: build with `-t lib/main_prod.dart`
3. Add to Gradle: productFlavors (dev, staging, prod) with different app IDs (com.dogquest.app.dev, etc.) so multiple flavors can coexist on device
4. Docs: "Local dev: `flutter run -t lib/main_dev.dart`; staging tests: `flutter run -t lib/main_staging.dart`"

**Effort**: 3-4 hr (flavor setup, Gradle config, Firebase/Supabase project creation, CI wiring).

---

### Low

#### OPS-L-001 — No Makefile `doctor` target (Phase 3B noted as missing)
**Severity**: Low (developer convenience; not a blocker).  
**Operational risk**: New developer doesn't know if their environment is correctly set up.  
**Locations**: Makefile, no `doctor` target.  
**Recommendation**:
```makefile
doctor: ## Check local dev environment
	@echo "── Flutter ──"
	flutter doctor -v
	@echo ""
	@echo "── Dart ──"
	dart --version
	@echo ""
	@echo "── Android SDK ──"
	which adb
	@echo ""
	@echo "── Git hooks ──"
	if [ -x "$(GIT_DIR)/hooks/pre-commit" ]; then echo "✓ Pre-commit hook installed"; else echo "✗ Run: make hooks-install"; fi
```

**Effort**: 30 min.

---

#### OPS-L-002 — Makefile `menu` target hardcoded options (could be dynamic)
**Severity**: Low (documentation could auto-generate from Makefile targets).  
**Operational risk**: Menu options drift from actual targets.  
**Recommendation**: Document but deprioritize. Makefile `help` already works well; `menu` is convenience.  
**Effort**: 1 hr (optional).

---

## Multi-workflow inventory

The scope document mentions **5 workflows** (dogquest-ci.yml, aviquest-ci.yml, flutter-ci.yml, infrastructure-ci.yml, release.yml). Currently **zero exist in repo**; `.github/workflows/` is empty.

**What needs to be created**:

| File | Purpose | Recommended status | Action |
|------|---------|-------------------|--------|
| `dogquest-ci.yml` | DogQuest CI: format/analyze/test/build on push + PR | **MUST CREATE** | New 4-job pipeline (OPS-C-001) |
| `aviquest-ci.yml` | AviQuest CI (parent project) | **DELETE or clarify scope** | Ask Jesse: is this a sibling project in same repo? If yes, update trigger paths; if separate repo, delete |
| `flutter-ci.yml` | Generic Flutter CI (2026-03-03) | **DELETE** | Old, pre-dogquest fork; overlap with dogquest-ci.yml |
| `infrastructure-ci.yml` | Infra tests (2026-03-03) | **DELETE** | Old, pre-dogquest; unclear purpose (Supabase? backend?); if Supabase migrations exist, this belongs in dogquest-ci.yml |
| `release.yml` | Release pipeline (2026-03-03) | **REPLACE with dogquest release pipeline** | OPS-H-002: new release.yml with Play Store upload + versioning |

**Recommendation**: Create dogquest-ci.yml and release.yml (per OPS-C-001 and OPS-H-002); delete the 3 pre-existing 2026-03-03 workflows unless they serve the parent AviQuest repo (in which case move them and update path filters).

---

## Closed-beta launch readiness

| Item | Status | Effort | Notes |
|------|--------|--------|-------|
| Local Makefile gates (format/analyze/test/build) | **Done** | 0 | `make check` works |
| GitHub Actions CI pipeline | **Missing** | 3 hr | OPS-C-001 |
| Branch protection on main | **Missing** | 1 hr | OPS-H-003 |
| Signed APK + keystore config | **Done** | 0 | OPS-002 closed 2026-04-25 |
| Keystore password rotation | **Missing** | 1.5 hr | OPS-C-002 |
| Pre-commit hook (optional, installed manually) | **Done** | 0 | `make hooks-install` available |
| Play Console internal-test track upload | **Missing** | 3 hr | OPS-H-002 |
| Hotfix runbook for beta defects | **Missing** | 2-3 hr | OPS-H-005 |
| **Subtotal for closed-beta launch** | | **10-12 hr** | Focus: OPS-C-001, OPS-H-003, keystore rotate, Play upload |

For **closed-beta launch only** (internal testing via Play Console internal-test track or side-load), the minimum viable set is:
1. GitHub Actions dogquest-ci.yml (prevents obvious compile/analyze errors) — **OPS-C-001**
2. Rotated keystore password — **OPS-C-002**
3. Play Console internal-test upload — **OPS-H-002** (or skip if side-loading to single device)
4. Branch protection — **OPS-H-003** (hygiene; optional for solo dev on single machine)

**Realistic 2-day closure for closed-beta**: OPS-C-001 + OPS-C-002 + OPS-H-002 = 7-8 hr of work. **OPS-H-003** (branch protection) is 1 hr and highly recommended.

---

## Public-launch readiness

| Item | Status | Effort | Hard gate? | Notes |
|------|--------|--------|-----------|-------|
| GitHub Actions CI pipeline | Missing | 3 hr | **YES** | OPS-C-001 |
| Release pipeline (tag → APK/AAB → Play Store) | Missing | 3-4 hr | **YES** | OPS-H-002 |
| Branch protection + PR template | Missing | 1 hr | NO | OPS-H-003 (hygiene) |
| Play Console internal-track → staged rollout setup | Missing | 1 hr | **YES** | Rollout % config in Play Console (manual, not CI) |
| Keystore rotation + secret management | Missing | 1.5 hr | **YES** | OPS-C-002, OPS-C-003 |
| Version bumping automation | Missing | 2 hr | **YES** | OPS-H-001 |
| `dart pub audit` in CI | Missing | 1 hr | NO | OPS-H-004 (security best practice) |
| Hotfix pathway & runbook | Missing | 2-3 hr | NO | OPS-H-005 (operational readiness) |
| Supabase IaC (migrations) | Missing | 2-3 hr | NO | OPS-M-003 (if backend goes live) |
| Environment separation (dev/staging/prod) | Missing | 3-4 hr | NO | OPS-M-004 (quality best practice) |
| Makefile doctor target | Missing | 30 min | NO | OPS-L-001 (convenience) |
| **Subtotal for public launch** | | **20-25 hr** | | **Hard gates: 10-11 hr** (C1, C2, H1, H2, C3 secrets) |

**Pre-public-launch critical path**: OPS-C-001 (CI) + OPS-C-002 (keystore) + OPS-C-003 (secrets) + OPS-H-001 (versioning) + OPS-H-002 (Play upload) = ~10-11 hr. All other items (branch protection, hotfix runbook, Supabase IaC, env separation) are **recommended but deferrable** to post-launch T2 work.

---

## What's operationally sound

**Strengths**:
- **Makefile discipline**: 30+ well-named targets, self-documenting via `make help`, interactive `make menu`, pre-commit hook available. Pattern: each target is atomic, testable independently, and safe (no destructive ops without confirmation).
- **Local signing**: Android signing config correctly reads from `key.properties` (gitignored), `storeFile` path is absolute, Gradle recipe (Firebase + Crashlytics plugins) is modern. APK build process is sound.
- **Firebase wiring**: Crashlytics integrated into Gradle plugin (com.google.firebase.crashlytics), OPS-002 confirmed on-device verification pending (T1 phone-bound). Analytics auto-collected on app lifecycle.
- **Model file protection**: `aaptOptions { noCompress 'tflite' }` ensures TFLite model is not compressed in APK (correct for uint8-quantized inference).
- **Version management**: `pubspec.yaml` version (0.1.0+1) and `local.properties` fallback (versionCode/versionName) is correct pattern; just needs automation (OPS-H-001).

**Clean local-dev UX**: `make build`, `make deploy`, `make test`, `make logs` is a solid developer experience. Removing friction (e.g., mandatory `hooks-install`, playbook docs) is secondary to getting CI wired.

---

## Recommendations for next session

1. **Immediate (before closed-beta sign-off)**: Implement OPS-C-001 (GitHub Actions), OPS-C-002 (keystore rotation), OPS-H-002 (Play Console upload) — 7 hr critical path
2. **Strongly recommended**: OPS-H-003 (branch protection) — 1 hr; OPS-H-004 (dart pub audit) — 1 hr
3. **Before public Play Store**: Add OPS-H-001 (versioning automation) — 2 hr
4. **Post-launch nice-to-haves**: OPS-M-004 (env separation), OPS-M-003 (Supabase IaC), OPS-H-005 (hotfix runbook)

