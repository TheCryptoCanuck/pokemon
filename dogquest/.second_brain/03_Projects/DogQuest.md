# DogQuest

Tags: #project #active #flutter #ml

## Session-start reading order (read before any work)

This project file is a status snapshot — it does not capture the live posture, decisions, or task tiering. **At session start, read in order:**

1. [[Strategy]] — `.second_brain/02_Context/Strategy.md` — current posture and constraints. **As of 2026-04-25 the posture is "quality-first with closed beta as feedback loop", NOT ship-first.** Phase 4 manual launch tasks (TASK-058/059/060/061) are deferred until quality bar is met.
2. [[Decisions]] — `.second_brain/01_Memory/Decisions.md` — newest entries first reflect latest direction; old entries may have been superseded.
3. [[Active_Tasks]] — `.second_brain/03_Projects/Active_Tasks.md` — authoritative task list, tier-ordered. Tier 1 cheap wins are the next-action surface; everything else is queued behind them.
4. [[Failure_Patterns]] — `.second_brain/01_Memory/Failure_Patterns.md` — skim before any TFLite/training/data work.
5. This file (`DogQuest.md`) — for status, blockers, and cross-links.

If this file's status section disagrees with the live vault, **the vault wins**. Update this file at the end of meaningful sessions; otherwise treat it as a snapshot from the date last edited.

## Project Name

DogQuest — Flutter dog breed identification app (forked from AviQuest).

## Repo layout (monorepo)

DogQuest lives in the **`TheCryptoCanuck/boring`** monorepo (private). Sibling projects under the same root: `aviquest/`, `aviquest-web/`, `backend/`, `infrastructure/terraform/`, `ml/`, `docs/`, `agents/`, `.ui-design/`.

