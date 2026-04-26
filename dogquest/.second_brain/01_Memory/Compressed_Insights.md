# Compressed Insights

Tags: #memory #insights #patterns

Condensed session learnings. One entry per non-obvious insight worth keeping across sessions.

---

## Architecture

**ChangeNotifier-as-local-state for screen-scoped controllers.**
When a screen has async state (remote fetch, stream subscription) that doesn't need to cross widget boundaries, a ChangeNotifier held in `initState` is cleaner than a Riverpod provider. Pattern:
```dart
late LostDogMapController _controller;
void initState() {
  _controller = LostDogMapController();
  _controller.addListener(_rebuild);
}
void _rebuild() { if (mounted) setState(() {}); }
void dispose() { _controller.removeListener(_rebuild); _controller.dispose(); super.dispose(); }
```
Benefit: no provider registration noise, lifecycle is local and obvious, `dispose()` is guaranteed.
When NOT to use: if two sibling widgets need the same state, promote to Riverpod.
Source: Phase 4a, 2026-04-25.

**Widget-returning methods on StatelessWidget are pragmatically fine for non-reusable map overlays.**
CLAUDE.md's "no widget-returning functions" rule targets widget functions that escape their scope. Private methods on a StatelessWidget that build overlay/popup content which is never reused don't add naming value — premature extraction adds weight without reducing complexity.
Source: Phase 4a code review, 2026-04-25.

**Parallel agent file-boundary design: zero overlap = zero conflicts.**
For a refactor spanning screen + extracted files + model + service + main.dart, split agents by file cluster with no shared ownership. Agent A: screen file + new service/widget files (all net-new). Agent B: existing model + existing service + main.dart. Merge is clean because each agent writes only files the other can't touch.
Source: Phase 4a/4b parallel agents, 2026-04-25.

---

## Offline-First

**SyncStatus enum on the model keeps sync state close to the data.**
`LostDogReport.syncStatus: SyncStatus` (pending/synced/failed) is the right home — not a separate map in the service. The service's `updateSyncStatus(id, status)` method is a narrow write gate; the flush loop reads `allReports.where((r) => r.syncStatus == SyncStatus.pending)`. Simple and correct for this scale.
Source: Phase 4b, 2026-04-25.

**`unawaited()` in a stream listener is valid but MUST be explicit.**
`Connectivity().onConnectivityChanged.listen((results) { unawaited(_flush()); })` — the async work is genuinely fire-and-forget (background flush when internet restores; outcome is not consumed by the caller). CLAUDE.md requires the `unawaited()` wrapper to make this intent visible; omitting it is a lint/review flag.
Source: Phase 4b sync service, 2026-04-25.

**Nullable `SupabaseLostDogService?` makes offline mode safe by default.**
`LostDogSyncService(this._lostDogSvc, this._supabaseSvc)` where `_supabaseSvc` is nullable. All sync paths bail with `if (_supabaseSvc == null) return`. No Supabase session = no sync attempt = no exception. The provider default `Provider<LostDogSyncService?>((ref) => null)` means unoverridden (test/offline) contexts get no-op behavior for free.
Source: Phase 4b, 2026-04-25.

---

## Verification

**"Complete this" on a todo item: grep before spawning agents.**
When asked to implement a task from a list, the feature may already be fully implemented from a prior session. Run a targeted grep first (`grep -rn "ClassName\|methodName" lib/`). If it exists, confirm to the user and close the task. Spawning parallel implementation agents on already-shipped code wastes budget and risks overwriting correct code.
Source: tasks 2d (multi-photo embedding) and 3e (reunion celebration screen) verified-already-done, 2026-04-25.

**Bash sandbox shows stale state after Edit-tool writes — Read tool is the source of truth.**
After writing a file via Edit, `wc -l` / `tail` from bash may show the pre-write state due to virtiofs cache lag. Use the Read tool to confirm the actual file content before declaring success. Don't issue `git checkout` or restore commands based on bash-reported file size alone.
Source: sighting_sync_service.dart false-truncation alarm, 2026-04-25. Logged in Failure_Patterns.md.

