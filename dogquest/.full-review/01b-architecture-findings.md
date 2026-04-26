# Phase 1B — Architecture Findings

**Review Date**: 2026-04-25 (evening, post 13 commits since prior review)  
**Scope**: Follow-up to 2026-04-25 morning review (archived at `.full-review-archive-2026-04-25/`). Checks for regressions and new issues post-commit.  
**Context**: Pre-launch (closed beta), quality-first posture, Riverpod + go_router + Supabase  
**Strictness**: Yes — critical findings halt Phase 2 until resolved

---

## Executive Summary

DogQuest maintains **solid fundamental architecture** with no new critical issues introduced. The 13 commits since the prior review (5 sec, 5 refactor-recovery, 5 T1 deck-clearing) have not degraded the codebase. Prior findings (C1-C3, covered by these commits) remain closed. The same medium-priority items (FINDING-002: SightingSyncService sec-C2, FINDING-005: god-class screens) persist but are not regressions — they were open before and remain dormant/deferred as intended.

**No new critical or high-severity findings detected.** The codebase is architecturally sound for closed-beta launch.

---

## Status of Prior Findings

### Closed (Verified Fixed)
- **C1 (sync ownership)**: Router redirect + sync-service guards + RLS verified → closed ✅
- **C2 (SightingSync UUID)**: Dormant marker with `init()` throw, sec-C2 documented in dartdoc → mitigated ✅
- **C3 (vestigial backend/)**: Removed per commit `aaebc5d` → closed ✅
- **OPS-001 (no CI/CD)**: GitHub Actions wired → closed ✅
- **OPS-002 (no signing)**: Keystore + signed APK pipeline → closed ✅
- **DOC-001 (CLAUDE.md drift)**: Updated per commit `df8b38a` → closed ✅

No regressions detected in closed items.

### Open and Unchanged (Not Regressions, By Design)
- **FINDING-002 (SightingSyncService index-vs-sorted-position)**: Still dormant. `init()` unconditionally throws StateError. Sec-C2 bug is documented in dartdoc (lines 29–49). **Status**: Deferred before closed beta, acceptable. Still requires fix before production sync, but not a blocker for beta.
- **FINDING-005 (five god-class screens >800 LOC)**: Still present. `lost_dog_map_screen.dart` (1429 LOC, +39 from prior), `profile_screen.dart` (1425 LOC, +157 from prior), `pack_screen.dart` (1253 LOC, unchanged). Not fixed, but known deferred. **Status**: Acceptable technical debt for pre-launch.

Both items were flagged as acceptable deferred in the prior review. No regression in architectural integrity.

---

## New Findings This Pass

### Critical Issues
**None detected.**

---

### High-Severity Issues
**None detected.**

All of FINDING-001 through FINDING-009 from the prior review remain unchanged in severity and status. No new high-level architectural violations.

---

### Medium-Severity Issues

#### FINDING-M1: KennelService Implicit DogService Dependency via Setter

**Severity**: Medium  
**Architectural Impact**: Fragile initialization contract. `KennelService` optionally depends on `DogService` via `setDogService()` (line 13). If the setter is not called, `collectedDogs` silently returns empty list instead of throwing.

**Evidence** (`lib/services/kennel_service.dart` lines 22–29):
```dart
List<Dog> get collectedDogs {
  final svc = _dogSvc;
  if (svc == null) return [];  // Silent fallback — no assertion
  return _box.values.map((name) => svc.lookup(name)).whereType<Dog>().toList();
}
```

Current initialization (main.dart lines 627–631) is correct:
```dart
final kennelSvc = KennelService(kennelBox);
final playerNotifier = PlayerNotifier(playerBox);
final dailyDogSvc = DailyDogService(dogSvc, playerBox);
kennelSvc.setDogService(dogSvc);  // ← called in correct order
```

But there is **no compile-time guarantee**. A refactor could omit the call and `collectedDogs` would silently degrade.

**Recommendation**:
Add an assertion in `collectedDogs`:
```dart
List<Dog> get collectedDogs {
  assert(_dogSvc != null, 'KennelService.setDogService() must be called during init');
  return _box.values.map((name) => _dogSvc!.lookup(name)).whereType<Dog>().toList();
}
```

