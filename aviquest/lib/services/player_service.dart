import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../constants.dart';
import '../models/bird.dart';

class PlayerState {
  final int level;
  final int xp;
  final int streak;
  final Set<String> unlockedAchievements;

  const PlayerState({
    this.level = 1,
    this.xp = 0,
    this.streak = 1,
    this.unlockedAchievements = const {},
  });

  PlayerState copyWith({
    int? level,
    int? xp,
    int? streak,
    Set<String>? unlockedAchievements,
  }) => PlayerState(
    level: level ?? this.level,
    xp: xp ?? this.xp,
    streak: streak ?? this.streak,
    unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
  );

  String get title {
    if (level < 3) return 'Fledgling';
    if (level < 6) return 'Nestling';
    if (level < 10) return 'Sparrow';
    if (level < 15) return 'Warbler';
    if (level < 20) return 'Songweaver';
    if (level < 30) return 'Falconer';
    if (level < 40) return 'Eagle Scout';
    return 'Master Birder';
  }

  int get xpForNextLevel => (1000 * pow(level, 1.4)).round();
  double get xpProgress => (xp / xpForNextLevel).clamp(0.0, 1.0);
}

class PlayerNotifier extends StateNotifier<PlayerState> {
  final Box _box;

  PlayerNotifier(this._box) : super(const PlayerState()) {
    _load();
  }

  void _load() {
    state = PlayerState(
      level: _box.get('level', defaultValue: 1) as int,
      xp: _box.get('xp', defaultValue: 0) as int,
      streak: _box.get('streak', defaultValue: 1) as int,
      unlockedAchievements: Set<String>.from(
        _box.get('achievements', defaultValue: <String>[]) as List,
      ),
    );
  }

  void _save() {
    _box.put('level', state.level);
    _box.put('xp', state.xp);
    _box.put('streak', state.streak);
    _box.put('achievements', state.unlockedAchievements.toList());
  }

  /// Awards XP for a bird and returns list of newly unlocked achievement keys.
  List<String> addXpForBird(Bird bird, int aviaryCount) {
    var newLevel = state.level;
    var newXp = state.xp + bird.xp;

    while (newXp >= (1000 * pow(newLevel, 1.4)).round()) {
      newXp -= (1000 * pow(newLevel, 1.4)).round();
      newLevel++;
    }

    final newAchievements = Set<String>.from(state.unlockedAchievements);
    final unlocked = <String>[];

    void tryUnlock(String key) {
      if (!newAchievements.contains(key)) {
        newAchievements.add(key);
        unlocked.add(key);
      }
    }

    if (aviaryCount >= 1) tryUnlock('first_bird');
    if (aviaryCount >= 5) tryUnlock('five_species');
    if (aviaryCount >= 10) tryUnlock('ten_species');
    if (aviaryCount >= 20) tryUnlock('twenty_species');
    if (bird.rarity == Rarity.rare || bird.rarity == Rarity.legendary) tryUnlock('rare_find');
    if (bird.rarity == Rarity.legendary) tryUnlock('legendary_find');
    if (newLevel >= 5) tryUnlock('level_5');
    if (newLevel >= 10) tryUnlock('level_10');
    if (newLevel >= 20) tryUnlock('level_20');

    state = state.copyWith(
      level: newLevel,
      xp: newXp,
      unlockedAchievements: newAchievements,
    );
    _save();
    return unlocked;
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  throw UnimplementedError('playerProvider must be overridden after Hive init');
});
