import 'dart:async';
import 'dart:developer' as developer;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../models/lost_dog_report.dart';
import 'lost_dog_service.dart';
import 'supabase_lost_dog_service.dart';

final _log = Logger('LostDogSyncService');

/// Manages offline-first sync queue for lost dog reports.
/// Reports created without internet are marked as pending and synced
/// when connectivity is restored.
class LostDogSyncService {
  final LostDogService _lostDogSvc;
  final SupabaseLostDogService? _supabaseSvc;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  LostDogSyncService(this._lostDogSvc, this._supabaseSvc);

  /// Start listening to connectivity changes and flush pending reports
  /// when internet becomes available.
  void start() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasInternet = results.isNotEmpty &&
          !results.every((r) => r == ConnectivityResult.none);
      if (hasInternet) {
        developer.log('Internet restored — flushing pending lost dog reports');
        // Fire-and-forget: flush happens in background when connectivity restores.
        unawaited(_flushPending());
      }
    });
    _log.info('Lost dog sync service started');
  }

  /// Flush all pending reports to Supabase when internet is available.
  Future<void> _flushPending() async {
    final pending = _lostDogSvc.allReports
        .where((r) => r.syncStatus == SyncStatus.pending)
        .toList();

    if (pending.isEmpty || _supabaseSvc == null) {
      return;
    }

    _log.info('Syncing ${pending.length} pending report(s)');

    for (final report in pending) {
      await _syncReport(report);
    }

    _log.info('Finished syncing pending reports');
  }

  /// Sync a single report to Supabase.
  Future<void> _syncReport(LostDogReport report) async {
    try {
      final result = await _supabaseSvc!.reportLost(
        dogName: report.dogName,
        breed: report.breed ?? '',
        description: report.notes ?? '',
        lastSeenLat: report.lastSeenLat ?? 0.0,
        lastSeenLon: report.lastSeenLon ?? 0.0,
        contactInfo: report.ownerContact ?? '',
        embedding: report.embedding,
        gdprConsentAt: report.gdprConsentAt,
      );

      if (result != null) {
        _lostDogSvc.updateSyncStatus(report.id, SyncStatus.synced);
        _log.info('Synced report ${report.id}');
      } else {
        _lostDogSvc.updateSyncStatus(report.id, SyncStatus.failed);
        _log.warning('Failed to sync report ${report.id}: null result');
      }
    } catch (e) {
      _lostDogSvc.updateSyncStatus(report.id, SyncStatus.failed);
      _log.severe('Error syncing report ${report.id}: $e');
    }
  }

  /// Manually trigger sync of pending reports (e.g., user-initiated retry).
  Future<void> flushNow() => _flushPending();

  /// Dispose resources and stop listening to connectivity changes.
  void dispose() {
    _connectivitySub?.cancel();
    _log.info('Lost dog sync service disposed');
  }
}

final lostDogSyncServiceProvider = Provider<LostDogSyncService?>((ref) => null);
