# Corrections

Tags: #memory #corrections

Use when the user corrects Claude.

## Format

- Date:
- Correction:
- What to do differently next time:
- Score:

## Entries

- Date: 2026-04-25
  Correction: Wrote `@claude-flow/cli@1.x.y` as a pin-syntax example. Claude Code (correctly) noted the example version doesn't exist — current claude-flow major is 3.x and the actual pin landed at 3.5.80.
  What to do differently: When suggesting version-pin syntax, either look up the current major first OR explicitly mark the version as illustrative ("e.g. `@pkg@CURRENT-MAJOR.x.y`") so the agent doesn't act on an invalid string.
  Score: 0.7

- Date: 2026-04-25
  Correction: Asserted `.mcp.json` was probably leftover/unused from the AviQuest fork without checking. Claude Code (correctly) found evidence claude-flow IS active: `package.json` declares it, `node_modules/@claude-flow/*` is installed, `.claude-flow/plugins/dogquest-ml/` exists, active `mcp__ruflo__*` tools route through it.
  What to do differently: Before declaring inherited config "leftover," grep for it in `package.json`, `node_modules/`, plugin folders, AND check for active tool calls in the live session. Apply the same rule to ANY inherited tooling — vestigial-looking is not the same as actually-vestigial. Logged in Failure_Patterns.md as well.
  Score: 0.85

- Date: 2026-04-25
  Correction: Wall-time projection for the GPU audit was off by ~6× — I said 15–25 min, actual was ~1.9h (and pre-batching CPU TFLite would have been ~3.7h). I was thinking inference-bound (50–80ms/batch on RTX 3060 Ti); the actual bottleneck was PIL preprocessing + EXIF bake on single-threaded Python (~161ms/img end-to-end).
  What to do differently: When estimating wall time for a pipeline, separate inference cost from data-loading/preprocessing/serialization cost. End-to-end throughput is gated by the slowest stage, not the headline op. For Python image pipelines, assume preprocessing dominates unless multiprocessing or tf.data is in play.
  Score: 0.8

- Date: 2026-04-25
  Correction: Claimed the 20-image test harness lived at `outputs/test_20_images.py` in the project repo. It actually lived in Cowork's session-only sandbox `/sessions/.../mnt/outputs/`, which is invisible to Claude Code. Caused a HALT during the agentic audit task.
  What to do differently: Persistent project artifacts (scripts, harnesses, reports) MUST be written into the user's workspace folder (`C:\...\dogquest\`), not the Cowork sandbox. The sandbox is for ephemeral work-in-progress only. When the vault references a file path, that path must resolve in the user's actual environment, not just Cowork's.
  Score: 1.0

- Date: 2026-04-25
  Correction: Reported `lib/services/sighting_sync_service.dart` was truncated mid-`syncSingle` at line 222 with no closing braces, and proposed Jesse run `git checkout HEAD -- ...` to restore. The file was actually fine at 302 lines on Windows-side disk; what I saw was a virtiofs-mount cache artifact in the bash sandbox where post-Edit state hadn't propagated. The "restore" .bat that ran on Windows confirmed the file was already whole.
  What to do differently: When bash sandbox `wc -l` / `tail` / `sed` show a file as truncated/corrupt right after an Edit-tool write, do not panic. The Cowork bash mount has cache lag relative to actual Windows-side disk state. Re-read the file via the Read tool (which goes through a different path) before declaring data loss. Better: write out a `.bat` that does `find /c /v "" < FILE` on Windows side and read the log — that's the source of truth.
  Score: 0.85

- Date: 2026-04-25
  Correction: Logged "C1 mostly committed in code" earlier in the session based on grep finding `sec-C1` markers in `lib/services/sighting_sync_service.dart`. The file was actually UNTRACKED (`??` in git status) — markers existed in the working tree but were never in any commit. The router-side change (`lib/router.dart`) WAS modified-tracked (`M`), so half of C1 was committable; the other half wasn't yet in git at all.
  What to do differently: Before claiming any sec-finding is "mostly committed in code," run a full `git status --short` on the relevant files and distinguish between (a) tracked-and-modified (M), (b) tracked-and-clean (no marker = already committed), (c) untracked-but-edited (??). Only (b) is "committed". (a) and (c) are working-tree state and need explicit `git add` + `git commit` to land. Drove the surgical commit fix later in the same session.
  Score: 0.9

