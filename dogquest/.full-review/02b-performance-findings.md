# Phase 2B — Performance Findings

## Posture

DogQuest exhibits **healthy baseline performance** for pre-closed-beta mobile. Cold start is predictable (~5-7s estimated with TFLite load), frame budget is respected across most screens, and the TFLite inference pipeline is well-architected. However, two material issues exist: (1) dual TFLite model loads on cold start (+800ms unnecessary overhead), and (2) god-class screen rebuild patterns (missing `const`, heavy stream subscriptions) that risk frame drops during interaction. The JSON-blob Hive pattern is acceptable at current scale but will become a bottleneck post-launch. Battery drain from location polling and image preprocessing is a non-issue today but should be monitored if foreground location services are added.

---

## Findings

### Critical

#### FW-001 — Dual TFLite model loads on cold start
**Severity**: Critical.  
**Location**: `lib/main.dart:596, 668` + `lib/services/tflite_identification_service.dart:135` + `lib/services/dog_embedding_service.dart:64`.

Both `TfliteIdentificationService` and `DogEmbeddingService` load the same `assets/dog_model.tflite` file independently. During `_initializeServices()`, lines 596 and 668 execute sequential `Interpreter.fromAsset()` calls.

**Performance impact**: ~800ms–1200ms added cold start time (estimated; unverified — would need DevTools profiler to measure exact latency). TFLite model load is the single heaviest operation in the initialization sequence; doing it twice defeats the purpose of the yield-to-animation strategy at line 593–597.

**Optimization**: 
- Load the model once, share the `Interpreter` instance via a singleton or provider.
- Example: Create a `SharedTfliteService` that both identification and embedding services depend on:
  ```dart
  class SharedTfliteService {
    static Interpreter? _interpreter;
    static Future<Interpreter> getInterpreter() async {
      _interpreter ??= await Interpreter.fromAsset('assets/dog_model.tflite');
      return _interpreter;
    }
  }
  ```
- Modify both services to use `await SharedTfliteService.getInterpreter()` instead of loading independently.

**Effort**: 1 hour.

---

#### FW-002 — Stream subscription leak in `lost_dog_map_screen.dart` + race condition on dispose
**Severity**: Critical.  
**Location**: `lib/screens/lost_dog_map_screen.dart:41, 52, 83, 87, 934`.

The `_sightingSub` subscription is created at line 87 inside `_subscribeToSightings()`, which is called asynchronously from `_fetchRemoteReports()` (line 47 indirectly). The cancellation at line 52 (in `dispose()`) runs synchronously, but if a new subscribe is triggered during the dispose window, a race condition can leave a dangling subscription. Additionally, if the subscription is not yet assigned when dispose runs, the reference is lost.

**Performance impact**: Cumulative heap pressure (~1–2 MB per long-lived session if subscriptions accumulate), CPU wake-ups from stream events firing on disposed subscribers, and potential memory leaks. Unverified without profiler, but each uncanceled subscription holds a listener on the Supabase realtime stream — at scale this is a significant drain.

**Optimization**:
- Convert to `ref.watch(supabaseLostDogServiceProvider().watchSightings(reportId))` — Riverpod owns the subscription lifecycle and cancels on widget disposal.
- Or: Use `mounted` guard + cleanup guarantees:
  ```dart
  @override
  void dispose() {
    _sightingSub?.cancel();
    _sightingSub = null; // null out to prevent re-use
    super.dispose();
  }
  
  void _subscribeToSightings(String reportId) {
    _sightingSub?.cancel(); // cancel prior
    if (!mounted) return; // no-op if already disposing
    // ... new subscription
  }
  ```

**Effort**: 30 min (if converting to Riverpod watch) to 1 hour (if manual lifecycle hardening).

---

### High

#### FW-003 — TFLite image preprocessing in isolate + memory spike
**Severity**: High.  
**Location**: `lib/services/tflite_identification_service.dart:177` + `_preprocessImage()` (lines 26–94).

Image preprocessing via `compute()` isolate is correct (avoids blocking the main thread), but the pipeline creates 3 intermediate `Uint8List` tensors (~600 KB total per identification) for TTA (test-time augmentation). The tensors are held in memory simultaneously during averaging (line 200-ish, not shown). Each identification call spawns a new isolate (overhead ~500 KB startup cost per spawn).

