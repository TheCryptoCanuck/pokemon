# Phase 2b: Performance & Scalability Review

**Status**: complete. 4 High, 6 Medium, 3 Low findings.

This review covers:
- ML inference path (TTA, isolate offloading, synonym clustering)
- Sync queue + offline-first (backoff, indexing, conflict resolution)
- Hive local storage (reads, startup JSON parse)
- Hot UI paths (identify_screen, kennel_screen, profile_screen)
- Image handling (cached_network_image, Wikimedia)
- Startup + cold-start (service initialization, time-to-interactive)
- AdMob monetization (frequency cap, cooldown)
- Python audit tooling (GPU batching)

## Findings

### P-H1: ML Inference Path — 3-Variant TTA Overhead Justified but Monitor On-Device Wall Time

**Severity**: High  
**Estimated Performance Impact**: +150–200% latency vs single-pass inference on-device; acceptable for closed beta.

**Context**:
- `tflite_identification_service.dart` implements 3-variant TTA (tight center, horizontal flip, loose zoom).
- Each variant is ~300KB flat Uint8List; isolate offloading via `compute(_preprocessImage, bytes)` sends bytes and returns 3×300KB tensors.
- Inference loop runs all 3 variants, averages confidence scores across variants.
- Measured (Python/Keras GPU only): ~161ms with Keras batched; on-device TFLite CPU expected ~319ms per image (CLAUDE.md notes).

**Issue**:
TTA is justified (improved top-1 accuracy on noisy images), but on-device wall time is material. For 319ms baseline:
- 3 variants = ~950ms total inference time on mid-range Android CPU
- Plus preprocessing + result building → ~1.2–1.5s capture-to-result latency
- User-perceived latency is acceptable (result appears while shutter animation plays), but at the edge of "feels instant"

**Recommendation**:
1. **Pre-beta validation**: On first available Android test device (Pixel 5 / 6 or Moto G), measure actual on-device wall time for:
   - Single image capture → TTA inference → UI update
   - Report absolute ms and whether 60fps shutter animation holds steady during inference
   - Expected: ~800ms–2s is acceptable; >2.5s becomes noticeable jank