- Date: 2026-04-25
  Correction: Said the comprehensive review's Phase 1+2 final report would have findings counts "5 Critical, 15 High, 18 Medium, 6 Low" but those numbers reflected Phase 3+4 only — I summarized the new agent outputs without re-counting Phase 1+2 findings into the cross-phase totals. The final report in `.full-review/05-final-report.md` notes this ("Total findings (Phase 3+4 only, prior phases not re-counted here)") so the leak was caught, but my session summary to Jesse implied total-across-all-phases.
  What to do differently: When summarizing multi-phase outputs, either explicitly re-count cross-phase totals OR clearly label per-phase counts as "this phase only". Don't let "total" do double duty.
  Score: 0.7

- Date: 2026-04-25
  Correction: Treated Sentry as default observability for TASK-050 without flagging the trial-banner UX upfront. Jesse pointed out the signup page foregrounds a 14-day trial; he found the messaging off-putting before realizing the Developer plan stays free. Cost: ~5 min of back-and-forth before pivoting to Crashlytics.
  What to do differently: For any "wire in vendor X" task, surface free-tier limits AND any prominent paid-tier UX in the same message that proposes the wiring. Better: when vendor pricing has a known sharp edge (trial banners, low free-tier caps, hard rate limits), proactively offer 1-2 alternatives in the initial recommendation, not after the user pushes back. Saves a round-trip.
  Score: 0.7

- Date: 2026-04-25
  Correction: Generated a new release keystore via `keytool` without checking whether one already existed at the canonical project path. A working March keystore was already at `android/dogquest-release.jks`, already wired in `android/key.properties` with password `dogquest2026`. My fresh keystore at `C:\Users\Administrator\dogquest-release.jks` was a duplicate, and would have silently displaced the existing one if Jesse had said "use new" without my catching it mid-flight. Same pattern played out earlier in the session when I overwrote `.github/workflows/ci.yml` (which was an AviQuest workflow) without checking — caught only via the 49-line deletion in the commit diff stat.
  What to do differently: Before any create-artifact task (signing keys, CI yml, README, license, config), run `ls`/`Test-Path`/grep for the canonical location AND for references in adjacent config files (`pubspec.yaml`, `build.gradle`, `*.properties`, `.gitignore`). If found, present the existing-vs-new tradeoff to the user. For credentials specifically, never auto-replace — the cost of a wrong call (lost Play Store update path) is irreversible. Logged in Failure_Patterns.md as "existing-artifact discovery" pattern, score 0.85.
  Score: 0.85

- Date: 2026-04-25
  Correction: Briefed Phase 4B of the comprehensive review with the vault claim "5 yml files in `.github/workflows/`" as a known fact. The 4B agent then reported the directory was empty, contradicting my brief. Bash check after the fact: `.github/` doesn't exist on the working tree at all. The vault's OPS-001 closure claim ("commits `c949c92` + `d859f81`") had not been verified against disk before I propagated it into the agent context. Result: ~30 min of agent time spent on a brief that started from a false premise; agent had to course-correct mid-report. The agent's read was correct; my brief was wrong.
  What to do differently: Before propagating ANY vault closure claim into agent briefs, run a 30-second bash existence check on the artifact (file/directory/commit). The pattern: vault attestation ≠ disk truth. For "OPS-XXX closed" / "DOC-XXX closed" / "TASK-XXX closed" specifically, the brief should say "vault claims X is at PATH; verify before relying on" if the bash check hasn't run yet. Also: surface this to Jesse so future "closed" claims in Active_Tasks get commit-hash-verified rather than vault-attested. Logged in Failure_Patterns.md as "vault-claim-trust-without-disk-verification" pattern, score 0.9.
  Score: 0.9

