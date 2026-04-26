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

## Related Notes

- [[Memory]]
- [[Decisions]]
- [[Active_Tasks]]
