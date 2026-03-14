import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import '../constants.dart';
import '../helpers/date_helpers.dart';
import '../models/dog.dart';

final _log = Logger('PlayerService');

class PlayerState {
  final int level;
  final int xp;
  final int streak;
  final int bestStreak;
  final int streakSavers;
  final Set<String> unlockedAchievements;
  final int quizzesCompleted;
  final int quizPerfectScores;
  final int totalSightings;
  final String selectedAvatar;

  const PlayerState({
    this.level = 1,
    this.xp = 0,
    this.streak = 0,
    this.bestStreak = 0,
    this.streakSavers = 0,
    this.unlockedAchievements = const {},
    this.quizzesCompleted = 0,
    this.quizPerfectScores = 0,
    this.totalSightings = 0,
    this.selectedAvatar = 'default',
  });

  PlayerState copyWith({
    int? level,
    int? xp,
    int? streak,
    int? bestStreak,
    int? streakSavers,
    Set<String>? unlockedAchievements,
    int? quizzesCompleted,
    int? quizPerfectScores,
    int? totalSightings,
    String? selectedAvatar,
  }) => PlayerState(
    level: level ?? this.level,
    xp: xp ?? this.xp,
    streak: streak ?? this.streak,
    bestStreak: bestStreak ?? this.bestStreak,
    streakSavers: streakSavers ?? this.streakSavers,
    unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
    quizzesCompleted: quizzesCompleted ?? this.quizzesCompleted,
    quizPerfectScores: quizPerfectScores ?? this.quizPerfectScores,
    totalSightings: totalSightings ?? this.totalSightings,
    selectedAvatar: selectedAvatar ?? this.selectedAvatar,
  );

  String get title {
    if (level < 3) return 'Puppy';
    if (level < 6) return 'Good Boy';
    if (level < 10) return 'Pack Member';
    if (level < 15) return 'Breed Spotter';
    if (level < 20) return 'Dog Whisperer';
    if (level < 30) return 'Expert Handler';
    if (level < 40) return 'Show Judge';
    return 'Best in Show';
  }

  int get xpForNextLevel => (1000 * pow(level, 1.4)).round();
  double get xpProgress => (xp / xpForNextLevel).clamp(0.0, 1.0);

  /// Streak-based XP multiplier: +10% per streak day, capped at +100% (day 10).
  double get streakXpMultiplier {
    if (streak <= 2) return 1.0;
    final bonus = (streak - 2).clamp(0, 10) * 0.10;
    return 1.0 + bonus;
  }

}

class PlayerNotifier extends StateNotifier<PlayerState> {
  final Box _box;

  PlayerNotifier(this._box) : super(const PlayerState()) {
    _load();
    _updateStreak();
  }

  /// Public read-only access to the current state (avoids @protected warning).
  PlayerState get currentState => state;

  /// Reload player state from Hive. Used by demo mode to pick up
  /// externally-written data without restarting the app.
  void reload() => _load();

  void _load() {
    state = PlayerState(
      level: _box.get('level', defaultValue: 1) as int,
      xp: _box.get('xp', defaultValue: 0) as int,
      streak: _box.get('streak', defaultValue: 0) as int,
      bestStreak: _box.get('best_streak', defaultValue: 0) as int,
      streakSavers: _box.get('streak_savers', defaultValue: 0) as int,
      unlockedAchievements: Set<String>.from(
        _box.get('achievements', defaultValue: <String>[]) as List,
      ),
      quizzesCompleted: _box.get('quizzes_completed', defaultValue: 0) as int,
      quizPerfectScores: _box.get('quiz_perfect_scores', defaultValue: 0) as int,
      totalSightings: _box.get('total_sightings', defaultValue: 0) as int,
      selectedAvatar: _migrateAvatarId(_box.get('selected_avatar', defaultValue: 'default') as String),
    );
  }

  /// Migrate legacy bird-themed avatar IDs to dog-themed ones.
  static String _migrateAvatarId(String id) {
    const mapping = {
      'robin': 'good_boy',
      'owl': 'guard_dog',
      'eagle': 'bloodhound',
      'parrot': 'show_champion',
      'phoenix': 'top_dog',
    };
    return mapping[id] ?? id;
  }

