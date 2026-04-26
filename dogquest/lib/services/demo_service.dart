import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';

import 'package:dogquest/models/lost_dog_report.dart';
import 'package:dogquest/services/dog_service.dart';
import 'package:dogquest/services/player_service.dart';
import 'package:dogquest/services/dog_mastery_service.dart';

final _log = Logger('DemoService');

/// Pre-seeded demo data for investor demos.
///
/// Seeds the app with ~25 discovered breeds, realistic sighting history,
/// player stats (level 7), achievements, and GPS coordinates around
/// NYC Central Park area.
class DemoService {
  DemoService._();

  /// Whether the app is currently in demo mode.
  static bool get isDemoMode {
    try {
      final box = Hive.box('dogquest_player_stats');
      return box.get('demo_mode', defaultValue: false) as bool;
    } catch (_) {
      return false;
    }
  }

  /// NYC Central Park area coordinates for realistic sighting locations.
  /// Each entry: (lat, lon, label).
  static const _demoLocations = <(double, double, String)>[
    (40.7829, -73.9654, 'Central Park - Great Lawn'),
    (40.7736, -73.9712, 'Central Park - Bethesda Fountain'),
    (40.7694, -73.9716, 'Central Park - The Mall'),
    (40.7812, -73.9665, 'Central Park - Reservoir'),
    (40.7968, -73.9493, 'Central Park - Harlem Meer'),
    (40.7484, -73.9856, 'Madison Square Park'),
    (40.7580, -73.9855, 'Bryant Park'),
    (40.7197, -73.9991, 'Washington Square Park'),
    (40.7527, -73.9772, 'Grand Central area'),
    (40.7614, -73.9776, 'Rockefeller Center area'),
    (40.7794, -73.9632, 'Metropolitan Museum area'),
    (40.7411, -73.9897, 'Union Square Park'),
    (40.6892, -74.0445, 'Battery Park - Statue of Liberty view'),
    (40.7282, -73.7949, 'Flushing Meadows Park'),
    (40.6602, -73.9690, 'Prospect Park, Brooklyn'),
  ];

  /// Demo breeds to seed, with sighting counts for mastery variety.
  /// Format: (breed name, number of sightings).
  static const _demoBreeds = <(String, int)>[
    // Common breeds (10) - well-known, investors will recognize
    ('Labrador Retriever', 5),
    ('Golden Retriever', 4),
    ('German Shepherd', 3),
    ('French Bulldog', 3),
    ('Beagle', 2),
    ('Poodle', 2),
    ('Bulldog', 1),
    ('Rottweiler', 1),
    ('Boxer', 1),
    ('Dachshund', 1),
    // Uncommon breeds (9) - interesting variety
    ('Bernese Mountain Dog', 3),
    ('Dalmatian', 2),
    ('Samoyed', 2),
    ('Akita', 1),
    ('Whippet', 1),
    ('Irish Setter', 1),
    ('Weimaraner', 1),
    ('Rhodesian Ridgeback', 1),
    ('Siberian Husky', 1),
    // Rare breeds (5) - shows the rarity system
    ('Afghan Hound', 2),
    ('Borzoi', 1),
    ('Basenji', 1),
    ('Komondor', 1),
    ('Irish Wolfhound', 1),
    // Legendary breeds (2) - the crown jewels
    ('Chinook', 1),
    ('Kai Ken', 1),
  ];

  /// Demo achievements to unlock.
  static const _demoAchievements = <String>{
    'first_dog',
    'five_species',
    'ten_species',
    'twenty_species',
    'rare_find',
    'legendary_find',
    'level_5',
    'streak_3',
    'streak_7',
    'first_quiz',
  };

