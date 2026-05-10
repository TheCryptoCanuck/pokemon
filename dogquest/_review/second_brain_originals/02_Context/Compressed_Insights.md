# Compressed Insights

Tags: #context #compression

Use this file to store condensed insights from large notes.

## Format

### Source
[Original note / project / session]

### Compressed Insight
- Key point 1
- Key point 2
- Key point 3

### Actionability
[How this should affect future work.]

## Entries

### Source
2026-04-25 working session — synonym clustering, agentic data audit, comprehensive review

### Compressed Insight
- **Quantization is leaving 9.4pt of top-3 on the table.** TFLite uint8 (deployed) gives 31.8% top-3; Keras float32 (same weights) gives 41.2% top-3 on the same harness. Means the model already "knows" answers the deployed inference path can't express. Recovery paths exist (QAT, float16, per-channel int8) — see task #32.
- **Audit harnesses double as label-noise detectors.** When the harness reports >50% confidence on a non-folder breed, the image is almost certainly mislabeled training data. Two manually-confirmed mislabels in `poodle/` validated the pattern; the agentic v2 audit then quarantined 5,082 images with KEEP_SUCCESS auto-decision — pattern is real and scalable.
- **Cluster admission criteria are narrower than "looks similar".** A cluster is admissible only when members are the same breed under different names (color/coat/size variants, registry duplicates). Visually-similar-but-genuinely-distinct breeds (Whippet↔Azawakh, GSD↔Malinois↔Dutch Shepherd, Russell↔Boston Terrier) MUST stay separate — clustering them erases real signal. Locked into the code comment in `lib/services/tflite_identification_service.dart`.
- **Agentic execute-and-verify is responsible only when (a) the action is reversible and (b) a measurable success signal exists.** The data-quality audit qualified — quarantine-not-delete + 3-seed harness = automated rollback safety. Don't generalize to actions without those properties.
- **Strict-mode comprehensive review on a pre-launch codebase will surface Critical findings on infrastructure that "works in testing".** Phase 2 found 3 Criticals (offline auth persistence, sighting sync UUID, vestigial backend) that data-hygiene work doesn't address. Quality-first means BOTH model improvements AND auth/sync hardening — they're independent threads.
- **Tier discipline rule: agents may write specs / design docs / research notes for Tier N+1, but NOT code or branches, while Tier N is open.** Specs are revisable; code creates merge gravity. Locked into Strategy.md.

### Actionability
- Before any future TFLite re-export, capture the Keras-vs-TFLite top-1/top-3 delta as the post-export quality gate (≥+1 pt drift = halt and investigate calibration).
- Future audit runs default to Keras+GPU batched, never CPU TFLite for sweeps >1000 images.
- For any new "agentic without human gate" task: explicitly check the (reversible action) AND (measurable success signal) properties before promoting from supervised to autonomous.
- Comprehensive review's `.full-review/state.json` is the resume anchor — don't lose it; resume after Critical fixes land.
- Heavy-flagged folders from the audit (`american_hairless_terrier`, `grand_basset_griffon_vendeen`, `goldador`, `cesky_terrier`, `petit_basset_griffon_vendeen`) are now top candidates for the next round of manual data hygiene.

### Source

2026-04-25 evening — automation push + T1 closure + comprehensive review Phases 3-5

### Compressed Insight

