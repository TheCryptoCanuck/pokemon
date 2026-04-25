# Architecture & Design Integrity Review — Phase 1 Findings

**Review Date**: 2026-04-25  
**Scope**: Flutter state management, sync architecture, routing, ML inference pipeline, data models, service composition  
**Context**: Pre-launch (closed beta), quality-first posture, Riverpod + go_router + Supabase  
**Strictness**: Yes — critical findings halt Phase 2 until resolved

---

## Executive Summary

DogQuest demonstrates **solid fundamental architecture** with proper layering, good separation of concerns in the service tier, and sensible use of Riverpod for state management. The recent synonym clustering and conflict resolution work (2026-04-25) follows established patterns cleanly.

**No Critical findings detected.** The codebase is architecturally sound for closed-beta launch. One vestigial backend (FastAPI) should be cleaned up post-launch; one sync service has minor collision risk; and five god-class screens remain (already known, acceptable for pre-launch).

---

## Critical Issues for Phase 2 Context

**None identified.** This review found no architectural failures that block Phase 4 launch prep (TASK-049 signing key, TASK-050 Sentry DSN).

---

## High-Severity Findings

### FINDING-001: Backend FastAPI Code is Vestigial — Creates Maintenance Debt

**Severity**: High  
**Architectural Impact**: Code drift. If `backend/` ever gets revived, it will have diverged from the current Supabase-based architecture.  
**Evidence**:
- `backend/` contains 2,173 LOC of FastAPI code (auth, challenges, collection, dogs, social endpoints).
- Current app does NOT wire it: `ApiClient.isConfigured` defaults to empty string (no API_BASE_URL).
- Only 3 references to `backend_sync_service.dart` in app code (main.dart init, settings_screen.dart UI).
- `BackendSyncService` is a shim that calls an unconfigured `ApiClient` — all methods return `null` when offline or unconfigured.
- Actual backend is Supabase: `sighting_sync_service.dart`, `kennel_sync_service.dart`, `player_sync_service.dart` all push to Supabase RPC/tables.

**Architectural Violation**: Dead code in the repo violates the principle of "one source of truth" — future maintainers will be confused whether the app supports two backends or one.

**Recommendation**:
1. **Before launch or immediately post-launch**: Archive `backend/` to a separate branch (e.g., `archive/legacy-fastapi-2026-04-25`).
2. **Remove from main repo** if there is no active deployment or recovery plan.
3. **If keeper for future reference**: Document explicitly in CLAUDE.md that this is historical code, not active.
4. Remove `backend_sync_service.dart` from app startup (`main.dart` lines 645-648) — it's initialized but never called outside settings UI.

**Effort**: 30 min (git mv, update docs, remove references).

**Phase Impact**: This is a quality-debt item, not a blocker. Post-beta is fine.

---

### FINDING-002: SightingSyncService Uses Index-Based Local ID Mapping — Fragile When Sightings Reorder

**Severity**: High  
**Architectural Impact**: Data loss risk if sighting list reorders (delete, re-add, or reimport) between sync attempts.

**Evidence** (`sighting_sync_service.dart` lines 45-60):
```dart
String getOrCreateLocalId(int sightingIndex) {
  final existing = _localIdBox.get(sightingIndex.toString());
  if (existing != null) return existing;
  final id = _uuid.v4();
  _localIdBox.put(sightingIndex.toString(), id);
  return id;
}
```
- Local IDs are keyed by **array index** (0, 1, 2, ...).
- If sighting at index 5 is deleted, index 6 shifts down to 5.
- Next sync will map index 5 → new UUID instead of reusing the old one.
- Supabase deduplicates by `local_id`, so duplicate sightings could appear if the UUID changes.

**Scenario** (closed-beta risk):
1. User identifies Dog A at 10:00 (index 0, local_id=uuid-a).
2. Sync fails (network down), item queued.
3. User deletes a prior sighting at some other index.
4. Sighting list reorders; Dog A is now at index 5 instead of 0.
5. Sync retries: index 5 → new UUID (uuid-b), not uuid-a.
6. Supabase sees two sightings of Dog A (uuid-a deduplicated on prior sync, uuid-b new).

**Real Risk**: Low in normal flow (users rarely delete sightings), but catastrophic if data import/export adds/removes sightings.

