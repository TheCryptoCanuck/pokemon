# Phase 1 — Code Quality & Architecture (Consolidated)

**Review date**: 2026-04-25 evening (post 13-commit landing)
**Mode**: strict, security-focus
**Method**: Strategic sampling + pattern grep (1A); top-down + service layer + data model + commits diff (1B)

## Executive read

DogQuest is in **good architectural health** and **good-but-uneven code-quality health**. The 2026-04-25 god-class extraction landed cleanly (no dead-duplicate-class regressions detected). Null safety is rigorous; resource lifecycle is disciplined; dependencies are modern; the router/auth gate is correct. Service layer separation, Hive isolation, and Riverpod patterns are sound.

Where it shows strain:
- **2 Criticals** from 1A (stream subscription leaks + swallowed geolocator exceptions). 1B found no new architectural Criticals.
- **9 files exceed 1000 lines** (god-class debt persists post-refactor on the screens that didn't get extracted yet — `lost_dog_map_screen` 1390, `profile_screen` 1268, `pack_screen` 1253, `dog_found_dialog` 1219).
- **0.04% test coverage** (22 tests / 52.9K lines) — security-sensitive services have no unit tests.
- **Configuration leak** — Supabase URL + anon key have hardcoded defaults in `main.dart:100-103` that ship to release if `--dart-define` is omitted.
- **81 widget-returning helper functions** scattered across screens block testability and `const`-ification.
- **Two read-modify-write JSON blob services** (LostDog, Pack, DogFriendship, DogSocial) — fine for beta scale, won't survive post-launch growth.

No regressions in the closed prior-review items (C1, C2-dormant, C3, OPS-001, OPS-002, DOC-001).

## Critical findings (strict-mode bar)

### Q1 — Stream subscription leaks (4 instances)
**Source**: 1A. **Severity**: Critical.
- `lib/screens/lost_dog_map_screen.dart:41` (`_sightingSub` race-condition risk on dispose timing)
- `lib/screens/lost_dog_hub_screen.dart:~90` (likely similar — binary grep match)
- `lib/widgets/lost_dog/help_find_tab.dart` (refactor may have carried forward a leak)
- 4th instance from binary-match count
**Fix**: Pair every `.listen()` with cancel-in-`dispose()` BEFORE `super.dispose()`. Or convert to `ref.watch()` (Riverpod owns lifecycle).
**Effort**: ~30 min.

### Q2 — Swallowed geolocator exceptions
**Source**: 1A. **Severity**: Critical (in security-focus + lost-dog context where location accuracy is the feature).
- `lib/widgets/lost_dog/help_find_tab.dart:57-62` — generic `catch (e)`, no log.
- `lib/screens/lost_dog_map_screen.dart:77` — `catch (_)` discards entirely.
- ~10 more spots use generic broad catches per 1A (M4 below).
**Fix**: `_log.warning('Geolocator failed', e, st)` and surface exception type in user-facing copy. Crashlytics will then record it.
**Effort**: ~30 min.

## High findings

### Q3 — 81 widget-returning helper functions block testability and extraction
**Source**: 1A H1.
**Why**: Private `_buildSomething()` methods are invisible to the analyzer, can't be `const`, can't be tested. Pattern is endemic across screens.
**Fix**: Convert to named widget classes; >20 lines extract to `lib/widgets/<scope>/`. Match the 2026-04-25 refactor pattern.
**Effort**: ongoing during feature work; ~40-60 hr full-codebase sweep. Prioritize the >1000-line screens first.

### Q4 — Test coverage at 0.04% on 52.9K lines
**Source**: 1A H3.
**Untested security-sensitive paths**: auth flows (offline + Supabase), api_client, all Supabase services except `supabase_social` (which has 30 broken mocks pending T5 rewire), photo_upload, lost_dog sync, embedding extraction.
**Fix**: 60% coverage target on critical paths first (auth, lost_dog PII, sighting crypto, embedding). `mocktail` already in deps.
**Effort**: 10-15 hr phased. Hooks into the T5 test-fix tasks already on Active_Tasks.

### Q5 — Hardcoded Supabase defaults in main.dart
**Source**: 1A H4.
- `lib/main.dart:100`: `SUPABASE_URL` defaults to `https://hdcpymjnrbelaawhncep.supabase.co`
- `lib/main.dart:102`: `SUPABASE_ANON_KEY` defaults to a public key
**Why**: These ship to APK if `--dart-define` is omitted in any release build. While the keys are "publishable", the project's Supabase instance is now exposed to anyone who decompiles. Same shape as the api_client.dart pre-existing concern flagged in CLAUDE.md.
**Fix**: `assert(_supabaseUrl.isNotEmpty, 'SUPABASE_URL required')` at startup; CI guards `--dart-define` presence.
**Effort**: 15 min.

### Q6 — GlobalKey use (9 instances)
**Source**: 1A H2.
- `lib/widgets/dog_found_dialog.dart:51` (`_shareCardKey` for `RenderRepaintBoundary` capture)
- 8 more from binary-grep
**Fix**: Most replaceable with `RepaintBoundary` + `render()` (no key) or `ref.watch()`. Audit each.
**Effort**: 1-2 hr.

## Medium findings

### Q7 — 9 files >1000 lines (god-screen debt)
**Source**: 1A M1, 1B FINDING-005.
- `lost_dog_map_screen.dart` 1390 (1A) / 1429 (1B reports +39 from prior — minor disagreement on line count, treat ~1390-1430 as range; either way it's the biggest)
- `profile_screen.dart` 1268
- `pack_screen.dart` 1253
- `dog_found_dialog.dart` 1219 (T2 redesign spec already exists)
- `quiz_screen.dart` 1042 (post TASK-046 refactor; spec already in queue)
- `map_tab.dart` 1020
- `identify_screen.dart` 1002
- `scan_stray_screen.dart` 976
- `friends_screen.dart` 899
- `settings_screen.dart` 869
**Fix**: Extract per the 2026-04-25 widget-subfolder pattern. Each → coordinator + 2-4 named widgets, target ~300 LOC per file.
**Effort**: ~6 hr per screen at current pattern velocity.

### Q8 — 464 null assertions, 34 missing `context.mounted` guards, 12-15 generic async catches
**Source**: 1A M2/M3/M4.
**Fix**: Linter rule sweep for `mounted` guards (1 hr); typed exception scoping on async sweeps (~3 hr); `late final` and `firstOrNull` migrations as opportunistic touch-ups.

### Q9 — KennelService implicit DogService setter dependency
**Source**: 1B FINDING-M1.
- `lib/services/kennel_service.dart:22-29` — `collectedDogs` returns `[]` silently if setter not called.
**Fix**: Add `assert(_dogSvc != null, 'setDogService must be called during init')` (5 min).

### Q10 — Read-modify-write JSON-blob pattern in 4 services
**Source**: 1B FINDING-M2.
- `LostDogService` (sec-C2-style risk if scaled), `PackService`, `DogFriendshipService`, `DogSocialService`
**Why**: Acceptable for beta scale; doesn't survive 1000+ items per box.
**Fix**: Post-launch refactor to per-item Hive storage or repository pattern with explicit `flush()`.
**Effort**: 4-8 hr deferred to post-launch.

### Q11 — Analysis options disable `prefer_const_constructors` and `prefer_const_literals_to_create_immutables`
**Source**: 1A M5. `lib/analysis_options.yaml:4-6`
**Fix**: Re-enable; use `// ignore:` on specific false positives.
**Effort**: ~1 hr including the cleanup pass.

### Open from prior review (still open, not regressions)
| ID | Title | Status |
|----|-------|--------|
| FINDING-002 | SightingSyncService sec-C2 | Dormant (init throws); deferred |
| FINDING-003 | Synonym clustering has no validation | Open |
| FINDING-004 | TfliteIdentificationService load-order dependency | Open (order is correct) |
| FINDING-005 | Five god-class screens >800 LOC | Open (Q7 above is the live count) |
| FINDING-006 | Conflict resolution enum naming inconsistency | Open |
| FINDING-007 | Router auth gate redundant checks | Open (low) |
| FINDING-008 | IdentificationOrchestrator couples 20+ services | Open (acceptable) |
| FINDING-009 | TTA is compile-time constant | Open |

## Low findings

- **Q-L1**: 0 `unawaited()` calls despite CLAUDE.md guideline; 1 fire-and-forget at `lib/screens/identify_screen.dart:73` should be wrapped (1A L1).
- **Q-L2**: 1 `print()` call in committed code (1A L2).
- **Q-L3**: Dart 3 sealed classes underutilized for state unions (1A L4).

## Patterns observed

1. **Widget-returning helper functions** (81 instances) — biggest stylistic debt, blocks the "extract widget" velocity gains the recent refactor delivered.
2. **Async error handling drift** — 12-15 broad/swallowed catches, especially around geolocator and async Supabase calls.
3. **Stream lifecycle gaps** — 4 instances. Codebase mostly avoids subscriptions (good) but the ones that exist are precarious.
4. **Missing `context.mounted` guards** — 34 sites. Latent crash vector.
5. **Configuration surface leaks** — `main.dart` Supabase + `api_client.dart` dev URL both ship defaults.
6. **JSON-blob services don't scale** — 4 services hit the read-modify-write pattern; fine until growth.

## What's healthy

- Null safety enforcement (no unsafe casts; bangs justified)
- Resource lifecycle discipline (81 dispose calls; 37 `late final`)
- Dependency hygiene (Riverpod 2.5, go_router 14, tflite_flutter 0.11; no abandoned packages)
- Router and auth gate (sec-C1 fix landed correctly; redirect logic clean)
- Hive isolation (`dogquest_` prefix; sightings AES-encrypted)
- Riverpod provider architecture (26 providers in main.dart, no circular deps, no sprawl beyond prior baseline)
- Logging consistency (`Logger('ServiceName')`, appropriate levels)
- Code style (matches CLAUDE.md conventions throughout)
- Test structure (the 22 that exist are well-organized — issue is volume, not quality)
- The recent god-class refactor — no dead-duplicate-class regression detected this pass; pattern worked

## Critical issues to carry into Phase 2 context

For the security agent (Phase 2A):
- **Q5** (hardcoded Supabase keys in main.dart) is half-security/half-quality — the security implications dominate.
- **Q2** (swallowed geolocator exceptions) is a security/observability gap on a feature that processes precise location.
- **Q4** (test coverage on auth + Supabase services + lost_dog) means whatever security findings Phase 2A surfaces likely have ZERO test guardrails.
- The lost-dog-spec GDPR Criticals (plaintext contact_info broadcast, no consent/policy plumbing, public photo URLs, exact GPS) are in scope for Phase 2A — re-flag at proper severity.

For the performance agent (Phase 2B):
- **Q1** (stream subscription leaks) is a perf concern as much as a correctness concern.
- **Q10** (read-modify-write JSON blob) is the canonical scalability ceiling.
- **Q7** (god-class screens) — `lost_dog_map_screen` builds a heavy map widget tree; check for unnecessary rebuilds and missing `const`.
- TFLite load: prior review's FW-001 (dual TFLite model load on cold start) — verify whether still present.