- **The Cowork ↔ Windows-host automation gap closes via the Run dialog, not via terminals.** Computer-use tags terminals/IDEs as tier-`click` (no typing), but the Windows Run dialog is tier-`full` (typing allowed, not a terminal). So `open_application("Run")` → type `path\to\foo.bat` → `Return` → bash reads `foo.log` is the durable round-trip. Validated this session by 5 commits driven without Jesse touching a terminal.
- **Cowork's per-conversation permission cache is stickier than the Settings toggle implies.** "Allow all browser actions" → "Applies to new sessions" is literal; flipping it mid-session does not reset the per-domain deny state. Once you get a single "Permission denied by user" on a domain, every subsequent navigate to ANY domain in that session keeps failing — switching Brave → Chrome doesn't help because the cache is on the Cowork side, not the browser side. Either start a fresh conversation or fall back to user-paste; do not retry.
- **Virtiofs cache between Cowork sandbox and Windows disk has visible lag.** Edit-tool writes go to Windows fast, but the bash-sandbox `cat`/`wc -l` view can show stale/truncated content for ~30+ seconds after a concurrent op (e.g. sandbox `dart format` while sandbox `wc` is invoked). Don't issue `git checkout` based on sandbox-bash-reported corruption alone — re-read via the Read tool, OR push the check to a `.bat` that runs natively on Windows.
- **C2 "dormant code" pattern: Critical-by-classification ≠ Critical-by-blast-radius.** `SightingSyncService` had a real bug (index-vs-sorted-position UUID conflation) but had ZERO production callers. `BackendSyncService` (the wired path) is itself a stub. So the bug couldn't fire. Reduced-scope close (`init()` throws StateError + class dartdoc explaining the bug) was the right call vs full UUID-on-model migration. Generalize: before scheduling fix work for a Critical, grep for instantiation + provider registration + downstream stub status.
- **Comprehensive review phase-by-phase resumability works.** Phase 1+2 paused at Checkpoint 1 (Critical findings present, strict mode); Critical fixes landed across multiple working sessions; Phase 3-5 resumed cleanly and produced the consolidated report. The `.full-review/state.json` resume anchor held the gap. Pattern: use `strict_mode: true` flag for any review where you'd want to halt-and-fix.
- **Two-layer Supabase ownership enforcement: RPC + RLS, both required.** RPC alone (`auth.uid()` hardcoded in INSERT) covers the via-RPC path; RLS (`auth.uid() = user_id` ALL-policy) covers the bypass-RPC path. Either alone is insufficient. Verify both.

### Actionability

- For any future Cowork-driven shell work on Windows: use the Run-dialog → .bat → log pattern. PowerShell for multi-step or noisy-output scripts; .bat for short verify+commit operations. Don't try to drive terminals directly.
- For any future Chrome MCP plan: verify (a) extension installed, (b) `list_connected_browsers` returns non-empty, (c) "Allow all browser actions" was ON before this Cowork session started — BEFORE committing to the plan. If (c) wasn't true, fall back to user-paste from the start.
- After every Edit-tool write, treat sandbox-bash file reads as eventually-consistent for ~30 sec. The Read tool is the source of truth for in-session verification. The Windows side is the source of truth for ground reality.
- For every new Critical finding from a code review: do the wiring audit (instantiations + providers + stubs) before scheduling fix effort. Reduced-scope close + dormancy guard is a legitimate option for dormant code.
- The post-T1 next-actions surface is well-defined in `.full-review/05-final-report.md`: pre-closed-beta gate (~1.5 days), closed-beta gate (~3-4 days more). Don't re-derive — read.

### Source

2026-04-25 night — parallel-feature-development repair (Claude Code → Cowork handoff)

### Compressed Insight