  void _save() {
    _box.putAll({
      'level': state.level,
      'xp': state.xp,
      'streak': state.streak,
      'best_streak': state.bestStreak,
      'streak_savers': state.streakSavers,
      'achievements': state.unlockedAchievements.toList(),
      'quizzes_completed': state.quizzesCompleted,
      'quiz_perfect_scores': state.quizPerfectScores,
      'total_sightings': state.totalSightings,
      'selected_avatar': state.selectedAvatar,
    });
  }

  /// Record a completed quiz. Returns newly unlocked achievement keys.
  List<String> recordQuiz(int score, int total) {
    final isPerfect = score == total;
    state = state.copyWith(
      quizzesCompleted: state.quizzesCompleted + 1,
      quizPerfectScores: isPerfect ? state.quizPerfectScores + 1 : null,
    );

    final newAchievements = Set<String>.from(state.unlockedAchievements);
    final unlocked = <String>[];

    void tryUnlock(String key) {
      if (!newAchievements.contains(key)) {
        newAchievements.add(key);
        unlocked.add(key);
      }
    }

    if (state.quizzesCompleted >= 1) tryUnlock('first_quiz');
    if (state.quizzesCompleted >= 10) tryUnlock('ten_quizzes');
    if (isPerfect) tryUnlock('perfect_quiz');
    if (state.quizPerfectScores >= 5) tryUnlock('five_perfect');

    if (unlocked.isNotEmpty) {
      state = state.copyWith(unlockedAchievements: newAchievements);
    }
    _save();
    return unlocked;
  }

  /// Increment total sightings counter.
  void recordSighting() {
    state = state.copyWith(totalSightings: state.totalSightings + 1);
    _save();
  }

  /// Update selected avatar.
  void setAvatar(String avatarId) {
    state = state.copyWith(selectedAvatar: avatarId);
    _save();
  }

  /// Whether a streak saver was used on this app open.
  bool streakSaverUsed = false;

  /// The previous streak value before it was broken (0 if not broken).
  int brokenStreakValue = 0;

  /// Whether the streak was broken on this app open.
  bool get streakWasBroken => brokenStreakValue > 1;

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
    final dayBeforeKey = _dateKey(now.subtract(const Duration(days: 2)));

    if (lastActiveKey == yesterdayKey) {
      // Consecutive day — increment streak
      final newStreak = state.streak + 1;
      final newBest = newStreak > state.bestStreak ? newStreak : state.bestStreak;
      state = state.copyWith(streak: newStreak, bestStreak: newBest);
      _log.info('Streak continued: $newStreak days');
      _awardStreakMilestoneXp(newStreak);
    } else if (lastActiveKey.isEmpty) {
      // First ever session
      state = state.copyWith(streak: 1, bestStreak: 1);
      _log.info('First session — streak started');
    } else if (lastActiveKey == dayBeforeKey && state.streakSavers > 0) {
      // Missed exactly one day — use streak saver
      final newStreak = state.streak + 1;
      final newBest = newStreak > state.bestStreak ? newStreak : state.bestStreak;
      state = state.copyWith(
        streak: newStreak,
        bestStreak: newBest,
        streakSavers: state.streakSavers - 1,
      );
      streakSaverUsed = true;
      _log.info('Streak saved! Used 1 streak saver (${state.streakSavers} remaining)');
    } else {
      // Missed one or more days — capture old streak and reset to 1
      brokenStreakValue = state.streak;
      _log.info('Streak broken at ${state.streak} days (last active: $lastActiveKey, today: $todayKey)');
      state = state.copyWith(streak: 1);
    }

    // Award a streak saver every 7 consecutive days (max 3 banked)
    if (state.streak > 0 && state.streak % 7 == 0 && state.streakSavers < 3) {
      state = state.copyWith(streakSavers: state.streakSavers + 1);
      _log.info('Streak saver earned! (${state.streakSavers} available)');
    }

