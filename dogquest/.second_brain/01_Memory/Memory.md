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
- **Cowork sandbox excludes the monorepo root.** Only `dogquest/` is mounted; `AviQuest-/` (the git root) is NOT. Git commands cannot run from the sandbox at all — Jesse runs them in PowerShell from `AviQuest-`. Pattern: I do file triage + edits in the sandbox; Jesse executes per-finding-ID `git add` / `git commit` / `git push` sequences I generate.

## Project conventions (durable, DogQuest-specific)

- **`assert()` is banned for any guard that must fire in production** (established 2026-05-01). `assert(condition, 'msg')` is compiled out entirely in Dart release builds — it's a complete no-op for production users. Always use `if (!condition) throw ArgumentError('msg')` for programmer-error cases (bad inputs, invalid params) and `if (!condition) throw StateError('msg')` for runtime state violations (session expired, required service not initialized). Apply this in any new service, main.dart entrypoint, or validation method. Three instances found and fixed in Sprint 12: `main.dart` (`_assertSupabaseEnv`), `api_client.dart` (`assertBaseUrl`), `sync_queue_service.dart` (operation validation).
- **`_userId` service getter pattern** (established 2026-05-01). Services that require auth use a private getter: `String get _userId { final uid = _client.auth.currentUser?.id; if (uid == null) throw StateError('No authenticated user — session expired'); return uid; }`. Never `currentUser!.id` — JWT expiry returns null, not an exception, so `!` crashes. The `throw StateError` in the getter is cleaner than cascading nullable returns at every call site.
- **DogQuest's own docs are AviQuest-free** (established 2026-04-26). `dogquest/CLAUDE.md` and `dogquest/README.md` do NOT mention AviQuest, `aviquest/`, `aviquest-web/`, the fork lineage, or the literal `AviQuest-/` path. Use placeholders like `<repo-root>/` or "the monorepo root, one directory above `dogquest/`" instead. Vault-side files (`.second_brain/`) and the monorepo root may still reference AviQuest as factual context. Scrub policy applies to docs INSIDE `dogquest/` only.
- **Trust subagent zero-ref claims with skepticism.** Delegated code-search agents produce false-positive orphan claims when they grep only one casing of a Dart symbol (CamelCase OR snake_case). Always verify with both: `grep -E "ClassName|snake_case_basename"` before any delete decision. Established 2026-04-26 after Explore reported 4 false-positive orphans that all had live refs visible only via the alternate casing.
- **Don't write integration tests from the Cowork sandbox.** No `flutter test` available; no way to verify the test compiles or passes. False-confidence risk: shipping a broken test that fails CI on Jesse's push. Document the test gap as a follow-up task instead. Logged as a tech-debt entry (e.g. C-Lost-A integration test). Established 2026-04-26.
- **Hotfix widget changes need corresponding test updates.** When a hotfix changes a widget's visual property (alpha, color, size), grep `test/` for the widget's test file and update assertions in the same commit. The breed_ghost_card border alpha change (0.25→0.55) was caught only at deploy-checklist time because the test wasn't updated alongside the hotfix. Established 2026-05-09.
- **After deleting any class/function, check for orphaned imports.** Grep the file for each symbol from the deleted code's imports. If the only match is the import line itself, the import is dead. Five orphaned imports survived in `identify_screen.dart` after `_DailyDogPill` + `_PriorityContextBanner` removal until caught by `dart analyze`. Established 2026-05-09.
- **In `State<T>` classes, use `if (!mounted) return;` — NOT `if (!context.mounted) return;`.** The analyzer treats `context.mounted` as checking a different object ("unrelated 'mounted' check") when it expects `State.mounted`. Both are nearly equivalent at runtime, but the lint fires on `context.mounted` in State classes. Reserve `context.mounted` for non-State contexts (functions receiving a BuildContext). Established 2026-05-09.
- **Parallel agent lint cleanup: 3 agents, file-ownership boundaries, zero conflicts.** For mechanical lint fixes (trailing commas, const, curly braces, avoid_dynamic_calls), decompose by file cluster with zero overlap. Each agent gets a self-contained file list and lint category set. The `avoid_dynamic_calls` category is the riskiest — requires understanding surrounding types to cast correctly (e.g., `dog as Dog?`, `pack as Map<String, dynamic>`). Brief agents with explicit type hints for dynamic casts. Established 2026-05-09.
- **Subagent import-removal needs cross-symbol grep, not just type/class names.** When a subagent recommends "delete this unused import," the grep that justified the call must also check for top-level constants, enums, and re-exports reachable through that import. Established 2026-04-28: F2 agent removed `dog_service.dart` import from `dog_found_dialog.dart` after grepping `DogService` / `dogServiceProvider`, but missed that `kDeployedBreedCount` (top-level const) was reached through the same import on origin's tree. CI broke twice before the fix landed (inline the literal). Subagent briefs for import-removal should now include: "grep for all symbols defined in the imported file, not just the file's primary class".