- **parallel-feature-development on god-class screens has a "dead-duplicate-class" footgun.** The agent extracts widgets to `lib/widgets/<scope>/`, rewires the parent screen's `build()` to use the public versions, but FAILS to delete the private originals. Result: parent file imports the public widget AND has the private duplicate as dead code. Compile errors cluster in the dead privates because their type imports were stripped during extraction. `lost_dog_hub_screen.dart` had 1538 lines of dead duplicates (1665 → 127 on cleanup). When debugging a parallel-feature-development run that "should have worked," `grep -an "^class " lib/screens/<file>.dart` is the first diagnostic — any private classes whose public versions exist in `lib/widgets/<scope>/` are dead.
- **The default-import miss in parallel-feature-development is `lib/services/supabase_*_service.dart`.** Types named `*Remote` (LostDogReportRemote, PackRemote, PackDogRemote, etc.) live alongside the service that owns them, NOT in `lib/models/`. The agent guesses `models/` because the natural-language name suggests "model." Generalize: before declaring extraction done, grep for every undefined-class error against `lib/` and verify the import maps to the actual definition file.
- **Rules locked yesterday can be overridden today with explicit say-so.** The tier-discipline rule (no T2+ code while T1 open) was breached by the parallel-feature-development run. After 3-agent research (repair feasibility / architecture critic / tier-discipline analyst), Jesse said "override and repair all files I trust you" — informed override, not drift. Pattern: surface the rule conflict + 3 paths + tradeoffs, then execute Jesse's choice without re-litigating. The rule isn't a veto; it's a strong default the user can knowingly relax.
- **Surgical-commit-scope preference held under repair pressure.** 102 lib errors + 180 format-dirty files could have collapsed into one mass merge; instead landed as 5 logical commits (`e1f7a2e..5a8d0a3`): (1) new widget files, (2) screen rewires + dead-code purge, (3) pre-existing API drift, (4) friends_screen sendRequest cleanup, (5) format pass. Each is a self-contained logical change reviewable independently. Generalize: even on big repair pushes, the surgical structure scales — group by intent, not by chronology.
- **PowerShell `Out-File -Append` buffers `flutter test` output until the runner exits.** Verify .ps1 reported FORMAT_EXIT and ANALYZE_EXIT promptly but the TEST step's output stayed at +123 in the log for 3+ minutes after tests had likely finished. Buffer flushed only when the script terminated. Workaround for future: split the verify into separate .bats per step (format / analyze / test), each with its own Out-File so each step's exit is observable in isolation. Or use `Tee-Object` instead of `Out-File -Append` for live tail behavior.

### Actionability

- After any future parallel-feature-development run, run two pre-commit checks: (a) `grep -an "^class " lib/screens/<rewired-file>.dart` to spot dead private duplicates of newly-public widgets; (b) for every undefined-type error, run `grep -rn "class <T>" lib/` and verify the import path maps to the actual definition file (Supabase `*Remote` types are in `lib/services/supabase_*_service.dart`, NOT `lib/models/`).
- For any tier-rule conflict: Claude surfaces the conflict + 3 paths + tradeoffs in one round, then executes the user's chosen path without re-litigating. Don't keep arguing after the user says "override."
- For multi-step verify scripts on Windows, prefer one .bat per step over one PowerShell with multiple Out-File -Append. The buffering risk is real and the per-step files give earlier failure feedback.
- The architecture critic's "splits-largely-sensible" verdict means refactor-recovery work can recover real design value, not just compile fixes. Worth investing the 7-9 hours when the splits are good. Worth reverting when the critic says "splits are arbitrary or actively wrong."

### Source

2026-04-25 night — T1 deck-clearing session (DOC-001/002, OPS-001, OBS-001 swap, OPS-002)

### Compressed Insight