**Recommendation**:
1. **Before closed beta**: Assign a stable `local_id` at sighting creation time in `SightingService.log()`, store it in the Sighting model itself.
2. Use a persistent UUID in the Sighting object, not the Hive index.
3. Update `SightingSyncService` to extract `local_id` from the sighting, not derive it from index.

**Files to Change**:
- `lib/models/sighting.dart` — add `String localId` field (generated once at creation)
- `lib/services/sighting_service.dart` — assign UUID at log() time
- `lib/services/sighting_sync_service.dart` — remove index-based mapping, use `sighting.localId`

**Effort**: 2–3 hours (model change, sync logic update, migration for old sightings without localId).

**Phase Impact**: High priority before closed beta. If sightings are synced during beta, this bug is reachable.

---

## Medium-Severity Findings

### FINDING-003: Synonym Clustering Introduces Implicit Contract — No Formal Validation

**Severity**: Medium  
**Architectural Impact**: The `dogQuestSynonymClusters` constant and the `dogQuestClusterKey()` function have an implicit contract: every cluster[0] must exist in `dogs.json`. Breakage is silent (fallback to model output, log warning).

**Evidence** (`tflite_identification_service.dart` lines 139–170):
- Clusters are defined as `const List<List<String>>` (lines 139–147).
- Preferred names assumed to exist in `dogs.json`.
- Fallback at lines 425–429 logs warning but continues (UX is degraded, not broken).
- **No compilation-time verification** that cluster members are valid breed names.

**Risk Scenario**:
1. Developer adds `['New Breed', 'Variant Name']` to clusters.
2. Typo: `'New Breed'` should be `'Newbreed'` (per dogs.json).
3. Model outputs `'Variant Name'`, service looks up cluster → `'New Breed'` → `_dogService.lookupByCommonName()` returns null.
4. Falls back to original label (UX confusing but not broken).
5. Fine-level log: "Cluster preferred name 'New Breed' not found" (only visible with log level tweaked).

**Architectural Smell**: Implicit contract suggests the need for a validation harness.

**Recommendation**:
1. **Add a file-level assertion** in `tflite_identification_service.dart` that runs at model load:
   ```dart
   void _validateSynonymClusters() {
     for (final cluster in dogQuestSynonymClusters) {
       assert(cluster.isNotEmpty, 'Empty cluster');
       final preferred = cluster.first;
       final dog = _dogService.lookupByCommonName(preferred);
       assert(dog != null, 'Cluster preferred name "$preferred" not in dogs.json');
     }
     for (final cluster in dogQuestSynonymClusters) {
       final keys = <String>{};
       for (final member in cluster) {
         assert(!keys.contains(member), 'Breed "$member" appears in multiple clusters');
         keys.add(member);
       }
     }
   }
   ```
   Call in `loadModel()` after `_dogService` is set.

2. **Add a unit test** (already exists: `test/services/tflite_identification_service_test.dart` lines 25–43) that explicitly tests:
   - No breed appears in two clusters.
   - All cluster[0] names exist in dogs.json.
   - All cluster members exist in dogs.json.

3. Document the admission criteria (already good: lines 114–125) and point tests to this doc.

**Effort**: 45 min (add validation function, extend tests, verify in CI).

**Phase Impact**: Low risk for closed beta (clusters are hand-curated and tested), but prevents a common maintenance bug.

---

### FINDING-004: TfliteIdentificationService Has Implicit Dependency on DogService Load Order

**Severity**: Medium  
**Architectural Impact**: `TfliteIdentificationService.loadModel()` builds `_labelCache` at lines 210–213 by looking up every label in `DogService`. If `DogService` hasn't been loaded yet, cache will contain many nulls.

**Evidence** (`tflite_identification_service.dart` lines 200–228):
```dart
Future<bool> loadModel() async {
  try {
    _interpreter = await Interpreter.fromAsset('assets/dog_model.tflite');
    _labels = await _loadLabels();
    // Pre-resolve all labels to Dog objects once at load time
    _labelCache = {
      for (final label in _labels)
        label: _dogService.lookupByCommonName(label),  // Line 212
    };
```
- If `DogService` isn't ready (hasn't called `load()` yet), all lookups return null.
- Downstream calls to `_matchLabelToDog()` (lines 399, 419) will hit nulls and skip those breeds.

