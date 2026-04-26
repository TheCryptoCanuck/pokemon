# Memory

Tags: #memory #identity

Long-form durable memory for the DogQuest project. Rebuilt 2026-04-25 evening after a stash-loss event lost the prior content; augmented across the same evening session with Jesse-attested preferences and project context. Some pre-rebuild entries (older session-attested patterns) are preserved in `Compressed_Insights.md` and `Patterns.md` which survived the loss.

## User

- Jesse Garside (jesseg.8899@gmail.com), TheCryptoCanuck on GitHub.
- Solo developer on DogQuest. Posture: quality-first with closed beta as feedback loop (pivot 2026-04-25). 4 weeks of pure quality work before reassessing.
- Working environment: Windows + PowerShell 5.x. Has WSL/GPU available for ML work (RTX 3060 Ti) but day-to-day dev is Windows.
- Time zone: Berlin / GMT+1 (per the `aviquest-web/` GMT+1 timestamp seen in the Actions UI).

## Communication preferences (durable)

- **No preamble.** No "Sure!", "Great question". No narrating intent before doing something. Just do it.
- **Concise step-by-step instructions for terminal work.** Code blocks for commands; numbered or bulleted only when sequencing matters.
- **Acknowledge mistakes without self-flagellation.** Take ownership, fix the thing, don't dwell.
- **Match Jesse's ownership tone.** When Jesse says "i fucked up" or "sorry," reflect equivalent ownership when I'm the one who erred. Don't displace blame onto charitable-sounding inferences ("the user scrolled past..." was caught and called out as anthropomorphizing — "this you being funny :)").
- **Confidence tags at end of substantive work:** `solid` (verified), `uncertain` (not sure), `drift` (generated without verifying — default for any version/API/assertion not directly read).
- **Concrete is better than abstract.** Real commit hashes, real file paths, real error counts. Don't generalize when the specifics are knowable.
- **Push back on noise.** Jesse will say "shitload of warning and it maxes out the shell" — that's a signal to filter, redirect, or change diagnostic approach. Don't keep producing noise after pushback.
- **Humor lands.** Jesse engages with self-aware humor. "this you being funny :)" was Jesse engaging warmly when I anthropomorphized. Match the tone when it's appropriate, but don't force it.

## Workflow preferences (durable)

- **Cowork edits + Windows verification.** Cowork sandbox has no Dart toolchain. Pattern: I edit files via Edit/Write, hand Jesse a `dart format` + `dart analyze` + `flutter test` verification step + a `git commit` + `git push` step. Don't claim "shipped" until Jesse's terminal output confirms it.
- **Per-finding-ID commits, not mega-commits.** Each finding (C1, C2, T5-A, etc.) gets its own commit with the finding ID in the message. Friction worth it for surgical revert + commit-grep discoverability.
- **Strip-not-commit when in doubt.** When CI fails on a tracked-file reference to working-tree-only code, default to stripping with `(T5-feature-restore)` markers rather than committing dependency cascades. Restoration tracker in Active_Tasks.
- **Inline paste over file upload for short outputs.** Cowork's file-upload UI dedups by filename — re-uploading the same name caches stale content. Inline paste avoids the trap.
- **Ground-truth anything that surprises me.** "The vault says X is closed" is a hypothesis until I check disk + git. "The user said Y is on disk" is a hypothesis until I `Glob`/`Read`/`Test-Path` it. Don't propagate unverified claims into agent briefs or downstream reasoning.

## Decision-making preferences (durable)

- **State assumptions and proceed.** Don't ask unless wrong-assumption cost > 10 min.
- **Tier discipline:** when waiting on Tier N completion, agents may write specs / design docs / research notes for Tier N+1 — but NOT code, branches, or staged commits. Jesse can override with explicit say-so.
- **Surface tradeoffs + recommendation, then execute Jesse's choice.** Pattern: 2-3 paths with effort + risk for each, my recommendation, wait for Jesse's pick, execute without re-litigating.
- **Free-tier/trial-banner UX flagged proactively.** Don't propose a vendor wiring without surfacing pricing sharp edges in the same message. Sentry got rejected for the trial banner; Crashlytics replaced it cleanly because the proactive comparison was offered up front.

