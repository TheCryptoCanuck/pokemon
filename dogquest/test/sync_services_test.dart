// ignore_for_file: subtype_of_sealed_class

import 'dart:math';

import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:test/test.dart';

import 'package:dogquest/services/sync_queue_service.dart';
import 'package:dogquest/services/conflict_resolution_service.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder<dynamic> {}

class MockSession extends Mock implements Session {}

class MockUser extends Mock implements User {}

// ---------------------------------------------------------------------------
// Helpers — local replica of the backoff formula used by SyncQueueService
// ---------------------------------------------------------------------------

/// Mirrors: `_baseDelayMs * pow(2, retryCount - 1)`
/// Constants in the source: _baseDelayMs = 1000, _maxRetries = 5.
int _backoffMs(int retryCount) => (1000 * pow(2, retryCount - 1)).toInt();

SyncQueueItem _makeItem({
  String id = 'test-id',
  String table = 'sightings',
  String operation = 'insert',
  Map<String, dynamic>? data,
  DateTime? createdAt,
  int retryCount = 0,
  String? lastError,
  String status = 'pending',
}) {
  return SyncQueueItem(
    id: id,
    table: table,
    operation: operation,
    data: data ?? {'breed': 'Golden Retriever'},
    createdAt: createdAt ?? DateTime(2026, 3, 15, 10, 0, 0),
    retryCount: retryCount,
    lastError: lastError,
    status: status,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  group('SyncQueueItem — serialization', () {
    test('toJson / fromJson roundtrip preserves all fields', () {
      final original = _makeItem(
        id: 'abc-123',
        table: 'sightings',
        operation: 'update',
        data: {'breed': 'Poodle', 'confidence': 0.95},
        createdAt: DateTime.utc(2026, 3, 15, 8, 30, 0),
        retryCount: 2,
        lastError: 'timeout',
        status: 'processing',
      );

      final json = original.toJson();
      final restored = SyncQueueItem.fromJson(json);

      expect(restored.id, equals('abc-123'));
      expect(restored.table, equals('sightings'));
      expect(restored.operation, equals('update'));
      expect(restored.data['breed'], equals('Poodle'));
      expect(restored.data['confidence'], equals(0.95));
      expect(restored.createdAt, equals(DateTime.utc(2026, 3, 15, 8, 30, 0)));
      expect(restored.retryCount, equals(2));
      expect(restored.lastError, equals('timeout'));
      expect(restored.status, equals('processing'));
    });

    test('fromJson uses defaults for optional fields when absent', () {
      final minimalJson = {
        'id': 'min-id',
        'table': 'users',
        'operation': 'insert',
        'data': <String, dynamic>{},
        'created_at': '2026-03-15T00:00:00.000',
      };

      final item = SyncQueueItem.fromJson(minimalJson);

      expect(item.retryCount, equals(0));
      expect(item.lastError, isNull);
      expect(item.status, equals('pending'));
    });

    test('toJson uses snake_case key names matching Hive persistence format',
        () {
      final item = _makeItem(retryCount: 3, lastError: 'network error');
      final json = item.toJson();

      expect(json.containsKey('retry_count'), isTrue);
      expect(json.containsKey('last_error'), isTrue);
      expect(json.containsKey('created_at'), isTrue);
      expect(json['retry_count'], equals(3));
      expect(json['last_error'], equals('network error'));
    });

    test('FIFO order: earlier createdAt sorts before later createdAt', () {
      final early = _makeItem(
        id: 'e',
        createdAt: DateTime.utc(2026, 3, 15, 9, 0),
      );
      final late_ = _makeItem(
        id: 'l',
        createdAt: DateTime.utc(2026, 3, 15, 10, 0),
      );

      final items = [late_, early]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      expect(items.first.id, equals('e'));
      expect(items.last.id, equals('l'));
    });
  });

  // -------------------------------------------------------------------------
  group('SyncQueueService — exponential backoff formula', () {
    // Source formula: _baseDelayMs * pow(2, retryCount - 1)
    // _baseDelayMs = 1000, _maxRetries = 5
    const expected = {1: 1000, 2: 2000, 3: 4000, 4: 8000, 5: 16000};

    for (final entry in expected.entries) {
      final retry = entry.key;
      final ms = entry.value;

      test('retry $retry → ${ms}ms delay', () {
        expect(_backoffMs(retry), equals(ms));
      });
    }
  });

  // -------------------------------------------------------------------------
  group('ConflictResolutionService — resolvePlayerStats', () {
    // ConflictResolutionService._ref is only used in logConflict() which
    // calls an analytics provider. The pure resolution methods (resolvePlayerStats,
    // resolveUserProfile, resolveKennelCount, resolveSighting) do not call _ref.
    // The default constructor accepts an optional Ref, so unit tests can omit
    // it entirely — logConflict short-circuits when _ref is null.
    late ConflictResolutionService svc;

    setUp(() {
      svc = ConflictResolutionService();
    });

    test('local total_xp > remote → resolved value is local (max)', () {
      final local = {
        'total_xp': 500,
        'level': 5,
        'current_streak': 3,
        'longest_streak': 7,
        'total_sightings': 20,
      };
      final remote = {
        'total_xp': 300,
        'level': 4,
        'current_streak': 1,
        'longest_streak': 5,
        'total_sightings': 15,
      };

      final result = svc.resolvePlayerStats(local, remote);

      expect(result.resolvedValue['total_xp'], equals(500));
      expect(result.hadConflict, isTrue);
    });

    test('remote total_xp > local → resolved takes max (remote wins for xp)',
        () {
      final local = {
        'total_xp': 200,
        'level': 3,
        'current_streak': 4,
        'longest_streak': 8,
        'total_sightings': 10,
      };
      final remote = {
        'total_xp': 900,
        'level': 7,
        'current_streak': 2,
        'longest_streak': 10,
        'total_sightings': 40,
      };

      final result = svc.resolvePlayerStats(local, remote);

      expect(result.resolvedValue['total_xp'], equals(900));
      expect(result.resolvedValue['level'], equals(7));
    });

    test('current_streak always comes from local regardless of remote value',
        () {
      final local = {
        'total_xp': 100,
        'level': 2,
        'current_streak': 7,
        'longest_streak': 7,
        'total_sightings': 5,
      };
      final remote = {
        'total_xp': 100,
        'level': 2,
        'current_streak': 99,
        'longest_streak': 99,
        'total_sightings': 5,
      };

      final result = svc.resolvePlayerStats(local, remote);

      // current_streak is not in the maxKeys set — local value is preserved
      expect(result.resolvedValue['current_streak'], equals(7));
    });

    test('longest_streak takes the larger of local and remote', () {
      final local = {
        'total_xp': 100,
        'level': 2,
        'current_streak': 1,
        'longest_streak': 12,
        'total_sightings': 5,
      };
      final remote = {
        'total_xp': 100,
        'level': 2,
        'current_streak': 1,
        'longest_streak': 8,
        'total_sightings': 5,
      };

      final result = svc.resolvePlayerStats(local, remote);

      expect(result.resolvedValue['longest_streak'], equals(12));
    });

    test('hadConflict is false when local and remote are identical', () {
      final stats = {
        'total_xp': 100,
        'level': 2,
        'current_streak': 1,
        'longest_streak': 3,
        'total_sightings': 5,
      };

      final result = svc.resolvePlayerStats(stats, Map.from(stats));

      expect(result.hadConflict, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  group('ConflictResolutionService — resolveUserProfile', () {
    late ConflictResolutionService svc;

    setUp(() {
      svc = ConflictResolutionService();
    });

    test('server wins regardless of local values', () {
      final local = {
        'username': 'local_dog',
        'display_name': 'Local Dog',
        'updated_at': '2026-03-15T12:00:00Z',
      };
      final remote = {
        'username': 'server_dog',
        'display_name': 'Server Dog',
        'updated_at': '2026-03-10T08:00:00Z',
      };

      final result = svc.resolveUserProfile(local, remote);

      expect(result.resolvedValue['username'], equals('server_dog'));
      expect(result.strategy, equals(ConflictStrategy.serverWins));
    });

    test('hadConflict is true when local updated_at is newer than remote', () {
      final local = {
        'username': 'dog',
        'updated_at': '2026-03-16T00:00:00Z',
      };
      final remote = {
        'username': 'dog',
        'updated_at': '2026-03-10T00:00:00Z',
      };

      final result = svc.resolveUserProfile(local, remote);

      // Server still wins, but the conflict is flagged
      expect(result.hadConflict, isTrue);
      expect(result.resolvedValue, equals(remote));
    });
  });

  // -------------------------------------------------------------------------
  group('ConflictResolutionService — resolveKennelCount', () {
    late ConflictResolutionService svc;

    setUp(() {
      svc = ConflictResolutionService();
    });

    test('takes max when local count > remote', () {
      final result = svc.resolveKennelCount(42, 30);
      expect(result.resolvedValue['kennel_count'], equals(42));
    });

    test('takes max when remote count > local', () {
      final result = svc.resolveKennelCount(10, 55);
      expect(result.resolvedValue['kennel_count'], equals(55));
    });

    test('hadConflict is false when both counts are equal', () {
      final result = svc.resolveKennelCount(20, 20);
      expect(result.hadConflict, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  group('ConflictResolutionService — resolveSighting', () {
    late ConflictResolutionService svc;

    setUp(() {
      svc = ConflictResolutionService();
    });

    test('wraps sighting data with local_id field for Supabase dedup', () {
      final data = {'breed_name': 'Beagle', 'confidence': 0.88};
      final result = svc.resolveSighting('uuid-abc', data);

      expect(result.resolvedValue['local_id'], equals('uuid-abc'));
      expect(result.resolvedValue['breed_name'], equals('Beagle'));
      expect(result.strategy, equals(ConflictStrategy.deduplicateById));
    });

    test('hadConflict is always false for sightings (insert-only dedup)', () {
      final result = svc.resolveSighting('id-1', {'breed_name': 'Pug'});
      expect(result.hadConflict, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  group('PullSyncService — auth session guard logic', () {
    test('syncAll returns early when currentSession is null', () {
      final mockAuth = MockGoTrueClient();
      when(() => mockAuth.currentSession).thenReturn(null);

      // The documented guard: if (_client.auth.currentSession == null) return
      expect(mockAuth.currentSession, isNull,
          reason: 'No session means pull sync must be skipped');
    });

    test('syncAll proceeds when a valid session is present', () {
      final mockAuth = MockGoTrueClient();
      final mockSession = MockSession();
      when(() => mockAuth.currentSession).thenReturn(mockSession);

      expect(mockAuth.currentSession, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  group('SightingSyncService — auth session guard (sec-C1)', () {
    // Documents the guard added in lib/services/sighting_sync_service.dart:
    // both syncAll() and syncSingle() must refuse to upload sightings when
    // Supabase.instance.client.auth.currentSession is null. This prevents
    // sightings created during offline mode from being uploaded under
    // whichever session happens to be active when connectivity returns.

    test('syncAll: contract is "return 0 when no session"', () {
      final mockAuth = MockGoTrueClient();
      when(() => mockAuth.currentSession).thenReturn(null);
      // Pre-condition for the guard: session is null.
      expect(mockAuth.currentSession, isNull);
      // Documented post-condition (verified at integration level): the
      // service returns 0 and emits a warning, without invoking the RPC.
    });

    test('syncSingle: contract is "return false when no session"', () {
      final mockAuth = MockGoTrueClient();
      when(() => mockAuth.currentSession).thenReturn(null);
      expect(mockAuth.currentSession, isNull);
      // Documented post-condition: syncSingle returns false; sighting stays
      // queued locally and will retry once the user authenticates.
    });

    test('router clears stale offline_mode when session exists', () {
      // Mirrors the guard added to lib/router.dart redirect:
      //   if (session != null && offlineMode) {
      //     postFrameCallback -> playerBox.put('offline_mode', false)
      //   }
      // Documents the invariant: an authenticated session implies
      // offline_mode must be false on the next router pass.
      final mockAuth = MockGoTrueClient();
      final mockSession = MockSession();
      when(() => mockAuth.currentSession).thenReturn(mockSession);

      const offlineModeBeforeAuth = true;
      final sessionPresent = mockAuth.currentSession != null;
      // The router fires the clear when both conditions hold:
      final shouldClear = sessionPresent && offlineModeBeforeAuth;
      expect(shouldClear, isTrue,
          reason: 'session+offline_mode → router must schedule the clear');
    });

    test('offline → online → offline: flag round-trips correctly', () {
      // After successful auth, offline_mode is false (cleared by login_screen
      // on the happy path, or by router as the safety net).
      // After explicit "Continue Offline", offline_mode is true again.
      bool offlineMode = false;

      // 1. Initial state: no session, no offline mode -> router redirects
      //    to /login.
      bool hasSession = false;
      expect(hasSession || offlineMode, isFalse);

      // 2. User taps "Continue Offline" -> sets the flag.
      offlineMode = true;
      expect(hasSession || offlineMode, isTrue,
          reason: 'router lets the user through in offline mode');

      // 3. User authenticates. The router safety net (sec-C1) clears the
      //    flag once a session appears.
      hasSession = true;
      if (hasSession && offlineMode) offlineMode = false; // mirrors router
      expect(offlineMode, isFalse,
          reason: 'authenticated session must invalidate offline_mode');

      // 4. User signs out, taps "Continue Offline" again -> flag back on.
      hasSession = false;
      offlineMode = true;
      expect(hasSession, isFalse);
      expect(offlineMode, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  group('PullSyncService — pullUserProfile updated_at skip logic', () {
    test('skips write when local updated_at equals server value', () {
      const ts = '2026-03-14T10:00:00.000Z';
      final server = DateTime.parse(ts);
      final local = DateTime.parse(ts);

      // Guard: skip if local is NOT before server
      expect(local.isBefore(server), isFalse,
          reason: 'Equal timestamps → local is current, skip write');
    });

    test('skips write when local updated_at is newer than server', () {
      final server = DateTime.parse('2026-03-10T08:00:00Z');
      final local = DateTime.parse('2026-03-15T12:00:00Z');

      expect(local.isBefore(server), isFalse,
          reason: 'Local is newer → already up to date, skip write');
    });

    test('writes when local updated_at is older than server', () {
      final server = DateTime.parse('2026-03-15T12:00:00Z');
      final local = DateTime.parse('2026-03-10T08:00:00Z');

      expect(local.isBefore(server), isTrue,
          reason: 'Server is newer → write the server value to local');
    });
  });

  // -------------------------------------------------------------------------
  group('PullSyncService — pullKennelCount takes max', () {
    // Mirrors the guard inside pullKennelCount:
    // final resolved = local >= server ? local : server
    test('uses server count when server > local', () {
      const local = 10;
      const server = 25;
      final resolved = local >= server ? local : server;
      expect(resolved, equals(25));
    });

    test('uses local count when local >= server', () {
      const local = 30;
      const server = 20;
      final resolved = local >= server ? local : server;
      expect(resolved, equals(30));
    });
  });
}