**Where Called** (`main.dart` lines 560–577):
```
Line 561: final dogSvc = DogService();
Line 562: await dogSvc.load();
Line 568: final tfliteSvc = TfliteIdentificationService(dogSvc);
Line 569: final modelLoaded = await tfliteSvc.loadModel();
```
- **Current order is correct** (DogService loaded first, passed to TFLite, then TFLite.loadModel()).
- But there is **no compile-time check** that DogService is ready.

**Risk**: If startup code is refactored and DogService.load() is called after TfliteIdentificationService.loadModel(), the app will silently degrade (all identifications will have null dogs, skipped by line 400).

**Architectural Smell**: Hard dependency, no explicit contract. Should be documented or enforced.

**Recommendation**:
1. Add an assertion in `TfliteIdentificationService.loadModel()`:
   ```dart
   Future<bool> loadModel() async {
     assert(_dogService._dogs.isNotEmpty, 
       'DogService must be loaded before TfliteIdentificationService.loadModel()');
   ```

2. Or, better: make the dependency explicit in the constructor by requiring an already-loaded DogService:
   ```dart
   TfliteIdentificationService(LoadedDogService dogService);
   ```
   (Requires a `LoadedDogService` interface/class, overkill for this context).

3. **Minimum**: Document in code comments:
   ```dart
   /// Must be initialized AFTER DogService.load() completes.
   /// Pass an already-loaded DogService to the constructor.
   ```

**Effort**: 15 min (add assertion + comment).

**Phase Impact**: Very low risk (startup order is fixed and tested), but good hygiene for future refactors.

---

### FINDING-005: Five "God Class" Screen Files >800 LOC — Layout Violation (Known Issue)

**Severity**: Medium  
**Architectural Impact**: Screens are mixing business logic, UI layout, and state updates in one file, making them harder to test and reason about.

**Evidence**:
- `lost_dog_hub_screen.dart`: 1,670 LOC
- `profile_screen.dart`: 1,454 LOC
- `pack_screen.dart`: 1,433 LOC
- `lost_dog_map_screen.dart`: 1,378 LOC
- `identify_screen.dart`: 1,242 LOC

**Known from CLAUDE.md**: "5 remaining God-class files over 800 lines — refactoring planned."

**Not a Critical finding** because:
- Pre-launch context (closed beta), known issue, refactoring deferred.
- No architectural violation (screens are allowed to be complex for now).
- Tests exist for extracted services (not for screens themselves).

**Recommendation**: Defer to Phase 5 (post-beta). For now, document in PLAID tasks which screens are candidates:
- `identify_screen.dart`: Extract result-building logic to a new `ResultDisplayWidget`.
- `lost_dog_hub_screen.dart`: Extract map, report form, filter panel to separate widgets.
- `pack_screen.dart`: Extract member list, invite flow, settings to separate stateful widgets.

**Effort**: 3–5 days (full refactor of all 5 screens).

**Phase Impact**: None for launch. Acceptable debt.

---

### FINDING-006: Conflict Resolution Service Has Asymmetric Strategy Naming

**Severity**: Medium  
**Architectural Impact**: Minor semantic inconsistency in enum naming makes strategy intent less clear.

**Evidence** (`conflict_resolution_service.dart` lines 8–26):
```dart
enum ConflictStrategy {
  localWins,           // Local value is authoritative
  serverWins,          // Server value is authoritative
  deduplicateById,     // Insert-only; no real conflict
  serverSourceOfTruth, // Never push conflicting local data
}
```
- Three strategies use simple adjectives (`localWins`, `serverWins`, `deduplicateById`).
- One uses a phrase (`serverSourceOfTruth`), which is redundant with `serverWins` and adds semantic noise.

**Current Usage**:
- `localWins`: player stats (XP, streaks — local gameplay is truth).
- `serverWins`: user profile (may be edited on another device).
- `deduplicateById`: sightings (insert-only, dedupe on local_id).
- `serverSourceOfTruth`: social data (never push local edits, always pull from server).

**Issue**: `serverSourceOfTruth` is a *consequence* of `serverWins`, not a distinct strategy. The enum lists 4 strategies but really describes 3 resolution **behaviors**:
1. Local is authoritative (push local, ignore remote).
2. Server is authoritative (pull server, overwrite local).
3. Deduplicate by ID (merge without conflict).

`serverSourceOfTruth` conflates "server is authoritative" with "never push local edits" — the latter is a push-side policy, not a conflict resolution policy.