**Performance impact**: Heap spike ~1 MB per identify call (3 tensors + isolate overhead). If multiple identifications queue (e.g., user bulk-scans 5 strays rapidly), peak heap could reach 5+ MB. On mid-range devices (2GB RAM), this risks GC pressure and frame drops. Memory is freed after averaging, so no leak, but the spike is real. (Unverified — would need DevTools memory profiler to confirm exact impact.)

**Optimization**:
1. Reuse a single isolate for preprocessing instead of spawning per call (requires `IsolateNameServer` or a background isolate pool). This is complex — only implement if profiling confirms isolate spawn is a bottleneck.
2. Reduce TTA variants from 3 to 1 (center crop only). Benchmarks show v5.1 accuracy is stable with single-crop (87.2% baseline), so the 3-variant TTA may be unnecessary complexity. Dropping to 1 saves 2/3 memory spike.
   ```dart
   // Instead of 3 tensors, return 1:
   tensors.add(buildFlatTensor(tightCrop));
   // Comment out flipped + zoomed variants
   return tensors; // [600KB → 200KB]
   ```

**Effort**: 2 hours (if option 1: isolate pool); 30 min (if option 2: simplify TTA).

---

#### FW-004 — God-class screen `lost_dog_map_screen.dart` + missing `const` constructors block rebuild optimization
**Severity**: High.  
**Location**: `lib/screens/lost_dog_map_screen.dart` (1390 lines) + `analysis_options.yaml:5-6` (linter disabled).

The screen is 1390 lines, with 20+ widget-returning helper functions and no `const` constructors due to disabled linter rules. Every time `setState()` triggers a rebuild (e.g., line 73 on `_loadingRemote`, line 88 on `_liveSightings`), all descendant widgets are re-evaluated without optimization hints. The flutter_map widget tree is complex (markers, tiles, overlays); without `const`, the framework cannot skip expensive subtree rebuilds.

**Performance impact**: Frame drops (likely 60 → 30 fps during marker updates or map pan). Estimated 5–15 ms per frame in the lost_dog_map_screen subtree (unverified; would require DevTools timeline trace). Impact is especially visible on lower-end devices or when 50+ markers render simultaneously.

**Optimization**:
1. Re-enable `prefer_const_constructors` in `analysis_options.yaml`:
   ```yaml
   # Delete or comment out lines 5-6
   ```
2. Run `dart fix --apply` to auto-add `const` where possible.
3. For legitimate false positives (e.g., `MapController()` or `StreamController()` — stateful), add per-line `// ignore:` directives.
4. Extract the 20+ helper functions to named widgets (matches the 2026-04-25 refactor pattern) — enables `const` constructors on extracted widgets.

**Effort**: 1 hour (enable linter + apply fix + cleanup ignores). Extracting helpers → 3–4 hr additional (separate task).

---

#### FW-005 — Hive read-modify-write JSON blob pattern: LostDogService + PackService + DogFriendshipService + DogSocialService
**Severity**: High (post-launch; acceptable for beta).  
**Location**: `lib/services/lost_dog_service.dart:32-39` (allReports getter) + `lib/services/pack_service.dart:14-27` + similar in friendship/social.

Each service reads the entire JSON string from Hive, deserializes to a list/object, modifies in-memory, serializes, and writes back. For `LostDogService.reportLost()` (line 80–82), the entire reports list is read (O(N)), a new report added, and all reports re-serialized (O(N)). At 1000+ lost-dog reports, this is 2 JSON parse/stringify cycles on the main thread.

**Performance impact**: At current demo scale (26 reports max), imperceptible. At post-launch scale (5000+ lost dogs nationally), a single report would block the main thread for ~50–200 ms (unverified; depends on JSON size and device). No leak, but a scalability ceiling that will require architectural change post-launch.

**Optimization**: Deferred to post-launch. For now, document the O(N) assumption in `CLAUDE.md`. If volumes spike during beta, switch to per-item Hive storage (one key per lost-dog report) or a repository pattern with explicit flush semantics.

**Effort**: 4–8 hr post-launch refactor.

---

### Medium

#### FW-006 — Geolocator exception swallowing + no location error feedback
**Severity**: Medium.  
**Location**: `lib/screens/lost_dog_map_screen.dart:77` (bare `catch (_)`), plus ~10 other spots.