    _box.put('last_active_date', todayKey);
    _save();
  }

  /// Award a flat XP bonus (used for profile creation, special events, etc.).
  void awardBonusXp(int amount) {
    if (amount <= 0) return;
    state = state.copyWith(xp: state.xp + amount);
    _save();
  }

  /// Award bonus XP at streak milestones.
  void _awardStreakMilestoneXp(int streak) {
    int bonus = 0;
    if (streak == 7) bonus = 100;
    if (streak == 14) bonus = 250;
    if (streak == 30) bonus = 500;
    if (streak == 60) bonus = 1000;
    if (bonus > 0) {
      final newXp = state.xp + bonus;
      state = state.copyWith(xp: newXp);
      _log.info('Streak milestone $streak days: +$bonus XP');
    }
  }

  /// Format a date as YYYY-MM-DD for reliable comparison.
  String _dateKey(DateTime d) => formatDateKey(d);

  /// Awards XP for a dog and returns list of newly unlocked achievement keys.
  ///
  /// [collectedDogs] is the full list of collected dog names (used for
  /// rarity-specific counting). [allDogs] is the full dog catalogue
  /// (used for "collect all" milestones).
  ///
  /// [seasonalMultiplier] is the current seasonal event XP multiplier (1.0 if
  /// no event is active). [familyBonus] is the dog family mastery XP bonus
  /// (1.0 if no mastery earned).
  List<String> addXpForDog(
    Dog dog,
    int kennelCount, {
    List<Dog> collectedDogs = const [],
    List<Dog> allDogs = const [],
    double seasonalMultiplier = 1.0,
    double familyBonus = 1.0,
    double comboMultiplier = 1.0,
    double mysteryMultiplier = 1.0,
  }) {
    final oldLevel = state.level;
    var newLevel = state.level;
    // Apply all XP multipliers: streak + seasonal + family + combo + mystery
    final effectiveXp = (dog.xp * state.streakXpMultiplier * seasonalMultiplier * familyBonus * comboMultiplier * mysteryMultiplier).round();
    var newXp = state.xp + effectiveXp;

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
    if (kennelCount >= 1) tryUnlock('first_dog');
    if (kennelCount >= 5) tryUnlock('five_species');
    if (kennelCount >= 10) tryUnlock('ten_species');
    if (kennelCount >= 20) tryUnlock('twenty_species');
    if (kennelCount >= 50) tryUnlock('fifty_species');
    if (kennelCount >= 100) tryUnlock('hundred_species');
    if (kennelCount >= 200) tryUnlock('two_hundred_species');

    // ─── Rarity-specific collection ────────────────────────────────────
    if (dog.rarity == Rarity.rare || dog.rarity == Rarity.legendary) {
      tryUnlock('rare_find');
    }
    if (dog.rarity == Rarity.legendary) tryUnlock('legendary_find');

    // ─── Rarity badge achievements (first finds) ────────────────────
    if (dog.rarity == Rarity.uncommon) tryUnlock('first_uncommon');
    if (dog.rarity == Rarity.rare) tryUnlock('first_rare');
    if (dog.rarity == Rarity.legendary) tryUnlock('first_epic');

    if (collectedDogs.isNotEmpty) {
      final uncommonCount = collectedDogs.where((b) => b.rarity == Rarity.uncommon).length;
      final rareCount = collectedDogs.where((b) => b.rarity == Rarity.rare).length;
      final legendaryCount = collectedDogs.where((b) => b.rarity == Rarity.legendary).length;
      if (rareCount >= 5) tryUnlock('five_rare');
      if (legendaryCount >= 5) tryUnlock('five_legendary');

      // ─── Rarity badge achievements (ten milestones) ─────────────
      if (uncommonCount >= 10) tryUnlock('ten_uncommon');
      if (rareCount >= 10) tryUnlock('ten_rare');

      // "Collect all" milestones
      if (allDogs.isNotEmpty) {
        final totalCommon = allDogs.where((b) => b.rarity == Rarity.common).length;
        final collectedCommon = collectedDogs.where((b) => b.rarity == Rarity.common).length;
        if (collectedCommon >= totalCommon && totalCommon > 0) tryUnlock('all_common');

        final totalUncommon = allDogs.where((b) => b.rarity == Rarity.uncommon).length;
        final collectedUncommon = collectedDogs.where((b) => b.rarity == Rarity.uncommon).length;
        if (collectedUncommon >= totalUncommon && totalUncommon > 0) tryUnlock('all_uncommon');

        final totalRare = allDogs.where((b) => b.rarity == Rarity.rare).length;
        final collectedRare = collectedDogs.where((b) => b.rarity == Rarity.rare).length;
        if (collectedRare >= totalRare && totalRare > 0) tryUnlock('all_rare');
      }

      // Conservation achievements
      final hasEndangered = collectedDogs.any((b) =>
          b.conservationStatus == 'Endangered' ||
          b.conservationStatus == 'Critically Endangered');
      if (hasEndangered) tryUnlock('endangered_spotter');

      final threatenedCount = collectedDogs.where((b) =>
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