  /// Seed the app with demo data. Returns true on success.
  ///
  /// This writes directly to the Hive boxes that are already open.
  /// After calling this, providers must be invalidated so the UI
  /// picks up the new data.
  static Future<bool> seedDemoData(WidgetRef ref) async {
    try {
      _log.info('Seeding demo data...');

      final dogSvc = ref.read(dogServiceProvider);
      final rng = Random(42); // Fixed seed for reproducible demo

      // ── 1. Seed player stats ──────────────────────────────────
      final playerBox = Hive.box('dogquest_player_stats');
      playerBox.put('demo_mode', true);
      playerBox.put('level', 7);
      playerBox.put('xp', 1850);
      playerBox.put('streak', 8);
      playerBox.put('best_streak', 12);
      playerBox.put('streak_savers', 1);
      playerBox.put('achievements', _demoAchievements.toList());
      playerBox.put('quizzes_completed', 4);
      playerBox.put('quiz_perfect_scores', 1);
      playerBox.put(
        'total_sightings',
        _demoBreeds.fold<int>(0, (sum, b) => sum + b.$2),
      );
      playerBox.put('selected_avatar', 'bloodhound'); // 20+ breeds avatar
      playerBox.put('cached_username', 'DogLover');
      playerBox.put('offline_mode', true);
      playerBox.put('onboarding_complete', true);
      // Set last active to today so streak shows correctly
      final now = DateTime.now();
      playerBox.put(
        'last_active_date',
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      );

      // ── 2. Seed kennel (collected breeds) ─────────────────────
      final kennelBox = Hive.box<String>('dogquest_kennel');
      for (final (breedName, _) in _demoBreeds) {
        final dog =
            dogSvc.lookup(breedName) ?? dogSvc.lookupByCommonName(breedName);
        if (dog != null) {
          kennelBox.put(dog.name, dog.name);
        } else {
          _log.warning('Demo breed not found in database: $breedName');
        }
      }

      // ── 3. Seed sightings with GPS coordinates ───────────────
      final sightingsBox = Hive.box<Map>('dogquest_sightings_v1');

      // Spread sightings over the past 18 days
      int locationIdx = 0;
      for (final (breedName, count) in _demoBreeds) {
        final dog =
            dogSvc.lookup(breedName) ?? dogSvc.lookupByCommonName(breedName);
        if (dog == null) continue;

        for (int i = 0; i < count; i++) {
          // Spread timestamps: most recent sightings first
          final daysAgo = (locationIdx * 18 ~/ _totalSightings).clamp(0, 17);
          final hoursOffset = rng.nextInt(10) + 8; // Between 8 AM and 6 PM
          final minuteOffset = rng.nextInt(60);
          final sightingTime = DateTime(
            now.year,
            now.month,
            now.day - daysAgo,
            hoursOffset,
            minuteOffset,
          );

          // Pick a location, add small random offset for realism
          final loc = _demoLocations[locationIdx % _demoLocations.length];
          final latJitter = (rng.nextDouble() - 0.5) * 0.002;
          final lonJitter = (rng.nextDouble() - 0.5) * 0.002;

          sightingsBox.add({
            'dog': dog.name,
            'ts': sightingTime.toIso8601String(),
            'conf': (0.75 + rng.nextDouble() * 0.20), // 75-95% confidence
            'src': 'ml',
            'lat': loc.$1 + latJitter,
            'lon': loc.$2 + lonJitter,
            'acc': 5.0 + rng.nextDouble() * 15.0, // 5-20m GPS accuracy
          });

          locationIdx++;
        }
      }

      // ── 4. Seed mastery counts ────────────────────────────────
      try {
        final masteryBox = await Hive.openBox<int>('dogquest_mastery');
        for (final (breedName, count) in _demoBreeds) {
          final dog =
              dogSvc.lookup(breedName) ?? dogSvc.lookupByCommonName(breedName);
          if (dog != null) {
            masteryBox.put(dog.name, count);
          }
        }
      } catch (e) {
        _log.warning('Could not seed mastery data: $e');
      }

      // ── 5. Seed lost dog reports for recognition network demo ──
      _seedLostDogReports(playerBox, rng, now);

      // ── 6. Seed daily challenge progress ──────────────────────
      // (Daily challenges auto-regenerate, so just marking some progress
      //  in the player stats is enough for a good demo impression.)

      _log.info('Demo data seeded: ${kennelBox.length} breeds, '
          '${sightingsBox.length} sightings');

      // ── 7. Invalidate providers so UI refreshes ───────────────
      _refreshProviders(ref);

      return true;
    } catch (e, st) {
      _log.severe('Failed to seed demo data', e, st);
      return false;
    }
  }

