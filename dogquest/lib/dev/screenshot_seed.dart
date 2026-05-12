import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:dogquest/services/dog_service.dart';
import 'package:dogquest/services/kennel_service.dart';
import 'package:dogquest/services/player_service.dart';

/// Seeds the Hive boxes and Riverpod state with a deterministic snapshot
/// suitable for marketing screenshots:
///
///   - Kennel: first 47 breeds from `assets/dogs.json` (47 / 150 = 31%
///     collection — visually full but with clear "more to find" framing).
///   - Player: Level 4 ("Good Boy" title), 1850 XP, 12-day streak,
///     a small set of unlocked achievements.
///
/// **Debug-only.** No-ops when compiled in release mode. Guarded by
/// [kDebugMode] so the entry point and seeding logic are tree-shaken
/// from production builds — this means the import of this file is also
/// safe to leave in release code.
///
/// To trigger the offline banner (screen 6) and the camera-overlay state
/// (screen 1), use the device's airplane mode and the standard identify
/// flow respectively — those aren't seeded through state.
///
/// Returns a human-readable summary of what was seeded, e.g.
/// `"Seeded 47 breeds + player Level 4 (1850 XP, 12-day streak)"`.
Future<String> seedScreenshotState(WidgetRef ref) async {
  if (!kDebugMode) {
    return 'Screenshot seed is debug-only.';
  }

  final dogService = ref.read(dogServiceProvider);
  final kennelSvc = ref.read(kennelServiceProvider);

  // ── Seed kennel ─────────────────────────────────────────────────────────
  final picks = dogService.all.take(47).toList();
  var added = 0;
  for (final dog in picks) {
    if (kennelSvc.add(dog.name)) added++;
  }

  // ── Seed player stats ───────────────────────────────────────────────────
  // Keys mirror PlayerNotifier._load() in lib/services/player_service.dart.
  final playerBox = Hive.box('dogquest_player_stats');
  await playerBox.putAll(<String, dynamic>{
    'level': 4,
    'xp': 1850,
    'streak': 12,
    'best_streak': 12,
    'streak_savers': 2,
    'achievements': const <String>[
      'first_breed',
      'streak_7',
      'pack_starter',
      'rare_find',
    ],
    'quizzes_completed': 8,
    'quiz_perfect_scores': 3,
    'total_sightings': 53,
    'selected_avatar': 'default',
  });
  ref.read(playerProvider.notifier).reload();

  return 'Seeded $added breeds + player Level 4 (1850 XP, 12-day streak)';
}

/// Clears the kennel and resets player stats to a fresh-install baseline.
/// Use after captures to return the device to its pre-seed state.
///
/// **Debug-only.** No-ops in release builds.
Future<String> clearScreenshotState(WidgetRef ref) async {
  if (!kDebugMode) {
    return 'Screenshot reset is debug-only.';
  }

  final kennelBox = Hive.box<String>('dogquest_kennel');
  final removed = kennelBox.length;
  await kennelBox.clear();

  final playerBox = Hive.box('dogquest_player_stats');
  await playerBox.putAll(<String, dynamic>{
    'level': 1,
    'xp': 0,
    'streak': 0,
    'best_streak': 0,
    'streak_savers': 0,
    'achievements': const <String>[],
    'quizzes_completed': 0,
    'quiz_perfect_scores': 0,
    'total_sightings': 0,
    'selected_avatar': 'default',
  });
  ref.read(playerProvider.notifier).reload();

  return 'Cleared $removed breeds + reset player state.';
}
