import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import '../constants.dart';
import '../models/bird.dart';

final _log = Logger('PlayerService');

class PlayerState {
  final int level;
  final int xp;
  final int streak;
  final Set<String> unlockedAchievements;

  const PlayerState({
    this.level = 1,
    this.xp = 0,
    this.streak = 0,
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
    _updateStreak();
  }

  void _load() {
    state = PlayerState(
      level: _box.get('level', defaultValue: 1) as int,
      xp: _box.get('xp', defaultValue: 0) as int,
      streak: _box.get('streak', defaultValue: 0) as int,
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

  /// Check and update the daily streak on app open.
  void _updateStreak() {
    final now = DateTime.now();
    final todayKey = _dateKey(now);
    final lastActiveKey = _box.get('last_active_date', defaultValue: '') as String;

    if (lastActiveKey == todayKey) {
      // Already logged in today — no change
      return;
    }

    final yesterdayKey = _dateKey(now.subtract(const Duration(days: 1)));

    if (lastActiveKey == yesterdayKey) {
      // Consecutive day — increment streak
      final newStreak = state.streak + 1;
      state = state.copyWith(streak: newStreak);
      _log.info('Streak continued: $newStreak days');
    } else if (lastActiveKey.isEmpty) {
      // First ever session
      state = state.copyWith(streak: 1);
      _log.info('First session — streak started');
    } else {
      // Missed one or more days — reset to 1
      _log.info('Streak reset (last active: $lastActiveKey, today: $todayKey)');
      state = state.copyWith(streak: 1);
    }

    _box.put('last_active_date', todayKey);
    _save();
  }

  /// Format a date as YYYY-MM-DD for reliable comparison.
  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Awards XP for a bird and returns list of newly unlocked achievement keys.
  ///
  /// [collectedBirds] is the full list of collected bird names (used for
  /// rarity-specific counting). [allBirds] is the full bird catalogue
  /// (used for "collect all" milestones).
  List<String> addXpForBird(
    Bird bird,
    int aviaryCount, {
    List<Bird> collectedBirds = const [],
    List<Bird> allBirds = const [],
  }) {
    final oldLevel = state.level;
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

    // ─── Collection milestones ─────────────────────────────────────────
    if (aviaryCount >= 1) tryUnlock('first_bird');
    if (aviaryCount >= 5) tryUnlock('five_species');
    if (aviaryCount >= 10) tryUnlock('ten_species');
    if (aviaryCount >= 20) tryUnlock('twenty_species');
    if (aviaryCount >= 50) tryUnlock('fifty_species');
    if (aviaryCount >= 100) tryUnlock('hundred_species');
    if (aviaryCount >= 200) tryUnlock('two_hundred_species');

    // ─── Rarity-specific collection ────────────────────────────────────
    if (bird.rarity == Rarity.rare || bird.rarity == Rarity.legendary) {
      tryUnlock('rare_find');
    }
    if (bird.rarity == Rarity.legendary) tryUnlock('legendary_find');

    if (collectedBirds.isNotEmpty) {
      final rareCount = collectedBirds.where((b) => b.rarity == Rarity.rare).length;
      final legendaryCount = collectedBirds.where((b) => b.rarity == Rarity.legendary).length;
      if (rareCount >= 5) tryUnlock('five_rare');
      if (legendaryCount >= 5) tryUnlock('five_legendary');

      // "Collect all" milestones
      if (allBirds.isNotEmpty) {
        final totalCommon = allBirds.where((b) => b.rarity == Rarity.common).length;
        final collectedCommon = collectedBirds.where((b) => b.rarity == Rarity.common).length;
        if (collectedCommon >= totalCommon && totalCommon > 0) tryUnlock('all_common');

        final totalUncommon = allBirds.where((b) => b.rarity == Rarity.uncommon).length;
        final collectedUncommon = collectedBirds.where((b) => b.rarity == Rarity.uncommon).length;
        if (collectedUncommon >= totalUncommon && totalUncommon > 0) tryUnlock('all_uncommon');
      }

      // Conservation achievements
      final hasEndangered = collectedBirds.any((b) =>
          b.conservationStatus == 'Endangered' ||
          b.conservationStatus == 'Critically Endangered');
      if (hasEndangered) tryUnlock('endangered_spotter');

      final threatenedCount = collectedBirds.where((b) =>
          b.conservationStatus == 'Vulnerable' ||
          b.conservationStatus == 'Endangered' ||
          b.conservationStatus == 'Critically Endangered' ||
          b.conservationStatus == 'Near Threatened').length;
      if (threatenedCount >= 5) tryUnlock('conservation_hero');
    }

    // ─── Level milestones ──────────────────────────────────────────────
    if (newLevel >= 5) tryUnlock('level_5');
    if (newLevel >= 10) tryUnlock('level_10');
    if (newLevel >= 20) tryUnlock('level_20');
    if (newLevel >= 30) tryUnlock('level_30');

    // ─── Streak milestones ─────────────────────────────────────────────
    if (state.streak >= 3) tryUnlock('streak_3');
    if (state.streak >= 7) tryUnlock('streak_7');
    if (state.streak >= 30) tryUnlock('streak_30');

    state = state.copyWith(
      level: newLevel,
      xp: newXp,
      unlockedAchievements: newAchievements,
    );
    _save();

    if (newLevel > oldLevel) {
      _log.info('Level up! $oldLevel → $newLevel');
    }
    if (unlocked.isNotEmpty) {
      _log.info('Achievements unlocked: $unlocked');
    }

    return unlocked;
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  throw UnimplementedError('playerProvider must be overridden after Hive init');
});