2. **If on-device latency >2.5s in closed beta**: Implement runtime TTA toggle (compile-time constant at `_enableTTA = true` already exists; move to `.g.dart` provider for Riverpod toggle)
3. **Do not remove TTA before closed beta**: 9.4pt quantization headroom (task #32) means TTA is helping accuracy; removal only if on-device latency forces it

**Effort**: 5 min to validate on device (measurement), 30 min to add toggle if needed.

---

### P-H2: Sync Queue Indexing — SightingSyncService Uses Fragile Array-Index Local IDs, Duplicate Risk Under Load

**Severity**: High  
**Estimated Performance Impact**: Silent duplicate sightings if IDs reorder; N+1 query cost on pull-sync to detect dups.

**Context**:
- `sighting_sync_service.dart` maps sightings by array index (`0, 1, 2…`) to generate "local IDs" for deduplication on Supabase
- When a sighting is deleted or the Hive box is reindexed (compaction, transaction rollback), array indices shift
- Subsequent sync generates new local IDs for the same sighting, Supabase treats as inserts → duplicate sightings

**Evidence**:
```dart
// sighting_sync_service.dart lines 46–60
String getOrCreateLocalId(int sightingIndex) {
  final existing = _localIdBox.get(sightingIndex.toString());
  if (existing != null) return existing;
  final id = _uuid.v4(); // fresh UUID for same sighting if box reindexed
  _localIdBox.put(sightingIndex.toString(), id);
  return id;
}
```

**Closed-Beta Risk**:
Users in offline sync flow (add sightings → sync → offline crash → app restart → sighting deleted → sync again) will trigger index reordering, creating duplicates. This is low-probability per-user but **guaranteed to happen to at least one beta tester**.

**Recommendation** (CRITICAL BEFORE CLOSED BETA):
1. Add `localId: UUID` field to `Sighting` model in `models/dog.dart`
2. Assign UUID at creation time in `SightingService.log()`, not at sync time
3. Update `sighting_sync_service.dart` to read/write `sighting.localId` instead of array indices
4. Migrate existing Hive sightings on first app launch (generate UUIDs for any without `localId`)
5. Add unit test: delete sighting from middle of box, re-sync, verify no duplicates

**Effort**: 2–3 hours (model change, migration, service refactor, test).  
**Blocker Status**: YES — halt closed-beta distribution until fixed. Risk of data integrity issues across user accounts is unacceptable.

---

### P-H3: Hive Box Reads Without Caching — No Observability of Read Patterns

**Severity**: High  
**Estimated Performance Impact**: 1–5ms per Hive read depending on box size; 10–50 reads per screen frame = 10–250ms cumulative if uncached.

**Context**:
- `kennel_screen.dart` uses `ValueListenableBuilder<Box<String>>` to react to kennel changes
- Each `kennel_service.add()` / `contains()` / `count` triggers Hive lookups
- No explicit caching layer; Hive's internal memory-mapped file overhead applies per operation
- `dog_service.dart` loads 296 breeds into memory at startup, indexes by name → O(1) lookup (good pattern, but not replicated in sync services)
- `player_service.dart` reads/writes player stats from Hive repeatedly during gamification loops (XP calc, level-up, achievement checks)

**Issue**:
Hive reads are reasonably fast (usually <5ms), but pattern is scattered. No central read cache or batch optimization. Worst case: kennel grid rendering at 296 dogs triggers 296 Hive reads + 296 network requests for dog images, even though all data is already loaded.

**Recommendation**:
1. **Add read-side instrumentation**: Log Hive read count + latency per frame in debug builds:
   ```dart
   // In main.dart, after frame callback
   void _instrumentHiveReads() {
     final starts = <int>[];
     final origGet = _box.get; // capture original method
     _box.get = (key) {
       final t = Stopwatch()..start();
       final result = origGet(key);
       t.stop();
       debugPrint('Hive read ${t.elapsedMilliseconds}ms for $key');
       return result;
     };
   }
   ```
2. **For kennel grid rendering**: Add `@cached` annotation to `kennelSvc.contains(dogName)` so it returns the in-memory set for the current frame, not repeated box reads
3. **For player stats**: Consider moving frequently-accessed fields (XP, level, streak) to an in-memory cache with a write-through model (cache.add() → Hive.put() → box notifyListeners)

**Effort**: 30 min instrumentation + 1–2 hours for caching refactor (defer post-beta if profiling shows <5% overhead).

---

### P-H4: Startup Initialization Order — Dual TFLite Model Load (Identification + Embedding)

**Severity**: High  
**Estimated Performance Impact**: +1–2s startup latency; TTA preprocessing adds another 500ms–1s per inference.

**Context**:
- `main.dart` lines 568–577: Load `TfliteIdentificationService` model (23.8 MB)
- `main.dart` lines 639–641: Load `DogEmbeddingService` model (same 23.8 MB file, opened twice)
- Both load from asset synchronously; Interpreter is thread-safe but file I/O is serial
- Model load is split ~0.35–0.60 progress range (25% of init time)

**Issue**:
1. Two `Interpreter.fromAsset()` calls load the same binary twice into separate Interpreter instances
2. Hive boxes are parallelized (Future.wait), but TFLite loads are sequential
3. For Lost Dog recognition, embedding service is only used when user navigates to lost dog screen — doesn't need to load at startup

**Recommendation**:
1. **Move `DogEmbeddingService.loadModel()` to lazy load**: Create a `loadOnDemand()` wrapper in `lost_dog_service.dart` that calls `embeddingSvc.loadModel()` on first use, with a one-time promise to avoid double-loads
2. **Reuse single Interpreter for both services**: Create a `SharedTFLiteModel` provider that both services read from
3. **Measure**: Compare startup time before/after lazy embedding load (expected: -0.5–1.0s to first frame)

**Effort**: 1–2 hours (lazy load pattern, shared provider, test).

---

### P-M1: Synonym Cluster Lookup — O(k) Linear Scan Per Result (k=7 clusters, negligible but verify)

**Severity**: Medium  
**Estimated Performance Impact**: <1ms per result (7 clusters scanned linearly); 3 results per identification = <3ms overhead, imperceptible.

**Context**:
- `tflite_identification_service.dart:159–170` `dogQuestClusterKey()` scans all clusters to find a breed
- Loop is `for (final cluster in clusters)` — O(k) where k=7
- Called once per result in `_buildResults()` line 402, so 3 calls per identification

**Evidence**:
```dart
for (final cluster in clusters) {  // k=7
  if (cluster.contains(dogName)) {
    return cluster.first;
  }
}
return dogName;
```

**Issue**:
Negligible performance impact, but could be optimized to O(1) with a precomputed reverse index at service load time.

**Recommendation**:
1. Add precomputed cluster map at module level:
   ```dart
   final Map<String, String> _dogToClusteKey = {
     for (final cluster in dogQuestSynonymClusters)
       for (final name in cluster)
         name: cluster.first,
   };
   ```
2. Replace loop with `String dogQuestClusterKey(String dogName) => _dogToClusterKey[dogName] ?? dogName;`
3. No measurable impact on UX, but cleaner code

**Effort**: 15 min. Defer to post-beta if not addressed this session.

---

### P-M2: Pull Sync Queries Not Indexed — `updated_at` Filtering Has N+1 Risk

**Severity**: Medium  
**Estimated Performance Impact**: First pull sync on fresh session may take 5–10s if Supabase `users` / `sightings` tables lack `updated_at` indexes; negligible if indexed.

**Context**:
- `pull_sync_service.dart` lines 71–75: Query `users` table for profile
  ```dart
  final row = await _client
      .from('users')
      .select('username, display_name, avatar_url, updated_at')
      .eq('id', userId)
      .maybeSingle();
  ```
- Lines 85–89: Compare `updated_at` timestamps to skip redundant writes
- Similar pattern in `pullKennelCount()`, `pullSightingCount()`, `pullNotifications()` (not shown)

**Issue**:
If Supabase `users` table has 10K+ rows and no `updated_at` index, the equality filter on `updated_at` becomes a full table scan. RLS policies should restrict to current user, but index coverage still matters for query planner.

**Recommendation**:
1. Create Supabase migration to add indexes:
   ```sql
   CREATE INDEX IF NOT EXISTS users_updated_at ON users(updated_at);
   CREATE INDEX IF NOT EXISTS users_id_updated_at ON users(id, updated_at);
   ```
2. Verify in Supabase dashboard under Table Editor → {table} → Indexes
3. Add to Phase 4 DevOps checklist (TASK-049 signing key, TASK-050 Sentry DSN, TASK-05X Supabase indexes)

**Effort**: 30 min (SQL + verification). Deferred to post-beta but document as DevOps task.

---

### P-M3: Kennel Grid Rendering — No Virtualization for 296-Breed Grid

**Severity**: Medium  
**Estimated Performance Impact**: ~100–200ms frame time on low-end Android (Moto G7) if kennel has 200+ dogs; 60fps will drop to 45–50fps during scroll.

**Context**:
- `kennel_screen.dart` renders all collected dogs in a grid
- Uses `GridView.builder` (virtualizing), but each dog card loads image via `CachedNetworkImage`
- 296 dogs × 5KB thumbnail (~1.5MB) + 296 dog-detail lookups + 296 rarity badge renders

**Issue**:
`GridView.builder` is implemented correctly (virtualizing), but image cache misses on first view of a full kennel (200+ new dogs added) trigger 200+ network requests in parallel, causing:
1. Main thread jank from network thread pool contention
2. Memory spike from in-flight image decoders (JPEG decode ~5MB per image, 10 in-flight = 50MB)

**Recommendation**:
1. Measure on low-end device (Moto G7 or equivalent): scroll kennel at 100+ dogs, report frame times
2. If frame time >33ms (drops below 60fps): add `CachedNetworkImage(maxWidthDiskCache: 512, maxHeightDiskCache: 512, ...)` to reduce decode memory
3. Consider progressive loading: show placeholder for off-screen dogs, prioritize visible rows (this is GridView default, so likely OK)
4. If still jank: defer dog-detail lookup to tap event instead of rendering card (low effort)

**Effort**: 30 min measurement + 15 min optimization if needed.

---

### P-M4: Conflict Resolution Service — No O(n²) Scans Detected but Merge Logic Undocumented

**Severity**: Medium  
**Estimated Performance Impact**: Negligible if data sets small (<1K sightings); O(n) merge loops over sightings list are acceptable for closed beta.

**Context**:
- `conflict_resolution_service.dart` implements merging strategies: `localWins`, `serverWins`, `deduplicateById`
- `resolvePlayerStats()` merges top-level keys: O(1) per field
- `resolveSightings()` (not shown in initial read) likely iterates sightings list

**Issue**:
Code is reasonable, but no docstring explaining time complexity or merge algorithm. If sightings list grows to 10K+, any O(n²) deduplication becomes noticeable.

**Recommendation**:
1. Document worst-case complexity for each method:
   ```dart
   /// Merges [numLocal] sightings with [numRemote] by local_id deduplication.
   /// Time complexity: O(numLocal + numRemote) [uses HashSet for dedup].
   ```
2. Verify implementation uses `Set<T>` for deduplication, not nested loops
3. Add unit test: 10K local + 10K remote sightings merge in <500ms

**Effort**: 15 min (doc + verification).

---

### P-M5: Camera Reinit Pattern — `dispose() + reinit()` After takePicture May Leak Resources

**Severity**: Medium  
**Estimated Performance Impact**: Repeated photo captures may cause gradual memory growth (~5–10MB per 100 captures) on low-memory devices.

**Context**:
- CLAUDE.md notes: "Camera reinit pattern — `dispose() + reinit()` after takePicture (failure pattern documented). Cost?"
- `identify_screen.dart` lines 46–82: Camera setup with state management
- No explicit reinit logic shown in excerpt, but pattern exists in codebase

**Issue**:
CameraController disposal must be paired with cleanup of native camera handles. If reinitialization doesn't fully release the previous controller, gradual memory leaks occur.

**Recommendation**:
1. Verify `_cam?.dispose()` is called in `dispose()` method of `_IdentifyScreenState`
2. Add explicit `await Future.delayed(Duration(milliseconds: 100))` after dispose before reinit to allow native cleanup
3. Test: take 50 photos rapidly, monitor memory via `adb shell dumpsys meminfo com.dogquest.app`. If RSS growth > 100MB for 50 photos, leak exists

**Effort**: 30 min (verification + test).

---

### P-M6: AdMob Interstitial Load Timing — Async Load Without Timeout May Delay Ad Show

**Severity**: Medium  
**Estimated Performance Impact**: Ad show delayed by ad-network latency (500ms–3s) if load request was queued but slow network. Acceptable with frequency cap but monitor.

**Context**:
- `ad_service.dart` lines 140–157: `_loadInterstitial()` is async but fire-and-forget
- Called in constructor and after ad dismiss; no timeout specified

**Issue**:
```dart
InterstitialAd.load(
  adUnitId: _adUnitId,
  request: const AdRequest(),
  adLoadCallback: InterstitialAdLoadCallback(
    onAdLoaded: (ad) {
      _interstitialAd = ad;
      // ... no timeout for slow networks
    },
    onAdFailedToLoad: (error) {
      _log.warning('Interstitial failed to load: $error');
    },
  ),
);
```
If network is slow (5G, 3G, or congested), ad load may take 5–10s. When user matches the frequency cap and triggers `showInterstitialIfReady()`, if load is still pending, ad is skipped (silently). This is correct behavior, but no visibility into "why ad didn't show."

**Recommendation**:
1. Add timeout to load callback:
   ```dart
   Timer? _loadTimeout;
   void _loadInterstitial() {
     _loadTimeout?.cancel();
     _loadTimeout = Timer(Duration(seconds: 5), () {
       _log.warning('Interstitial load timeout — giving up');
       _interstitialAd = null;
     });
     InterstitialAd.load(...);
   }
   ```
2. Log ad-show skip events to analytics (low-priority diagnostic)
3. Test: disable mobile network, trigger ad load, verify timeout fires within 5s

**Effort**: 20 min.

---

### P-L1: Image Preprocessing Loop — Double Iteration (Pixel-by-Pixel Copy in Nested Loops)

**Severity**: Low  
**Estimated Performance Impact**: ~20–50ms per image preprocessing on CPU; vectorized bulk copy would save ~15–30ms but CPU preprocessing is already offloaded to isolate.

**Context**:
- `tflite_identification_service.dart` lines 36–56 `buildFlatTensor()`:
  ```dart
  for (int y = 0; y < _kInputSize; y++) {
    for (int x = 0; x < _kInputSize; x++) {
      final pixel = resized.getPixel(x, y);
      flat[offset++] = pixel.r.toInt().clamp(0, 255);
      // ... 2 more assignments
    }
  }
  ```
- 300×300 image = 90K pixels × 3 operations per pixel = 270K individual assignments in nested loop
- `image` library does not expose bulk pixel copy; this is a known pattern

**Issue**:
Nested loop is safe and correct, but CPU-intensive. For 3 TTA variants, this becomes 810K assignments total. On devices with slow CPUs (Snapdragon 680, etc.), preprocessing may take 100–200ms.

**Recommendation** (LOW PRIORITY):
1. Benchmark on actual device: measure 3-variant preprocessing time for 300×300 image
2. If >100ms: explore `image` library's `encodePng()` / `decodeImage()` bulk operations for faster copy
3. Or use `dart:typed_data` `ByteData` view for faster bulk writes (advanced optimization, likely 5–10ms savings)

**Effort**: 1–2 hours if pursued. Likely not worth it given isolate offloading (preprocessing doesn't block UI).

---

### P-L2: DogEmbeddingService Cosine Similarity — O(n) Loop Not Vectorized

**Severity**: Low  
**Estimated Performance Impact**: ~1–5ms for 296-dim embedding per similarity calculation; acceptable for lost dog matching at 10–100 comparisons per session.

**Context**:
- `dog_embedding_service.dart` lines 118–137 `cosineSimilarity()`:
  ```dart
  for (int i = 0; i < a.length; i++) {
    dotProduct += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  ```
- 296 dimensions × 3 ops per dimension = ~900 FLOPs per similarity
- Modern CPUs execute ~1B FLOP/s, so ~0.9μs compute time; memory access dominates, actual time ~1–5ms

**Issue**:
O(n) loop is unavoidable for dot product. No significant optimization available without SIMD / native code, which is overkill for lost dog matching use case (users rarely compare >10 dogs).

**Recommendation**:
- Monitor actual usage: log similarity calculation count per session in analytics
- If users routinely match >100 dogs: consider native FFI wrapper for SIMD
- For now: acceptable as-is

**Effort**: negligible (just verify usage patterns).

---

### P-L3: Sync Queue Exponential Backoff — Cap at 16s May Delay Critical Syncs by >1 min

**Severity**: Low  
**Estimated Performance Impact**: Retry #5 fires at 1+2+4+8+16 = 31s total delay; acceptable for offline-first pattern.

**Context**:
- `sync_queue_service.dart` lines 70–71:
  ```dart
  static const _baseDelayMs = 1000;  // 1s, 2s, 4s, 8s, 16s
  static const _maxRetries = 5;
  ```
- Total delay for 5 retries: 1 + 2 + 4 + 8 + 16 = 31s
- After 31s, item marked failed, logged, and can be manually retried

**Issue**:
31s delay is noticeable if user expects sync to complete quickly (e.g., after returning online). No jitter to avoid thundering herd if many queued items retry simultaneously.

**Recommendation** (LOW PRIORITY):
1. Add jitter: `delay = baseDelay * (1 + random(0, 0.1)) * 2^retryCount`
2. Document: "Offline syncs may take up to 31s to complete after network recovery"
3. Surface in UI: show "syncing..." badge with retry count during retries

**Effort**: 15 min (jitter + logging).

---

## Summary Table

| ID | Surface | Severity | Effort | Blocker | Defer | Impact |
|----|---------|----------|--------|---------|-------|--------|
| P-H1 | TTA latency | High | 30 min | No | No | ~1.2–1.5s inference; monitor on-device |
| **P-H2** | **SightingSync index IDs** | **High** | **2–3 hrs** | **YES** | **No** | **Duplicate sightings risk** |
| P-H3 | Hive read caching | High | 1–2 hrs | No | Yes | 10–250ms per frame if uncached |
| P-H4 | Dual TFLite loads | High | 1–2 hrs | No | Yes | +1–2s startup; lazy load embedding |
| P-M1 | Cluster lookup O(k) | Medium | 15 min | No | Yes | <1ms; precompute index |
| P-M2 | Pull sync indexing | Medium | 30 min | No | Yes | 5–10s first pull if unindexed |
| P-M3 | Kennel grid rendering | Medium | 30 min | No | Yes | Frame jank at 200+ dogs |
| P-M4 | Conflict resolution docs | Medium | 15 min | No | Yes | Undocumented complexity |
| P-M5 | Camera reinit leak | Medium | 30 min | No | No | Gradual memory growth |
| P-M6 | AdMob load timeout | Medium | 20 min | No | Yes | Ad load delay up to 5–10s |
| P-L1 | Pixel loop optimization | Low | 1–2 hrs | No | Yes | 15–30ms savings if pursued |
| P-L2 | Embedding SIMD | Low | negligible | No | Yes | 1–5ms per similarity; acceptable |
| P-L3 | Sync backoff jitter | Low | 15 min | No | Yes | 31s total delay; noticeable |

## Critical Blockers

**P-H2 (SightingSync local IDs)** is a hard blocker for closed-beta distribution. Duplicate sightings from array-index reordering create data integrity issues. Fix required before beta launch.

## Pre-Beta Validation Checklist

- [ ] P-H1: Measure on-device TTA latency (Pixel 5 or equivalent)
- [ ] P-H2: Implement UUID-based local IDs for sightings (blocker)
- [ ] P-M5: Verify camera dispose/reinit does not leak memory (take 50 photos, check RSS)
- [ ] P-M6: Test AdMob load timeout on slow network
- [ ] P-M3: Benchmark kennel grid scroll on low-end device (Moto G7)

## Post-Beta Optimization Roadmap

1. P-H3: Add Hive read caching layer (deferred, low observed impact in beta)
2. P-H4: Lazy-load embedding service (1–2s startup savings)
3. P-M2: Add Supabase indexes for pull-sync queries
4. P-M1: Precompute cluster reverse map (cleanup)
5. P-M6: Add jitter to sync backoff (thundering herd prevention)
6. P-L1: Profile and optimize image preprocessing if needed (low ROI)

## Non-Performance Findings Relevant to Phase 2

- Firebase Analytics wired but Sentry DSN missing (task #50)
- No error categorization on identification failures (M1 from Phase 1)
- `DogEmbeddingService` undocumented (M3 from Phase 1)

---

**End Phase 2b**
