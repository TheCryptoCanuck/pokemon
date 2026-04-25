import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'analytics_service.dart';

/// Conflict resolution strategies for Hive (local) + Supabase (cloud) sync.
///
/// Each data type uses a fixed strategy:
/// - Sightings: [deduplicateById] — Supabase deduplicates on `local_id`.
/// - Player stats: [localWins] — gameplay is local-first.
/// - User profile: [serverWins] — may be updated from another device.
/// - Social data: [serverSourceOfTruth] — always pulled from Supabase.
/// - Kennel collection: [localWins] — discoveries happen locally.
enum ConflictStrategy {
  /// Local value is authoritative. Push local to server on sync.
  localWins,

  /// Server value is authoritative. Overwrite local cache on pull.
  serverWins,

  /// Deduplicate by a unique local ID. No real conflict — insert-only.
  deduplicateById,

  /// Server is the single source of truth. Never push conflicting local data.
  serverSourceOfTruth,
}

/// The result of resolving a sync conflict between local and remote data.
class ConflictResult {
  /// The merged / resolved value after applying the conflict strategy.
  final Map<String, dynamic> resolvedValue;

  /// Which strategy was applied.
  final ConflictStrategy strategy;

  /// Whether the local and remote values actually differed.
  final bool hadConflict;

  /// Human-readable description of what happened.
  final String details;

  const ConflictResult({
    required this.resolvedValue,
    required this.strategy,
    required this.hadConflict,
    required this.details,
  });

  @override
  String toString() =>
      'ConflictResult(strategy: $strategy, hadConflict: $hadConflict, details: $details)';
}

/// Handles conflict resolution when offline edits sync with Supabase.
///
/// Each public method encodes the correct strategy for its data type so callers
/// never need to think about conflict logic — just call the right method.
class ConflictResolutionService {
  /// Construct with an optional [Ref]. When omitted, conflict logging is a
  /// no-op — pure resolution methods (resolvePlayerStats, resolveUserProfile,
  /// resolveKennelCount, resolveSighting) work without any provider access,
  /// so unit tests can omit the Ref entirely.
  ConflictResolutionService([this._ref]);

  final Ref? _ref;
  final _log = Logger('ConflictResolutionService');

  // ---------------------------------------------------------------------------
  // Player Stats — local wins (with intelligent merge)
  // ---------------------------------------------------------------------------

  /// Resolves player stats by merging local and remote intelligently.
  ///
  /// Strategy: [ConflictStrategy.localWins].
  /// - `total_xp`: max of both (XP is monotonically increasing).
  /// - `level`: max of both.
  /// - `current_streak`: local wins (reflects real-time gameplay).
  /// - `longest_streak`: max of both.
  /// - `total_sightings`: max of both.
  /// - All other keys: local value takes precedence.
  ConflictResult resolvePlayerStats(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final merged = Map<String, dynamic>.from(local);

    // Keys where we always take the larger value (monotonically increasing).
    const maxKeys = {
      'total_xp',
      'level',
      'longest_streak',
      'total_sightings',
    };

    bool hadConflict = false;
    final diffs = <String>[];

    for (final key in maxKeys) {
      final localVal = (local[key] as num?) ?? 0;
      final remoteVal = (remote[key] as num?) ?? 0;
      if (remoteVal > localVal) {
        merged[key] = remoteVal;
        hadConflict = true;
        diffs.add('$key: local=$localVal < remote=$remoteVal, took remote');
      }
    }

    // current_streak always comes from local — it's real-time.
    if (remote.containsKey('current_streak') &&
        remote['current_streak'] != local['current_streak']) {
      hadConflict = true;
      diffs.add(
        'current_streak: kept local=${local['current_streak']} '
        '(remote=${remote['current_streak']})',
      );
    }

    final details = hadConflict
        ? 'Merged player stats: ${diffs.join('; ')}'
        : 'Player stats identical — no conflict';

    _log.fine(details);

    if (hadConflict) {
      logConflict('player_stats', 'localWins', {
        'diffs': diffs,
        'local_xp': local['total_xp'],
        'remote_xp': remote['total_xp'],
      });
    }

    return ConflictResult(
      resolvedValue: merged,
      strategy: ConflictStrategy.localWins,
      hadConflict: hadConflict,
      details: details,
    );
  }

  // ---------------------------------------------------------------------------
  // User Profile — server wins
  // ---------------------------------------------------------------------------