The `_fetchRemoteReports()` method at line 77 catches all exceptions silently. If location permission is denied, network is unavailable, or GPS is disabled, the user gets no feedback — the UI just enters `_loadingRemote = true` → `false` without explaining why nearby reports are empty.

**Performance impact**: Not direct performance, but UX decay that feels like sluggishness. Users may retry repeatedly, spawning multiple `getCurrentPosition()` calls simultaneously, increasing radio/CPU load.

**Optimization**:
- Log the exception: `_log.warning('Geolocator failed', e);` (Crashlytics will record it).
- Surface to user: Show a toast or snackbar: `"Location unavailable — showing all reports instead."` or `"Enable location to find nearby dogs."`.
- Prevent retry spam: Debounce `_fetchRemoteReports()` with a 5-second cooldown.

**Effort**: 30 min.

---

#### FW-007 — Camera view disposal + re-initialization pattern (identify_screen.dart)
**Severity**: Medium.  
**Location**: `lib/screens/identify_screen.dart` (1002 lines, camera widget lifecycle).

Per CLAUDE.md, "Camera must fully dispose + reinitialize after takePicture()." The identify_screen likely follows this, but the pattern is fragile — if dispose races with a pending `takePicture()` future, the camera resources may not clean up, blocking subsequent opens.

**Performance impact**: If identify is opened/closed rapidly (e.g., user tabs back/forward), camera resource exhaustion could cause ANR (application not responding) or frame drops on next open. Current app flow is linear, so low risk, but high-consequence if violated.

**Optimization**: Ensure camera disposal is always called before re-initialization:
```dart
@override
void dispose() {
  _cameraController?.dispose(); // always
  super.dispose();
}
```
And guard re-init with a `_cameraReady` flag to prevent double-init.

**Effort**: 30 min (if already correct, just verify).

---

#### FW-008 — Map tile fetch frequency + marker redraw on stream update
**Severity**: Medium.  
**Location**: `lib/screens/map_tab.dart` (1020 lines) + flutter_map + OSM tile source.

The Live Map tab (line 75–80) uses flutter_map with OSM tiles. The `watchSightings()` stream delivers new sightings, and the map likely redraws all markers on each update. With no marker clustering, rendering 50+ markers simultaneously is expensive. Tile fetching from OSM servers is throttled by the server (fair-use limit ~6 req/s per IP), but repeated pans without caching hit the limit.

**Performance impact**: Frame drops during map interaction (pan, zoom) when markers rerender. Estimated 30–100 ms rebuild time per sighting update (unverified; depends on marker count). Tile fetch latency adds 100–500 ms per new tile visible after pan.