- Date: 2026-04-25
  Correction: When briefing Phase 4B I told the agent that "supabase/ schema files don't exist in repo" without verifying. The agent then flagged OPS-M-003 ("No infrastructure-as-code for Supabase migrations") at Medium severity, which I caught after a follow-up bash check showed `supabase/00_foundation_schema.sql`, `01_social_schema.sql`, `02_social_rls_policies.sql`, `03_rpc_functions.sql` all exist on disk. The schema IS version-controlled; what's missing is just CI automation to apply migrations. The error was symmetric to the other vault-trust failure but in the opposite direction — I propagated a negative absence claim without verification.
  What to do differently: Symmetric to the prior correction. Don't claim "X doesn't exist in repo" without a bash check OR a glob. Especially when the brief is going into 30+ min of agent reasoning that builds on the assumption. The fix is the same as the previous entry: before propagating any positive OR negative claim about repo state, verify via bash/glob/Read.
  Score: 0.85

- Date: 2026-04-25 (evening)
  Correction: Audited the T5-B sub-agent's `_AwaitableFilterBuilderWrapper` and concluded "should pass for all 7 tests under current service code paths" with "medium-confidence" runtime expectation. Flagged the dual `Future<List<dynamic>>, PostgrestFilterBuilder<dynamic>` interface risk as a "D-tier hypothetical concern (if the SDK migrates...)". Reality: the SDK ALREADY had `PostgrestBuilder extends Future<dynamic>` in supabase_flutter 2.10.2, so the wrapper failed analyze immediately on next CI push. My audit was too optimistic — the fundamental compile-time conflict was the actual blocker, not a hypothetical.
  What to do differently: When a wrapper or proxy class implements multiple interfaces with overlapping method signatures, do a targeted analyzer check (or read the dependency's interface source) BEFORE declaring the audit done. Specifically: if `class X implements A, B`, and A and B have any methods/fields with the same name, those signatures must reconcile or analyze fails. The `D-tier hypothetical` framing was a hedge that should have triggered a verification step instead.
  Score: 0.85

- Date: 2026-04-25 (evening)
  Correction: DRIFT-1 went through 4 verification passes and I updated the same Active_Tasks block 3 times with progressively-corrected conclusions, each based on partial evidence. Pass 1: trusted vault closure. Pass 2: ran `git log --all -- .github/` from `dogquest/` (cwd-relative path issue), got empty, declared closure phantom. Pass 3: GitHub UI screenshot showed `.github/workflows/` IS tracked, partially walked back. Pass 4: ran `git log origin..HEAD` from `AviQuest-/`, confirmed commits ARE real on local-ahead-of-origin queue. Net cost: ~3 corrections to the same vault entry, ~30 min of session time on a state that was always coherent — just queried wrong.
  What to do differently: When verifying repo-state claims, ALWAYS run the diagnostic from the repo root (`git rev-parse --show-toplevel` first if uncertain). Use absolute paths in `git log -- PATH` arguments OR `cd` to root. Don't update the vault until verification is COMPLETE, not partial — partial corrections compound and require re-correction. Logged in Failure_Patterns as `git-log-cwd-relative-path-arguments` (score 0.85).
  Score: 0.9

- Date: 2026-04-25 (evening)
  Correction: Concluded `.github/` doesn't exist on disk because the directory wasn't in Jesse's pasted `git status` untracked listing. The listing was ~150 visible entries (paginated/scrolled output of ~350 total). The directory DID exist with a 95-line working CI yml — I'd just scrolled past it OR it was beyond the paste boundary. The Read tool only saved me because Write's "file already exists" error surfaced when I tried to overwrite it with my misplaced duplicate.
  What to do differently: Negative existence claims about disk state require independent positive verification. Don't infer "X doesn't exist" from absence in a long listing pasted by the user. Use `Glob`/`Read`/`Test-Path` against the canonical filesystem path instead. Paginated output is unreliable as a negative-existence proof. Logged in Failure_Patterns as `dont-infer-absence-from-partial-listings` (score 0.85).
  Score: 0.85

- Date: 2026-04-25 (evening)
  Correction: Wrote that Jesse "scrolled past in the ~350-item untracked listing" as the explanation for why `.github/` wasn't visible in the git status output. Jesse pushed back: "this you being funny :)" — pointing out that I was anthropomorphizing (Jesse hadn't done anything wrong; I had read a partial listing and inferred absence). The "scrolled past" framing was me reaching for a charitable explanation that put the gap on the user instead of acknowledging my own incomplete read.
  What to do differently: When reasoning about why a piece of evidence didn't surface, distinguish between (a) my own incomplete read of the data, (b) genuine truncation in the source, and (c) actual user behavior. Default to (a) when the evidence is in something I parsed myself. Don't displace responsibility onto the user with charitable-sounding inferences.
  Score: 0.8

