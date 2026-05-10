# Failure Patterns

Tags: #memory #failure #self-improvement

Use this file to prevent repeated mistakes.

## Format

- Failure:
- Trigger:
- Fix:
- Score:
- Last seen:

## Current Failure Patterns

### assert-compiled-out-in-dart-release (Score 0.9, NEW 2026-05-01)

- Failure: `assert(condition, 'message')` in Dart is compiled out entirely in release builds. Any env guard, input validation, or session-state check written as `assert()` is a complete no-op for production users — no exception, no log, silent pass-through. Found in `main.dart` (`_assertSupabaseEnv`), `api_client.dart` (`assertBaseUrl`), and `sync_queue_service.dart` (operation validation). All three guards appeared to work in debug builds, giving false confidence they'd fire in release.
- Trigger: Writing any guard that must hold in production (env var non-empty, session authenticated, argument valid) using `assert()`. Especially common when Dart's `assert()` is reached for by reflex for "programmer-error" cases — that framing is correct, but Dart's definition of "programmer error" excludes runtime environment conditions.
- Fix: `if (!condition) throw ArgumentError('message')` for programmer-error cases (invalid argument values). `if (!condition) throw StateError('message')` for runtime state violations (no auth session). Never use `assert()` for any guard that must fire in release. Reserve `assert()` only for invariants that are genuinely impossible in correct code AND don't need to catch misconfiguration.
- Score: 0.9
- Last seen: 2026-05-01 (4-agent audit found all three; swept lib/ with grep, caught all instances; fixed in Sprint 12)

### flutter-animate-autoplay-false-stuck-at-initial-state (Score 0.8, NEW 2026-05-01)

- Failure: `flutter_animate` with `autoPlay: false` leaves the widget at the animation's INITIAL state — opacity 0 for `.fadeIn()`, scale 0.9 for `.scale()`. It does NOT snap to the final visible state. Used `autoPlay: !_hasAnimated` on kennel grid owned cards: after first render `_hasAnimated = true`, so any card mounted later (e.g. a newly-owned breed returned from the result screen) rendered with `autoPlay: false` and stayed permanently transparent. The Rottweiler and other freshly-added breeds were present in the grid but completely invisible.
- Trigger: Conditional `autoPlay: !someBool` where the bool flips to `true` after first render. Any widget that gets mounted later — by being a new widget type at a grid position (ghost→owned), by being newly sorted into range, or by any other mid-session addition — picks up `autoPlay: false` and freezes at opacity 0.
- Fix: (a) Use `autoPlay: true` if you want newly-appearing cards to animate in on mount. (b) Remove the `.animate()` wrapper entirely for cards that should appear instantly — owned collection cards are the primary example. Ghost cards can keep the stagger via `autoPlay: !_hasAnimated` for the initial load experience. Never mix the two: ghost cards animate on first load, owned cards appear instantly on promotion.
- Score: 0.8
- Last seen: 2026-05-01 (kennel_screen.dart owned breed cards invisible after returning from result screen; `.animate()` removed from owned card path, fixed)

### bash-mount-scope-mistaken-for-read-tool-scope (Score 0.85, NEW 2026-04-30)

- Failure: Declaring monorepo-scope-limited based on `ls /sessions/.../mnt/` showing only one subproject mounted, when Read/Glob/Edit tools on the underlying Windows paths actually reach the entire filesystem. Concrete instance: Pass 1 of /deployment-validation:config-validate scoped to dogquest only because bash sandbox showed only `dogquest` mounted. Wrote the scope limit into the findings doc as a "scope realized" caveat. Jesse responded "you have access to everything" — a single Glob on `C:\Users\Administrator\AviQuest-\.github\workflows\*.yml` returned all 5 yml files immediately. Pass 2 covered the full monorepo (CI yml + terraform + backend + supabase) without further sandbox limitation.
- Trigger: Scope-checks at the start of a multi-file task. The bash sandbox listing (`ls /sessions/.../mnt/`) is the easiest evidence to gather, and it's the LIMITING evidence — Read tool reach is broader. Especially common when the user says "full monorepo" and you assume the sandbox mount is the boundary.
- Fix: Bash mount limit ≠ Read tool reach. Confirm Read/Glob reach BEFORE declaring scope-limited. Quick test: `Glob "C:\Users\Administrator\AviQuest-\*"` — if it returns files, Read/Edit on those Windows paths work, regardless of bash mount. The two filesystem views in Cowork: bash sees its sandbox-mount paths; Read/Glob/Edit see Windows paths directly. Document this as a Memory entry too (durable across sessions).
- Score: 0.85
- Last seen: 2026-04-30 (config-validate Pass 1 → Pass 2 correction).

### multi-agent-leverage-conflict-resolved-by-sequencing-not-picking (Score 0.6, NEW 2026-04-30)

- Failure: When 6 specialist agents are spawned to propose "next steps" in their domain, each picks their own "single highest leverage" item — those picks naturally conflict (mobile says T5-feature-restore, backend says SUPA-001, ML says v6 QAT retrain, UI says Phase 3 verify, deployment says CI-002 release.yml retarget, test says T5-B redesign). The temptation is to pick a "winner" across tracks; that's wrong. Each domain's leverage claim is real — they're optimizing different dimensions. Picking one means ignoring 5 other valid claims.
- Trigger: Synthesizing parallel multi-domain proposals into a single roadmap. Especially when proposals are written in isolation and each agent doesn't see the others.
- Fix: Resolve via sequencing, not picking. Layer the proposals as parallel tracks (one per agent). Identify week-1 must-land items by intersection of "blocks other tracks" + "small effort". Draw critical-path arrows BETWEEN tracks. The synthesized plan should preserve all 6 highest-leverage picks but order them so each unlocks downstream work. The synthesizer's job is sequencing, not selecting.
- Score: 0.6
- Last seen: 2026-04-30 (six-agent next-steps planning session).