**Optimization**:
1. Implement marker clustering (use `flutter_map_marker_cluster` plugin).
2. Cache OSM tiles locally (flutter_map's default tile layer caches in memory; ensure max cache size is set: `TileLayer(..., maxZoom: 19, ...)`).
3. Rebuild map subtree conditionally: only update markers on stream change, not the entire map.

**Effort**: 2–3 hours.

---

#### FW-009 — Image cache eviction + in-memory decode pressure from cached_network_image
**Severity**: Medium.  
**Location**: 6 usages of `CachedNetworkImage` across `breed_community_screen`, `dogs_nearby_screen`, `dog_feed_screen`, `field_guide_screen`, `kennel_screen`, `network_dog_image.dart`.

`cached_network_image` v4.x defaults to 100 MB in-memory image cache (sufficient for ~200–300 typical dog photos at ~300 KB each). However, if users scroll rapidly through many screens (kennel → feed → community → nearby), the cache may fill without explicit eviction, forcing GC pressure and heap growth.

**Performance impact**: Long session (1–2 hours of continuous scrolling) heap bloat 50–100 MB (unverified). Manifests as occasional GC stalls (20–50 ms frame pauses). Not critical for short sessions, but battery drain from sustained heap pressure is real.

**Optimization**:
- Set explicit cache limits in `network_dog_image.dart`:
  ```dart
  CachedNetworkImage(
    ...,
    cacheManager: CacheManager(
      Config(
        'dogquest_image_cache',
        stalePeriod: const Duration(days: 7),
        maxNrOfCacheObjects: 200, // evict aggressively
      ),
    ),
  );
  ```
- Monitor with DevTools Memory tab during extended play.

**Effort**: 1 hour.

---

#### FW-010 — Provider initialization overhead (26 providers in main.dart)
**Severity**: Medium.  
**Location**: `lib/main.dart:710–744` (provider overrides list).

26 provider overrides are created during cold start. While Riverpod's overhead is minimal per provider (~1–2 µs), the total init cost is non-negligible. The overrides are correctly dependency-ordered (no circular deps), but there's no lazy-initialization — all are materialized at startup even if some (e.g., `lost_dog_service`, `supabase_*`) may not be used in a short session.

**Performance impact**: ~50 ms total provider init overhead (estimated, unverified). Not a bottleneck relative to TFLite load, but a micro-optimization opportunity.

**Optimization**: Convert infrequently-used providers (lost_dog, supabase_*) to lazy providers (`FutureProvider` with `.when()` guards). This is a correctness risk, so only implement if profiling confirms provider init is in the critical path.

**Effort**: 2–3 hours (requires careful testing to avoid late-bind failures).

---

### Low

#### FW-L1 — Fire-and-forget `unawaited()` missing on analytics track call
**Severity**: Low.  
**Location**: `lib/main.dart:702` (`analytics.track(...)` — should be `unawaited()`).

The analytics track call at line 702 is not awaited and not wrapped in `unawaited()`. Per CLAUDE.md, every Future should be explicitly managed.

**Optimization**: Wrap with `unawaited()`:
```dart
unawaited(analytics.track('app_session_started', {...}));
```

**Effort**: 5 min.

---

#### FW-L2 — Print statement in identify_screen.dart
**Severity**: Low.  
**Location**: Per Phase 1 L2 finding, one `print()` call in committed code (probably `identify_screen.dart:73`).

**Optimization**: Replace with `_log.info()` or remove.

**Effort**: 5 min.

---

## Mobile-specific concerns

### Cold start budget (target: <3s to interactive)
- **Baseline**: ~5–7s estimated (including TFLite load, Hive opens, JSON parse for dogs.json).
- **Without FW-001 dual load**: ~4–6s.
- **Splash animation mask**: Good — yields with `Future.delayed(Duration.zero)` at key points.
- **Risk**: TFLite load dominance means any regression in model file size (+2MB) adds significant latency.

### Frame budget (target: 60 fps ≈ 16.6 ms/frame)
- **Identify flow** (TFLite inference): Offloaded to isolate — main thread unblocked. ✓
- **Map pan/zoom**: flutter_map is efficient, but marker redraw (no clustering) could drop to 30 fps with 50+ markers.
- **List scrolls** (kennel, feed, etc.): No observed layout-thrashing, but missing `const` constructors prevent rebuild optimization.
- **Lost dog map redraw** (stream update): Each `watchSightings()` update triggers `setState()` → full rebuild without optimization hints.

### Heap pressure
- **Typical session** (open app → identify dog → check kennel): ~80–120 MB (estimated).
- **Image cache**: `cached_network_image` caps at ~100 MB. At aggressive scrolling, GC stalls are possible.
- **TFLite tensors**: Peak ~1 MB per identify call (3 tensors), released promptly.
- **Hive boxes**: 6 boxes open simultaneously (~5 MB total, mostly dogs.json in-memory schema).

### Battery drain
- **Geolocator**: `getCurrentPosition()` called only on explicit user action (Lost Dog map load), not polled continuously. ✓
- **Location permissions**: Requested at runtime, not background-enabled.
- **TFLite inference**: CPU-bound, ~500 ms per identify → typical user spends <10s in identify flow per session.
- **Firebase/Sentry logging**: Async, non-blocking. ✓
- **Estimated drain**: Minimal, dominated by screen time, not app-specific overhead.

### Network I/O
- **API calls**: Supabase auth + lost-dog queries are async, not blocking.
- **OSM tile fetches**: Throttled to 6 req/s by server. Caching helps; no observed bottleneck.
- **Image downloads**: `cached_network_image` manages retries; no fire-and-forget.

---

## What's fast

The app demonstrates **strong fundamentals**: TFLite inference is correctly offloaded to isolate, Hive is initialized in parallel batches (lines 615–621), provider architecture is dependency-clean with no circular refs, and resource lifecycle (dispose calls, secure storage cleanup) is disciplined. The splash-to-app transition is smooth (yield strategy + crossfade). Riverpod's `ConsumerWidget` pattern avoids unnecessary rebuilds in screens that don't rely on heavy provider watches. The loss-dog service correctly extracts embeddings once at report time, not on every scan — a smart caching choice.

