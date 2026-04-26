import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:dogquest/services/sighting_service.dart';

final _log = Logger('SightingSyncService');
const _uuid = Uuid();

/// Tracks sync status for each sighting by local_id.
///
/// Uses a separate Hive box (`dogquest_sync_status`) so sync metadata
/// is decoupled from the sighting data itself. Each entry maps a
/// local_id (String) to the DateTime it was last synced.
///
/// **DORMANT — DO NOT WIRE WITHOUT FIXING sec-C2.**
///
/// As of 2026-04-25 this service has zero non-self callers in `lib/`.
/// Production sync goes through `BackendSyncService`, which is itself a
/// stub. Before wiring this class into a production code path, fix the
/// sec-C2 bug documented below.
///
/// ## sec-C2 bug: index-vs-sorted-position conflation
///
/// The parallel `dogquest_local_ids` Hive box keys local_ids by the
/// position-as-string in `_localIdBox.put(sightingIndex.toString(), id)`.
/// However, [syncAll] iterates `_sightingService.all`, which is sorted
/// **newest-first by timestamp**, not by Hive insertion order. After the
/// first successful sync, every subsequent sync run looks up the UUID
/// for sorted-position `i`, which corresponds to a different sighting
/// than it did on the first sync. The result is silent data loss for
/// new sightings (their sorted-position UUIDs are already-synced and
/// the loop skips them) plus silent server-side duplication of old
/// sightings (which re-upload under fresh UUIDs).
///
/// Fix path: move `localId` onto the [Sighting] model itself; generate
/// at construction; persist with the sighting in `dogquest_sightings_v1`.
/// Then drop `_localIdBox` and `getOrCreateLocalId` entirely. Backfill
/// existing rows on first launch by iterating Hive entries and assigning
/// fresh UUIDs.
///
/// See `.second_brain/03_Projects/Active_Tasks.md` C2 entry for the
/// reduced-scope vs. full-migration decision.
class SightingSyncService {
  static const _syncBoxName = 'dogquest_sync_status';
  static const _localIdBoxName = 'dogquest_local_ids';

  late Box<String> _syncBox; // local_id -> synced_at ISO string
  late Box<String> _localIdBox; // sighting index -> local_id (UUID)
  late SightingService _sightingService;

  bool _isSyncing = false;
  Timer? _debounceTimer;

  /// Initialise Hive boxes. Call once during app startup, after Hive.initFlutter().
  ///
  /// **Throws [StateError] unconditionally** — see sec-C2 in the class
  /// dartdoc. This service must not be wired into production until the
  /// index-vs-sorted-position bug is fixed.
  Future<void> init(SightingService sightingService) async {
    throw StateError(
      'SightingSyncService is dormant pending sec-C2 fix. '
      'See class dartdoc and .second_brain/03_Projects/Active_Tasks.md C2.',
    );
    // ignore: dead_code
    _sightingService = sightingService;
    _syncBox = await Hive.openBox<String>(_syncBoxName);
    _localIdBox = await Hive.openBox<String>(_localIdBoxName);
    _log.info(
      'Sync service ready: ${_syncBox.length} synced, '
      '${_localIdBox.length} local IDs tracked',
    );
  }

  // ── Local ID Management ──────────────────────────────────────────

  /// Returns the local_id for a sighting at the given Hive index,
  /// generating one if it doesn't exist yet.
  String getOrCreateLocalId(int sightingIndex) {
    final existing = _localIdBox.get(sightingIndex.toString());
    if (existing != null) return existing;
    final id = _uuid.v4();
    _localIdBox.put(sightingIndex.toString(), id);
    return id;
  }

  /// Ensures every sighting in the sighting box has a local_id.
  /// Called on first launch or after migration.
  void _ensureAllLocalIds() {
    final total = _sightingService.totalSightings;
    for (var i = 0; i < total; i++) {
      getOrCreateLocalId(i);
    }
  }

  // ── Sync Status ──────────────────────────────────────────────────

  /// Check whether a sighting with [localId] has been synced.
  bool isSynced(String localId) => _syncBox.containsKey(localId);

  /// Mark a sighting as synced right now.
  void markSynced(String localId) {
    _syncBox.put(localId, DateTime.now().toUtc().toIso8601String());
  }

  /// Number of sightings that have not been synced yet.
  int getUnsyncedCount() {
    _ensureAllLocalIds();
    var count = 0;
    for (final localId in _localIdBox.values) {
      if (!isSynced(localId)) count++;
    }
    return count;
  }

  // ── Payload Formatting ──────────────────────────────────────────