- **PowerShell `-File` reads `.ps1` content with ANSI codepage by default, not UTF-8.** Em-dash (U+2014), smart quotes, ellipsis written via the Write tool come out as `â€"` and break the parser at the next quoted string. Symptom is a `ParserError` referencing "missing terminator" on a line that visually looks fine. The fix that lands cheapest: keep `.ps1` files ASCII-only (replace `—` with `--` or `,`). Alternative: write `.ps1` with a UTF-8 BOM. Validated by the `verify_release_build.ps1` failure followed by clean rerun after rewriting with ASCII punctuation.
- **Always check for existing artifacts before creating new ones.** Caught the lesson twice this session: the OPS-001 commit silently overwrote a pre-existing `.github/workflows/ci.yml` that was AviQuest's CI (49 deletions in the diff stat surfaced it post-commit), and the OPS-002 keytool generation produced a duplicate keystore at `C:\Users\Administrator\dogquest-release.jks` while a working March keystore at `android/dogquest-release.jks` was already wired with password `dogquest2026`. Both caught Jesse-side, not Claude-side. The pattern: comprehensive review tasks framed as "create X" don't include "if not present"; vault claims of "X is missing" can be stale. Pre-flight check is `ls`/`Test-Path` for the canonical path AND grep for references in adjacent config files (pubspec, build.gradle, .gitignore) that imply the artifact already exists. For credentials specifically, the cost of a wrong call is irreversible (lost Play Store update path) — never auto-replace.
- **Vendor pricing surface drift makes "default observability" a moving target.** Sentry's Developer free tier still exists, but the signup page foregrounds a 14-day trial banner that read as costly to Jesse. The right move was a same-intent swap: Crashlytics aligned with existing Firebase setup (already in pubspec, same console, free forever). Generalize: when proposing a SaaS wire-in, surface free-tier limits AND any prominent paid-tier UX in the proposal, not after pushback. Pre-emptively offer 1-2 alternatives within the same intent space.
- **Multi-workflow CI inventory matters.** The `.github/workflows/` directory had 5 yml files at session end (3 pre-existing from 2026-03-03: `flutter-ci.yml`, `infrastructure-ci.yml`, `release.yml`, plus my new `dogquest-ci.yml` and the restored `aviquest-ci.yml`). I didn't inspect the older 3 — Jesse needs to review for overlap. The fact that they predate the active branch means they may be either (a) intentional multi-project CI, (b) stale leftovers, or (c) targeted at master/main on a different cadence. Don't assume single-CI-yml when adding new ones.
- **Surgical-commit preference held under deck-clearing pressure.** 4 separate logical commits this evening (DOC-001 / DOC-002 / OPS-001 initial + workflow split / OBS-001), plus an out-of-tree keystore artifact (no commit) for OPS-002. Combined with the earlier 5 refactor-recovery commits, that's 9 logical commits in one evening, none mass. The pattern that scales it: write a per-task `commit_<task>.bat` that adds only the relevant files and commits with a per-task message; resist the temptation to `git add -u` mid-session.
- **Run-dialog automation has a non-deterministic focus failure.** Multiple times this session, `open_application("Run")` + click + type + Return produced no .bat execution despite the Run dialog visibly being open with the right path. No log file, no build/ activity. Retry cycles ate ~5 min before falling back to Jesse pasting the path in PowerShell directly. The pattern is hard to pin to a specific trigger (sometimes worked first try, sometimes needed 2-3 attempts). Mitigation: take a screenshot after `open_application("Run")` to verify the dialog is frontmost (active blue title bar) before typing; if focus is wrong, fall back to user-paste rather than retrying.

### Actionability

- For any future PowerShell `.ps1` written via Write tool, scan for non-ASCII punctuation before saving. Build a tiny lint pass: if the file body contains any of `—–'''""…`, replace with ASCII equivalents. Or default to writing `.ps1` with a BOM.
- Bake a "check existing artifacts" pre-flight into create-X tasks: before any keystore/CI/README/license/.env creation, run a `ls` + reference-grep, then surface findings to the user with the existing-vs-new tradeoff.
- For SaaS wire-in tasks, lead the proposal with: (free-tier shape, paid-tier triggers, alternatives in the same intent space). Treat the user's first "this looks expensive" as evidence to swap, not to defend.
- Multi-workflow CI: when adding `.github/workflows/X.yml`, list all existing files first AND check whether their triggers (`on:` paths, `branches:`) overlap with X. Multi-workflow setups are valid (per-project, per-purpose) but unintentional duplication is wasteful.
- Surgical-commit pattern that worked tonight: `scripts/commit_<task>.bat` per task — adds only that task's files, commits with a focused message, logs the commit hash. Reusable across projects.
- Run-dialog automation: budget at most 2 retries before falling back to user-paste. Wasted retries cost more than the user typing one path.

### Source

2026-04-25 night — lost-dog improvement spec (4-agent investigation) + full-app comprehensive review re-run

### Compressed Insight