  /// Seed demo lost dog reports for the Lost Dog Recognition Network.
  ///
  /// Creates 4 "lost" dogs from other users in the NYC area with
  /// synthetic embeddings. When the demo user scans a matching breed,
  /// the cosine similarity will produce a credible match.
  static void _seedLostDogReports(Box playerBox, Random rng, DateTime now) {
    // Synthetic 150-dim embeddings — each breed gets a spike at a
    // different index so same-breed scans produce high similarity.
    List<double> syntheticEmbedding(int spikeIdx) {
      final emb = List<double>.filled(150, 0.005);
      emb[spikeIdx] = 0.65 + rng.nextDouble() * 0.15;
      // Add minor noise to a few neighboring indices for realism
      for (int i = 1; i <= 3; i++) {
        if (spikeIdx + i < 150) {
          emb[spikeIdx + i] = 0.02 + rng.nextDouble() * 0.05;
        }
        if (spikeIdx - i >= 0) {
          emb[spikeIdx - i] = 0.02 + rng.nextDouble() * 0.05;
        }
      }
      return emb;
    }

    final demoLostDogs = <LostDogReport>[
      LostDogReport(
        id: 'demo-lost-001',
        dogName: 'Buddy',
        breed: 'Golden Retriever',
        embedding: syntheticEmbedding(1), // Golden Retriever ~ index 1
        lastSeenLat: 40.7736,
        lastSeenLon: -73.9712,
        lastSeenLocation: 'Central Park - Bethesda Fountain',
        lostDate: now.subtract(const Duration(days: 3)),
        createdAt: now.subtract(const Duration(days: 3)),
        ownerContact: 'Sarah M. — (212) 555-0147',
        notes:
            'Red collar with bone-shaped tag. Very friendly, responds to "Buddy".',
      ),
      LostDogReport(
        id: 'demo-lost-002',
        dogName: 'Luna',
        breed: 'French Bulldog',
        embedding: syntheticEmbedding(3), // French Bulldog ~ index 3
        lastSeenLat: 40.7484,
        lastSeenLon: -73.9856,
        lastSeenLocation: 'Madison Square Park',
        lostDate: now.subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 1)),
        ownerContact: 'Mike T. — (646) 555-0283',
        notes: 'Brindle coloring, blue harness. Microchipped.',
      ),
      LostDogReport(
        id: 'demo-lost-003',
        dogName: 'Max',
        breed: 'German Shepherd',
        embedding: syntheticEmbedding(2), // German Shepherd ~ index 2
        lastSeenLat: 40.7812,
        lastSeenLon: -73.9665,
        lastSeenLocation: 'Central Park - Reservoir',
        lostDate: now.subtract(const Duration(days: 5)),
        createdAt: now.subtract(const Duration(days: 5)),
        ownerContact: 'Alex K. — (917) 555-0391',
        notes:
            'Black and tan, 3 years old. Wearing GPS collar (battery may be dead).',
      ),
      LostDogReport(
        id: 'demo-lost-004',
        dogName: 'Coco',
        breed: 'Labrador Retriever',
        embedding: syntheticEmbedding(0), // Labrador ~ index 0
        lastSeenLat: 40.6602,
        lastSeenLon: -73.9690,
        lastSeenLocation: 'Prospect Park, Brooklyn',
        lostDate: now.subtract(const Duration(days: 2)),
        createdAt: now.subtract(const Duration(days: 2)),
        ownerContact: 'Jennifer L. — (718) 555-0512',
        notes:
            'Chocolate lab, pink bandana. Loves treats — very food motivated.',
      ),
    ];

    playerBox.put(
      'lost_dog_reports',
      jsonEncode(demoLostDogs.map((r) => r.toJson()).toList()),
    );
    _log.info('Seeded ${demoLostDogs.length} demo lost dog reports');
  }

  /// Total sightings across all demo breeds.
  static int get _totalSightings =>
      _demoBreeds.fold<int>(0, (sum, b) => sum + b.$2);

  /// Clear all demo data and return to a fresh state.
  ///
  /// This effectively resets the app. The caller should navigate
  /// to the splash/login screen after calling this.
  static Future<bool> clearDemoData(WidgetRef ref) async {
    try {
      _log.info('Clearing demo data...');

      // Clear kennel
      final kennelBox = Hive.box<String>('dogquest_kennel');
      await kennelBox.clear();

      // Clear sightings
      final sightingsBox = Hive.box<Map>('dogquest_sightings_v1');
      await sightingsBox.clear();

      // Clear mastery
      try {
        final masteryBox = await Hive.openBox<int>('dogquest_mastery');
        await masteryBox.clear();
      } catch (_) {}

      // Reset player stats
      final playerBox = Hive.box('dogquest_player_stats');
      playerBox.put('demo_mode', false);
      playerBox.put('level', 1);
      playerBox.put('xp', 0);
      playerBox.put('streak', 0);
      playerBox.put('best_streak', 0);
      playerBox.put('streak_savers', 0);
      playerBox.put('achievements', <String>[]);
      playerBox.put('quizzes_completed', 0);
      playerBox.put('quiz_perfect_scores', 0);
      playerBox.put('total_sightings', 0);
      playerBox.put('selected_avatar', 'default');
      playerBox.put('last_active_date', '');

      _log.info('Demo data cleared');

      // Invalidate providers so UI refreshes
      _refreshProviders(ref);

      return true;
    } catch (e, st) {
      _log.severe('Failed to clear demo data', e, st);
      return false;
    }
  }

  /// Refresh providers so the UI picks up the new Hive data.
  ///
  /// KennelService and SightingService read directly from their Hive boxes,
  /// so their data is always live. PlayerNotifier and DogMasteryNotifier
  /// cache state in memory, so we call reload() on them.
  static void _refreshProviders(WidgetRef ref) {
    // Reload in-memory state from Hive
    ref.read(playerProvider.notifier).reload();
    ref.read(dogMasteryProvider.notifier).reload();
    // KennelService and SightingService read from Hive boxes directly,
    // so no explicit refresh is needed — UI will pick up changes on
    // the next build cycle.
  }
}