## Interaction design conventions (2026-05-10)

- **Pill entrance animations**: `.animate().fadeIn(delay: Xms).slideY(begin: 0.3, delay: Xms, duration: 280ms, curve: Curves.easeOut)` — standard stagger for context info pills in `dog_found_dialog.dart`. Combo pill: 570ms, flash pill: 630ms.
- **XP countup**: `TweenAnimationBuilder<int>` with `IntTween(begin: 0, end: value)`, 1000ms, `Curves.easeOut`. Wrap in `.animate().fadeIn(delay: 400.ms)`.
- **Result dialog transition**: `showGeneralDialog` (not `showDialog`) with `transitionDuration: 380ms`, `SlideTransition(Offset(0, 0.08)→Offset.zero)` + `FadeTransition`, `CurvedAnimation(curve: Curves.easeOutCubic)`.

## Supabase project facts (2026-05-10)

- **Project ref:** `hdcpymjnrbelaawhncep`
- **Org slug:** `jaoyzyuqvmudqnhqzrlt`
- **Region:** `eu-west-1` (AWS Ireland)
- **Anon key:** `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhkY3B5bWpucmJlbGFhd2huY2VwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1MzE0NzcsImV4cCI6MjA4OTEwNzQ3N30.aNRS4K_XuQU1pYm0goq3kmq9aJlPHmRfnRy3FX80T7M`
- **Free-tier pausing:** project auto-pauses after ~7 days inactivity on free tier. Resume via Supabase dashboard (Settings → General → Resume project, takes ~5 min). Symptoms: "Retrieving API keys" spinner loops indefinitely on the API keys page.
- **Key retrieval while paused:** use the Management API with the dashboard's own access token: `GET https://api.supabase.com/v1/projects/{ref}/api-keys` with `Authorization: Bearer <token>`. Token extracted from `localStorage['supabase.dashboard.auth.token'].access_token` in browser devtools while logged into `app.supabase.com`. This works even when the project is paused.

## GitHub Actions secrets (set 2026-05-10)

All 5 secrets live in `TheCryptoCanuck/boring` → Settings → Secrets → Actions:
- `SUPABASE_URL`, `SUPABASE_ANON_KEY` — real project values (see above)
- `API_BASE_URL` — placeholder `https://placeholder.example.com` (no real API backend yet)
- `ADMOB_INTERSTITIAL_ID`, `ADMOB_BANNER_ID` — Google test IDs for closed beta; swap for real IDs before production

## Environment quirks (Windows + Cowork) — supplements

- **Cowork sandbox blocks `rm`/`rmdir` on mounted user directories.** `Operation not permitted` on any destructive filesystem op against the mount. Workaround: `mv` to a `_trash/` dir in the sandbox, then `Remove-Item -Recurse -Force _trash` from PowerShell on the Windows side. The sandbox CAN create, move, and write — just not delete.
- **PowerShell `Remove-Item` syntax, not cmd.exe.** `Remove-Item -Recurse -Force <path>` replaces `rmdir /s /q`. `Remove-Item <path1>, <path2>` replaces `del`. Jesse's terminal is PowerShell 5.x — cmd.exe builtins (`rmdir`, `del` with `/s /q` flags) error out. This is a recurring trap when generating cleanup instructions.