- Date: 2026-04-25 (evening)
  Correction: Wrote a duplicate `dogquest-ci.yml` at `dogquest/.github/workflows/` (one level too deep) before checking the canonical path. Git root is `AviQuest-/`, so GitHub Actions only reads `.github/workflows/*.yml` at `AviQuest-/.github/workflows/`. My misplaced duplicate would have been invisible to GitHub. The canonical file at `AviQuest-/.github/workflows/dogquest-ci.yml` already existed; the Write tool's "file already exists, must Read first" error was the only thing that surfaced this — otherwise I'd have written a new file at the wrong path AND assumed the canonical didn't exist (since the partial git status didn't show it; see prior correction).
  What to do differently: Before writing CI workflow files in a multi-project monorepo, run `git rev-parse --show-toplevel` to confirm the repo root, then `Glob '.github/workflows/*'` from that root to inventory existing workflows. Never assume the cwd is the repo root in a Flutter-subproject layout. Logged in Failure_Patterns as `create-artifact-without-existence-check` (score 0.85).
  Score: 0.8

- Date: 2026-04-25 (evening)
  Correction: Pushed Sprint 1 commits to origin without first simulating origin's tree to catch tracked-file dependency gaps. Each push surfaced a new dangling reference that local analyze didn't see because Jesse's working tree had unstaged modifications providing the missing symbols. Cost: 5 successive failed CI runs, each 1-2 minutes wall time + push/wait overhead. Pattern: tracked files in working tree had unstaged additions (radiusKm parameter, distanceKm getter, etc.) that newly-committed files depended on; origin lacked those additions; CI failed.
  What to do differently: Before pushing to a CI-gated branch, run `git stash push -m diagnostic && dart analyze && git stash pop` (or use `git worktree add`) to simulate origin's tree. Errors that surface are the dependencies origin will be missing. Either commit the necessary unstaged modifications OR strip the dependent code from the about-to-push commits BEFORE the push. Iteration cost on CI is high — each push is 3-5 min minimum. Logged in Failure_Patterns as `working-tree-vs-origin-drift-on-tracked-files` (score 0.85).
  Score: 0.85

- Date: 2026-04-25 (evening)
  Correction: Ran `git stash push -u` on Windows with `.second_brain/` and many other deeply-nested untracked dirs in working tree. The command appeared to succeed but `git stash pop` ("Already up to date") didn't restore most untracked files. `.second_brain/` was lost from disk. Suspected cause: the CRLF normalization warning flood interrupted partial completion of stash content capture. Recovery via `git stash apply 2` later worked for some files but stash@{2} was consumed in the process, losing access to original versions of 4 files (which I rebuilt from chat history).
  What to do differently: For diagnostic "what does CI see" comparisons, use `git worktree add ../diagnostic origin/branch-name` instead of `git stash -u`. The worktree approach: (a) gives a clean origin checkout in a separate dir; (b) doesn't touch the active working tree; (c) is reliably cleanable via `git worktree remove`; (d) doesn't interact with untracked file capture at all. Reserve `git stash` for tracked-modified work that needs temporary parking. Logged in Failure_Patterns as `git-stash-u-loses-deeply-nested-untracked` (score 0.7).
  Score: 0.85

- Date: 2026-04-26 (vault hygiene session)
  Correction: Inserted the monorepo addendum at the TOP of `dogquest/CLAUDE.md` immediately after `## Project Overview`, leaving the `## Project Overview` header with no body — the actual overview text got displaced to line 14, orphaned between two H2s. Jesse caught it via the `git diff` paste showing the structural break. The correct fix was to insert the new section AFTER the Project Overview body, not before it.
  What to do differently: When prepending a new H2 above an existing one, check that the existing section's body is still under its header. Read the structure: `H2 → body → blank → H2 → body`. Don't insert another H2 between an H2 and its body. If using `Edit` with prepend semantics, anchor on `## Existing Section\n\nbody text` and append after the body, not after the header.
  Score: 0.7