### admob-test-id-as-production-fallback-shipped-to-real-users (Score 0.75, NEW 2026-04-30)

- Failure: Using Google's documented test AdMob ad-unit ID as the `defaultValue` for `String.fromEnvironment(ADMOB_*)` lookups means release builds without dart-define silently serve test placeholders to real users. AdMob policy treats real-traffic patterns on test units as a violation. Same anti-pattern as API_BASE_URL hard-defaults caught 2026-04-28 — defaults that "just work" in dev are exactly what hide misconfiguration in prod.
- Trigger: Adding any new `String.fromEnvironment(...)` lookup with a non-empty `defaultValue` for a config that should fail loudly when missing in release. The temptation is to make local dev "just work" — but the same convenience leaks to production.
- Fix: Empty default + caller-side check OR debug-only fallback gated by `kDebugMode`. For ad units: `static const _configuredId = String.fromEnvironment('ADMOB_*'); String get _adUnitId => kDebugMode ? _testId : _configuredId;` — empty `_adUnitId` short-circuits the load with an info log. For URLs/keys: assert non-empty in main, like API_BASE_URL pattern. Apply this pattern to ANY new --dart-define going forward. Generalize: defaults that "just work" in dev are config smells in prod.
- Score: 0.75
- Last seen: 2026-04-30 (config-validate ENV-002 fix in `lib/services/ad_service.dart:48` and `lib/widgets/dogquest_banner_ad.dart:25`).

### agent-claims-action-input-affected-by-working-directory (Score 0.7, NEW 2026-04-30)

- Failure: Subagent claims a GitHub Actions workflow has a path bug because `defaults.run.working-directory: ./dogquest` would double-up the path on `actions/upload-artifact@v4`'s `path` parameter (yielding `dogquest/dogquest/...`). Reality: `working-directory` only applies to shell commands in `run:` steps; action inputs (`path:`, `name:`, `with:` keys) execute in the repo root regardless. The agent's reading of GitHub Actions semantics was wrong. Almost surfaced the false finding to Jesse as a MEDIUM severity item; caught at synthesis time by re-reading the docs.
- Trigger: Subagent audits any workflow yml that combines `defaults.run.working-directory` with an `actions/*-artifact` upload/download step. Or any claim that a path resolution depends on working-directory when the path is an action input.
- Fix: When validating GitHub Actions claims, remember: `working-directory` only affects `run:` steps. Every action input runs in the repo root. Cross-check before adding the finding to the consolidated report. Add this explicit reminder to subagent briefs for CI-yml audits going forward.
- Score: 0.7
- Last seen: 2026-04-30 (deployment-engineer agent flagged false positive on `dogquest-ci.yml:98` upload-artifact path during config-validate Pass 2).

### cowork-bash-vs-read-tool-filesystem-desync (Score 0.65, NEW 2026-04-26)

- Failure: After using the Edit tool to append content to a file, the Read tool sees the updated content (correct line numbers, new sections present) but `mcp__workspace__bash` running `cat`/`grep`/`wc -l` on the same file returns the OLD content (pre-edit line count, no match for the appended text). Concrete instance: edited `.second_brain/01_Memory/Memory.md` to add a "Project conventions" section + 3 bullets; Read showed 84 lines with the new content; bash `wc -l` showed 69 lines and `grep "Project conventions"` returned no match. Almost concluded the edit had failed and was about to re-apply it (which would have created a duplicate).
- Trigger: Verifying Edit-tool writes via the bash tool. Common during end-of-session vault sweeps where you want to confirm all writes landed.
- Fix: The Read tool (which operates on the Windows path `C:\Users\Administrator\...`) is the source of truth for what's on disk. The bash tool (which operates on `/sessions/vigilant-peaceful-ramanujan/mnt/...`) reads from a Linux mount that may cache reads or have async write propagation. For verification of Edit-tool writes, prefer Read over bash. If bash MUST be used (e.g., to grep across many files), accept that recently-written files may show stale content; cross-check with a Read.
- Score: 0.65
- Last seen: 2026-04-26 (vault hygiene end-of-session sweep — bash reported Memory.md and Compressed_Insights.md edits as missing; Read confirmed they were present).

### addendum-prepend-orphans-existing-section-body (Score 0.6, NEW 2026-04-26)

- Failure: When prepending a new H2 section above an existing H2 in a markdown file, anchored to the existing H2's HEADER rather than its body, the existing section's body becomes orphaned between the new section and the next H2. Concrete instance: inserted `## Repo layout (monorepo)` immediately after `## Project Overview` in CLAUDE.md, leaving Project Overview header with no body and the actual overview text floating between the new section and `## Tech Stack`. Jesse caught it via `git diff` paste.
- Trigger: Using `Edit` with a small anchor like `## Section\n` to append content; the existing section's body is below that anchor and gets pushed to live between the new section and the next header.
- Fix: Anchor on `## Section\n\nbody text` (header + blank + body), then append the new section AFTER the body, not after the header. Alternative: read the section structure first (`grep -n '^##'`) to identify body-line ranges, then place the new section between completed sections (after one body, before the next H2).
- Score: 0.6
- Last seen: 2026-04-26 (CLAUDE.md monorepo addendum placement; restructured in same turn).

### dogquest-claude-md-aviquest-default (Score 0.65, NEW 2026-04-26)