- **PowerShell angle-brackets `<` and `>` are stdin/stdout redirect operators.** `flutter build ... --dart-define=KEY=<real>` causes "The syntax of the command is incorrect" because `<real>` triggers stdin redirection. Never use angle-bracket placeholders in PowerShell commands. Wrap all dart-define values in quotes: `"--dart-define=KEY=value"`.
- **PowerShell has no `head` command.** Use `Select-Object -First N` instead. `git status --short | head -30` → `git status --short | Select-Object -First 30`. Same for `tail -n` → `Select-Object -Last N`.
- **AAB release build** (closed beta): `flutter build appbundle --release` with placeholder `--dart-define` values produces `build\app\outputs\bundle\release\app-release.aab` (~75.3 MB). Play Store accepts this directly.
- **adb path on Jesse's machine:** `C:\Users\Administrator\AppData\Local\Android\sdk\platform-tools\adb.exe`. Not on PATH by default. Quick add to user PATH: `[Environment]::SetEnvironmentVariable("Path", "$([Environment]::GetEnvironmentVariable('Path', 'User'));$sdkPath", "User")` then reopen terminal. Or use Flutter's wrappers: `flutter install --debug` and `flutter logs` work without adb on PATH.
- **Test device:** Sony XQ CT54 (deviceId `QV770SJQCQ`), Android 14 (API 34), Adreno GPU. USB Debugging enabled. Visible to `flutter devices`.
- **Multi-line commit messages in PowerShell** — use here-string written to file, then `git commit -F`:
  ```powershell
  @"
  subject line

  body paragraph
  "@ | Out-File -FilePath commit-msg.txt -Encoding utf8
  git commit -F commit-msg.txt
  Remove-Item commit-msg.txt
  ```
  `git commit -m "..."` with embedded newlines hangs at the `>>` continuation prompt because PowerShell can't tell when the string is closed. Multiple `-m` flags work as a fallback (each becomes a paragraph) but here-string preserves formatting. Note: `Out-File -Encoding utf8` writes a UTF-8 BOM in PS 5.x; the BOM lands in the commit message but is invisible in `git log`. Use `[System.IO.File]::WriteAllText(...)` for BOM-free writes.