- **Git root:** `C:\Users\Administrator\AviQuest-\` — NOT `dogquest/`. The `dogquest/` directory is a subproject inside the repo.
- **CI workflows:** live at the repo root in `AviQuest-/.github/workflows/`, NOT `dogquest/.github/`. The DogQuest CI yml uses `defaults.run.working-directory: ./dogquest` to scope `flutter` commands to this subproject.
- **Active branch:** `phase-1/social-backend-realtime`.

Practical implications:

- `git status` / `git diff` / `git log` MUST be run from `AviQuest-/` (or with absolute paths) to see the full repo state. Running from `dogquest/` makes `--` path arguments cwd-relative and silently misses repo-root paths like `.github/workflows/`. (See `Failure_Patterns.md → git-log-cwd-relative-path-arguments`.)
- A `.git` directory is NOT visible under `dogquest/` — git commands from there discover the parent root via the standard upward walk.
- Cowork sandbox sessions mount `dogquest/` only; the repo root is NOT in the sandbox. Git commands cannot run from the sandbox — Jesse runs them in PowerShell.

## Objective

Ship a polished, monetized, social dog-ID app to the Play Store with a 296-breed TFLite model, working sync, and a complete gamification + social loop. Phase 4 launch is the immediate target; Phase 5 growth follows.

## Current Status (2026-04-26 — vault hygiene session)

- **14 modified-but-unstaged files RESOLVED** via per-finding-ID commits. Branch went from "5 commits ahead of origin" baseline to staged sequence covering: C-Lost-A scanStray remote-corpus fix, Phase 4a lost-dog UI tail, comp-review re-run snapshot, DogQuest.md monorepo addendum, orphan deletes, CLAUDE.md AviQuest scrub + monorepo addendum. Plus Group X (additional 5 lost-dog files surfaced after first commit batch), 3 T5-feature-restore un-strips, 2 confirmed orphan-service deletes.
- **C-Lost-A SHIPPED** (pending push). `scanStray()` now consults remote Supabase corpus via `getActiveNearby` RPC + radius filter; matches dedupe by ID against local Hive results. Verified end-to-end by code-reviewer agent. Test coverage gap (integration test for the remote branch) logged as tech-debt.
- **C-Lost-2 (GDPR consent gate) and pgvector RPC migration** filed as separate open items in Active_Tasks. C-Lost-2 blocks public Play Store, not closed beta.
- **DogQuest CLAUDE.md is now AviQuest-free** (project policy established 2026-04-26 — see Memory.md project conventions). Vault files and monorepo root may still reference AviQuest as factual context.
- **T5-feature-restore: 3/8 sites un-stripped** (`help_find_tab.dart` × 2, `lost_dog_map_controller.dart` × 1). 5 remain across `main.dart` (3), `router.dart` (1), `sync_services_test.dart` (1) — all flagged "OPEN — re-verify" since the underlying service files now exist on disk; compile-error status not verified this session.
- **Subagent verification pattern**: Explore agent reported 4 false-positive orphans (CamelCase-only grep). Caught via parent-side broader regex. Logged as Failure_Patterns entry + Memory.md project convention.
- **Sandbox-bound workflow established**: Cowork mounts only `dogquest/`; git runs only from Jesse's PowerShell at `AviQuest-`. Pattern is now documented in Memory.md, Compressed_Insights.md, and the monorepo addenda in CLAUDE.md and DogQuest.md.

## Current Status (2026-04-25 night — lost-dog spec + full-app comp review re-run)

- **Lost-dog improvement spec** shipped via 4-agent parallel investigation. `docs/session_2026-04-26/lost_dog_improvements_spec.md` distills ~70 findings into 3 user-facing decisions: matching honesty (softmax-as-fingerprint structurally weak), network-vs-self matching (`scanStray` only matches local Hive, never the remote corpus), GDPR timing (2 Critical findings before public Play Store).
- **Full-app comprehensive review re-run** (5 phases, 8 specialist agents). Final report at `.full-review/05-final-report.md`. Prior morning review preserved at `.full-review-archive-2026-04-25/`. Status=complete.
- **3 vault-vs-disk drift findings** surfaced — these are now Tier 0 (must verify before any other work):
  - DRIFT-1 Critical: vault claims OPS-001 (CI/CD) closed via 2 specific commits shipping 5 yml files in `.github/workflows/`. Bash check shows `.github/` does not exist on the working tree at all. Either commits on a non-checked-out branch, never pushed, or premature closure marker.
  - DRIFT-3 Medium: `android/key.properties` mtime 2026-03-14 predates OPS-002 (2026-04-25) closure claim that says it points to the new keystore. If file actually still references the March keystore, the signed APK at `build\app\outputs\flutter-apk\app-release.apk` was built with the OLD keystore + OLD password (`dogquest2026`), not the new one — vault SHA-256 fingerprint claim would be wrong.
  - DRIFT-2 Low (positive): 4B agent reported "no Supabase IaC in repo" — actually `supabase/00_foundation_schema.sql`, `01_social_schema.sql`, `02_social_rls_policies.sql`, `03_rpc_functions.sql` exist on disk. OPS-M-003 downgraded to "needs CI automation only" (~2 hr).
- **9 distinct Criticals** in the new review (after dedup). 5 are quick-fix code-side (~3-4 hr total — stream leaks, dual TFLite load, geolocator logging, lint re-enable, unawaited wrap). 2 are GDPR (12-20 hr; same as lost-dog spec C-Lost-1/C-Lost-2). 1 is auth integration test (TEST-CRIT-2, 3 hr). 1 is keystore password rotation (1.5 hr).
- **Effort budgets**: closed-beta sign-off ~9-11 hr (Step 0 drift + Step 1 quick-fix Criticals + Step 2 ops opening gate); public Play Store hard gates ~30-40 hr more; comfortable launch with full test backlog and widget refactor ~70-90 hr.
- **Cross-validation signal**: lost-dog spec's Agent C (GDPR) and comprehensive review's 2A (security-auditor) independently flagged the same 2 Critical GDPR findings at the same severity, ran 3 hours apart from different briefs on the same files. Strong confidence those Criticals are real.
- Branch state per Active_Tasks: `phase-1/social-backend-realtime`, was 18 commits ahead at start of session — but DRIFT-1 means we don't actually know what's on the working branch's HEAD until Jesse runs `git status`.

## Current Status (2026-04-25 evening, T1 deck-clearing complete)

- **Pre-closed-beta gate is essentially open.** A signed `app-release.apk` (110 MB) sits in `build\app\outputs\flutter-apk\` — that's the artifact for distribution to 5-10 friends/family beta testers.
- T1 closes this evening (in order): DOC-001 (`df8b38a`) → DOC-002 (`88649a8`) → OPS-001 (`c949c92` + `d859f81`) → OBS-001 supersedes TASK-050 (`3e4f1e3`) → OPS-002 (no commit, gitignored artifacts only).
- **Observability swap**: Sentry → Firebase Crashlytics (Jesse rejected Sentry's 14-day trial banner UX; Crashlytics aligns with existing Firebase setup, free forever for typical crash volume).
- **Keystore**: new keystore at `C:\Users\Administrator\dogquest-release.jks` with weak password (sequential digits — fine for closed beta, MUST regenerate before Play Store production). SHA-256 fingerprint logged in Decisions.md OPS-002 entry. March keystore at `android/dogquest-release.jks` is now stale leftover (Jesse's call whether to delete).
- **CI multi-workflow inventory**: `.github/workflows/` has 5 yml files including 3 pre-existing from 2026-03-03 (`flutter-ci.yml`, `infrastructure-ci.yml`, `release.yml`) that I did not inspect. Jesse to review for overlap.
- **Remaining T1**: 3 phone-bound items (~30 min Jesse time): on-device cluster verify, Crashlytics force-crash dashboard test, GitHub branch protection UI toggle.
- **Branch state**: `phase-1/social-backend-realtime`, **18 commits ahead of origin** (was 8 at start-of-day, +13 across two sessions).

## Current Status (2026-04-25 session-end, parallel-feature-development repair)

- **God-class refactor recovery shipped.** A Claude Code parallel-feature-development run earlier in the day produced 42 new widget files + 6 god-class screen rewires that didn't compile (132 analyze errors). After 3-agent parallel research (repair-feasibility / architecture-critic / tier-discipline-analyst), Jesse explicitly overrode the locked tier-discipline rule and authorized in-place repair. 5 surgical commits brought the tree to 0 lib errors + clean format + 125+ tests passing.
  - `e1f7a2e` Extract god-class screens into widget subfolders (refactor pass 1/4) — 42 files
  - `55b7317` Wire god-class screens to extracted widgets; purge 1538 lines of dead duplicate classes from lost_dog_hub_screen (refactor pass 2/4) — 1665 → 127 lines on that file
  - `c17643e` Pre-existing API drift fixes (refactor pass 3/4) — main.dart wiring, getCurrentLocation rename, hasAdConsent rename, connectivity_plus import
  - `953bb92` Drop broken Supabase sendRequest path (refactor pass 4/4)
  - `5a8d0a3` `dart format` across 180 files
- **New T5 tasks added** to Active_Tasks: friends_screen sendRequest dog-id wire-up, LostDogReportCard cohesion split, supabase_social_test mock rewire.
- **New failure pattern logged**: parallel-feature-development leaves dead-duplicate private classes in the parent file when extracting public widgets — score 0.9.
- **Branch state**: `phase-1/social-backend-realtime`, **13 commits ahead of origin** (was 8 pre-session).

## Current Status (2026-04-25 session-end, automation+T1-close push)

- **Posture: quality-first with closed beta** (locked 2026-04-25). 4-week time-box on pure quality work.
- **T1 Critical security: ALL 3 closed in commit history.** C3 (`aaebc5d`), C1 (`4da92cf` router + `f8eae20` sync service), C2 (`f8eae20` reduced-scope dormant marker). Server-side Supabase RLS verified via dashboard (`sightings_own: auth.uid() = user_id` + RPC `auth.uid()` hardcoded).
- **Comprehensive code review Phases 1–5 COMPLETE.** State machine set to `complete` in `.full-review/state.json`. Final report at `.full-review/05-final-report.md`. Phases 3-5 added 5 new Criticals (OPS-001 no CI/CD, OPS-002 no signing pipeline, DOC-001 CLAUDE.md drift, plus 2 high-impact test gaps) — these are the new T1 surface; see Active_Tasks.
- **5 sec-related commits this session, all surgically scoped:**
  - `d1127f2` Comprehensive review phases 3-5 (15 files, 4490 insertions)
  - `b247a4a` Instrument dog_found_dialog v1 telemetry (sec-E5)
  - `f8eae20` Add SightingSyncService — sec-C1 auth guards, sec-C2 dormant marker
  - `4da92cf` Invalidate stale offline_mode flag at every session redirect (sec-C1)
  - `aaebc5d` Archive vestigial FastAPI backend (sec-C3) [pre-existing, verified]
- **Branch state**: `phase-1/social-backend-realtime`, 8 commits ahead of origin. Broader untracked surface (~200 files: vault, scripts, specs, .second_brain, docs/session_2026-04-26/) remains working-tree state for Jesse to triage.
- **Cowork-driven Windows automation pattern adopted**: Run-dialog → .bat → log → bash-sandbox-read. 8 .bat scripts + `scripts/close_t1.ps1` + `scripts/close_t1.md` + 6 new Makefile targets shipped. No terminal interaction needed for git/dart/flutter/adb.
- Data hygiene audit shipped earlier (commit `3f084d9`): 5,082 quarantined; top-1 +14.8pt / top-3 +21.9pt.
- Synonym clustering Option B + 6 clusters (Poodle, Kelpie). 95 unit tests passing.
- Quantization headroom: -9.4pt top-3 (TFLite uint8 vs Keras float32). T3 path locked: **float16 TFLite export** (3-5 hr, +8-9pt expected; agent research at `docs/session_2026-04-26/quantization_headroom_research.md`).
- Heavy-flag spot-check done (`docs/session_2026-04-26/heavy_flag_spotcheck.md`): keep `DIFFERENT_BREED_THRESHOLD` at 0.40.
- Counter dissonance fix shipped earlier (`dog_found_dialog.dart`). Commit `2c0fe18`.
- Two-tool workflow validated: Claude Code + Cowork sharing the vault.
- Model v6 (EfficientNetV2-S, 296 breeds, 51.65% Stanford val_acc) deployed with corrected TFLite quant scale; on-device canary verified.
- T2 specs landed: `docs/session_2026-04-26/dog_found_dialog_redesign_spec.md` (with §(e) Critic Pass) + `docs/session_2026-04-26/quiz_redesign_spec.md`.
- Phase 4 manual tasks DEFERRED (TASK-058/059/060/061) until quality bar met. TASK-049/050 still in scope as pre-closed-beta gate items.

## Key Decisions

See [[Decisions]] for full list. Highlights:
- Quant scale 1.0 (not 1/255) for v6 export.
- Riverpod + go_router + StatefulShellRoute baseline.
- Supabase backend, Hive local-first, prefix `dogquest_`.
- AdMob: every-3rd interstitial, 5-min cooldown.
- Wild canids excluded from output.

## Open Questions

- Are the 4 flagged supplemental folders (siberian_husky, belgian_laekenois, american_bulldog, combai) actually mislabeled, or just hard?
- Is EfficientNetV2-M worth the longer training run for +5–10 val_acc points?
- Should iOS support land before or after first 1k Android installs?

## Next Actions (post 2026-04-25 night session — supersedes prior next-actions list)

**Step 0** (Jesse, ~30 min Windows-side, BEFORE everything else):
- DRIFT-1: `git status` + `git log --all --oneline -- .github/` + `git branch -av`
- DRIFT-3: `type C:\Users\Administrator\AviQuest-\dogquest\android\key.properties` and confirm path + password match the OPS-002 vault claim

**Step 1** (Claude Code, ~3-4 hr after Step 0):
- C1 stream-leak Riverpod conversion — 30 min
- C2 shared TFLite interpreter — 1 hr
- C3 geolocator error logging — 30 min
- C4 re-enable `prefer_const_*` lints + `dart fix` sweep — 1-2 hr
- C5 unawaited wrap on identify_screen.dart:73 — 15 min

**Step 2** (~5-7 hr after Step 1, closed-beta opening gate):
- Keystore password rotation (1.5 hr)
- Branch protection toggle (1 hr, T1 phone-bound)
- OPS-001 CI YAML (0-3 hr depending on DRIFT-1 outcome)

Then per `.full-review/05-final-report.md` Steps 3-8: GDPR work (12-20 hr), ops gates (8-13 hr), test backlog (25 hr phased), widget refactor (20-30 hr opportunistic), documentation polish (15-20 hr opportunistic), architectural backlog (post-launch).

## Prior Next Actions (pre-closed-beta gate, ~1.5 days work — see `.full-review/05-final-report.md`)

1. **OPS-002** — Generate release signing key + Gradle release config (TASK-049, ~1.5 hr, Jesse).
2. **OPS-003 / TASK-050** — Sentry signup + DSN copy + `make wire-sentry SENTRY_DSN=...` (~30 min, Jesse + Cowork).
3. **OPS-001** — Wire minimum GitHub Actions CI workflow (format / analyze / test) + branch protection (~3-4 hr, Cowork).
4. **DOC-001** — Reconcile CLAUDE.md ML-spec drift (~30 min).
5. **DOC-002** — Add README.md at repo root (~1 hr).
6. On-device cluster verification (Yorkie/Poodle/Husky photos, ~10 min, Jesse — physical phone).

Closed-beta gate (additional ~3-4 days):
7. OPS-004 (env config externalization), OPS-005 (Supabase IaC), DOC-003 (RPC contract docs).
8. TEST-001/002/003 (sec-C1/C2/E5 verification tests).
9. **FW-001** — Fix dual TFLite model load at startup (30-45 min, measurable user-facing win on cold start).
10. T2 implementation: `dog_found_dialog` top-3 redesign (spec at `docs/session_2026-04-26/dog_found_dialog_redesign_spec.md` — review (e) Critic Pass first).

Post-beta queue (driven by feedback):
11. **T3 float16 TFLite export** (3-5 hr, +8-9pt expected — research at `docs/session_2026-04-26/quantization_headroom_research.md`).
12. TEST-005 widget-test scaffold + per-screen coverage.
13. Full sec-C2 UUID-on-model migration if SightingSyncService gets wired.
14. P2/P3 framework / docs / OPS items from final report.

## Failure Risks

- Ship Play Store with unsigned APK (TASK-049 not done).
- Ship without Sentry → blind to production crashes.
- Confidence-band UX still feels "this is your dog" instead of "top 3 candidates" → user trust erosion on hard breeds.
- Future model retrain runs into the same OOM patterns documented in [[Failure_Patterns]].

## Relevant Files

- `CLAUDE.md` (project root) — full project intelligence
- `Makefile` — 30+ build/deploy targets
- `train_model_v6.py`, `continue_training_v6.py`, `export_tflite.py`
- `assets/dog_model.tflite` (v6 deployed)
- `lib/services/tflite_identification_service.dart`
- `lib/widgets/dog_found_dialog.dart` — real breed result card (1459 lines, takes `Dog` + confidence). NOT `identification_result_card.dart` (dead code).
- `lib/dev/screenshot_seed.dart` — kDebugMode-gated seed function for marketing screenshots
- `lib/dev/mock_screen_1.dart` — branded camera-with-live-prediction mock (not shipped on real camera)
- `lib/dev/mock_screen_5.dart` — branded share UI mock with friend avatars (not shipped; production uses OS-native share)
- `scripts/capture_screenshots.ps1` — interactive `adb screencap` automation per device label
- `screenshots/README.md` — full screenshot capture pipeline doc
- `screenshots/copy.md` — final marketing copy per screen + typography rules
- `screenshots/brand_review.md` — pre-submit brand + a11y audit
- `store-listing/play_store_listing.md` — Play Console paste-ready listing
- `docs/session_2026-04-25/dogquest_session_final.md`
- [[Active_Tasks]]
- [[Decisions]]
- [[Failure_Patterns]]
- [[Strategy]]

## Notes

- Use `make help` or `make menu` for the interactive build/deploy menu.
- ML training requires WSL2 + LD_LIBRARY_PATH dance — see CLAUDE.md "Training Environment" section.
- For any future TFLite export, run the Dalmatian canary BEFORE declaring shipped.