  /// Build the JSONB payload for the Supabase RPC from a [Sighting]
  /// and its [localId].
  Map<String, dynamic> _formatSightingPayload(
    Sighting sighting,
    String localId,
  ) {
    return {
      'breed_name': sighting.dogName,
      'confidence': sighting.confidence,
      'top3_breeds': null, // not on current Sighting model — reserved for v2
      'latitude': sighting.latitude,
      'longitude': sighting.longitude,
      'location_accuracy': sighting.accuracy,
      'xp_earned': null, // enriched at server or added later
      'is_new_breed': null,
      'rarity': null,
      'local_id': localId,
      'created_at': sighting.timestamp.toUtc().toIso8601String(),
    };
  }

  // ── Sync Operations ─────────────────────────────────────────────

  /// Bulk-upload all unsynced sightings via the `sync_sightings` RPC.
  ///
  /// Returns the number of sightings the server accepted, or -1 on error.
  Future<int> syncAll() async {
    if (_isSyncing) {
      _log.fine('Sync already in progress — skipping');
      return 0;
    }

    // sec-C1: refuse to sync without an authenticated Supabase session.
    // Sightings created during offline mode must not be uploaded under
    // whichever session happens to be active when connectivity returns.
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      _log.warning('Cannot sync sightings — no authenticated session');
      return 0;
    }

    _isSyncing = true;

    try {
      _ensureAllLocalIds();

      final allSightings = _sightingService.all;
      final payloads = <Map<String, dynamic>>[];

      for (var i = 0; i < allSightings.length; i++) {
        final localId = getOrCreateLocalId(i);
        if (isSynced(localId)) continue;
        payloads.add(_formatSightingPayload(allSightings[i], localId));
      }

      if (payloads.isEmpty) {
        _log.fine('All sightings already synced');
        return 0;
      }

      _log.info('Syncing ${payloads.length} sightings to Supabase...');

      final result = await Supabase.instance.client.rpc(
        'sync_sightings',
        params: {'p_sightings': payloads},
      );

      final syncedCount = (result as int?) ?? payloads.length;
      _log.info('Server accepted $syncedCount sightings');

      // Mark all uploaded sightings as synced.
      for (final payload in payloads) {
        markSynced(payload['local_id'] as String);
      }

      return syncedCount;
    } catch (e, st) {
      _log.severe('Bulk sync failed', e, st);
      return -1;
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync a single sighting immediately.
  ///
  /// The [sightingIndex] is the position in the Hive sighting box.
  /// If not provided, the sighting is assumed to be the most recently added.
  Future<bool> syncSingle(Sighting sighting, {int? sightingIndex}) async {
    // sec-C1: refuse to sync without an authenticated Supabase session.
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      _log.warning('Cannot sync sighting — no authenticated session');
      return false;
    }

    final index = sightingIndex ?? (_sightingService.totalSightings - 1);
    final localId = getOrCreateLocalId(index);

    if (isSynced(localId)) {
      _log.fine('Sighting $localId already synced');
      return true;
    }

    try {
      final payload = _formatSightingPayload(sighting, localId);

      await Supabase.instance.client.rpc(
        'sync_sightings',
        params: {
          'p_sightings': [payload],
        },
      );

      markSynced(localId);
      _log.info('Synced sighting $localId (${sighting.dogName})');
      return true;
    } catch (e, st) {
      _log.warning('Single sync failed for $localId', e, st);
      return false;
    }
  }

  /// Hook to call immediately after a new sighting is saved locally.
  ///
  /// Assigns a local_id and queues a debounced sync attempt so rapid
  /// successive sightings are batched into one RPC call.
  void onSightingCreated(Sighting sighting) {
    final index = _sightingService.totalSightings - 1;
    final localId = getOrCreateLocalId(index);
    _log.fine('New sighting queued for sync: $localId (${sighting.dogName})');

    // Debounce: wait 2 seconds after the last sighting before syncing,
    // so burst sightings (e.g. demo mode) are batched.
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      _trySyncUnsynced();
    });
  }

  /// Attempt to sync unsynced sightings if we have connectivity.
  Future<void> _trySyncUnsynced() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.contains(ConnectivityResult.none)) {
        _log.fine('Offline — sync deferred');
        return;
      }
      await syncAll();
    } catch (e) {
      _log.fine('Sync attempt failed (will retry later): $e');
    }
  }

  /// Call when Supabase connection is first established to bulk-upload
  /// any sightings that were created while offline.
  Future<void> onConnected() async {
    final unsynced = getUnsyncedCount();
    if (unsynced > 0) {
      _log.info('Connection established — syncing $unsynced sightings');
      await syncAll();
    }
  }

  void dispose() {
    _debounceTimer?.cancel();
  }
}

// ── Riverpod Providers ──────────────────────────────────────────────

/// Must be overridden after Hive init in main.dart:
/// ```dart
/// final syncService = SightingSyncService();
/// await syncService.init(sightingService);
/// ```
final sightingSyncServiceProvider = Provider<SightingSyncService>((ref) {
  throw UnimplementedError(
    'sightingSyncServiceProvider must be overridden after Hive init',
  );
});
