/// Performance benchmarks validating the Hound optimization pass.
///
/// These tests verify that caching, batch persistence, and derived-data
/// optimizations are working as intended. They are NOT micro-benchmarks —
/// they measure relative speedups and structural invariants.
///
/// Run with:
///   flutter test test/performance/perf_benchmark_test.dart -v
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dogquest/services/sighting_service.dart';
import 'package:dogquest/services/player_service.dart';
import 'package:dogquest/helpers/date_helpers.dart';

// =============================================================================
// Mock helpers
// =============================================================================

class MockBox extends Mock implements Box<Map> {}

class MockPlayerBox extends Mock implements Box {}

/// Build a real Hive-backed SightingService seeded with [count] sightings.
///
/// Uses a temp directory that is automatically cleaned up by the OS.
/// The sightings span 50 unique breeds distributed uniformly.
Future<SightingService> _buildSightingService({
  required String hivePath,
  required int count,
}) async {
  final service = SightingService();
  await service.init();

  final breeds = List.generate(50, (i) => 'Breed_$i');
  final rng = Random(42); // deterministic seed for reproducibility
  for (var i = 0; i < count; i++) {
    service.log(
      Sighting(
        dogName: breeds[i % breeds.length],
        timestamp: DateTime(2026, 1, 1).add(Duration(hours: i)),
        confidence: 0.7 + rng.nextDouble() * 0.3,
        source: 'ml',
        latitude: 40.0 + rng.nextDouble(),
        longitude: -74.0 + rng.nextDouble(),
        accuracy: 5.0 + rng.nextDouble() * 20,
      ),
    );
  }
  return service;
}

/// Measures wall-clock time of [fn] in microseconds.
int _timeMicros(void Function() fn) {
  final sw = Stopwatch()..start();
  fn();
  sw.stop();
  return sw.elapsedMicroseconds;
}