## Project: DogQuest

- Flutter/Dart app for dog breed identification + lost-dog recovery network.
- Forked from AviQuest (predecessor bird app). Now lives in monorepo `TheCryptoCanuck/boring` (private) alongside `aviquest/`, `aviquest-web/`, `backend/`, `infrastructure/terraform/`, `ml/`, `docs/`, `agents/`, `.ui-design/`.
- **Repo structure:** git root is `C:\Users\Administrator\AviQuest-\` (NOT `dogquest/`). Flutter project lives in `dogquest/` subdirectory. `.github/workflows/` lives at the repo root with `defaults.run.working-directory: ./dogquest`.
- Active branch: `phase-1/social-backend-realtime`. As of 2026-04-25 evening: synced with origin.
- Deployed model: EfficientNetB2 v5.1, 150 breeds, uint8 quantized, 260x260 input. Target: v6 EfficientNetV2-S, 294 breeds (in training).
- 12 vault files in `.second_brain/`. CI green on all 4 jobs (format / analyze / test / build APK) as of Run #6.

## Tech stack conventions

- **Flutter/Dart**, Riverpod (code-gen pattern preferred where models compile), go_router with auth gate.
- **Hive** boxes prefixed `dogquest_`, AES-encrypted sightings box (key in FlutterSecureStorage).
- **Supabase** backend (auth + RLS + RPCs). Server-side `auth.uid()` enforcement; client never tags user_id on inserts.
- **Firebase Crashlytics** (OBS-001) is primary error reporter. Sentry preserved as opt-in via `--dart-define=SENTRY_DSN=...`.
- **TFLite** identification offloaded to isolate via `compute()`. Single shared interpreter via `SharedTfliteService` (C2 fix). uint8 input/output, divide output by 255.0 for confidence.
- **TTA:** v5.1 uses 3-crop (center tight + center flipped + center zoomed-out), was 5-crop pre-TASK-046.
- **CI:** `.github/workflows/dogquest-ci.yml`. 4 jobs (format / analyze / test / build-debug-apk). Currently `--no-fatal-warnings --no-fatal-infos` pending C4 const sweep + unused-imports cleanup.

## Environment quirks (Windows + Cowork)

- **PowerShell 5.x doesn't support `&&`** — use `;` or separate lines. PS 7+ has `&&` and `||` like bash; install via `winget install --id Microsoft.PowerShell` eventually.
- **PowerShell expands `{N}` in command args** without quoting. For git stash refs use `'stash@{N}'` or the bare integer.
- **LF/CRLF normalization warnings flood stderr** during git operations on big working trees. Mute with `2>$null` when needed; use `2>warnings.log` if you want to keep them separate from stdout.
- **`git log -- PATH` is cwd-relative.** From a subproject (`dogquest/`), the path argument resolves to `dogquest/PATH`, not repo-root `PATH`. Specify absolute paths or `cd $(git rev-parse --show-toplevel)` first.
- **`git stash -u` on Windows can lose deeply-nested untracked files** during the CRLF warning flood. Use `git worktree add` for diagnostic checkouts.
- **Cowork sandbox has no Dart toolchain.** All `.dart` edits via Edit/Write tools need Windows-side verification before "shipped" claims.
- **Cowork file-upload UI dedups by filename.** Re-uploading the same filename caches stale content. Inline-paste for short outputs.

## Related Notes

- [[Active_Tasks]] — operational state.
- [[Decisions]] — durable decisions.
- [[Corrections]] — past mistakes Jesse called out.
- [[Failure_Patterns]] — anti-patterns to never repeat.
- [[Compressed_Insights]] — condensed cross-session learnings.
- [[Patterns]] — older session-attested patterns (survived the stash loss).