- Failure: Defaulted to "factual completeness" framing when drafting `dogquest/CLAUDE.md` content — included AviQuest sibling list, fork lineage prose, literal `AviQuest-/` paths, `/aviary` legacy route diff bullets, BirdNET diff bullets. Jesse rejected: "i dont want anything mentioning aviquest in the md". Required full scrub of 8 references after the fact.
- Trigger: Drafting or editing any file inside `dogquest/` that documents the project (CLAUDE.md, README.md, top-level docs/). The completeness instinct is to acknowledge fork heritage; that's wrong for DogQuest's own surface.
- Fix: For files INSIDE `dogquest/`, default to AviQuest-free framing. Use placeholders: `<repo-root>/` not `AviQuest-/`; "the monorepo root, one directory above `dogquest/`" not the literal Windows path. Don't write "forked from AviQuest" or "Differences from AviQuest" sections. Vault-side files (`.second_brain/`) and the monorepo root MAY reference AviQuest as factual context — this is a dogquest/-only policy. Logged as Memory.md project convention + Decisions.md entry.
- Score: 0.65
- Last seen: 2026-04-26 (CLAUDE.md scrub).

### subagent-narrow-regex-false-positive-orphan (Score 0.7, NEW 2026-04-26)

- Failure: A delegated Explore-tier subagent reported `conflict_resolution_service`, `ad_service`, `device_token_service`, `pull_sync_service` as "candidate orphans" with 0 live refs, recommending deletion. Verification with both CamelCase and snake_case patterns (`ConflictResolutionService|conflict_resolution`) showed 2 files referencing each — the agent's grep was filtered to one casing only and missed the actual class refs (e.g. `import '...conflict_resolution_service.dart'` AND `ConflictResolutionService(...)` constructor call). If the parent had trusted the agent and ran the deletes, T5-A test `sync_services_test.dart` and `ad_service_test.dart` would have broken on next CI run.
- Trigger: Subagent reports zero refs for a Dart symbol; the agent's grep used only snake_case (file path) OR only CamelCase (class name), not both. Particularly common when the agent's tool reports default to file-name patterns but the actual usage is class-instantiation in different files.
- Fix: For Dart orphan checks, the parent must run a final verification with BOTH `grep -E "ClassName|snake_case_basename"` patterns before any delete decision. Treat subagent zero-ref claims as "lower bound — confirm with widened pattern". Build the verification step into the agent brief: "report grep command + match count, AND verify with the alternate-casing pattern; flag mismatches".
- Score: 0.7
- Last seen: 2026-04-26 (Explore agent reported 4 false-positive orphans during vault hygiene; verification step caught all 4 before any delete).


### vault-claim-trust-without-disk-verification (Score 0.95)

