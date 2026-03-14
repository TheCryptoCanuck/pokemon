import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../helpers/date_helpers.dart';
import '../models/dog.dart';
import 'dog_service.dart';

/// Provides a deterministic "Dog of the Day" based on the current date.
///
/// The selection is seeded by day so every user sees the same featured dog
/// on a given date. Bonus XP is awarded once per day for identifying the
/// daily dog via [claimDailyBonus].
class DailyDogService {
  final DogService _dogService;
  final Box _playerBox;

  DailyDogService(this._dogService, this._playerBox);

  /// Today's date key (e.g. "2026-03-03").
  String get _todayKey => formatDateKey(DateTime.now());

  /// Get today's featured dog. Deterministic: same dog for all users on a
  /// given day, rotating through the full catalogue over ~385 days.
  Dog get todaysDog {
    final now = DateTime.now();
    // Days since epoch gives a stable daily index.
    final daysSinceEpoch = now.toUtc().difference(DateTime.utc(2024, 1, 1)).inDays;
    final allDogs = _dogService.all;
    return allDogs[daysSinceEpoch % allDogs.length];
  }

  /// Whether the user has already claimed the daily bonus today.
  bool get isBonusClaimed {
    return _playerBox.get('daily_bonus_date') == _todayKey;
  }

  /// The bonus XP multiplier for identifying the daily dog.
  static const int bonusMultiplier = 3;

  /// Claim the daily bonus. Returns bonus XP amount, or 0 if already claimed.
  int claimDailyBonus() {
    if (isBonusClaimed) return 0;
    _playerBox.put('daily_bonus_date', _todayKey);
    return todaysDog.xp * bonusMultiplier;
  }

  /// A fun fact or challenge text for the daily dog.
  String get dailyChallenge {
    final dog = todaysDog;
    switch (dog.rarity) {
      case _:
        final facts = [
          'Find and identify ${dog.name} today for ${bonusMultiplier}x XP!',
          'Today\'s challenge: Spot the ${dog.name} (${dog.scientificName})',
          'Daily Quest: The ${dog.name} awaits — ${bonusMultiplier}x XP bonus!',
        ];
        final dayIndex = DateTime.now().day % facts.length;
        return facts[dayIndex];
    }
  }
}

final dailyDogServiceProvider = Provider<DailyDogService>((ref) {
  throw UnimplementedError('dailyDogServiceProvider must be overridden');
});