---

---

## CI / Push Iteration Loop

**Always simulate origin's tree before pushing to a CI-gated branch.** Working tree has unstaged modifications that local analyze sees but CI doesn't. The Sprint 1 push triggered 5 successive CI failures, each surfacing a different dangling dependency (radiusKm param, distanceKm getter, lostDogAlertService import, SyncQueueItem class, untracked screen imports). Iteration cost on CI is high (3-5 min minimum per push). Cheap pre-flight: `git worktree add ../mirror origin/branch && cd ../mirror/dogquest && dart analyze` — clean origin checkout without touching the working tree. Don't use `git stash -u` for this on Windows; deeply-nested untracked dirs get lost.
Source: Sprint 1 push iteration, 2026-04-25 evening.

**Strip-not-commit pattern for working-tree-only references.** When a tracked-and-committed file references symbols that exist only in untracked-or-uncommitted siblings, two paths: (a) commit the supporting files (risk: pulling unrelated drift, cascading dependencies), or (b) strip the dependent code with restoration markers. Pick (b) for closed-beta scope. Mark every strip site with an inline `(T5-feature-restore)` comment for grep-discovery. Maintains an explicit restoration tracker in Active_Tasks listing what was stripped, why, and what to commit when restoring.
Source: Sprint 1 CI unblock — 6 strip commits, 2026-04-25 evening.

**Per-finding-ID commits beat one mega-commit.** Sprint 1 shipped as 7 commits each tagged with a finding ID (C1+C3-review, C2-review, C5-review, T5-A, T5-B, T5-feature-restore). Friction cost: 7 commits instead of 1. Benefit: surgical revert, pinpoint CI failure attribution, restoration commits visible in `git log --grep=T5-feature-restore`. Worth it.
Source: Sprint 1 commit hygiene, 2026-04-25 evening.

---

## Verification Discipline

**Closure markers need TWO verifications, not one.** A vault entry claiming `closed via commit abc123` is half-attested if only the commit hash is recorded. Need ALSO: (a) artifact exists on disk at the claimed path, (b) commit hash resolves via `git log --all --oneline -- PATH` from the **repo root** (not from a subdirectory). Both must pass. If only one passes, treat as half-closure: reopen with explicit "audit trail broken" or "artifact missing" framing. Failed in this session via DRIFT-1's 4-pass loop where the commits were real but I mis-queried them with cwd-relative paths.
Source: DRIFT-1 audit, 2026-04-25 evening.

**`git log -- PATH` is cwd-relative — always specify from repo root.** In a multi-project monorepo (e.g., `TheCryptoCanuck/boring` with `dogquest/` as one of several subprojects), running `git log --all -- .github/` from `dogquest/` queries `dogquest/.github/`, not the repo-root `.github/`. Default to absolute paths or `cd $(git rev-parse --show-toplevel)` first. The DRIFT-1 4-pass saga happened because pass 2 ran from `dogquest/` and got empty results.
Source: DRIFT-1 pass-2 misdirection, 2026-04-25 evening.

**Don't infer absence from partial listings.** Negative existence claims about disk state require independent positive verification — `Glob`/`Read`/`Test-Path` against the canonical filesystem path. A long paginated `git status` output may scroll past entries; a search-filtered output may exclude what you're looking for. Pair every negative claim with an explicit existence check. Tool-level guardrails (Write demanding a prior Read on existing files) saved a clobber-rewrite this session — don't rely on them.
Source: `.github/` false-absence claim, 2026-04-25 evening.

---

## Multi-Project Monorepo Quirks