- Failure: Propagating vault closure claims ("OPS-001 closed", "supabase/ schema is in repo", "commit `abc123` shipped X") into agent briefs or downstream reasoning without first running an existence check on the artifact AND a `git log` resolution check on the commit hash. Caused multiple wrong conclusions this session: (1) Phase 4B of comprehensive review reported `.github/workflows/` empty against vault claim of 5 yml files; (2) symmetric failure on `supabase/` — claimed it didn't exist; disk showed 4 SQL files; (3) DRIFT-1 went through 4 verification passes because each pass trusted partial evidence.
- Trigger: Writing agent briefs, Active_Tasks updates, or in-session reasoning that quote prior closure markers (Active_Tasks, Decisions, prior review docs) without verifying the underlying disk + git state in the same session. Especially common when the vault claim was attested in a prior session and may be stale.
- Fix: Closure claims need TWO verifications: (a) artifact exists on disk (`Read`/`ls`/`Test-Path`/`Glob`); (b) commit hash resolves via `git log --all --oneline -- <path>` from the **repo root**, not from a subdirectory. Both must pass. If only one passes, treat as half-closure: the work was done, the historical record is broken (or vice-versa). Record the resolved commit hashes in the closure marker; if hashes don't resolve, REOPEN.
- Stronger rule: a closure block claiming `commits abc123 + def456` must satisfy `git log --all --oneline -- PATH | grep -E 'abc123|def456'` returning at least one match. If hashes don't resolve via `git log --all`, the closure is phantom and must be reopened. Run this check on every closure block written by a prior session before trusting it.
- Score: 0.95 (raised from 0.9 — DRIFT-1 verification 2026-04-25 evening confirmed the OPS-001 closure was **partially-true with fabricated audit-trail**: claimed commit hashes were real but originally couldn't be resolved because the diagnostic was running with the wrong cwd. Sprint 0's DRIFT verification protocol is the only thing that surfaced it through 4 passes.)
- Last seen: 2026-04-25 evening (DRIFT-1 final verdict: OPS-001 commits c949c92 + d859f81 ARE real, on local 18-ahead-of-origin queue; CI Run #6 went green after pushing).

### dont-infer-absence-from-partial-listings (Score 0.85, NEW 2026-04-25 evening)

- Failure: Drawing negative existence claims ("file is missing", "directory doesn't exist", "no such path") from absence in a long paginated listing the user pasted, without an independent positive verification step. DRIFT-1 audit, pass 2: read Jesse's `git status` paste (~150 visible untracked entries), didn't see `../.github/`, concluded `.github/` doesn't exist on disk. Wrote that into the Active_Tasks correction as a verified finding. Reality: the dir DID exist with a 95-line working CI yml; the entry was scrolled past in the paginated output. The Read tool only saved me because Write demands a prior Read on existing files — I tried to overwrite and got "file has not been read yet," which surfaced the existence. If Write had succeeded silently, I'd have clobbered a working CI file and reported "fixed" on a non-broken thing.
- Trigger: Drawing negative existence claims from absence in a long paginated listing (>100 items), or from `git status` output the user paged through with `less`/`more`, or from any output sorted in an order that hides what you're looking for.
- Fix: Negative existence claims about disk state require their own positive verification step. `git status | grep PATTERN` is necessary but not sufficient — the listing may be truncated, the file may be gitignored without the user knowing, or it may be on disk-but-untracked-and-buried in a long list. Pair every negative claim with a `Glob`/`ls`/`Test-Path` against the canonical filesystem path. For Cowork-on-Windows: `Read` on the suspected path is the strongest test (returns content if file exists, errors if not). For repos: `git ls-files --others --exclude-standard --directory | grep PATTERN` is more reliable than scrolling status output.
- Score: 0.85
- Last seen: 2026-04-25 evening (OPS-001 DRIFT-1 — concluded `.github/` doesn't exist from absence in partial git-status output; disk Read showed file actually exists. Tool-level guardrail (Write demands Read first) prevented a clobber).

### git-log-cwd-relative-path-arguments (Score 0.85, NEW 2026-04-25 evening)

- Failure: Trusting `git log --all -- <relative path>` output without accounting for cwd. The `--` path argument is interpreted relative to the current working directory, NOT the repo root. So `git log --all -- .github/` from `dogquest/` queries `dogquest/.github/`, not the repo-root `.github/`. When the repo root is the parent of the cwd (monorepo subproject pattern), this produces "no commits found" on paths that DO have commits at the actual repo root.
- Trigger: Asking the user to run `git log -- PATH` or `git diff -- PATH` from a subdirectory of the repo root. Especially common when the user's prompt shows them `cd`'d into a subproject (e.g., `dogquest/`) but you're reasoning about repo-root paths (`.github/`, top-level configs).
- Fix: When verifying repo-state claims, ALWAYS specify paths from the repo root explicitly (`AviQuest-/.github/`) OR `cd` to the repo root first. Alternative: use absolute paths from any cwd — `git log --all -- C:/Users/Administrator/AviQuest-/.github/` works regardless of cwd. When in doubt, also pass `--all-match` or use `git rev-list` to verify commits independently. The DRIFT-1 four-pass loop happened because pass 2 trusted a cwd-relative `git log` that showed 0 results when the actual commits existed.
- Score: 0.85
- Last seen: 2026-04-25 evening (DRIFT-1 pass 2 ran `git log --all -- .github/` from `dogquest/`, got empty result, concluded commits were phantom. Three more passes needed to recover ground truth.)

### god-class-extract-without-import-fixup (Score 0.9)

- Failure: parallel-feature-development agents extract widgets into new files but leave the **private originals in place as dead duplicates**, then half-rewire the parent to use the public extraction while the private duplicates still reference symbols they never imported. End state: parent imports public widget at line N, also has private duplicate at line M, both compile-checked, ~50 errors per affected screen because the dead private classes can't resolve types. Observed in DogQuest 2026-04-25 lost_dog_hub_screen — 51 errors, all from the dead private `_MissingDogsTab` / `_HelpFindTab` / `_LostDogReportCard` / `_BottomSheetAction` / `_RemoteLostDogCard` (lines 131-1665). The fix was deleting lines 128-end, dropping the file from 1665 to 127 lines.
- Trigger: Running parallel-feature-development on god-class screens where the agent's "split into sub-widgets" output produces public widgets in `lib/widgets/<scope>/` AND keeps the private originals in the screen file. Look for: many `error - The name 'X' isn't a type` and `Undefined name 'someProvider'` errors clustered in the parent screen file, NOT in the extracted widgets, and the parent file size barely shrinking despite a successful "extraction".
- Fix: Before declaring the refactor done, check `grep -an "^class \|^enum " lib/screens/<screen>.dart` and look for private classes whose public equivalents now exist in `lib/widgets/<scope>/`. If the screen has both, the private ones are dead — delete them. Cross-reference: which classes does the parent's `build()` actually CALL? (Look at lines 100-130 of the rewired screen — those are the live widgets. Anything else is dead.) Pre-flight check for future refactors: have the agent emit a "post-extraction live-vs-dead" map listing every class declaration in the parent and tagging each as live/dead.
- Score: 0.9
- Last seen: 2026-04-25 (lost_dog_hub_screen.dart — 51 errors clearing in one Write tool call when lines 128-1665 deleted)

### extracted-widgets-missing-imports (Score 0.85)

- Failure: parallel-feature-development extracted widgets reference types/symbols whose **import lines weren't carried over**. Most common: model classes from `lib/services/supabase_*_service.dart` (LostDogReportRemote, PackRemote, PackDogRemote, etc.), helper modules (`lib/helpers/game_helpers.dart` for `achievements`), package imports (`flutter_animate`, `go_router`, `flutter/services`, `share_plus`, `connectivity_plus`, `dart:io`), and sibling widgets.
- Trigger: After parallel-feature-development on a god-class refactor, errors of shape `Undefined class 'X'`, `The name 'X' isn't a type`, `Target of URI doesn't exist`, `The method 'animate' isn't defined for the type 'Container'`, `The getter 'ms' isn't defined for the type 'int'`, `The method 'push' isn't defined for the type 'BuildContext'`.
- Fix: For each extracted widget, run `grep -rn "class <UndefinedType>" lib/` to locate the source file, then add the import. Common case: types named `*Remote` live in `lib/services/supabase_*_service.dart`, NOT in `lib/models/`. The agent often guesses `models/<thing>.dart` because the natural-language name suggests a model — but in this codebase the Supabase remote shapes live alongside the service.
- Score: 0.85
- Last seen: 2026-04-25 (8+ widget files needed import fixes; see commits e1f7a2e..953bb92 for full pattern)

### powershell-unicode-em-dash (Score 0.85)

- Failure: PowerShell `-File` script execution chokes on **Unicode em-dash** (U+2014) characters in script content. The script is read as Latin-1 / Windows-1252 even when `-Encoding utf8` was used by the writer, so an em-dash byte sequence (`E2 80 94`) appears as `â€"` and breaks the parser at the next quoted string.
- Trigger: Writing `.ps1` content via the Write tool that contains em-dash, en-dash, smart quotes, ellipsis, or other Unicode punctuation. The Write tool's UTF-8 output is correct; PowerShell's default ANSI input pipeline is what breaks.
- Fix: Use ASCII-only punctuation in `.ps1` files. Replace `—` with `--` or `,`, replace `'`/`'` with `'`, replace `…` with `...`. Or save the .ps1 with a UTF-8 BOM (the BOM tells PowerShell to read as UTF-8). Cheapest: ASCII-only.
- Score: 0.85
- Last seen: 2026-04-25 (verify_release_build.ps1 errored on em-dash in "skipping signature inspection" comment block)

### powershell-brace-expansion-on-stash-syntax (Score 0.7, NEW 2026-04-25 evening)

- Failure: PowerShell expands `{N}` in command arguments as a token separator before passing to the underlying program. `git stash show stash@{0}` becomes `git stash show 'stash@' 'MAA=' 'xml' 'xml'` (PowerShell base64-encodes/expands the brace token oddly). Errors with `Too many revisions specified`.
- Trigger: Telling the user to run any `git stash` (or equivalent) command with `stash@{N}` syntax in PowerShell without quoting.
- Fix: Wrap the whole reference in single quotes: `'stash@{0}'`. OR use the bare integer: `git stash show 0`. The latter is shortest and works across shells.
- Score: 0.7
- Last seen: 2026-04-25 evening (vault-recovery diagnostic — `git stash show --name-only stash@{0}` errored; `'stash@{0}'` and `0` both worked)

### create-artifact-without-existence-check (Score 0.85)

- Failure: Creating new artifacts (CI workflow, keystore, config file) without first checking whether one already exists at the canonical path. The new artifact silently displaces the old one. Caught multiple times this session: (a) wrote a new dogquest-ci.yml at `dogquest/.github/workflows/` while the canonical one already existed at `AviQuest-/.github/workflows/`; (b) the OPS-002 keystore generation produced a duplicate at `C:\Users\Administrator\dogquest-release.jks` while a working March keystore at `android/dogquest-release.jks` was already wired in `key.properties` with password `dogquest2026`.
- Trigger: Comprehensive review tasks framed as "create X" without scoping language like "if not present." Same risk for: signing keys, CI yml, README, license, .env, fastlane config, anything that has a canonical filesystem location. The vault may also have stale "X is missing" claims from before someone else added X.
- Fix: Before any create-artifact task, run `Glob`/`Test-Path` for the canonical location AND grep for any references in `pubspec.yaml`/`build.gradle`/`*.properties`/`.gitignore` that would imply the artifact already exists. If found, present the existing-vs-create-new tradeoff to the user before acting. For credentials specifically: never auto-replace an existing keystore — the security cost of a wrong call (lost Play Store update path) is high.
- Score: 0.85
- Last seen: 2026-04-25 evening (CI yml duplicate at wrong location; surfaced when Write demanded a prior Read on the canonical file).

### working-tree-vs-origin-drift-on-tracked-files (Score 0.85, NEW 2026-04-25 evening)

- Failure: Tracked files in working tree have unstaged modifications that add new symbols/parameters/imports. New code (committed elsewhere) depends on those modifications. Local analyze passes because the modifications are visible. CI fails because origin has the pre-modification version. Whack-a-mole ensues — each strip surfaces the next dangling reference.
- Trigger: Multi-session work where some commits land but the supporting modifications to tracked files are left in unstaged drift. Compounded when `.gitignore`-adjacent files (the modified files in `git status`) are ignored as "unrelated drift."
- Fix: Before pushing to a CI-gated branch, run `git stash push -m diagnostic`, then `dart analyze` (or equivalent), to simulate origin's tree. Errors that surface are the dependencies origin will be missing. EITHER commit the necessary unstaged modifications, OR strip the dependent code from the about-to-push commits. Don't push and discover via CI failure — the iteration cost is high (each push is 3-5 min CI cycle).
- Score: 0.85
- Last seen: 2026-04-25 evening (Sprint 1 push triggered 5 successive CI failures, each surfacing a different unstaged-modification dependency: router.dart screen imports, main.dart service imports, help_find_tab.dart radiusKm/distanceKm, sync_services_test.dart SyncQueueItem)

### git-stash-u-loses-deeply-nested-untracked (Score 0.7, NEW 2026-04-25 evening)

- Failure: `git stash push -u -m "..."` on Windows with a working tree containing many untracked files at varying depths produces inconsistent results. The stash captures tracked-modified files and SOME untracked files but appears to silently miss deeply-nested untracked dirs. On `git stash pop` the missed files are NOT restored — they're simply gone from disk. Suspected interaction with CRLF normalization warnings filling the stderr buffer and partial completion of the stash command.
- Trigger: Working tree has hundreds of untracked files across multiple subdirectory levels, plus modified tracked files. Running `git stash push -u` in PowerShell with default config.
- Fix: BEFORE any `git stash -u`, take an inventory: `git ls-files --others --exclude-standard | Out-File untracked-inventory.txt`. After pop, diff the inventory against current state. If files are missing, recover from `stash@{N}` via `git stash show -p N | git apply` (the apply form is more reliable than pop). Better: avoid `git stash -u` as a diagnostic on Windows; use `git worktree add` instead, which gives you a clean origin checkout in a separate dir without touching the working tree.
- Score: 0.7
- Last seen: 2026-04-25 evening (vault loss — `.second_brain/` not in any of the 3 diagnostic stashes despite being untracked; only `Decisions.md` (tracked-modified) survived in stash@{2}).

### subagent-import-removal-misses-top-level-constants (Score 0.75, NEW 2026-04-28)

- Failure: A "remove unused imports" subagent verified each import was unused by grepping the file for the imported file's primary class/provider name (e.g. `DogService`, `dogServiceProvider`). The grep missed top-level constants and enums that the same import re-exports or makes reachable. CI broke on `Undefined name 'kDeployedBreedCount'` because the constant lived in working-tree-only `constants.dart` but reached origin's `dog_found_dialog.dart` via `dog_service.dart`'s re-export — and the import was deleted. Took 3 successive commits to resolve (re-add import → also broken because origin's `dog_service.dart` doesn't define it either → finally inline literal `150`).
- Trigger: Delegating import-removal to a subagent on a multi-import Dart file where some imports re-export top-level symbols. Especially risky during in-flight rebrand or refactor work where some defining files are uncommitted in the working tree.
- Fix: Subagent brief for import-removal must include: "grep for ALL symbols exported by the imported file (top-level vars, consts, enums, typedefs, AND classes), not just the file's primary class name." Use `grep -nE "^(class|enum|typedef|const|final|var|void|[A-Z]\w+\s+\w+\s*=)" lib/services/<importedfile>.dart` to enumerate exports, then grep each in the consuming file. Parent agent must also cross-check whether the consuming file is in a branch where origin and working tree diverge — drift between them is the deeper failure mode (logged as `working-tree-vs-origin-drift-on-tracked-files`, score 0.85).
- Score: 0.75
- Last seen: 2026-04-28 (Phase 7 / F2 agent removed `dog_service.dart` import in `dog_found_dialog.dart`; broke CI #14 + #15; resolved in commit `669d6ab` by inlining the literal).

### powershell-git-commit-m-multiline-hangs (Score 0.6, NEW 2026-04-28)

- Failure: `git commit -m "..."` with newlines embedded in the quoted string hangs at PowerShell's `>>` continuation prompt indefinitely. Eventually completes if a closing `"` is somehow received, but the user thinks the command is stuck. Cost: ~5-10 minutes of confused troubleshooting per occurrence.
- Trigger: Pasting a multi-line commit message inside `git commit -m "..."` from a Cowork-generated instruction block in PowerShell.
- Fix: Use here-string to file pattern: `@"\n...body...\n"@ | Out-File -FilePath commit-msg.txt -Encoding utf8`, then `git commit -F commit-msg.txt`, then `Remove-Item commit-msg.txt`. Or fallback: multiple `-m` flags (each becomes a paragraph), separated with backticks for line continuation. Document the here-string pattern in any commit instruction generated for Cowork-on-PowerShell users.
- Score: 0.6
- Last seen: 2026-04-28 (Jesse hit `>>` prompt twice during the rebrand commit sequence; fixed by switching to `git commit -F`).

### channel-ids-bucketed-with-hive-prefixes (Score 0.5, NEW 2026-04-28)

- Failure: When the user explicitly defers "Hive `dogquest_*` prefixes" as out-of-scope for a rebrand, an audit agent matched ALL `dogquest_*` strings to that defer rule and skipped the 4 Android notification channel IDs (`dogquest_streak`, `dogquest_daily_dog`, `dogquest_smart`, `dogquest_lost_dog_alerts`). Notification channel IDs are NOT Hive — they're a separate Android construct that ships in the APK and registers in Android Settings → Apps → AppName → Notifications. Deferring them is wrong because once a closed-beta tester has them registered, renaming requires migration code.
- Trigger: Wide-net `dogquest_` grep matches followed by bucket-by-prefix triage. The prefix is generic enough to cover multiple distinct Android constructs.
- Fix: When auditing brand-string usage, classify each match by Android construct, not by prefix. Notification channel IDs (`*ChannelId = 'foo'`), Hive box names (`Hive.box('foo')`), SharedPreferences keys, FCM topic strings, and intent action names are separate buckets even when they share a `dogquest_` prefix. The defer rule must specify the construct, not the prefix.
- Score: 0.5
- Last seen: 2026-04-28 (Phase 1 / A2 audit initially missed `dogquest_lost_dog_alerts` because the file `lost_dog_alert_service.dart` was T5-feature-restore territory; surfaced when CI #14 ran flutter analyze on origin tree).

- Name: `cmd-redirect-corrupts-binary-adb-data`
- Pattern: Using `cmd.exe >` redirect to capture `adb exec-out screencap -p` output produces a corrupt PNG because cmd.exe injects CRLF line-ending normalization into binary data. File opens as broken image or fails silently.
- Trigger: Any `adb exec-out ... > file.bin` command run via cmd.exe PowerShell subprocess.
- Fix: `adb shell screencap /sdcard/screen.png && adb pull /sdcard/screen.png ./screen.png`. The `pull` path writes raw bytes without line-ending normalization.
- Score: 0.9
- Last seen: 2026-04-29 (screenshot capture during design critique session)

### context-mounted-vs-state-mounted (Score 0.7, NEW 2026-05-09)

- Failure: Agent added `if (!context.mounted) return;` as an async guard in a `State<T>` class (`breed_community_screen.dart:145`). The analyzer flagged it: "Don't use 'BuildContext's across async gaps, guarded by an unrelated 'mounted' check." The lint persisted because `context.mounted` checks the `BuildContext` object, while the analyzer expects `State.mounted` (the State's own property) as the guard in a `State<T>`.
- Trigger: Writing async guards after `await` in any `State<T>` class (StatefulWidget, ConsumerStatefulWidget). The two properties look identical but check different objects — `context.mounted` is on BuildContext, `mounted` is on State. In a State class, they're almost always equivalent at runtime, but the analyzer distinguishes them for correctness.
- Fix: In `State<T>` classes, always use `if (!mounted) return;` (the State property). In non-State contexts (e.g., a function that receives a BuildContext parameter), use `if (!context.mounted) return;`. The rule: match the guard to the object that owns the context you're about to use. In State, you use `context` (which is State's context), so guard with State's `mounted`.
- Score: 0.7
- Last seen: 2026-05-09 (breed_community_screen.dart:145 — agent used `context.mounted`, user reported lint still present, fixed to `mounted`)

### hotfix-widget-change-without-test-update (Score 0.75, NEW 2026-05-09)

- Failure: Kennel grid hotfix (Sprint Hotfix, 2026-05-01) changed `breed_ghost_card.dart` border alpha from `0.25` to `0.55` (`Color.withValues(alpha: 0.55)`) but did not update the corresponding test assertion in `test/widgets/breed_ghost_card_test.dart`. The test was asserting `shape.side.color.alpha == 64` (0.25 × 255) while the widget produced `140` (0.55 × 255). Caught during deploy checklist code quality gates (`flutter test` → 1 failure).
- Trigger: Any hotfix or sprint that changes a widget's visual property (color, alpha, size, padding) without grepping for the widget's test file. Especially risky for values written as `Color.withValues(alpha: X)` where `X` feeds into an integer-rounded assertion.
- Fix: After any widget value change, `grep -rn "widget_file_basename" test/` to find associated tests. Update assertions to match the new value. Include the test file in the same commit as the widget change. When the value is an alpha, the assertion is `(alpha * 255).round()`.
- Score: 0.75
- Last seen: 2026-05-09 (`breed_ghost_card_test.dart:103` — Expected: 64, Actual: 140; fixed by updating assertion to 140 and test name to "alpha 0.55")

### orphaned-imports-after-dead-code-removal (Score 0.7, NEW 2026-05-09)

- Failure: Removed dead classes `_DailyDogPill` and `_PriorityContextBanner` from `identify_screen.dart` (Sprint 9 Phase 3 camera overlay extraction) but left 5 orphaned imports that were only used by the deleted classes: `daily_dog_service.dart`, `flash_challenge_service.dart`, `seasonal_event_service.dart`, `flash_challenge_banner.dart`, `seasonal_event_banner.dart`. `dart analyze` flagged them as unused imports (info-level).
- Trigger: Deleting a class or function from a file without checking if any of its imports become orphaned. Especially common when removing extracted/dead private classes from a screen file.
- Fix: After deleting any class/function, grep the file for each symbol imported by lines only that class used. Pattern: `grep -n "ClassName\|methodName" lib/screens/<file>.dart` — if the only match is the import line itself, the import is orphaned. Remove it.
- Score: 0.7
- Last seen: 2026-05-09 (`identify_screen.dart` — 5 orphaned imports removed after `_DailyDogPill` + `_PriorityContextBanner` removal)

- Name: `edit-tool-requires-read-in-same-turn`
- Pattern: The Edit tool fails with "File has not been read yet" even if the file was read in a prior turn or in a prior tool call in the same response block. The tool's file-lock check appears scoped to the current response turn.
- Trigger: Attempting to Edit a file without an explicit Read of that file in the same response.
- Fix: Always include a Read call on the target file in the same response block before the Edit call, even if the file was recently read.
- Score: 0.8
- Last seen: 2026-04-29 (CLAUDE.md edit failed; fixed by re-reading file first)

### dart-format-output-none-is-dry-run (Score 0.7, NEW 2026-04-29)

- Failure: `dart format --output=none .` is a DRY RUN — it reports which files WOULD change but does NOT write any changes to disk. Jesse ran it after Phase 2 agent edits, saw "3 changed", committed the files, then re-ran it and saw the same "3 changed" — the files were never actually formatted. The commits contained unformatted code, requiring a `style: dart format Phase 2 files` fixup commit.
- Trigger: Using `dart format --output=none .` as the formatting step in commit instructions. The `--output=none` flag suppresses output (i.e., "send output to /dev/null"), which means the formatter runs in check-only mode. Easy to confuse with "format in place with no extra output."
- Fix: Two-step pattern in all commit instructions: (1) `dart format .` (actually formats), (2) `dart format --output=none .` (verify: should report 0 changed). Never skip step 1. When generating PowerShell verification blocks, always include both commands with a comment explaining which one writes and which one checks.
- Score: 0.7
- Last seen: 2026-04-29 (Sprint 9 Phase 2 — 3 agent-written files committed unformatted; fixup commit required).

### agent-complex-nested-tree-unverified-bracket-claim (Score 0.8, NEW 2026-05-01)

- Failure: Agent edited `kennel_screen.dart` — a 1000+ line file with deep bracket nesting (`ValueListenableBuilder → Scaffold → CustomScrollView → slivers: [...] → collection-if else ...[...]`) — and reported `solid` confidence + "syntactically correct." The agent introduced two structural errors: (1) an extra `),` at 12-space indent after the slivers `],` closed the class prematurely, causing all subsequent `_KennelScreenState` methods (setState, ref usage, etc.) to land at top-level scope and produce "Undefined name" errors for every symbol; (2) the `else ...[` spread list at line 392 had no closing `],` before the outer slivers list closed, producing `Can't find ']' to match '['`. Compilation failed. Root cause: the Cowork sandbox has no Dart toolchain, so `dart analyze` cannot run in-session. The agent didn't caveat this and reported solid instead.
- Trigger: Any agent (subagent or direct) editing a Dart file that contains `slivers: [...]`, `children: [...]`, or other widget-list collections with collection-if/else or spread operators (`...[...]`). Especially risky in files >500 lines with multiple levels of bracket nesting. Confidence `solid` without Dart toolchain access.
- Fix: (1) After any agent-generated Dart edit, tag confidence `uncertain` if dart toolchain is unavailable in the sandbox. (2) Hand off `dart analyze` to Jesse before declaring done — include it in the verification block. (3) When the error pattern is "Undefined name X" for a class's own instance variables (e.g., `_viewMode`, `ref`, `setState`), the class bracket closed prematurely — look for a stray `)` or missing `]` at the wrong indentation level just before where the undefined symbols start. (4) When `Can't find ']' to match '['` fires on a `slivers:` or `children:` line, a `...[...]` spread inside that list is missing its closing `]`.
- Score: 0.8
- Last seen: 2026-05-01 (kennel_screen.dart bracket structure broken by AppBar-entry-point agent; fixed in 2 manual Edit calls).

### cmd-syntax-to-powershell-user (Score 0.6, NEW 2026-05-01)

- Failure: Generated `rmdir /s /q _trash` and `del _review\ruvector.db _review\test_output.txt` as cleanup commands. These are cmd.exe builtins. Jesse runs PowerShell 5.x, where `rmdir` is aliased to `Remove-Item` but doesn't accept `/s /q` flags, and `del` doesn't handle comma-separated paths. User showed error screenshot.
- Trigger: Writing filesystem cleanup instructions under time pressure without checking which shell the user runs. Memory.md explicitly documents "PowerShell 5.x doesn't support `&&`" — the same awareness should extend to all cmd.exe-only syntax.
- Fix: Always use PowerShell cmdlets for Jesse: `Remove-Item -Recurse -Force <path>` (replaces `rmdir /s /q`), `Remove-Item <path1>, <path2>` (replaces `del`), `Get-ChildItem` (replaces `dir`). Never use cmd.exe builtins in generated instructions.
- Score: 0.6
- Last seen: 2026-05-01 (directory audit cleanup — user showed PowerShell errors on cmd.exe syntax).

### sandbox-rm-blocked-on-mounted-dirs (Score 0.7, NEW 2026-05-01)

- Failure: Attempted `rm -rf _trash/` from Cowork bash sandbox on a user-mounted directory. Got `Operation not permitted`. The sandbox mount allows create/move/write but blocks destructive ops (`rm`, `rmdir`). Previously known for Read/Edit desync (see `cowork-bash-vs-read-tool-filesystem-desync`) but the deletion block is a separate, harder constraint.
- Trigger: Any `rm` or `rmdir` command in bash targeting files under the mounted user directory (`/sessions/.../mnt/dogquest/`).
- Fix: For cleanup workflows, use `mv` to a `_trash/` staging dir in the sandbox, then delegate final deletion to the user's PowerShell terminal via `Remove-Item -Recurse -Force`. Don't attempt `rm` on mounted paths — it will always fail.
- Score: 0.7
- Last seen: 2026-05-01 (19 GB `_trash/` dir couldn't be deleted from sandbox; delegated to PowerShell).

### git-no-changes-to-commit-means-already-committed (Score 0.8, NEW 2026-05-10)

- Failure: "nothing to commit, working tree clean" / "no changes added to commit" was interpreted as "the edits failed to land." In fact the edits were already on HEAD from a prior session. Multiple passes of re-editing, re-staging, and running verification batch files were wasted before confirming with `git log --oneline -5` + `git show HEAD:<file> | findstr <marker>` that the commit (`46b20253`) was already on origin.
- Trigger: Starting a new session (or resuming after context compaction) to commit changes that were already committed in a prior session. The vault / summary says "awaiting commit" but the work actually landed. Especially likely after a session that ran out of context mid-commit flow.
- Fix: Before any re-edit-and-commit attempt, run TWO checks: (1) `git log --oneline -5` — does a recent commit message describe the change? (2) `git show HEAD:<file> | findstr <key_symbol>` — is the key new code actually in HEAD? If both say yes, the work is done; close the task and move on. Do NOT re-apply edits just because the vault status says "awaiting commit."
- Score: 0.8
- Last seen: 2026-05-10 (Sprint 16 interaction design — 2-session loop of re-editing files already on HEAD; confirmed via `git_verify.bat` log that `46b20253` was already pushed)

### flutter-animate-extension-import-forgotten (Score 0.75, NEW 2026-05-10)

- Failure: Added `.animate().scale().fadeOut()` chain on a `Container` widget in `identify_screen.dart`. Got `undefined_method 'animate'` + `undefined_getter 'ms'` errors. `flutter_animate` was used elsewhere in the app (other widgets import it) but the extension methods are NOT auto-available — each file that uses them must import the package explicitly.
- Trigger: Copying animate patterns from files where `flutter_animate` is already imported into a file where it isn't.
- Fix: Always add `import 'package:flutter_animate/flutter_animate.dart';` to any file where `.animate()` or `.ms` / `.s` duration extensions are used, even if those patterns appear elsewhere in the codebase.
- Score: 0.75
- Last seen: 2026-05-10 (identify_screen.dart coach mark implementation).

### powershell-git-commit-m-here-string-pathspec (Score 0.8, NEW 2026-05-10)

- Failure: Used PowerShell `@'...'@` here-string directly as the value of `git commit -m`. Git interpreted the continuation lines as pathspecs: `error: pathspec 'second line text...' did not match any file(s) known to git`.
- Trigger: Multi-line commit message passed via `-m @'...'@` in PowerShell 5.x. The `-m` flag consumes only the first token; subsequent lines are parsed as file arguments.
- Fix: Write the full message to a temp file first, then use `-F`: `$msg | Out-File -Encoding utf8 "$env:TEMP\commit.txt"; git commit -F "$env:TEMP\commit.txt"`. Confirmed working 2026-05-10.
- Note: The `git commit -m "$(cat <<'EOF'...EOF)"` Bash heredoc pattern in Claude Code's commit instructions does NOT apply to PowerShell. On Windows with PowerShell, always use the `-F tempfile` path.
- Score: 0.8
- Last seen: 2026-05-10 (Sprint 14 onboarding funnel commits).

## Related Notes

- [[Memory]]
- [[Decisions]]
- [[Active_Tasks]]