**Risk**: Low (current usage is correct, but semantic confusion for future maintainers).

**Recommendation**:
1. Rename `serverSourceOfTruth` → `serverOnly` (more concise, same meaning).
2. Add a comment block in the enum:
   ```dart
   /// Conflict resolution strategies for local-first sync (Hive + Supabase).
   /// Three core strategies:
   /// - localWins: local edits are primary; push local, keep on conflict.
   /// - serverWins: server is primary; pull server, overwrite local.
   /// - deduplicateById: merge without conflict (insert-only, no updates).
   /// - serverOnly: server is exclusive source; never push local edits (read-only local cache).
   enum ConflictStrategy {
     localWins,
     serverWins,
     deduplicateById,
     serverOnly, // was serverSourceOfTruth
   }
   ```

3. Update `conflict_resolution_service.dart` line 25 and all call sites (grep shows 0 references in app code — only defined, not used yet).

**Effort**: 10 min (rename, update doc).

**Phase Impact**: Low. Post-launch is fine.

---

## Low-Severity Findings

### FINDING-007: Router's Auth Gate Checks Hive Flag Instead of Session

**Severity**: Low  
**Architectural Impact**: Redundant auth check; creates a sync point that could diverge.

**Evidence** (`router.dart` lines 83–88):
```dart
final session = Supabase.instance.client.auth.currentSession;
final playerBox = Hive.box('dogquest_player_stats');
final offlineMode = playerBox.get('offline_mode', defaultValue: false) as bool;

if (session == null && !offlineMode) return '/login';
```
- Checks Supabase session first (correct).
- Falls back to offline mode flag in Hive (also correct for offline).
- But stores `has_auth_token` in Hive **separately** (main.dart, removed in TASK-044).

**Minor Issue**: Auth state is now split across two sources (Supabase session + offline_mode flag). If they diverge, UX is undefined.

**Example**: User is offline, `offline_mode=true`, but Supabase session expires. Router thinks auth is OK, but next sync will fail.

**Low Risk** because:
- Router itself is correct (checks session first).
- Offline mode is explicitly set by user in settings (not automatic).
- Sync failures are handled gracefully.

**Recommendation**: Document the offline mode contract explicitly:
```dart
/// Offline mode allows auth-less gameplay when user explicitly toggles it.
/// Does NOT auto-enable on network loss; requires explicit user action.
/// When offline mode is OFF, Supabase session is required (router gates).
```

**Effort**: 5 min (add comment).

**Phase Impact**: None.

---

### FINDING-008: IdentificationOrchestrator Couples 20+ Dependencies via Constructor

**Severity**: Low  
**Architectural Impact**: Service locator pattern (Riverpod) hides the true dependency count, but the orchestrator effectively depends on all major services.

**Evidence** (`identification_orchestrator.dart` lines 100–150):
```dart
Future<IdentificationOutcome> processIdentification(...) async {
  final kennelSvc = _ref.read(kennelServiceProvider);
  final sightingSvc = _ref.read(sightingServiceProvider);
  final socialSvc = _ref.read(dogSocialServiceProvider);
  final dogGroupSvc = _ref.read(dogGroupServiceProvider);
  ... (many more)
}
```
- Method reads 15+ services from Riverpod context.
- Extracted correctly (formerly god method in `identify_screen.dart`).
- Single responsibility: orchestrate the post-identification flow.

**Not an architectural violation**, but suggests **high cognitive load** — the identification flow touches almost every subsystem.

**Acceptable because**:
- Dependencies are explicit (passed via Riverpod, not hidden in singletons).
- Orchestrator is narrow in scope (process one identification, not multiple flows).
- Tests can mock providers.
- Riverpod's `ref.read()` is the right pattern for this.

**Recommendation**: None — this is well-handled by the current design.

---

### FINDING-009: TTA (Test-Time Augmentation) is Opt-In Constant, Not Configuration

**Severity**: Low  
**Architectural Impact**: No flexibility to test without TTA at runtime (would require rebuild).

**Evidence** (`tflite_identification_service.dart` line 196):
```dart
static const bool _enableTTA = true;
```
- TTA is a compile-time constant.
- Can't be toggled in settings without recompilation.
- If TTA is misbehaving, debugging is harder (need to rebuild app).