**Effort**: 5 min.  
**Phase Impact**: Low risk (current order is correct, tested). Good hygiene for future refactors.

---

#### FINDING-M2: Read-Modify-Write JSON Blob Pattern in Multiple Services

**Severity**: Medium  
**Architectural Impact**: Four services follow the same O(N) per-write pattern (full JSON parse → modify in memory → full JSON encode):
- `LostDogService` (line 80–82: `allReports` → add → `_saveReports()`)
- `PackService` (line 30–33: `pack` → add member → `_save()`)
- `DogFriendshipService` (line 51–63: `friendships` → add friendship → `_saveFriendships()`)
- `DogSocialService` (implicit via getters)

This is acceptable for small collections (< 1000 items) but creates contention if:
1. Multiple concurrent writes (pack members editing simultaneously in shared device mode — **Pack feature** is new).
2. Lost dog reports scale (migration from local → Supabase planned, but during offline phase this is the bottleneck).
3. Friendships scale (1000+ neighborhood dogs with interactions).

**Current Risk**: Low (beta users won't stress these), but the architecture won't scale to thousands of items without refactoring.

**Examples of affected code**:
- `LostDogService.markFound()` (line 89–96): reads all, modifies one, writes all.
- `PackService.addMember()` (line 29–34): reads pack, adds member, writes pack.
- `DogFriendshipService.visit()` (line 67–83): reads all friendships, increments one visit count, writes all.

**Architectural Smell**: Services are persisting entire collections as JSON blobs instead of using Hive's built-in document/record model or a lightweight index.

**Recommendation**:
1. **Acceptable for closed beta** (scale is not a concern yet).
2. **Post-launch refactor (low priority)**: Introduce a lightweight repository pattern that caches the parsed list and only writes on explicit `flush()` call, or switch to itemized Hive storage (one box entry per friendship/report).
3. **Consider**: `pull_sync_service.dart` already exists (line 40 in services list) — check if it's intended to replace this pattern.

**Effort**: 4–8 hours (refactor 4 services to use record-per-item storage).  
**Phase Impact**: None for closed beta. Post-launch optimization.

---

### Low-Severity Issues

No new low-severity findings.

---

## Architecture Consistency Check: Recent Commits

### Sec-Related Commits (5)
- Router auth gate: `offline_mode` now cleared on authenticated session (lines 97–101 in `router.dart`) — correct per prior review sec-C1.
- No new security boundaries violated.

### Refactor-Recovery Commits (5)
- Widget extraction patterns (lib/widgets/{identify,lost_dog,map,pack,profile}/) follow consistent pattern.
- No regressions in dependency injection or provider wiring.

### T1 Deck-Clearing Commits (5)
- `CLAUDE.md` updated (doc drift closed).
- No architectural changes.

**Assessment**: ✅ Commits are consistent with project architecture. No new violations.

---

## Data Model Integrity

### Hive Box Schema
- Still using `dogquest_` prefix isolation (no collisions with AviQuest).
- Sightings box remains AES-encrypted with secure key storage.
- No schema drift detected.

**Assessment**: ✅ Solid.

---

## Riverpod Provider Architecture

Providers follow consistent patterns:
- Immutable services: `overrideWithValue(service)`.
- Mutable state: `overrideWith((_) => notifier)`.
- 26 providers initialized in main.dart lines 710–735.

No circular dependencies detected. No provider sprawl beyond prior review.

**Assessment**: ✅ Well-structured.

---

## Service Layer Composition

### Known Dormant/Stubbed Services
- `BackendSyncService` — stub (returns null on all methods, per design).
- `SightingSyncService` — dormant (init() throws per sec-C2).
- No regression; both are intentional.

### Parallel Implementations
- Local-first (Hive): `dog_social_service.dart`, `pack_service.dart`, `dog_friendship_service.dart`, `lost_dog_service.dart`.
- Remote (Supabase): `supabase_*_service.dart` (5+ files).
- **No bridge logic yet** — both stacks exist but aren't coordinated. Acceptable for closed beta (local-first). Sync bridges planned for post-launch.

**Assessment**: ✅ Pattern is understood and documented.

---

## Router & Auth Gate

Redirect logic (router.dart lines 65–103):
- Checks Supabase session first.
- Falls back to offline mode flag for offline gameplay.
- Clears `offline_mode` when authenticated session appears (sec-C1 fix).

No regressions. Auth gate is correct.

**Assessment**: ✅ Solid.

---

## Observability & Error Handling

- Logging: Consistent use of `Logger('ServiceName')`.
- Errors: Logged at appropriate levels (info, warning, severe).
- Sentry: Integrated if DSN provided; fallback to local handlers if not.
- Firebase Crashlytics: Integrated with Sentry fallback.

No new observability gaps detected.

**Assessment**: ✅ Adequate for beta.

---

## What's Architecturally Sound

DogQuest demonstrates clean separation of concerns across the service layer, proper use of Riverpod for state management without sprawl, sensible Hive isolation, and correct auth gating. The ML inference pipeline (identification service → orchestrator → UI) is well-layered with no backflow. Provider initialization is explicit and sequenced correctly. Error handling is consistent and logged.

The codebase is fundamentally architected for quality and maintainability. The known medium-priority items (SightingSyncService sec-C2, god-class screens) are deferred intentionally and documented, not architectural failures.

---

## Summary Table: Open Items from Prior Review

| Finding ID | Title | Severity | Status | Blocker? |
|---|---|---|---|---|
| FINDING-001 | Backend FastAPI code is vestigial | High | Closed (removed) | No |
| FINDING-002 | SightingSyncService fragile index mapping | High | Open (dormant) | No (deferred) |
| FINDING-003 | Synonym clustering has no validation | Medium | Open | No |
| FINDING-004 | TfliteIdentificationService load-order dependency | Medium | Open | No (order is correct) |
| FINDING-005 | Five god-class screens >800 LOC | Medium | Open (known debt) | No |
| FINDING-006 | Conflict resolution enum naming inconsistency | Medium | Open | No |
| FINDING-007 | Router auth gate redundant checks | Low | Open | No |
| FINDING-008 | IdentificationOrchestrator couples 20+ services | Low | Open (acceptable) | No |
| FINDING-009 | TTA is compile-time constant, not configurable | Low | Open | No |
| **NEW** FINDING-M1 | KennelService implicit DogService dependency | Medium | **New** | No |
| **NEW** FINDING-M2 | Read-modify-write JSON blob pattern in 4 services | Medium | **New** | No |

---

## Recommendations for Phase 2 & Beyond

### Phase 2 (Security & Performance) — Pre-Beta
- **FINDING-002 (High)**: SightingSyncService remains dormant. Good. Do not wire without fixing sec-C2.
- **FINDING-M1 (Medium)**: Add assertion to `KennelService.collectedDogs` (5 min).
- **FINDING-M2 (Medium)**: Document read-modify-write pattern as acceptable for beta scale; flag for post-launch refactor.

### Phase 3 (Testing & Documentation)
- **FINDING-003, 004, 006**: Validation, load-order assertions, enum naming — low-risk cleanup.

### Phase 4 (Launch Prep)
- Ensure TASK-049 (signing key) and TASK-050 (Sentry DSN) are wired.

### Phase 5 (Growth)
- **FINDING-005**: Refactor god-class screens.
- **FINDING-M2**: Optimize read-modify-write services (per-item Hive storage or lightweight cache).

---

## Conclusion

DogQuest is **architecturally healthy and ready for closed-beta launch**. No new critical or architectural regressions introduced by the 13 recent commits. The prior review's closed items remain closed; open items remain deferred as intended.

Two new medium-priority findings (KennelService setter assertion, read-modify-write pattern scaling) are minor hygiene issues, not blockers.

**Next action**: Proceed to Phase 2 (Security & Performance review). FINDING-002 (SightingSyncService) must remain dormant until sec-C2 is fixed, but that's a pre-production gate, not a beta blocker.