- Date: 2026-04-26 (vault hygiene session)
  Correction: Drafted the monorepo addendum WITH a sibling-project list including `aviquest/` and `aviquest-web/`, plus a literal `C:\Users\Administrator\AviQuest-\` path. Jesse: "i dont want anything mentioning aviquest in the md". I had defaulted to "factual completeness" without checking whether the predecessor-app context was something Jesse wanted in dogquest's own docs. Required a full scrub: 8 separate references removed (sibling list, paths, Firebase project ID, fork lineage prose, "Key Differences from AviQuest" section, BirdNET/aviary diff bullets, Hive collision-avoidance prose, Firebase project ID parenthetical).
  What to do differently: For DogQuest's own docs (`dogquest/CLAUDE.md`, `dogquest/README.md`), default to AviQuest-free framing. Use placeholders like `<repo-root>/` or "the monorepo root, one directory above `dogquest/`" instead of literal paths that contain "AviQuest". Logged as a Memory.md project convention. Vault-side files and monorepo-root files may still reference AviQuest as factual context.
  Score: 0.8

- Date: 2026-04-26 (vault hygiene session)
  Correction: Trusted an Explore subagent's report that `conflict_resolution_service`, `ad_service`, `device_token_service`, `pull_sync_service` were "candidate orphans" with 0 live refs. Almost recommended `Remove-Item` on all 4 to Jesse. Verification with both CamelCase + snake_case patterns showed 1-2 live refs each (e.g. `ConflictResolutionService` is referenced from `test/sync_services_test.dart` and `lib/main.dart`). The agent's grep had used only one casing pattern. If I had passed the recommendation through unfiltered, T5-A test would have broken next CI run.
  What to do differently: For Dart orphan checks, the parent agent must verify subagent zero-ref claims with both CamelCase AND snake_case patterns before any delete decision. Build the verification into the subagent brief: "report the grep command + match count, AND verify with the alternate-casing pattern; flag any mismatch". Logged as Failure_Patterns entry `subagent-narrow-regex-false-positive-orphan` (Score 0.7).
  Score: 0.8

- Date: 2026-04-28 (Hound rebrand session)
  Correction: Recommended Jesse re-add `dog_service.dart` import to `dog_found_dialog.dart` to fix CI #14's `Undefined name 'kDeployedBreedCount'` error. My theory: origin's `dog_service.dart` defines the constant or re-exports it. Wrong — origin's `dog_service.dart` doesn't define it either. The constant lives only in working-tree `constants.dart` (uncommitted). CI #15 (with the import re-added) failed with the SAME error, just one line down because the import push line shifted. Final fix was to inline the literal `150` at the usage site. Cost: 1 wasted commit + CI cycle (~3 min wall + push iteration overhead).
  What to do differently: When an "undefined symbol" error surfaces in CI but the symbol exists in working tree, FIRST verify which file declares it on origin (not just where the working tree currently has it). Use `git show HEAD:path/to/file.dart | grep symbol` from the repo root to see origin's content. If origin has neither the symbol nor a re-export path to it, no amount of import-juggling will fix it — inline the value, commit the defining file, or strip the reference. Don't speculate about re-export chains without grepping the origin tree.
  Score: 0.8

- Date: 2026-04-28 (Hound rebrand session)
  Correction: Predicted CI would treat warnings as non-fatal because Active_Tasks said "CI workaround: `flutter analyze --no-fatal-warnings --no-fatal-infos`". Wrong — the workflow yml had been re-tightened in commit `3ce05afb` to use ONLY `--no-fatal-infos`, making warnings fatal again. CI #13 surfaced this when 8+ pre-existing warnings (unused fields, missing onError return, unused imports, unused locals) gated the analyze job. I had assumed the older "relaxed" setting still applied; should have read the active yml first. Cost: 1 wrong prediction in the smoke instructions, ~5 min of confusion before clicking into the failing job.
  What to do differently: Active_Tasks documents intent at the time of writing; the actual CI flag set is always the workflow yml at HEAD. Before predicting CI behavior, read `.github/workflows/<workflow>.yml` (or click into a recent failed run's step name) to confirm which fatality flags are actually live. Vault entries about CI config are quickly stale; always verify against the yml itself when CI behavior matters.
  Score: 0.7

- Date: 2026-04-28 (Hound rebrand session)
  Correction: Brief for Phase 7 / F2 agent said "delete unused dog_service.dart import after verifying nothing references DogService or dogServiceProvider in dog_found_dialog.dart." The agent's grep was correct for those symbols but missed `kDeployedBreedCount` — a top-level constant that was either re-exported from `dog_service.dart` on origin or co-imported through it. Result: F2 successfully removed an "unused" import that was actually needed at the origin tree level. CI failed on commit `5951952` because of this. The brief failure was mine, not the agent's.
  What to do differently: For ANY import-removal task, the brief must instruct the agent to enumerate all top-level symbols (consts, enums, typedefs, top-level vars, classes) defined in the imported file, then grep each in the consuming file — not just the file's primary class name. Logged as Failure_Patterns entry `subagent-import-removal-misses-top-level-constants` (Score 0.75).
  Score: 0.75

- Date: 2026-04-30 (config-validate session)
  Correction: Pass 1 of /deployment-validation:config-validate scoped only to dogquest based on `ls /sessions/cool-friendly-galileo/mnt/` showing only dogquest mounted. Wrote "Cowork sandbox does NOT mount the monorepo root (AviQuest-/). CI yml, terraform, backend configs unreachable from this run" into the findings doc. Jesse: "you have access to everything." Read tool on `C:\Users\Administrator\AviQuest-\.github\workflows\*.yml` and `C:\Users\Administrator\AviQuest-\infrastructure\terraform\*.tf` worked immediately — bash mount limit doesn't apply to Read/Glob/Edit on Windows paths. Cost: Pass 1 missed CI yml + terraform + backend audits that Pass 2 then covered (~30 min of redundant work avoided next time).
  What to do differently: Bash mount limit ≠ Read tool reach. Before declaring monorepo-scope-limited based on bash output, try `Glob "C:\Users\Administrator\AviQuest-\*"` to confirm Read tool reach. Cowork's two filesystem views: bash sees its sandbox mount; Read/Glob/Edit see the underlying Windows paths. The vault entry "Cowork sandbox excludes the monorepo root" was correct for bash and wrong for everything else. Updated Memory.md to reflect.
  Score: 0.85

- Date: 2026-04-30 (config-validate session)
  Correction: CI-yml audit subagent claimed `dogquest-ci.yml` line 98 had a path bug because `working-directory: ./dogquest` would double-up the path on `actions/upload-artifact@v4`'s `path` parameter, yielding `dogquest/dogquest/...`. Tagged it as MEDIUM severity in the agent's report. I almost included it in the consolidated findings doc as a Fix item before reading the spec: `working-directory` only applies to `run:` steps, not action inputs. Action inputs (`path:`, `name:`, etc.) execute in the repo root regardless of `defaults.run.working-directory`. The agent's finding was wrong; the workflow is correct as-is.
  What to do differently: For any GitHub Actions claim that depends on `working-directory` semantics, verify against the docs that `working-directory` only affects shell commands in `run:` steps. Action inputs always execute in the repo root. This is a recurring confusion pattern with both AI agents and human reviewers — flag it explicitly in agent briefs going forward. Did NOT include the false finding in the consolidated report; flagged the agent's MEDIUM as wrong.
  Score: 0.7

- Date: 2026-05-01 (nav redesign session)
  Correction: Parallel agent edited `kennel_screen.dart` — a 1000+ line file with deeply-nested `ValueListenableBuilder → Scaffold → CustomScrollView → slivers: [...] → else ...[...]` bracket structure — and reported "solid" confidence with "syntactically correct" output. The file had two structural errors: (1) an extra `),` at 12-space indent after the `slivers: [` closing `],` which caused all subsequent class methods to land at top-level scope (surfaced as "Undefined name '_viewMode'", "_filterRarity'", etc.); (2) `else ...[` spread list at line 392 had no closing `],` before the outer slivers list closed. Compilation failed with `Can't find ']' to match '['` and cascading "Undefined name" errors covering the entire helper-method surface of `_KennelScreenState`. The Cowork sandbox lacks the Dart toolchain, so `dart analyze` cannot run in-session — but the agent should have flagged this limitation rather than claiming solid confidence.
  What to do differently: After any agent edits a Dart file with nested collection-if or spread operators (`...[...]`) inside a slivers/children list, explicitly note that bracket correctness cannot be sandbox-verified and mark confidence `uncertain` (not `solid`). Hand off a `dart analyze` verification step to Jesse before claiming done. Never use `solid` when the Dart toolchain is unavailable. Logged in Failure_Patterns as `agent-complex-nested-tree-unverified-bracket-claim`.
  Score: 0.85

- Date: 2026-05-01 (directory audit session)
  Correction: Generated cmd.exe cleanup commands (`rmdir /s /q _trash`, `del _review\ruvector.db _review\test_output.txt`) for a PowerShell user. Jesse's screenshot showed the expected errors — PowerShell aliases `rmdir` to `Remove-Item` but doesn't support `/s /q` flags; `del` doesn't work with comma-separated paths the same way. Fixed with `Remove-Item -Recurse -Force _trash` and `Remove-Item _review\ruvector.db, _review\test_output.txt`.
  What to do differently: Always use PowerShell cmdlets (`Remove-Item`, `Get-ChildItem`, `Copy-Item`) in cleanup instructions — never cmd.exe builtins (`rmdir`, `del`, `xcopy`). Jesse's terminal is PowerShell 5.x. This is documented in Memory.md env quirks but was ignored under time pressure. Failure pattern logged as `cmd-syntax-to-powershell-user`.
  Score: 0.6

- Date: 2026-05-09 (lint cleanup session)
  Correction: Agent 1 added `if (!context.mounted) return;` in `breed_community_screen.dart` (a `ConsumerStatefulWidget` State class) as the async guard. The analyzer still flagged it: "guarded by an unrelated 'mounted' check." In a `State<T>`, the correct async guard is `if (!mounted) return;` — the State's own property, not `context.mounted`. The two are nearly always equivalent at runtime, but the analyzer treats them as checking different objects and considers `context.mounted` "unrelated" when it expects `State.mounted`.
  What to do differently: In any `State<T>` class, always use `if (!mounted) return;` for post-await guards. Reserve `context.mounted` for non-State contexts (standalone functions receiving a BuildContext parameter). When writing agent briefs for `use_build_context_synchronously` fixes, specify: "use `mounted` (State property) not `context.mounted`."
  Score: 0.7

- Date: 2026-05-10 (closed beta push session)
  Correction: Three rounds of camera focus fixes, each wrong. (1) Added `.timeout()` wrappers to `setFocusPoint`/`setExposurePoint` — still froze because the native HAL blocks synchronously before the Future is created, making Dart-side timeouts irrelevant. (2) Disabled tap-to-focus entirely — no more freeze, but user noted "autofocus doesn't work." (3) Removed 2s timeouts from init `setFocusMode`/`setExposureMode` and separated into independent try/catch — user said "revert last change." Final state: init focus back to 2s timeouts in single try/catch (working), tap-to-focus disabled (working, shipped as beta behavior).
  What to do differently: When a platform channel call blocks the entire app, the problem is on the NATIVE side (HAL blocking before returning to Dart). Dart `.timeout()` cannot help because the Future is never created — execution never reaches Dart's event loop. The correct diagnostic is: (a) confirm the call is genuinely synchronous-native-blocking (entire isolate freezes, not just UI jank), (b) if confirmed, the only safe fix is to NOT call that method at all, or call it from a separate isolate (which is complex for camera). Don't iterate through timeout-wrapper variations — they're all equivalent no-ops when the blocker is pre-Future.
  Score: 0.8

- Date: 2026-05-10 (Supabase Auth wiring session)
  Correction: Debugging `build_debug.ps1` encoding issue — tried hex dump for smart quotes (none found), then `sed` for LF→CRLF (didn't fix), then `sed` to replace em-dashes (changes didn't sync to Windows). Jesse: "are u drifting." Three unfocused attempts before landing on the actual fix (rewrite entire file via Write tool with ASCII-only content). The bash sandbox write-desync was the deeper issue — `sed` edits completed in bash but never propagated to the Windows filesystem.
  What to do differently: When a file has encoding/parse issues on Windows, go straight to the Write tool (which writes directly to the Windows filesystem) rather than iterating through bash sandbox modifications that may not sync. The bash sandbox is a read path, not a reliable write path for user-executed files. Also: don't guess at encoding fixes — if the first attempt doesn't work, step back and identify the actual character causing the problem before trying more sed passes.
  Score: 0.75

- Date: 2026-05-11 (screenshot pipeline session)
  Correction: Trusted Explore subagent's audit which pointed at `lib/widgets/identification_result_card.dart` as "the breed result card" and proposed editing it to add size/origin/temperament. Started reading the file to make the edit, then ran `grep IdentificationResultCard\(` and found zero construction sites — the widget is dead code. The real result card is `DogFoundDialog` (1459 lines, in a completely different file). The audit listed file paths without verifying any caller. Caught before editing the wrong file. Cost: ~5 min wasted reading dead-code internals before the grep.
  What to do differently: Before editing ANY widget identified by a subagent audit as "the X widget" or "the screen rendering Y," verify with a construction-site grep: `grep -E "WidgetName\(|const WidgetName\(" lib/`. Zero matches = dead code, audit wrong. The full grep-and-verify pattern was already established in Memory.md ("Trust subagent zero-ref claims with skepticism") for orphan checks; extending it now to subagent positive identification claims as well. Logged in Failure_Patterns as `subagent-dead-code-positive-id`.
  Score: 0.8

- Date: 2026-05-11 (screenshot pipeline session)
  Correction: Drafted full Play Store listing including the claim "No tracking. No data sale. No dark patterns." After writing, did a drift sweep on my own deliverable and ran `grep firebase_analytics|sentry pubspec.yaml` — both ARE dependencies. `grep FirebaseAnalytics\.instance lib/` returned `main.dart:627`. Sentry runs from `main.dart` + `sync_queue_service.dart`. The marketing claim was a false statement that would have violated Play's Misleading Claims policy if submitted. Rewrote to "Anonymous diagnostics only — Hound uses standard crash reporting and aggregate usage analytics to fix bugs and improve the model; you can opt out from Settings → Data & Privacy. No personal data is ever sold."
  What to do differently: For ANY marketing claim about app behavior or data practices, audit against the actual implementation BEFORE the claim ships. Specifically: claims about "no X" (no tracking, no ads, no accounts) must be verified by grepping pubspec.yaml + main.dart for the relevant dependencies. The bias for claims-without-verification is highest when writing marketing copy in a sustained flow — drift checks belong INSIDE the copy-writing loop, not as a separate after-pass. Logged in Failure_Patterns as `marketing-claim-without-deps-audit`.
  Score: 0.9

- Date: 2026-05-11 (screenshot pipeline session)
  Correction: Initial plan committed Task #3 to "Build integration_test screenshot harness" assuming this was the right tool for Android screenshot capture. Started the task: needed to add `integration_test` to `dev_dependencies`, write a test driver that exfiltrates PNG bytes (`test_driver/integration_test.dart`), then override `kennelServiceProvider` + `playerProvider` + `comboProvider` + `flashChallengeProvider` + `analyticsProvider` for each widget under test (all of which throw `UnimplementedError` until overridden), plus seed Hive boxes per test. Total scope: ~3 hours of test plumbing for screenshots that would be captured once and never re-run. Pivoted to: kDebugMode-gated seed function (15 min) + `adb shell screencap` interactive PowerShell script (15 min). Same output, ~10× faster, no test override boilerplate. Reverted the integration_test dependency addition before committing.
  What to do differently: For one-time marketing deliverables, the test/automation framing is often wrong. `integration_test` is correct for golden-image regression on shipped UI. For "capture this specific state once for a launch asset," seed-script + manual capture is the right shape. Apply this filter early: "will this artifact be regenerated repeatedly, or once?" If once, prefer simpler tooling.
  Score: 0.7

## Related Notes

- [[Failure_Patterns]]
- [[Memory]]