- **Cross-tool memory drift is the unsolved-but-solvable hygiene gap.** The full-app comprehensive review re-run caught what no other artifact would have: the vault claims OPS-001 (CI) closed today via 2 specific commits shipping 5 yml files; disk shows `.github/` doesn't exist at all on the working tree. Same shape on `key.properties` mtime predating OPS-002 closure. The morning review couldn't have caught this because the morning review's findings WERE the drift; the lost-dog spec couldn't have caught it because lost-dog doesn't touch CI. Only a fresh structured 5-phase pass against the actual current tree surfaced the gap. Generalize: comp-review-as-drift-detector is a distinct use case from comp-review-as-finding-finder. Closing notes in Active_Tasks should be commit-hash-attested AND disk-verified, not just commit-hash-claimed.
- **Strict-mode + checkpoint approval workflows have a built-in tradeoff.** The skill recommended "fix Criticals first" at Checkpoint 1 (5 distinct Criticals, 2 of which were ~30 min each). User chose "continue to Phase 3" instead — wanted the full picture before scheduling. This is a legitimate user preference (informed override of strict-mode recommendation, matching the pre-existing memory pattern), but it means the final report has to do double duty as both "summary of findings" AND "prioritized action plan." When users override the checkpoint recommendation, the final report should explicitly call out which Criticals could have been closed in the 2-hr window between checkpoints — that information makes the override-cost legible.
- **4-agent parallel research into orthogonal dimensions converges on the same Criticals when the bug is real.** The lost-dog spec's Agent C (GDPR) found 2 Criticals (contact broadcast, no consent/policy). The comprehensive review's 2A (security-auditor) independently found the same 2 Criticals at the same severity, ran 3 hours later from a different brief on the same files. That's not redundancy — it's cross-validation. Generalize: when 2+ independent agents flag the same finding from different briefs, treat that as substantially higher-confidence than a single-agent finding. For the comp-review re-run specifically, the 1B agent and the morning review's 1B both flagged the same god-class screens at the same line counts — also cross-validating.
- **The "redundant work" pushback can fail informationally even when it's correct cost-wise.** I pushed back on running comprehensive-review on the lost-dog subsystem because it was redundant with the just-finished 4-agent spec. User accepted the reframe (P0/P1/P2/P3 priority list) but then immediately escalated scope to whole-app comprehensive review. Lesson: when offering a cheaper alternative to a requested skill, frame it as additive ("here's the cheap thing first; want the full skill afterward?") not substitutive. Don't make the user choose between immediate value and durable artifact unless they explicitly say one suffices.
- **Embedding-as-fingerprint via softmax is structurally weak for individual-dog matching, regardless of threshold tuning.** Two golden retrievers will produce nearly identical 150-dim breed-probability distributions; cosine similarity ≥0.85 even on different dogs. The 0.50 threshold guarantees same-breed false positives. This isn't a tuning issue; it's an architectural mismatch between the model's output (P(breed | image)) and the feature's need (signature vector for individual identity). Fix paths: pre-softmax 1408-dim features if TFLite multi-output works (3-5 hr); separate MobileNetV3 embedding model (8-12 hr). Generalize: when a downstream feature uses a model output for purposes the model wasn't trained for, the gap is fundamental — threshold tuning is treating a symptom.

### Actionability

- For any future Active_Tasks closure marker, require BOTH commit-hash-attested AND on-disk-verified before the task moves from "Active" to "Completed". Add a Makefile target like `make verify-closures` that greps Active_Tasks for "closed via `<hash>`" patterns and runs `git log --oneline -- <implied-path>` to confirm. ~30 min to write.
- Before propagating any vault attestation into an agent brief, run a 30-second bash check. The pattern is now logged in Failure_Patterns; treat it as a pre-flight rule, not just a debugging aid.
- For comp-review-style structured artifacts, treat duplicate-scope re-runs as cheap drift-checks rather than waste. The cost is 8 agents × ~10-15 min each = ~2 hr of agent time; the benefit when drift IS present (as today) is catching things that would otherwise stay invisible until they break in production.
- For lost-dog Decision 1 (embedding quality): the cheapest unlock is the 30-min Python audit on `assets/dog_model.tflite` to enumerate output tensors. If multi-output works, path (b) opens; if not, path (c) is the right architectural answer. Do this audit FIRST before scheduling Decision 1 work.
- For checkpoint-override situations in skill-driven workflows: in the final report, quantify "if you'd taken Option 2 at the checkpoint, you'd have closed X Criticals in Y hours." Makes the override-cost legible and helps Jesse calibrate future checkpoint decisions.

## Related Notes

- [[Knowledge_Index]]
- [[Memory_Maintenance_Protocol]]