  /// Resolves user profile by letting the server win.
  ///
  /// Strategy: [ConflictStrategy.serverWins].
  /// If both have an `updated_at` timestamp and local is newer, a conflict is
  /// logged but server still wins (another device may have updated).
  ConflictResult resolveUserProfile(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    bool hadConflict = false;
    String details = 'Server profile accepted — no local changes';

    // Check if local was modified after remote (indicates a real conflict).
    final localUpdated =
        DateTime.tryParse(local['updated_at']?.toString() ?? '');
    final remoteUpdated =
        DateTime.tryParse(remote['updated_at']?.toString() ?? '');

    if (localUpdated != null &&
        remoteUpdated != null &&
        localUpdated.isAfter(remoteUpdated)) {
      hadConflict = true;
      details =
          'Local profile was newer (${localUpdated.toIso8601String()}) than '
          'server (${remoteUpdated.toIso8601String()}), but server wins';

      logConflict('user_profile', 'serverWins', {
        'local_updated_at': localUpdated.toIso8601String(),
        'remote_updated_at': remoteUpdated.toIso8601String(),
        'overwritten_fields': _changedKeys(local, remote),
      });
    }

    _log.fine(details);

    return ConflictResult(
      resolvedValue: Map<String, dynamic>.from(remote),
      strategy: ConflictStrategy.serverWins,
      hadConflict: hadConflict,
      details: details,
    );
  }

  // ---------------------------------------------------------------------------
  // Sightings — deduplicate by local_id
  // ---------------------------------------------------------------------------

  /// Wraps a sighting with its `local_id` for Supabase dedup.
  ///
  /// Strategy: [ConflictStrategy.deduplicateById].
  /// Supabase uses `ON CONFLICT (local_id) DO NOTHING`, so there is never a
  /// real conflict — the sighting either inserts or is silently skipped.
  ConflictResult resolveSighting(
    String localId,
    Map<String, dynamic> localData,
  ) {
    final resolved = Map<String, dynamic>.from(localData)
      ..['local_id'] = localId;

    _log.fine('Sighting $localId prepared for dedup sync');

    return ConflictResult(
      resolvedValue: resolved,
      strategy: ConflictStrategy.deduplicateById,
      hadConflict: false,
      details: 'Sighting $localId — dedup by local_id, no conflict possible',
    );
  }

  // ---------------------------------------------------------------------------
  // Kennel Count — local wins (monotonically increasing)
  // ---------------------------------------------------------------------------

  /// Resolves kennel count by taking the max of local and remote.
  ///
  /// Strategy: [ConflictStrategy.localWins].
  /// Breed discoveries only happen locally, so local is always >= remote.
  /// We take max as a safety net in case of clock drift or multi-device use.
  ConflictResult resolveKennelCount(int localCount, int remoteCount) {
    final resolved = localCount >= remoteCount ? localCount : remoteCount;
    final hadConflict = localCount != remoteCount;

    final details = hadConflict
        ? 'Kennel count conflict: local=$localCount, remote=$remoteCount, '
            'resolved=$resolved (took max)'
        : 'Kennel count identical ($localCount) — no conflict';

    _log.fine(details);

    if (hadConflict) {
      logConflict('kennel_count', 'localWins', {
        'local': localCount,
        'remote': remoteCount,
        'resolved': resolved,
      });
    }

    return ConflictResult(
      resolvedValue: {'kennel_count': resolved},
      strategy: ConflictStrategy.localWins,
      hadConflict: hadConflict,
      details: details,
    );
  }

  // ---------------------------------------------------------------------------
  // Conflict Logging
  // ---------------------------------------------------------------------------

  /// Logs a sync conflict to the analytics service for monitoring.
  void logConflict(
    String dataType,
    String strategy,
    Map<String, dynamic> details,
  ) {
    _log.info('Conflict [$dataType] strategy=$strategy details=$details');

    final ref = _ref;
    if (ref == null) {
      // No Ref provided — caller (typically a unit test) opted out of analytics.
      return;
    }

    try {
      final analytics = ref.read(analyticsProvider);
      analytics.track('sync_conflict', {
        'data_type': dataType,
        'strategy': strategy,
        ...details.map((k, v) => MapEntry(k, v.toString())),
      });
    } catch (e) {
      // Analytics should never break sync. Log and move on.
      _log.warning('Failed to log conflict to analytics: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns the list of keys whose values differ between two maps.
  List<String> _changedKeys(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final allKeys = {...a.keys, ...b.keys};
    return allKeys.where((k) => a[k]?.toString() != b[k]?.toString()).toList();
  }
}

/// Riverpod provider for [ConflictResolutionService].
final conflictResolutionServiceProvider =
    Provider<ConflictResolutionService>((ref) {
  return ConflictResolutionService(ref);
});