- **AdMob `MobileAdsInitProvider` requires APPLICATION_ID meta-data in AndroidManifest** even when ad unit IDs are env-driven. Without it, the SDK initializes via a `ContentProvider` at app launch and throws `IllegalStateException: Missing application ID` before the Dart entrypoint runs. Test ID for development: `ca-app-pub-3940256099942544~3347511713` (Google-published, won't serve real ads). Real production ID requires registering the package in an AdMob console.

- **adb screenshot workflow: use `adb pull`, not `cmd.exe >` redirect.** `adb exec-out screencap -p > file.png` via cmd.exe corrupts binary PNG data (CRLF line-ending injection). Correct pattern: `adb shell screencap /sdcard/screen.png && adb pull /sdcard/screen.png ./screen.png`. Device in use: Sony XQ-CT54 (model QV770SJQCQ).

## Workflow preferences (supplements, 2026-04-29)

- **`dart format .` then `dart format --output=none .`** — always two steps. The first WRITES formatting; the second VERIFIES (dry run, reports changes but writes nothing). Never skip step 1. `--output=none` alone produces zero disk changes. Logged as Failure_Patterns entry `dart-format-output-none-is-dry-run`.
- **Parallel agent file ownership works well for design sprints.** Phase 2 ran 4 agents across 6 files with zero merge conflicts. Key: each agent owns non-overlapping files. When two agents must touch the same file (e.g., `profile_screen.dart`), merge them into one sequential agent rather than risking Edit conflicts.
- **ShaderMask + LinearGradient + BlendMode.dstIn** is the right pattern for right-edge fade on scrollable rows. 6-line wrapper, not worth extracting to a widget.
- **Widget tests can be written from Cowork sandbox** (unlike integration tests). Pure widget tests don't need `flutter test` to verify compilation — they follow predictable patterns with `WidgetTester` + `pumpWidget` + `find.*` + `expect`. Risk is lower than integration tests because the patterns are mechanical.
- **`flutter_animate` `autoPlay: false` leaves widget at animation INITIAL state permanently** — NOT snapped to final state. A `fadeIn` widget with `autoPlay: false` is opacity 0 forever. Only use `autoPlay: !_hasAnimated` on ghost/unowned cards for first-load stagger. Remove `.animate()` entirely from owned/promoted card paths so they render at full opacity immediately on mount. (Kennel grid hotfix 2026-05-01.)
- **`BoxFit.contain` for collection photo cards** (not `BoxFit.cover`). Wikimedia `thumb.php` images are landscape; `cover` center-crops them into near-square cards and hides the dog's body. `contain` letterboxes with the dark card background — acceptable tradeoff for showing the full animal. Use `cover` only when the photo is portrait or the card is explicitly landscape.

## Navigation conventions (2026-05-01)

5-tab bottom nav: Discover / Identify / Kennel / Lost Dogs / Me.

Icons (active icon = same icon or filled variant, selectedItemColor: Colors.amber handles tinting):
- Discover: `Icons.explore_outlined` / `Icons.explore`
- Identify: amber circle container with `Icons.camera_alt` (special treatment, unchanged)
- Kennel: `Icons.collections_outlined` / `Icons.collections`
- Lost Dogs: `Icons.radar` (active: same with explicit amber via `Color.withValues`)
- Me: `Icons.person_outline` / `Icons.person`

Field Guide is NOT a bottom-nav tab. It lives as an `IconButton(icon: Icon(Icons.menu_book))` in the Kennel screen AppBar → `context.push('/guide')`.

User explicitly rejected `Icons.search` (magnifying glass) for Lost Dogs. Do not propose it again.

## PowerShell script execution (supplements, 2026-05-01)

- Local scripts require `.\` prefix (backslash, not `/`): `.\_deploy.bat` not `./deploy.bat`.
- The deploy script filename has an underscore prefix: `_deploy.bat`. Running `deploy.bat` fails because the file does not exist.
- Without `.\`, PowerShell does not search the current directory for executables.

## Camera / Device Quirks (2026-05-10)

- **`setFocusPoint` / `setExposurePoint` block the platform channel on Sony XQ-CT54 HAL** in release builds. The native side blocks synchronously before creating the Future, so `.timeout()` on the Dart side has no effect — the entire app freezes. Tap-to-focus is DISABLED for closed beta. Autofocus via `FocusMode.auto` set during `_initCamera()` still works. TODO: re-enable after `camera` package upgrade or isolate workaround.
- **`setFocusMode(FocusMode.auto)` / `setExposureMode(ExposureMode.auto)` in init**: wrapped in a single try/catch with 2s timeout. If the HAL blocks these too, the timeout may not help (same synchronous-block issue) but empirically these work on the Sony device.
- **Privacy policy consistency**: hosted `docs/privacy_policy.html` MUST match in-app `privacy_policy_screen.dart`. Play Store reviewers check both. Section 6a "Aggregated Sighting Data (Opt-In)" was missing from the HTML — added 2026-05-10.

## Exam System Conventions (2026-05-10)

- **ExamTier enum** in `exam_result.dart`: bronze (60% pass, 5m cooldown, 1.25× XP), silver (75%, 15m, 1.5×), gold (85%, 30m, 2.0×). Has `.next` getter for progression.
- **Hive box**: `dogquest_exams`. Key format: `{groupId}_{tier}` (e.g. `sporting_bronze`).
- **Color constants** in `constants.dart`: `examGold`, `examSilver`, `examBronze`.
- **Prestige title**: `ExamService.prestigeTitle` — "Canine Scholar" (all 7 Gold) or "{Group} Specialist" (first single Gold). UI composes with `?? playerState.title`.
- **XP multiplier**: `max(collectionBonus, examBonus)` — non-stacking.
- **IIFE pattern**: Prefer `() { ... }()` over `Builder` in ConsumerWidget scope when `ref` is already available.
- **Analytics events**: `exam_attempted`, `exam_passed`, `canine_scholar_achieved` — tracked via `ref.read(analyticsProvider).track()`.

## Supabase Auth wiring facts (2026-05-10)

- **Publishable key vs JWT anon key:** `.env.local` uses `sb_publishable_*` format (Supabase dashboard "publishable" key). The JWT anon key (`eyJ...`) is the REAL anon key needed for API calls and is stored in GitHub Actions secrets. Both are valid for different contexts — `sb_publishable_*` is a wrapper that Supabase client SDKs resolve to the JWT internally. For `--dart-define` in CI, use the JWT form.
- **Free-tier email rate limit:** 2 emails/hour PROJECT-WIDE (not per-email-address). Cannot be increased without configuring custom SMTP in Supabase dashboard (Auth → SMTP Settings). Tested 2026-05-10: even with a new email address, rate limit was hit because the counter is per-project.
- **Email confirmation currently DISABLED** for dev/testing. Toggle: Supabase dashboard → Auth → Sign In / Providers → "Confirm email" = OFF. Must be re-enabled before public beta with custom SMTP configured to avoid the 2/hr limit.
- **Site URL:** Changed from `http://localhost:3000` (Supabase default) to `com.hound.app://login-callback` for Android deep linking. Android intent filter already configured in `AndroidManifest.xml`.
- **`BackendSyncService.fetchProfile()` is a stub** — returns `null`. Any screen relying on it for user data (Settings, Profile) must fall back to `supabaseAuthServiceProvider.currentUser` session data.
- **Settings screen Supabase fallback pattern:** `settings_screen.dart` tries `_profile?['username']` / `_profile?['email']` first, then falls back to `supabaseAuthServiceProvider.currentUser.userMetadata['username']` / `.email`. If username isn't in `userMetadata` (depends on whether RegisterScreen stores it during signup), it remains "Unknown".

## Google Play Console Workflow (Session 2026-05-11)

**Account Setup:**
- New Play Console account created 2026-05-10 via Google Account signup (jesseg.8899@gmail.com). Requires 24-48 hr verification before any app submission.
- Developer account name: "DogQuest" (durable; becomes public on Play Store).
- App package name: `com.hound.app` (locked after first upload; must match AndroidManifest).

**Category System — Fixed Taxonomy (Critical Finding):**
- Google Play does NOT use dynamic tag filtering. Categories are rigid: each category has hard-coded valid tags embedded in it.
- Initial selection of "Lifestyle" category was invalid because Lifestyle lacks dog/pet-related tags.
- Revised to "Books & Reference" category which includes Reference, Encyclopedia, Educational content tags — suitable for breed-reference product positioning.
- Full taxonomy: 336 fixed categories with embedded tags per category. Must validate category selection against official taxonomy before listing submission. No custom tags possible.
- **DogQuest category decision:** Books & Reference + Reference/Encyclopedia tags (validated via asasa.txt taxonomy export).

**Store Listing Form Workflow:**
1. App name (64-char limit) + Short description (80-char soft limit)
2. Category + Content rating (IARC questionnaire auto-completed)
3. Contact details + Privacy policy URL + Support website
4. Screenshots (4-8 required, 720p+, max 8 per language) — MUST include messaging overlays per store-listing best practices
5. Expanded description (~3500 chars) — product utility, features, audience, call-to-action
6. Upload release APK/AAB (~75.3 MB for closed beta)
7. Create internal testing track + add tester emails (for closed beta)
8. Submit for review (automated 24-48 hr review, then manual review if flagged)

**Messaging Strategy — "Gamified Discovery":**
- Balances dog-breed reference/utility (learning pillar) with collection/gamification (engagement pillar).
- Neither utility-only nor gamification-only resonates; hybrid messaging appeals to broader audience.
- Short description encodes both pillars: `"Discover every dog breed. Snap a photo. Level up your knowledge."` (67 chars)
- Full description will expand into: breed reference value, feature capabilities (photo identify, leveling, exams), engagement hooks (collection, leaderboard, prestige), target segments (students, educators, pet enthusiasts, dog lovers)

**Known Blockers for Sprint 16:**
- Account verification window: 24-48 hrs (started 2026-05-10, expected complete 2026-05-12)
- Cannot submit listing until account verified
- Release AAB ready (built 2026-05-10 with placeholder env vars; real secrets via CI pipeline)

## Screenshot Pipeline Facts (Session 2026-05-11, later)

- **The real breed-result card is `DogFoundDialog`** (`lib/widgets/dog_found_dialog.dart`, 1459 lines, takes `Dog` + `confidence` + `alternatives`). The similarly-named `IdentificationResultCard` at `lib/widgets/identification_result_card.dart` is **dead code** — no construction sites anywhere in `lib/`. An Explore subagent pointed at the dead widget when asked to audit "the breed result card." Always grep for `WidgetName(` construction sites before claiming a widget is "the X."
- **Dog model populated fully across all 150 breeds** in `assets/dogs.json`: `sizeCategory` (small/medium/large/giant), `temperamentTraits` (list of strings, typically 3-5), `habitat` (format `"<Group> Group | Origin: <Country>"`), `lifespan`, `weight`, `exerciseNeeds`, `groomingNeeds`, `healthPredispositions`, `dietNotes`. The `Dog.fromJson` factory at `lib/models/dog.dart:63` is defensive against missing fields.
- **Real `bgDeep` color is `Color(0xFF0F1A10)`** (dark forest green) per `lib/constants.dart:42`. CLAUDE.md still says `#1A0F0A` (warm brown) — stale, predates the green-palette migration. Use `constants.dart` as source of truth, never CLAUDE.md, for color tokens. Other tokens: `accent = #D4874E` (amber), `accentGreen = #539548`, `bgCard = #1A2B1C`, `bgNav = #0A1A0C`.
- **Player level titles (8 tiers)** in `player_service.dart:62-69`: Puppy (<3) → Good Boy (<6) → Pack Member (<10) → Breed Spotter (<15) → Dog Whisperer (<20) → Expert Handler (<30) → Show Judge (<40) → Best in Show. `xpForNextLevel` formula: `(1000 * pow(level, 1.4)).round()`.
- **`kennelServiceProvider` and `playerProvider` throw `UnimplementedError` until overridden** after Hive init. This is documented in their declaration files (`kennel_service.dart:40`, `player_service.dart:433`). Any test or seed harness that wants to render screens depending on these must override them with concrete instances backed by initialized Hive boxes, OR boot the full app via `main()`. There is no middle path.
- **`PlayerNotifier.reload()` re-reads from Hive box.** Seed functions can write directly to `Hive.box('dogquest_player_stats')` with keys `{level, xp, streak, best_streak, streak_savers, achievements, quizzes_completed, quiz_perfect_scores, total_sightings, selected_avatar}` then call `ref.read(playerProvider.notifier).reload()` to refresh state without hot-restarting.
- **`lib/dev/` is now the established home for debug-only marketing/screenshot helpers.** Contents: `screenshot_seed.dart`, `mock_screen_1.dart`, `mock_screen_5.dart`. All guarded by `kDebugMode` and tree-shaken from release builds. Wired via Settings → Developer (only visible when `kDebugMode`).
- **Marketing privacy claims must be audited against `pubspec.yaml` + `main.dart`.** `firebase_analytics`, `firebase_crashlytics`, `sentry_flutter` are all active dependencies. `FirebaseAnalytics.instance` is initialized at `main.dart:627`. Sentry runs from `main.dart` + `sync_queue_service.dart`. **"No tracking" / "No data collection" are false claims** for this app — required wording is "anonymous diagnostics with opt-out at Settings → Data & Privacy."
- **Existing `DataConsentService` exists** for analytics opt-out (referenced in `settings_screen.dart` as `_dataSharing = DataConsentService.hasConsented;`). Use this when wiring opt-out language into marketing.
- **`google_mobile_ads ^5.1.0` is in pubspec but ad-unit IDs are the Google-test pair** per Memory.md GitHub Actions secrets section. Marketing copy that says "No ads. Ever." is technically accurate today (test units don't serve real ads) but the dependency itself is a soft contradiction. Either remove the dep or rephrase before public submission. Flagged as open item in `store-listing/play_store_listing.md`.

## Screenshot Pipeline Tooling (2026-05-11, later)

- **Capture pipeline:** kDebugMode-gated seed function (`lib/dev/screenshot_seed.dart`) → manual emulator navigation → `scripts/capture_screenshots.ps1` (interactive PowerShell, prompts per screen, runs `adb shell screencap` + `adb pull`). No `integration_test/` harness — too much override plumbing for a one-time marketing deliverable. The seed function writes to Hive boxes + calls `playerProvider.notifier.reload()` so no app restart is needed.
- **Mock screens for non-shipping UI:** `lib/dev/mock_screen_1.dart` (camera viewfinder with live prediction overlay — feature not yet implemented in shipping camera), `lib/dev/mock_screen_5.dart` (branded share UI with friend avatars — friends backend on `phase-1/social-backend-realtime` not in v5.1). Both use real `NetworkDogImage` + Wikimedia thumbs + the actual app design system, so they're visually consistent with the rest of the app. Pivoted from Figma mocks to Flutter widgets for: visual consistency, no MCP OAuth dependency, repeatable, faster turnaround.
- **Framing step (device shells + copy overlay):** manual Canva web or Hotpot.ai. Canva MCP exposed only auth tools in this session — `upload-asset-from-url` requires a public URL (can't ingest local screenshots), and there's no `phone_frame`/`device_mockup` `design_type`. Manual upload-and-frame is unblocked-fast; programmatic framing would require hosting raw PNGs publicly first.
- **Per-screen typography rules** documented in `screenshots/copy.md`: headline 56-64pt at 1080-wide, SF Pro Display Bold / Inter Bold, white on dark, 4.5:1 minimum contrast (add 40% black gradient if photo busy), top-third position, 64pt edge padding.

## Related Notes

- [[Active_Tasks]] — operational state.
- [[Decisions]] — durable decisions.
- [[Corrections]] — past mistakes Jesse called out.
- [[Failure_Patterns]] — anti-patterns to never repeat.
- [[Compressed_Insights]] — condensed cross-session learnings.
- [[Patterns]] — older session-attested patterns (survived the stash loss).
