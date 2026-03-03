import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../helpers/date_helpers.dart';
import '../models/bird.dart';
import 'bird_service.dart';

/// Provides a deterministic "Bird of the Day" based on the current date.
///
/// The selection is seeded by day so every user sees the same featured bird
/// on a given date. Bonus XP is awarded once per day for identifying the
/// daily bird via [claimDailyBonus].
class DailyBirdService {
  final BirdService _birdService;
  final Box _playerBox;

  DailyBirdService(this._birdService, this._playerBox);

  /// Today's date key (e.g. "2026-03-03").
  String get _todayKey => formatDateKey(DateTime.now());

  /// Get today's featured bird. Deterministic: same bird for all users on a
  /// given day, rotating through the full catalogue over ~385 days.
  Bird get todaysBird {
    final now = DateTime.now();
    // Days since epoch gives a stable daily index.
    final daysSinceEpoch = now.toUtc().difference(DateTime.utc(2024, 1, 1)).inDays;
    final birds = _birdService.all;
    return birds[daysSinceEpoch % birds.length];
  }

  /// Whether the user has already claimed the daily bonus today.
  bool get isBonusClaimed {
    return _playerBox.get('daily_bonus_date') == _todayKey;
  }

  /// The bonus XP multiplier for identifying the daily bird.
  static const int bonusMultiplier = 3;

  /// Claim the daily bonus. Returns bonus XP amount, or 0 if already claimed.
  int claimDailyBonus() {
    if (isBonusClaimed) return 0;
    _playerBox.put('daily_bonus_date', _todayKey);
    return todaysBird.xp * bonusMultiplier;
  }

  /// A fun fact or challenge text for the daily bird.
  String get dailyChallenge {
    final bird = todaysBird;
    switch (bird.rarity) {
      case _:
        final facts = [
          'Find and identify ${bird.name} today for ${bonusMultiplier}x XP!',
          'Today\'s challenge: Spot the ${bird.name} (${bird.scientificName})',
          'Daily Quest: The ${bird.name} awaits — ${bonusMultiplier}x XP bonus!',
        ];
        final dayIndex = DateTime.now().day % facts.length;
        return facts[dayIndex];
    }
  }
}

final dailyBirdServiceProvider = Provider<DailyBirdService>((ref) {
  throw UnimplementedError('dailyBirdServiceProvider must be overridden');
});