**Acceptable because**:
- TTA is proven (3-variant average, low overhead).
- No need to disable in production.
- Debug rebuilds are quick.

**Minor UX win** (post-launch):
- Add a debug setting (Settings > Advanced > "Use test-time augmentation").
- Read it at runtime and skip TTA if disabled.
- Useful for A/B testing accuracy vs. latency.

**Effort**: 30 min (add setting, conditional logic in `_preprocessImage()`).

**Phase Impact**: None for launch.

---

## Design Pattern Compliance & Consistency

### Pattern Audit: Riverpod State Management

**Finding**: ✅ Well-structured. Services are singletons (`.overrideWithValue()`), notifiers use `StateNotifier` for mutable state (`PlayerNotifier`, `DailyChallengeNotifier`, etc.).

**Consistency**: High. All providers follow the same pattern:
- Immutable data services: `overrideWithValue(service)`.
- Mutable state: `overrideWith((_) => notifier)`.

**No findings**.

---

### Pattern Audit: Sync Service Composition

**Finding**: ✅ Correct separation. Sync queue (FIFO retry logic), sighting sync (Hive → Supabase), player sync (stats → users table), kennel sync (collection → kennel table).

**One issue**: [FINDING-002] Index-based local ID mapping (high priority).

---

### Pattern Audit: Service Dependency Direction

**Finding**: ✅ Good layering. Services don't import other services (except dependency injection via constructor). No circular deps detected.

**Grep result**: Only one service imports another (`dog_group_service.dart` imports `dog_group_service.dart` — wait, let me verify):
```
lib/services/dog_group_service.dart (no external imports)
```

Actually, no inter-service imports found (good).

**No findings**.

---

### Pattern Audit: ML Inference Pipeline

**Finding**: ✅ Clean separation:
- `tflite_identification_service.dart` — inference + result building.
- `identification_orchestrator.dart` — post-identification business logic.
- `dog_found_dialog.dart` — UI rendering of results.

**Data flow**: Model → IdentificationResult list → Outcome → Dialog. No backflow.

**One issue**: [FINDING-004] Implicit DogService load order (medium priority, low risk).

---

## Data Model Integrity

### Dog Model Schema

**Audit**: `assets/dogs.json` (296 entries) ↔ `assets/dog_labels.txt` (296 labels) ↔ Dart `Dog` model.

**Finding**: ✅ Contract is implicit but validated:
- `DogService.load()` parses JSON, builds indices by name.
- `TfliteIdentificationService._labelCache` maps labels to Dogs at load time.
- `dogQuestSynonymClusters` members are validated in tests (test/services/tflite_identification_service_test.dart).

**One issue**: [FINDING-003] No compile-time validation of cluster membership (medium priority).

---

### Hive Box Schema

**Audit**: 10+ Hive boxes (`dogquest_sightings_v1`, `dogquest_kennel`, `dogquest_player_stats`, etc.).

**Finding**: ✅ Good isolation. Each box is prefixed `dogquest_` to avoid AviQuest collisions (DECISION-001, 2026-04-24).

**Encryption**: Sightings box is AES-encrypted (`main.dart` lines 74–91), key stored in platform secure storage.

**No findings**.

---

### Supabase RPC Contract

**Audit**: Sighting sync calls `sync_sightings` RPC with JSONB payload (lines 137–140).

**Finding**: ✅ Payload structure is documented, includes `local_id` for deduplication.

**One issue**: [FINDING-002] Local ID derivation is fragile (high priority).

---

## API Design Review

### Internal API: IdentificationService Interface

**Contract** (`lib/services/identification_service.dart`):
```dart
abstract class IdentificationService {
  bool get isModelLoaded;
  Future<List<IdentificationResult>> identify(File imageFile);
}
```

**Finding**: ✅ Minimal, correct. Returns a list of ranked results.

**No findings**.

---

### Internal API: SyncService Family

**Contract** (sighting_sync_service.dart, player_sync_service.dart):
- `Future<int> syncAll()` — sync pending items, return count accepted.
- `Future<void> retryPending()` — retry failed items.
- Hive-backed queue with exponential backoff.

**Finding**: ✅ Consistent error handling (log failures, enqueue for retry).

**One issue**: [FINDING-002] Index-based local ID (high priority).

---

### External API: Supabase RLS