**Repo root ≠ project root in monorepos.** `TheCryptoCanuck/boring` is the git repo; `dogquest/` is one of several Flutter sub-projects (alongside `aviquest/`, `aviquest-web/`, `backend/`, `infrastructure/terraform/`, `ml/`). Implications:
- Git ops (`git log`, `git stash`, `git status`) run from any subdirectory but interpret paths cwd-relative.
- `.github/workflows/` lives at the repo root, NOT in `dogquest/`. CI yml files in `dogquest/.github/workflows/` are invisible to GitHub Actions.
- `working-directory: ./dogquest` in the workflow yml's `defaults.run` is the standard pattern for running flutter commands against the subproject.
- File paths in PR diffs / commit messages should include the subproject prefix (`dogquest/lib/...`) when written for cross-project clarity.
Source: OPS-001 yml placement confusion, 2026-04-25 evening.

---

## Sub-Agent Audit Discipline

**Audit sub-agent output line-by-line for mock/wrapper patterns.** A sub-agent's "I fixed all 30 errors" claim about a Mock wrapper class needs an interface-conflict check. If the wrapper claims `implements A, B`, both A and B must be reconcilable on every shared method/field name. The T5-B sub-agent's `_AwaitableFilterBuilderWrapper implements Future<List<dynamic>>, PostgrestFilterBuilder<dynamic>` failed because `PostgrestBuilder extends Future<dynamic>` — generic args mismatched. My initial audit hedged this as a "D-tier hypothetical concern" and didn't run the verification step. Don't hedge structural compile-time conflicts as hypotheticals.
Source: T5-B audit failure, 2026-04-25 evening.

---

## Vault Recovery

**`git stash -u` on Windows is unreliable for deeply-nested untracked dirs.** Lost most of `.second_brain/` from disk. The CRLF normalization warning flood that floods stderr during the operation appears to interrupt the untracked-file-capture step. Recovery via `git stash apply` was partial; first apply silently restored some untracked files but didn't surface "already exists" notices for them, and the stash itself was consumed before I could re-apply.
Use `git worktree add ../mirror origin/branch` for diagnostic checkouts instead. Reserve `git stash` for tracked-modified work that needs temporary parking — its untracked-file capture mode (`-u` flag) is the unreliable path.
Source: vault loss + recovery, 2026-04-25 evening.

---

## PowerShell Quirks (Windows-side)

**`{N}` in command args gets brace-expanded by PowerShell.** `git stash show stash@{0}` errors with "Too many revisions specified" because PowerShell expands `stash@{0}` into multiple tokens. Quote the whole reference: `'stash@{0}'`. Or use the bare integer: `git stash show 0`. Same trap applies to any command with literal brace syntax.

**`&&` doesn't work in PowerShell 5.x.** Chain commands with `;` (no short-circuit on failure) or run them separately. PowerShell 7+ supports `&&` and `||` like bash. Worth installing eventually but not blocking; sequential execution with explicit error-handling is fine.

**LF/CRLF normalization warnings flood stderr during git operations.** Mute with `2>$null` redirection when needed. Beware: muting also hides legitimate errors. Use `2>warnings.log` if you want to keep them but separate them from stdout.
Source: vault recovery + git-add commands during Sprint 1, 2026-04-25 evening.

---

## Cowork-Side Tooling Quirks

**File-upload UI deduplicates by filename.** Re-uploading the same filename caches stale content — the user thinks they've shared fresh data but the assistant sees old content. Workaround: prefer inline-paste for short outputs (<50 lines); for larger outputs, rename the file before re-upload.

**Cowork sandbox has no Dart toolchain.** All `.dart` edits made via Edit/Write tools must be verified Windows-side via `dart format` + `dart analyze` + `flutter test` before declaring done. Pattern: do the Cowork edits, then hand the user a verification command + commit instructions.
Source: Sprint 1 execution + multiple file-upload friction events, 2026-04-25 evening.

---

## Related Notes

- [[Decisions]]
- [[Failure_Patterns]]
- [[Corrections]]
- [[Active_Tasks]]