/// Build a [MockPlayerBox] configured with sensible defaults.
MockPlayerBox _buildPlayerBox({
  int level = 1,
  int xp = 0,
  int streak = 0,
  int bestStreak = 0,
  int streakSavers = 0,
  List<String> achievements = const [],
  int quizzesCompleted = 0,
  int quizPerfectScores = 0,
  int totalSightings = 0,
  String selectedAvatar = 'default',
  String? lastActiveDate,
}) {
  final box = MockPlayerBox();
  final todayKey = lastActiveDate ?? formatDateKey(DateTime.now());

  when(() => box.get('level', defaultValue: any(named: 'defaultValue')))
      .thenReturn(level);
  when(() => box.get('xp', defaultValue: any(named: 'defaultValue')))
      .thenReturn(xp);
  when(() => box.get('streak', defaultValue: any(named: 'defaultValue')))
      .thenReturn(streak);
  when(() => box.get('best_streak', defaultValue: any(named: 'defaultValue')))
      .thenReturn(bestStreak);
  when(() => box.get('streak_savers', defaultValue: any(named: 'defaultValue')))
      .thenReturn(streakSavers);
  when(() => box.get('achievements', defaultValue: any(named: 'defaultValue')))
      .thenReturn(achievements);
  when(
    () => box.get(
      'quizzes_completed',
      defaultValue: any(named: 'defaultValue'),
    ),
  ).thenReturn(quizzesCompleted);
  when(
    () => box.get(
      'quiz_perfect_scores',
      defaultValue: any(named: 'defaultValue'),
    ),
  ).thenReturn(quizPerfectScores);
  when(
    () => box.get('total_sightings', defaultValue: any(named: 'defaultValue')),
  ).thenReturn(totalSightings);
  when(
    () => box.get('selected_avatar', defaultValue: any(named: 'defaultValue')),
  ).thenReturn(selectedAvatar);
  when(
    () => box.get('last_active_date', defaultValue: any(named: 'defaultValue')),
  ).thenReturn(todayKey);

  when(() => box.put(any(), any())).thenAnswer((_) async {});
  when(() => box.putAll(any())).thenAnswer((_) async {});

  return box;
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hound_perf_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // ===========================================================================
  // 1. SightingService cache benchmark
  // ===========================================================================

  group('SightingService cache performance', () {
    const sightingCount = 500;

    test('warm cache is at least 10x faster than cold cache for .all',
        () async {
      final service = await _buildSightingService(
        hivePath: tempDir.path,
        count: sightingCount,
      );

      // --- Cold cache: first access forces deserialization + sort ---
      final coldMicros = _timeMicros(() {
        final _ = service.all;
      });

      // --- Warm cache: second access returns the cached list ---
      final warmMicros = _timeMicros(() {
        final _ = service.all;
      });

      // Print timing results for observability
      // ignore: avoid_print
      print('[PERF] SightingService.all with $sightingCount sightings:');
      // ignore: avoid_print
      print('  Cold cache (deserialize + sort): ${coldMicros}us');
      // ignore: avoid_print
      print('  Warm cache (cached return):      ${warmMicros}us');

      final speedup = warmMicros > 0 ? coldMicros / warmMicros : coldMicros;
      // ignore: avoid_print
      print('  Speedup: ${speedup.toStringAsFixed(1)}x');

      // The warm cache should be dramatically faster — at least 10x.
      // Cold cache deserializes 500 maps and sorts; warm returns a pointer.
      expect(
        coldMicros,
        greaterThan(warmMicros * 10),
        reason: 'Warm cache should be at least 10x faster than cold. '
            'Cold=${coldMicros}us, Warm=${warmMicros}us',
      );
    });

    test('sightingCount() with warm cache is O(1) lookup', () async {
      final service = await _buildSightingService(
        hivePath: tempDir.path,
        count: sightingCount,
      );

      // Prime the cache
      final _ = service.all;

      // First call to sightingCount builds _cachedCounts from cached all
      final buildCountsMicros = _timeMicros(() {
        service.sightingCount('Breed_0');
      });

      // Second call is a direct map lookup — O(1)
      final lookupMicros = _timeMicros(() {
        service.sightingCount('Breed_1');
      });

      // ignore: avoid_print
      print('[PERF] SightingService.sightingCount():');
      // ignore: avoid_print
      print('  Build counts map (first call): ${buildCountsMicros}us');
      // ignore: avoid_print
      print('  Cached map lookup (2nd call):  ${lookupMicros}us');

      // The lookup should be essentially instant — allow generous headroom
      // for CI variability and Windows timer resolution.
      expect(
        lookupMicros,
        lessThan(200),
        reason: 'Cached sightingCount lookup should be < 200us',
      );
    });

    test('log() invalidates cache, next .all re-deserializes', () async {
      final service = await _buildSightingService(
        hivePath: tempDir.path,
        count: sightingCount,
      );

      // Prime cache
      final firstAll = service.all;
      expect(firstAll.length, sightingCount);

      // Warm read — should be instant
      final warmMicros = _timeMicros(() {
        final _ = service.all;
      });

      // Log a new sighting — this must invalidate the cache
      service.log(
        Sighting(
          dogName: 'NewBreed',
          timestamp: DateTime.now(),
        ),
      );

      // Next access should re-deserialize (cold again)
      final postLogMicros = _timeMicros(() {
        final all = service.all;
        expect(all.length, sightingCount + 1);
      });

      // ignore: avoid_print
      print('[PERF] SightingService cache invalidation after log():');
      // ignore: avoid_print
      print('  Warm read (before log):  ${warmMicros}us');
      // ignore: avoid_print
      print('  Cold read (after log):   ${postLogMicros}us');

      // After invalidation, the read should be significantly slower than warm
      expect(
        postLogMicros,
        greaterThan(warmMicros),
        reason: 'Post-invalidation read should be slower than warm cache',
      );
    });

    test('totalSightings uses box.length directly (not .all deserialization)',
        () async {
      final service = await _buildSightingService(
        hivePath: tempDir.path,
        count: sightingCount,
      );

      // Access totalSightings WITHOUT priming the cache
      final totalMicros = _timeMicros(() {
        final count = service.totalSightings;
        expect(count, sightingCount);
      });

      // ignore: avoid_print
      print('[PERF] SightingService.totalSightings: ${totalMicros}us');

      // box.length is O(1), should be very fast — allow headroom for
      // Windows timer resolution and CI jitter.
      expect(
        totalMicros,
        lessThan(500),
        reason: 'totalSightings should use box.length, not deserialize all',
      );
    });
  });

  // ===========================================================================
  // 2. SightingService derived data reuses cache
  // ===========================================================================

  group('SightingService derived data reuses cached .all', () {
    const sightingCount = 500;

    test('uniqueSpecies derives from cached counts without re-scanning box',
        () async {
      final service = await _buildSightingService(
        hivePath: tempDir.path,
        count: sightingCount,
      );

      // Prime cache by calling .all
      final _ = service.all;

      // First call: builds _cachedCounts from cached .all
      final firstMicros = _timeMicros(() {
        final unique = service.uniqueSpecies;
        expect(unique, 50); // 500 sightings across 50 breeds
      });

      // Second call: returns cached counts.length
      final secondMicros = _timeMicros(() {
        final unique = service.uniqueSpecies;
        expect(unique, 50);
      });

      // ignore: avoid_print
      print('[PERF] SightingService.uniqueSpecies:');
      // ignore: avoid_print
      print('  First call (build counts): ${firstMicros}us');
      // ignore: avoid_print
      print('  Second call (cached):      ${secondMicros}us');

      // Second call should be very fast — just .length on a cached map
      expect(
        secondMicros,
        lessThan(200),
        reason: 'Cached uniqueSpecies should be < 200us',
      );
    });

    test('bestDay derives from cached .all, not re-reading box', () async {
      final service = await _buildSightingService(
        hivePath: tempDir.path,
        count: sightingCount,
      );

      // Prime cache
      final _ = service.all;

      // Measure bestDay — it calls groupedByDate which iterates cached .all
      final bestDayMicros = _timeMicros(() {
        final result = service.bestDay;
        expect(result, isNotNull);
        expect(result!.$2, greaterThan(0));
      });

      // ignore: avoid_print
      print(
        '[PERF] SightingService.bestDay (from warm cache): ${bestDayMicros}us',
      );

      // bestDay iterates the cached list, so it should be reasonably fast
      // (no Hive deserialization). Allow generous time for grouping 500 items.
      expect(
        bestDayMicros,
        lessThan(10000),
        reason: 'bestDay from warm cache should complete in < 10ms',
      );
    });

    test('forDog derives from cached .all list', () async {
      final service = await _buildSightingService(
        hivePath: tempDir.path,
        count: sightingCount,
      );

      // Prime cache
      final _ = service.all;

      final forDogMicros = _timeMicros(() {
        final results = service.forDog('Breed_0');
        // 500 sightings across 50 breeds = 10 per breed
        expect(results.length, 10);
      });

      // ignore: avoid_print
      print('[PERF] SightingService.forDog (warm cache): ${forDogMicros}us');

      expect(
        forDogMicros,
        lessThan(5000),
        reason: 'forDog from warm cache should complete in < 5ms',
      );
    });
  });

  // ===========================================================================
  // 3. PlayerNotifier putAll benchmark
  // ===========================================================================

  group('PlayerNotifier _save uses putAll (batched persistence)', () {
    test('_save calls putAll exactly once, not 10 individual puts', () {
      final box = _buildPlayerBox();
      final notifier = PlayerNotifier(box);

      // Clear any calls from constructor (_load + _updateStreak + _save)
      clearInteractions(box);

      // Trigger a save by recording a sighting
      notifier.recordSighting();

      // putAll should have been called exactly once
      verify(() => box.putAll(any())).called(1);

      // Individual put should NOT have been called for field persistence.
      // (It IS called once in _updateStreak for 'last_active_date', but
      // _save itself should not call put for each field.)
      // We already cleared interactions, so only the recordSighting path
      // should show up. Since _updateStreak is only called in the
      // constructor (which we cleared), there should be zero put calls.
      verifyNever(() => box.put('level', any()));
      verifyNever(() => box.put('xp', any()));
      verifyNever(() => box.put('streak', any()));
      verifyNever(() => box.put('achievements', any()));
      verifyNever(() => box.put('total_sightings', any()));
    });

    test('putAll map contains all 10 player fields', () {
      final box = _buildPlayerBox(level: 5, xp: 200, streak: 3);
      final notifier = PlayerNotifier(box);

      clearInteractions(box);
      notifier.recordSighting();

      final captured = verify(() => box.putAll(captureAny())).captured;
      expect(captured, hasLength(1));

      final savedMap = captured.first as Map<dynamic, dynamic>;
      // ignore: avoid_print
      print(
        '[PERF] PlayerNotifier._save putAll keys: ${savedMap.keys.toList()}',
      );

      expect(savedMap.containsKey('level'), isTrue);
      expect(savedMap.containsKey('xp'), isTrue);
      expect(savedMap.containsKey('streak'), isTrue);
      expect(savedMap.containsKey('best_streak'), isTrue);
      expect(savedMap.containsKey('streak_savers'), isTrue);
      expect(savedMap.containsKey('achievements'), isTrue);
      expect(savedMap.containsKey('quizzes_completed'), isTrue);
      expect(savedMap.containsKey('quiz_perfect_scores'), isTrue);
      expect(savedMap.containsKey('total_sightings'), isTrue);
      expect(savedMap.containsKey('selected_avatar'), isTrue);
    });

    test('multiple mutations trigger one putAll per mutation, not N puts', () {
      final box = _buildPlayerBox();
      final notifier = PlayerNotifier(box);
      clearInteractions(box);

      // 5 sighting recordings = 5 saves, each with exactly 1 putAll
      for (var i = 0; i < 5; i++) {
        notifier.recordSighting();
      }

      verify(() => box.putAll(any())).called(5);
      // No individual field puts
      verifyNever(() => box.put('level', any()));
      verifyNever(() => box.put('xp', any()));
      verifyNever(() => box.put('total_sightings', any()));
    });
  });

  // ===========================================================================
  // 4. SightingService cache consistency
  // ===========================================================================

  group('SightingService cache consistency', () {
    test('sightingCount agrees with forDog().length for all breeds', () async {
      final service =
          await _buildSightingService(hivePath: tempDir.path, count: 200);

      for (var i = 0; i < 50; i++) {
        final breed = 'Breed_$i';
        final countFromCache = service.sightingCount(breed);
        final countFromFilter = service.forDog(breed).length;
        expect(
          countFromCache,
          countFromFilter,
          reason: 'sightingCount vs forDog mismatch for $breed',
        );
      }
    });

    test('uniqueSpecies equals distinct breed count in .all', () async {
      final service =
          await _buildSightingService(hivePath: tempDir.path, count: 300);

      final distinctBreeds = service.all.map((s) => s.dogName).toSet().length;
      expect(service.uniqueSpecies, distinctBreeds);
    });

    test('cache invalidation keeps counts consistent after log()', () async {
      final service =
          await _buildSightingService(hivePath: tempDir.path, count: 100);

      final beforeCount = service.sightingCount('Breed_0');
      final beforeTotal = service.totalSightings;

      // Log a new sighting for Breed_0
      service.log(
        Sighting(
          dogName: 'Breed_0',
          timestamp: DateTime.now(),
        ),
      );

      expect(service.totalSightings, beforeTotal + 1);
      expect(service.sightingCount('Breed_0'), beforeCount + 1);
      expect(service.all.length, beforeTotal + 1);
    });
  });

  // ===========================================================================
  // 5. Grouping operations performance with warm cache
  // ===========================================================================

  group('SightingService grouping operations (warm cache)', () {
    test('groupedByDate and sightingsByBreed use cached .all', () async {
      final service =
          await _buildSightingService(hivePath: tempDir.path, count: 500);

      // Prime cache
      final _ = service.all;

      final groupByDateMicros = _timeMicros(() {
        final grouped = service.groupedByDate();
        expect(grouped.isNotEmpty, isTrue);
      });

      final groupByBreedMicros = _timeMicros(() {
        final grouped = service.sightingsByBreed();
        expect(grouped.isNotEmpty, isTrue);
      });

      // ignore: avoid_print
      print('[PERF] SightingService grouping (warm cache, 500 sightings):');
      // ignore: avoid_print
      print('  groupedByDate:    ${groupByDateMicros}us');
      // ignore: avoid_print
      print('  sightingsByBreed: ${groupByBreedMicros}us');

      // Both should be fast since they iterate the cached list
      expect(
        groupByDateMicros,
        lessThan(10000),
        reason: 'groupedByDate from cache should be < 10ms',
      );
      expect(
        groupByBreedMicros,
        lessThan(10000),
        reason: 'sightingsByBreed from cache should be < 10ms',
      );
    });

    test('recent() returns slice of cached list without full scan', () async {
      final service =
          await _buildSightingService(hivePath: tempDir.path, count: 500);

      // Prime cache
      final _ = service.all;

      final recentMicros = _timeMicros(() {
        final r = service.recent(limit: 20);
        expect(r.length, 20);
      });

      // ignore: avoid_print
      print(
        '[PERF] SightingService.recent(20) (warm cache): ${recentMicros}us',
      );

      // .take(20).toList() on a cached list should be nearly instant
      expect(
        recentMicros,
        lessThan(500),
        reason: 'recent(20) from warm cache should be < 500us',
      );
    });
  });
}