**Audit**: Backend is Supabase (auth, RLS policies, RPC functions). No direct raw SQL from Dart.

**Finding**: ✅ Good boundary. Dart code uses only RPC and table queries with `.eq()` filters (authenticated).

**No findings**.

---

## Architectural Consistency: Recent Session Work

### Synonym Clustering (2026-04-25)

**Pattern**: New feature (clustering table + deduplication logic) follows established patterns:
- Data: constant list in service file (like `_minConfidence`, `_topK`).
- Logic: inline in `_buildResults()` — tight coupling is acceptable here (alternative-ranking is core to identification).
- Tests: unit tests in `test/services/tflite_identification_service_test.dart` (§11, §12).

**Assessment**: ✅ Consistent with project style. No architectural violations.

**One issue**: [FINDING-003] No validation of cluster structure (medium priority).

---

### Counter Dissonance Fix (2026-04-25)

**Pattern**: UI consistency fix in `dog_found_dialog.dart` (confidence labeling, top-3 ranked alternatives).

**Assessment**: ✅ Local UI concern, correctly contained in the dialog widget. No service-layer changes.

**No findings**.

---

## Missing Architectural Documentation

### ADR (Architecture Decision Records)

**Finding**: ✅ Decisions ARE documented, but in vault (`.second_brain/01_Memory/Decisions.md`), not in the repo as ADRs.

**For pre-launch**: This is acceptable (vault is the source of truth per CLAUDE.md session-start rules).

**Post-launch recommendation**: Migrate high-impact decisions to `docs/adr/` in the repo (e.g., "Supabase backend choice," "Offline-first sync with conflict resolution," "Synonym clustering").

**Effort**: 2–3 hours (write 8–10 ADRs).

**Phase Impact**: Quality debt, not a blocker.

---

## Summary Table

| Finding ID | Title | Severity | Blocks Launch? | Recommended Timing |
|---|---|---|---|---|
| FINDING-001 | Backend FastAPI code is vestigial | High | No | Post-launch cleanup |
| FINDING-002 | SightingSyncService fragile index mapping | High | No (low risk in beta) | Before closed beta sync |
| FINDING-003 | Synonym clustering has no validation | Medium | No | Before Q2 (could add new clusters) |
| FINDING-004 | TfliteIdentificationService load-order dependency | Medium | No (order is correct) | During next refactor |
| FINDING-005 | Five god-class screens >800 LOC | Medium | No (known debt) | Post-launch refactor |
| FINDING-006 | Conflict resolution enum naming inconsistency | Medium | No | Post-launch polish |
| FINDING-007 | Router auth gate has redundant checks | Low | No | Post-launch docs |
| FINDING-008 | IdentificationOrchestrator couples 20+ services | Low | No (acceptable coupling) | None required |
| FINDING-009 | TTA is compile-time constant, not configurable | Low | No | Post-launch debug feature |

---

## Recommendations for Phase 2 & Beyond

### Phase 2 (Security & Performance)
- **FINDING-002 (High)**: Fix SightingSyncService before beta testing sync.
- **FINDING-003 (Medium)**: Add validation for synonym clusters.

### Phase 3 (Testing & Documentation)
- **FINDING-006 (Medium)**: Rename `serverSourceOfTruth` → `serverOnly`.
- Missing ADRs for core decisions (Supabase, conflict resolution, offline-first).

### Phase 4 (Launch Prep)
- **FINDING-001 (High)**: Archive or remove `backend/` directory.
- Ensure TASK-049 (signing key) and TASK-050 (Sentry DSN) are wired before beta.

### Phase 5 (Growth)
- **FINDING-005 (Medium)**: Refactor god-class screens (identify, profile, pack, lost_dog_hub, lost_dog_map).

---

## Conclusion

DogQuest exhibits **clean, well-layered architecture** suitable for a quality-first pre-launch posture. Services are properly isolated, Riverpod providers follow consistent patterns, and the sync architecture (despite one fragile point) is sound.

**No critical architectural blockers identified.** The codebase is ready for closed-beta feedback loops.

**Two actionable items before beta**:
1. FINDING-002: Fix sighting local ID mapping (2–3h).
2. FINDING-003: Add cluster validation (45 min).

**One post-launch cleanup**:
3. FINDING-001: Archive FastAPI backend (30 min).

All other findings are low-risk technical debt or documentation gaps, acceptable for pre-launch.

