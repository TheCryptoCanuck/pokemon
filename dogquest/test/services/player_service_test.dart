import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dogquest/constants.dart';
import 'package:dogquest/models/dog.dart';
import 'package:dogquest/services/player_service.dart';
import 'package:dogquest/helpers/date_helpers.dart';

// ---------------------------------------------------------------------------
// Mock Hive Box
// ---------------------------------------------------------------------------

class MockBox extends Mock implements Box {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Returns a [MockBox] pre-configured with the given key/value overrides.
/// Any key not listed falls back to [defaultValue] as Hive would.
MockBox buildBox({
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
  String lastActiveDate = '',
}) {
  final box = MockBox();

  // Set up the generic get() to return sensible defaults.
  // Individual keys are handled first via when(...).
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
  ).thenReturn(lastActiveDate);

  // Writes are fire-and-forget; ignore them.
  when(() => box.put(any(), any())).thenAnswer((_) async {});
  when(() => box.putAll(any())).thenAnswer((_) async {});

  return box;
}

/// Convenience: creates a [Dog] with sensible defaults.
Dog makeDog({
  String name = 'Labrador',
  Rarity rarity = Rarity.common,
  int baseXp = 20,
  String conservationStatus = 'Least Concern',
}) {
  return Dog(
    name: name,
    scientificName: '',
    imageUrl: '',
    audioUrl: '',
    lore: '',
    habitat: '',
    conservationStatus: conservationStatus,
    rarity: rarity,
    baseXp: baseXp,
  );
}

/// Returns a [PlayerNotifier] whose internal Box was pre-seeded to simulate
/// "already logged in today" so that _updateStreak() is a no-op.
PlayerNotifier buildNotifier({
  MockBox? box,
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
}) {
  final todayKey = formatDateKey(DateTime.now());
  final b = box ??
      buildBox(
        level: level,
        xp: xp,
        streak: streak,
        bestStreak: bestStreak,
        streakSavers: streakSavers,
        achievements: achievements,
        quizzesCompleted: quizzesCompleted,
        quizPerfectScores: quizPerfectScores,
        totalSightings: totalSightings,
        selectedAvatar: selectedAvatar,
        lastActiveDate: todayKey, // prevents streak mutation
      );
  return PlayerNotifier(b);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // PlayerState — computed properties
  // =========================================================================

  group('PlayerState.title', () {
    PlayerState stateAtLevel(int lvl) =>
        const PlayerState().copyWith(level: lvl);

    test('level 1 → Puppy', () {
      expect(stateAtLevel(1).title, 'Puppy');
    });

    test('level 2 → Puppy', () {
      expect(stateAtLevel(2).title, 'Puppy');
    });

    test('level 3 → Good Boy', () {
      expect(stateAtLevel(3).title, 'Good Boy');
    });

    test('level 5 → Good Boy', () {
      expect(stateAtLevel(5).title, 'Good Boy');
    });

    test('level 6 → Pack Member', () {
      expect(stateAtLevel(6).title, 'Pack Member');
    });

    test('level 9 → Pack Member', () {
      expect(stateAtLevel(9).title, 'Pack Member');
    });

    test('level 10 → Breed Spotter', () {
      expect(stateAtLevel(10).title, 'Breed Spotter');
    });

    test('level 14 → Breed Spotter', () {
      expect(stateAtLevel(14).title, 'Breed Spotter');
    });

    test('level 15 → Dog Whisperer', () {
      expect(stateAtLevel(15).title, 'Dog Whisperer');
    });

    test('level 19 → Dog Whisperer', () {
      expect(stateAtLevel(19).title, 'Dog Whisperer');
    });

    test('level 20 → Expert Handler', () {
      expect(stateAtLevel(20).title, 'Expert Handler');
    });

    test('level 29 → Expert Handler', () {
      expect(stateAtLevel(29).title, 'Expert Handler');
    });

    test('level 30 → Show Judge', () {
      expect(stateAtLevel(30).title, 'Show Judge');
    });

    test('level 39 → Show Judge', () {
      expect(stateAtLevel(39).title, 'Show Judge');
    });

    test('level 40 → Best in Show', () {
      expect(stateAtLevel(40).title, 'Best in Show');
    });

    test('level 100 → Best in Show', () {
      expect(stateAtLevel(100).title, 'Best in Show');
    });
  });

  // -------------------------------------------------------------------------

  group('PlayerState.xpForNextLevel', () {
    test('level 1 formula: (1000 * 1^1.4).round() = 1000', () {
      const state = PlayerState(level: 1);
      expect(state.xpForNextLevel, (1000 * pow(1, 1.4)).round());
    });

    test('level 5 formula', () {
      const state = PlayerState(level: 5);
      expect(state.xpForNextLevel, (1000 * pow(5, 1.4)).round());
    });

    test('level 10 formula', () {
      const state = PlayerState(level: 10);
      expect(state.xpForNextLevel, (1000 * pow(10, 1.4)).round());
    });

    test('xpForNextLevel increases with level', () {
      final l1 = const PlayerState(level: 1).xpForNextLevel;
      final l5 = const PlayerState(level: 5).xpForNextLevel;
      final l10 = const PlayerState(level: 10).xpForNextLevel;
      expect(l5 > l1, isTrue);
      expect(l10 > l5, isTrue);
    });
  });

  // -------------------------------------------------------------------------

  group('PlayerState.xpProgress', () {
    test('0 xp → 0.0 progress', () {
      const state = PlayerState(level: 1, xp: 0);
      expect(state.xpProgress, 0.0);
    });

    test('xp == xpForNextLevel → 1.0', () {
      final threshold = const PlayerState(level: 1).xpForNextLevel;
      final state = PlayerState(level: 1, xp: threshold);
      expect(state.xpProgress, 1.0);
    });

    test('progress is clamped below 1.0 even when xp exceeds threshold', () {
      final threshold = const PlayerState(level: 1).xpForNextLevel;
      final state = PlayerState(level: 1, xp: threshold * 2);
      expect(state.xpProgress, 1.0);
    });

    test('half xp → approximately 0.5 progress', () {
      final threshold = const PlayerState(level: 1).xpForNextLevel;
      final state = PlayerState(level: 1, xp: threshold ~/ 2);
      expect(state.xpProgress, closeTo(0.5, 0.01));
    });

    test('progress is never negative', () {
      const state = PlayerState(level: 1, xp: 0);
      expect(state.xpProgress, greaterThanOrEqualTo(0.0));
    });
  });

  // -------------------------------------------------------------------------

  group('PlayerState.streakXpMultiplier', () {
    PlayerState withStreak(int s) => PlayerState(streak: s);

    test('streak 0 → 1.0 (no bonus)', () {
      expect(withStreak(0).streakXpMultiplier, 1.0);
    });

    test('streak 1 → 1.0 (no bonus)', () {
      expect(withStreak(1).streakXpMultiplier, 1.0);
    });

    test('streak 2 → 1.0 (threshold is exclusive)', () {
      expect(withStreak(2).streakXpMultiplier, 1.0);
    });

    test('streak 3 → 1.1 (+10%)', () {
      expect(withStreak(3).streakXpMultiplier, closeTo(1.1, 0.001));
    });

    test('streak 4 → 1.2 (+20%)', () {
      expect(withStreak(4).streakXpMultiplier, closeTo(1.2, 0.001));
    });

    test('streak 7 → 1.5 (+50%)', () {
      expect(withStreak(7).streakXpMultiplier, closeTo(1.5, 0.001));
    });

    test('streak 12 → 2.0 (capped at +100%, i.e. day 10 bonus)', () {
      // The bonus uses (streak-2).clamp(0,10), so streak 12 → clamp(10,10) → 1.0
      expect(withStreak(12).streakXpMultiplier, closeTo(2.0, 0.001));
    });

    test('streak 50 → 2.0 (cap still applies)', () {
      expect(withStreak(50).streakXpMultiplier, closeTo(2.0, 0.001));
    });
  });

  // =========================================================================
  // PlayerState.copyWith
  // =========================================================================

  group('PlayerState.copyWith', () {
    const base = PlayerState(
      level: 3,
      xp: 500,
      streak: 5,
      bestStreak: 7,
      streakSavers: 1,
      unlockedAchievements: {'first_dog'},
      quizzesCompleted: 2,
      quizPerfectScores: 1,
      totalSightings: 10,
      selectedAvatar: 'good_boy',
    );

    test('returns identical state when no overrides provided', () {
      final copy = base.copyWith();
      expect(copy.level, base.level);
      expect(copy.xp, base.xp);
      expect(copy.streak, base.streak);
      expect(copy.bestStreak, base.bestStreak);
      expect(copy.streakSavers, base.streakSavers);
      expect(copy.unlockedAchievements, base.unlockedAchievements);
      expect(copy.quizzesCompleted, base.quizzesCompleted);
      expect(copy.quizPerfectScores, base.quizPerfectScores);
      expect(copy.totalSightings, base.totalSightings);
      expect(copy.selectedAvatar, base.selectedAvatar);
    });

    test('overrides only specified fields', () {
      final copy = base.copyWith(level: 10, xp: 0);
      expect(copy.level, 10);
      expect(copy.xp, 0);
      // unchanged
      expect(copy.streak, base.streak);
      expect(copy.selectedAvatar, base.selectedAvatar);
    });

    test('can update unlockedAchievements independently', () {
      final copy =
          base.copyWith(unlockedAchievements: {'first_dog', 'five_species'});
      expect(copy.unlockedAchievements, {'first_dog', 'five_species'});
      expect(copy.level, base.level);
    });

    test('copyWith does not mutate original', () {
      base.copyWith(level: 99, xp: 9999);
      expect(base.level, 3);
      expect(base.xp, 500);
    });
  });

  // =========================================================================
  // PlayerNotifier._load — state initialisation from Hive
  // =========================================================================

  group('PlayerNotifier initialisation', () {
    test('loads persisted values from box', () {
      final notifier = buildNotifier(
        level: 5,
        xp: 300,
        streak: 4,
        bestStreak: 8,
        streakSavers: 2,
        achievements: ['first_dog', 'five_species'],
        quizzesCompleted: 3,
        quizPerfectScores: 1,
        totalSightings: 15,
        selectedAvatar: 'guard_dog',
      );

      expect(notifier.state.level, 5);
      expect(notifier.state.xp, 300);
      expect(notifier.state.streak, 4);
      expect(notifier.state.bestStreak, 8);
      expect(notifier.state.streakSavers, 2);
      expect(
        notifier.state.unlockedAchievements,
        {'first_dog', 'five_species'},
      );
      expect(notifier.state.quizzesCompleted, 3);
      expect(notifier.state.quizPerfectScores, 1);
      expect(notifier.state.totalSightings, 15);
      expect(notifier.state.selectedAvatar, 'guard_dog');
    });

    test('defaults to level 1, xp 0 when box is empty', () {
      final notifier = buildNotifier();
      expect(notifier.state.level, 1);
      expect(notifier.state.xp, 0);
      expect(notifier.state.streak, 0);
      expect(notifier.state.unlockedAchievements, isEmpty);
      expect(notifier.state.selectedAvatar, 'default');
    });
  });

  // =========================================================================
  // awardBonusXp
  // =========================================================================

  group('PlayerNotifier.awardBonusXp', () {
    test('adds XP to current state', () {
      final notifier = buildNotifier(xp: 100);
      notifier.awardBonusXp(50);
      expect(notifier.state.xp, 150);
    });

    test('ignores zero amount', () {
      final notifier = buildNotifier(xp: 100);
      notifier.awardBonusXp(0);
      expect(notifier.state.xp, 100);
    });

    test('ignores negative amount', () {
      final notifier = buildNotifier(xp: 100);
      notifier.awardBonusXp(-50);
      expect(notifier.state.xp, 100);
    });

    test('accumulates across multiple calls', () {
      final notifier = buildNotifier(xp: 0);
      notifier.awardBonusXp(100);
      notifier.awardBonusXp(200);
      expect(notifier.state.xp, 300);
    });

    test('persists to box (putAll called)', () {
      final box = buildBox();
      final notifier = PlayerNotifier(box);
      notifier.awardBonusXp(99);
      verify(() => box.putAll(any())).called(greaterThan(0));
    });
  });

  // =========================================================================
  // addXpForDog — XP calculation
  // =========================================================================

  group('PlayerNotifier.addXpForDog — XP calculation', () {
    test('awards dog.xp (common baseXp) at streak ≤ 2 (multiplier 1.0)', () {
      final notifier = buildNotifier(xp: 0, streak: 0);
      final dog = makeDog(baseXp: 20, rarity: Rarity.common);
      notifier.addXpForDog(dog, 1);
      expect(notifier.state.xp, 20);
    });

    test('uncommon dog xp = baseXp * 1.5', () {
      final notifier = buildNotifier(xp: 0, streak: 0);
      final dog = makeDog(baseXp: 20, rarity: Rarity.uncommon);
      // dog.xp = (20 * 1.5).round() = 30
      notifier.addXpForDog(dog, 1);
      expect(notifier.state.xp, 30);
    });

    test('rare dog xp = baseXp * 2', () {
      final notifier = buildNotifier(xp: 0, streak: 0);
      final dog = makeDog(baseXp: 20, rarity: Rarity.rare);
      notifier.addXpForDog(dog, 1);
      expect(notifier.state.xp, 40);
    });

    test('legendary dog xp = baseXp * 5', () {
      final notifier = buildNotifier(xp: 0, streak: 0);
      final dog = makeDog(baseXp: 20, rarity: Rarity.legendary);
      notifier.addXpForDog(dog, 1);
      expect(notifier.state.xp, 100);
    });

    test('streak multiplier applied (streak 7 → 1.5x)', () {
      final notifier = buildNotifier(xp: 0, streak: 7);
      final dog = makeDog(baseXp: 20, rarity: Rarity.common);
      // effectiveXp = (20 * 1.5).round() = 30
      notifier.addXpForDog(dog, 1);
      expect(notifier.state.xp, (20 * 1.5).round());
    });

    test('comboMultiplier doubles the XP', () {
      final notifier = buildNotifier(xp: 0, streak: 0);
      final dog = makeDog(baseXp: 20, rarity: Rarity.common);
      notifier.addXpForDog(dog, 1, comboMultiplier: 2.0);
      expect(notifier.state.xp, (20 * 2.0).round());
    });

    test('seasonalMultiplier is applied', () {
      final notifier = buildNotifier(xp: 0, streak: 0);
      final dog = makeDog(baseXp: 20, rarity: Rarity.common);
      notifier.addXpForDog(dog, 1, seasonalMultiplier: 1.5);
      expect(notifier.state.xp, (20 * 1.5).round());
    });

    test('familyBonus is applied', () {
      final notifier = buildNotifier(xp: 0, streak: 0);
      final dog = makeDog(baseXp: 20, rarity: Rarity.common);
      notifier.addXpForDog(dog, 1, familyBonus: 2.0);
      expect(notifier.state.xp, (20 * 2.0).round());
    });

    test('mysteryMultiplier is applied', () {
      final notifier = buildNotifier(xp: 0, streak: 0);
      final dog = makeDog(baseXp: 20, rarity: Rarity.common);
      notifier.addXpForDog(dog, 1, mysteryMultiplier: 3.0);
      expect(notifier.state.xp, (20 * 3.0).round());
    });

    test('all multipliers stack multiplicatively', () {
      final notifier = buildNotifier(xp: 0, streak: 7); // streak → 1.5x
      final dog = makeDog(baseXp: 20, rarity: Rarity.common);
      notifier.addXpForDog(
        dog,
        1,
        comboMultiplier: 2.0,
        seasonalMultiplier: 1.5,
        familyBonus: 1.25,
        mysteryMultiplier: 1.0,
      );
      final expected = (20 * 1.5 * 1.5 * 1.25 * 2.0 * 1.0).round();
      expect(notifier.state.xp, expected);
    });

    test('XP accumulates across multiple calls', () {
      final notifier = buildNotifier(xp: 0, streak: 0);
      final dog = makeDog(baseXp: 20);
      notifier.addXpForDog(dog, 1);
      notifier.addXpForDog(dog, 2);
      expect(notifier.state.xp, 40);
    });
  });

  // =========================================================================
  // addXpForDog — level-up logic
  // =========================================================================

  group('PlayerNotifier.addXpForDog — level-up', () {
    test('level does not increase when XP stays below threshold', () {
      final notifier = buildNotifier(level: 1, xp: 0, streak: 0);
      final dog = makeDog(baseXp: 20);
      notifier.addXpForDog(dog, 1);
      expect(notifier.state.level, 1);
    });

    test('level increases when XP crosses threshold', () {
      // Level 1 threshold = (1000 * 1^1.4).round() = 1000
      // Give the notifier 990 XP, then add 20 more → crosses 1000 → level 2
      final notifier = buildNotifier(level: 1, xp: 990, streak: 0);
      final dog = makeDog(baseXp: 20);
      notifier.addXpForDog(dog, 1);
      expect(notifier.state.level, 2);
    });

    test('XP is carried over after level-up', () {
      final threshold1 = (1000 * pow(1, 1.4)).round();
      final notifier = buildNotifier(level: 1, xp: threshold1 - 5, streak: 0);
      final dog = makeDog(baseXp: 20);
      notifier.addXpForDog(dog, 1);
      // Carried-over XP = 20 - 5 = 15
      expect(notifier.state.xp, 15);
    });

    test('multiple level-ups in a single call', () {
      // Start at level 1 with 0 XP. Award enough for levels 1 and 2.
      final threshold1 = (1000 * pow(1, 1.4)).round();
      final threshold2 = (1000 * pow(2, 1.4)).round();
      final totalNeeded = threshold1 + threshold2 + 1;
      final notifier = buildNotifier(level: 1, xp: 0, streak: 0);
      // Use awardBonusXp to pre-set XP without going through level-up logic,
      // then trigger the final addXpForDog call.
      notifier.awardBonusXp(totalNeeded - 1);
      final dog = makeDog(baseXp: 2);
      notifier.addXpForDog(dog, 1);
      expect(notifier.state.level, greaterThanOrEqualTo(3));
    });

    test('level_5 achievement unlocked on level-up to 5', () {
      // Calculate XP needed to be one dog-award away from level 5.
      int totalThreshold = 0;
      for (int lvl = 1; lvl < 5; lvl++) {
        totalThreshold += (1000 * pow(lvl, 1.4)).round();
      }
      final notifier = buildNotifier(level: 1, xp: 0, streak: 0);
      notifier.awardBonusXp(totalThreshold - 10);
      final dog = makeDog(baseXp: 20);
      final unlocked = notifier.addXpForDog(dog, 1);
      expect(notifier.state.level, greaterThanOrEqualTo(5));
      expect(unlocked, contains('level_5'));
    });
  });

  // =========================================================================
  // addXpForDog — achievement unlocking (collection milestones)
  // =========================================================================

  group('PlayerNotifier.addXpForDog — collection milestones', () {
    test('first_dog unlocked at kennelCount == 1', () {
      final notifier = buildNotifier();
      final dog = makeDog();
      final unlocked = notifier.addXpForDog(dog, 1);
      expect(unlocked, contains('first_dog'));
    });

    test('first_dog NOT unlocked when kennelCount == 0', () {
      final notifier = buildNotifier();
      final dog = makeDog();
      final unlocked = notifier.addXpForDog(dog, 0);
      expect(unlocked, isNot(contains('first_dog')));
    });

    test('five_species unlocked at kennelCount == 5', () {
      final notifier = buildNotifier();
      final unlocked = notifier.addXpForDog(makeDog(), 5);
      expect(unlocked, contains('five_species'));
    });

    test('ten_species unlocked at kennelCount == 10', () {
      final notifier = buildNotifier();
      final unlocked = notifier.addXpForDog(makeDog(), 10);
      expect(unlocked, contains('ten_species'));
    });

    test('twenty_species unlocked at kennelCount == 20', () {
      final notifier = buildNotifier();
      final unlocked = notifier.addXpForDog(makeDog(), 20);
      expect(unlocked, contains('twenty_species'));
    });

    test('fifty_species unlocked at kennelCount == 50', () {
      final notifier = buildNotifier();
      final unlocked = notifier.addXpForDog(makeDog(), 50);
      expect(unlocked, contains('fifty_species'));
    });

    test('hundred_species unlocked at kennelCount == 100', () {
      final notifier = buildNotifier();
      final unlocked = notifier.addXpForDog(makeDog(), 100);
      expect(unlocked, contains('hundred_species'));
    });

    test('two_hundred_species unlocked at kennelCount == 200', () {
      final notifier = buildNotifier();
      final unlocked = notifier.addXpForDog(makeDog(), 200);
      expect(unlocked, contains('two_hundred_species'));
    });

    test('already-unlocked achievements are not returned again', () {
      final notifier = buildNotifier(achievements: ['first_dog']);
      final unlocked = notifier.addXpForDog(makeDog(), 1);
      expect(unlocked, isNot(contains('first_dog')));
    });

    test('achievement stays in unlockedAchievements after unlock', () {
      final notifier = buildNotifier();
      notifier.addXpForDog(makeDog(), 1);
      expect(notifier.state.unlockedAchievements, contains('first_dog'));
    });
  });

  // =========================================================================
  // addXpForDog — achievement unlocking (rarity finds)
  // =========================================================================

  group('PlayerNotifier.addXpForDog — rarity achievements', () {
    test('rare_find unlocked for rare dog', () {
      final notifier = buildNotifier();
      final unlocked = notifier.addXpForDog(makeDog(rarity: Rarity.rare), 1);
      expect(unlocked, contains('rare_find'));
    });

    test('rare_find unlocked for legendary dog', () {
      final notifier = buildNotifier();
      final unlocked =
          notifier.addXpForDog(makeDog(rarity: Rarity.legendary), 1);
      expect(unlocked, contains('rare_find'));
    });

    test('rare_find NOT unlocked for common dog', () {
      final notifier = buildNotifier();
      final unlocked = notifier.addXpForDog(makeDog(rarity: Rarity.common), 1);
      expect(unlocked, isNot(contains('rare_find')));
    });

    test('legendary_find unlocked for legendary dog', () {
      final notifier = buildNotifier();
      final unlocked =
          notifier.addXpForDog(makeDog(rarity: Rarity.legendary), 1);
      expect(unlocked, contains('legendary_find'));
    });

    test('legendary_find NOT unlocked for rare dog', () {
      final notifier = buildNotifier();
      final unlocked = notifier.addXpForDog(makeDog(rarity: Rarity.rare), 1);
      expect(unlocked, isNot(contains('legendary_find')));
    });

    test('five_rare unlocked when collectedDogs has 5+ rare', () {
      final notifier = buildNotifier();
      final rares = List.generate(5, (_) => makeDog(rarity: Rarity.rare));
      final unlocked = notifier.addXpForDog(
        makeDog(rarity: Rarity.rare),
        6,
        collectedDogs: rares,
      );
      expect(unlocked, contains('five_rare'));
    });

    test('five_rare NOT unlocked with only 4 rare dogs', () {
      final notifier = buildNotifier();
      final rares = List.generate(4, (_) => makeDog(rarity: Rarity.rare));
      final unlocked = notifier.addXpForDog(
        makeDog(rarity: Rarity.rare),
        5,
        collectedDogs: rares,
      );
      expect(unlocked, isNot(contains('five_rare')));
    });

    test('five_legendary unlocked when collectedDogs has 5+ legendary', () {
      final notifier = buildNotifier();
      final legends =
          List.generate(5, (_) => makeDog(rarity: Rarity.legendary));
      final unlocked = notifier.addXpForDog(
        makeDog(rarity: Rarity.legendary),
        6,
        collectedDogs: legends,
      );
      expect(unlocked, contains('five_legendary'));
    });
  });

  // =========================================================================
  // addXpForDog — achievement unlocking (level milestones via direct state)
  // =========================================================================

  group('PlayerNotifier.addXpForDog — level milestones', () {
    // We seed the notifier at a level just below the milestone and push over.

    void testLevelMilestone(int targetLevel, String achievement) {
      test('$achievement unlocked when reaching level $targetLevel', () {
        // Accumulate thresholds for levels 1 through targetLevel-1
        int totalThreshold = 0;
        for (int lvl = 1; lvl < targetLevel; lvl++) {
          totalThreshold += (1000 * pow(lvl, 1.4)).round();
        }
        final notifier = buildNotifier(level: 1, xp: 0, streak: 0);
        notifier.awardBonusXp(totalThreshold - 10);
        final unlocked = notifier.addXpForDog(makeDog(baseXp: 20), 1);
        expect(notifier.state.level, greaterThanOrEqualTo(targetLevel));
        expect(unlocked, contains(achievement));
      });
    }

    testLevelMilestone(5, 'level_5');
    testLevelMilestone(10, 'level_10');
    testLevelMilestone(20, 'level_20');
    testLevelMilestone(30, 'level_30');
  });

  // =========================================================================
  // addXpForDog — achievement unlocking (streak milestones)
  // =========================================================================

  group('PlayerNotifier.addXpForDog — streak milestones', () {
    test('streak_3 unlocked when streak >= 3', () {
      final notifier = buildNotifier(streak: 3);
      final unlocked = notifier.addXpForDog(makeDog(), 1);
      expect(unlocked, contains('streak_3'));
    });

    test('streak_3 NOT unlocked when streak < 3', () {
      final notifier = buildNotifier(streak: 2);
      final unlocked = notifier.addXpForDog(makeDog(), 1);
      expect(unlocked, isNot(contains('streak_3')));
    });

    test('streak_7 unlocked when streak >= 7', () {
      final notifier = buildNotifier(streak: 7);
      final unlocked = notifier.addXpForDog(makeDog(), 1);
      expect(unlocked, contains('streak_7'));
    });

    test('streak_30 unlocked when streak >= 30', () {
      final notifier = buildNotifier(streak: 30);
      final unlocked = notifier.addXpForDog(makeDog(), 1);
      expect(unlocked, contains('streak_30'));
    });

    test('streak_7 and streak_30 both unlocked when streak == 30', () {
      final notifier = buildNotifier(streak: 30);
      final unlocked = notifier.addXpForDog(makeDog(), 1);
      expect(unlocked, containsAll(['streak_3', 'streak_7', 'streak_30']));
    });
  });

  // =========================================================================
  // addXpForDog — "collect all" milestones
  // =========================================================================

  group('PlayerNotifier.addXpForDog — collect-all milestones', () {
    test('all_common unlocked when all common dogs collected', () {
      final allDogs = [
        makeDog(name: 'A', rarity: Rarity.common),
        makeDog(name: 'B', rarity: Rarity.common),
      ];
      final notifier = buildNotifier();
      final unlocked = notifier.addXpForDog(
        makeDog(rarity: Rarity.common),
        1,
        collectedDogs: allDogs,
        allDogs: allDogs,
      );
      expect(unlocked, contains('all_common'));
    });

    test('all_common NOT unlocked when only some common dogs collected', () {
      final allDogs = [
        makeDog(name: 'A', rarity: Rarity.common),
        makeDog(name: 'B', rarity: Rarity.common),
        makeDog(name: 'C', rarity: Rarity.common),
      ];
      final collectedDogs = [makeDog(name: 'A', rarity: Rarity.common)];
      final notifier = buildNotifier();
      final unlocked = notifier.addXpForDog(
        makeDog(rarity: Rarity.common),
        1,
        collectedDogs: collectedDogs,
        allDogs: allDogs,
      );
      expect(unlocked, isNot(contains('all_common')));
    });

    test('all_uncommon unlocked when all uncommon dogs collected', () {
      final allDogs = [
        makeDog(name: 'X', rarity: Rarity.uncommon),
      ];
      final notifier = buildNotifier();
      final unlocked = notifier.addXpForDog(
        makeDog(rarity: Rarity.uncommon),
        1,
        collectedDogs: allDogs,
        allDogs: allDogs,
      );
      expect(unlocked, contains('all_uncommon'));
    });
  });

  // =========================================================================
  // addXpForDog — conservation achievements
  // =========================================================================

  group('PlayerNotifier.addXpForDog — conservation achievements', () {
    test('endangered_spotter unlocked when a collected dog is Endangered', () {
      final collectedDogs = [makeDog(conservationStatus: 'Endangered')];
      final notifier = buildNotifier();
      final unlocked = notifier.addXpForDog(
        makeDog(),
        1,
        collectedDogs: collectedDogs,
      );
      expect(unlocked, contains('endangered_spotter'));
    });

    test('endangered_spotter unlocked for Critically Endangered', () {
      final collectedDogs = [
        makeDog(conservationStatus: 'Critically Endangered'),
      ];
      final notifier = buildNotifier();
      final unlocked =
          notifier.addXpForDog(makeDog(), 1, collectedDogs: collectedDogs);
      expect(unlocked, contains('endangered_spotter'));
    });

    test('endangered_spotter NOT unlocked for Least Concern', () {
      final collectedDogs = [makeDog(conservationStatus: 'Least Concern')];
      final notifier = buildNotifier();
      final unlocked =
          notifier.addXpForDog(makeDog(), 1, collectedDogs: collectedDogs);
      expect(unlocked, isNot(contains('endangered_spotter')));
    });

    test('conservation_hero unlocked with 5+ threatened dogs', () {
      final threatened = List.generate(
        5,
        (_) => makeDog(conservationStatus: 'Vulnerable'),
      );
      final notifier = buildNotifier();
      final unlocked =
          notifier.addXpForDog(makeDog(), 1, collectedDogs: threatened);
      expect(unlocked, contains('conservation_hero'));
    });

    test('conservation_hero NOT unlocked with fewer than 5 threatened dogs',
        () {
      final threatened = List.generate(
        4,
        (_) => makeDog(conservationStatus: 'Vulnerable'),
      );
      final notifier = buildNotifier();
      final unlocked =
          notifier.addXpForDog(makeDog(), 1, collectedDogs: threatened);
      expect(unlocked, isNot(contains('conservation_hero')));
    });
  });

  // =========================================================================
  // recordQuiz
  // =========================================================================

  group('PlayerNotifier.recordQuiz', () {
    test('increments quizzesCompleted', () {
      final notifier = buildNotifier(quizzesCompleted: 0);
      notifier.recordQuiz(3, 5);
      expect(notifier.state.quizzesCompleted, 1);
    });

    test('increments quizPerfectScores on perfect score', () {
      final notifier = buildNotifier(quizPerfectScores: 0);
      notifier.recordQuiz(5, 5);
      expect(notifier.state.quizPerfectScores, 1);
    });

    test('does not increment quizPerfectScores on imperfect score', () {
      final notifier = buildNotifier(quizPerfectScores: 0);
      notifier.recordQuiz(4, 5);
      expect(notifier.state.quizPerfectScores, 0);
    });

    test('first_quiz unlocked after first quiz', () {
      final notifier = buildNotifier();
      final unlocked = notifier.recordQuiz(3, 5);
      expect(unlocked, contains('first_quiz'));
    });

    test('first_quiz NOT re-unlocked on subsequent quizzes', () {
      final notifier = buildNotifier(
        quizzesCompleted: 1,
        achievements: ['first_quiz'],
      );
      final unlocked = notifier.recordQuiz(3, 5);
      expect(unlocked, isNot(contains('first_quiz')));
    });

    test('ten_quizzes unlocked when quizzesCompleted reaches 10', () {
      final notifier = buildNotifier(quizzesCompleted: 9);
      final unlocked = notifier.recordQuiz(3, 5);
      expect(unlocked, contains('ten_quizzes'));
    });

    test('ten_quizzes NOT unlocked before 10 quizzes', () {
      final notifier = buildNotifier(quizzesCompleted: 8);
      final unlocked = notifier.recordQuiz(3, 5);
      expect(unlocked, isNot(contains('ten_quizzes')));
    });

    test('perfect_quiz unlocked on first perfect score', () {
      final notifier = buildNotifier();
      final unlocked = notifier.recordQuiz(5, 5);
      expect(unlocked, contains('perfect_quiz'));
    });

    test('perfect_quiz NOT unlocked on imperfect score', () {
      final notifier = buildNotifier();
      final unlocked = notifier.recordQuiz(4, 5);
      expect(unlocked, isNot(contains('perfect_quiz')));
    });

    test('five_perfect unlocked when quizPerfectScores reaches 5', () {
      final notifier = buildNotifier(
        quizPerfectScores: 4,
        achievements: ['first_quiz', 'perfect_quiz'],
      );
      final unlocked = notifier.recordQuiz(5, 5);
      expect(unlocked, contains('five_perfect'));
    });

    test('five_perfect NOT unlocked before 5 perfect scores', () {
      final notifier = buildNotifier(quizPerfectScores: 3);
      final unlocked = notifier.recordQuiz(5, 5);
      expect(unlocked, isNot(contains('five_perfect')));
    });

    test('returns empty list when no new achievements', () {
      final notifier = buildNotifier(
        quizzesCompleted: 2,
        achievements: ['first_quiz'],
      );
      final unlocked = notifier.recordQuiz(3, 5);
      expect(unlocked, isEmpty);
    });

    test('persists to box after recording', () {
      final box = buildBox();
      final notifier = PlayerNotifier(box);
      notifier.recordQuiz(5, 5);
      verify(() => box.putAll(any())).called(greaterThan(0));
    });
  });

  // =========================================================================
  // recordSighting
  // =========================================================================

  group('PlayerNotifier.recordSighting', () {
    test('increments totalSightings by 1', () {
      final notifier = buildNotifier(totalSightings: 0);
      notifier.recordSighting();
      expect(notifier.state.totalSightings, 1);
    });

    test('accumulates across multiple calls', () {
      final notifier = buildNotifier(totalSightings: 10);
      notifier.recordSighting();
      notifier.recordSighting();
      notifier.recordSighting();
      expect(notifier.state.totalSightings, 13);
    });

    test('persists to box after recording', () {
      final box = buildBox();
      final notifier = PlayerNotifier(box);
      notifier.recordSighting();
      verify(() => box.putAll(any())).called(greaterThan(0));
    });
  });

  // =========================================================================
  // setAvatar
  // =========================================================================

  group('PlayerNotifier.setAvatar', () {
    test('updates selectedAvatar in state', () {
      final notifier = buildNotifier(selectedAvatar: 'default');
      notifier.setAvatar('guard_dog');
      expect(notifier.state.selectedAvatar, 'guard_dog');
    });

    test('subsequent setAvatar replaces previous value', () {
      final notifier = buildNotifier(selectedAvatar: 'default');
      notifier.setAvatar('guard_dog');
      notifier.setAvatar('bloodhound');
      expect(notifier.state.selectedAvatar, 'bloodhound');
    });

    test('persists to box', () {
      final box = buildBox();
      final notifier = PlayerNotifier(box);
      notifier.setAvatar('top_dog');
      verify(() => box.putAll(any())).called(greaterThan(0));
    });
  });

  // =========================================================================
  // _migrateAvatarId — legacy bird ID migration (via _load)
  // =========================================================================

  group('PlayerNotifier._migrateAvatarId (loaded from box)', () {
    String loadedAvatar(String storedId) {
      final box = buildBox(selectedAvatar: storedId);
      final notifier = PlayerNotifier(box);
      return notifier.state.selectedAvatar;
    }

    test('robin → good_boy', () {
      expect(loadedAvatar('robin'), 'good_boy');
    });

    test('owl → guard_dog', () {
      expect(loadedAvatar('owl'), 'guard_dog');
    });

    test('eagle → bloodhound', () {
      expect(loadedAvatar('eagle'), 'bloodhound');
    });

    test('parrot → show_champion', () {
      expect(loadedAvatar('parrot'), 'show_champion');
    });

    test('phoenix → top_dog', () {
      expect(loadedAvatar('phoenix'), 'top_dog');
    });

    test('modern ID passes through unchanged', () {
      expect(loadedAvatar('bloodhound'), 'bloodhound');
    });

    test('default passes through unchanged', () {
      expect(loadedAvatar('default'), 'default');
    });

    test('unknown legacy ID passes through unchanged', () {
      expect(loadedAvatar('mystery_dog'), 'mystery_dog');
    });
  });

  // =========================================================================
  // Streak multiplier integration — addXpForDog
  // =========================================================================

  group('Streak multiplier — boundary conditions', () {
    test('streak 0: multiplier is 1.0, XP unmodified', () {
      final notifier = buildNotifier(xp: 0, streak: 0);
      notifier.addXpForDog(makeDog(baseXp: 100), 1);
      expect(notifier.state.xp, 100);
    });

    test('streak 2: multiplier is still 1.0 (bonus starts at streak 3)', () {
      final notifier = buildNotifier(xp: 0, streak: 2);
      notifier.addXpForDog(makeDog(baseXp: 100), 1);
      expect(notifier.state.xp, 100);
    });

    test('streak 3: multiplier is 1.1, XP = 110', () {
      final notifier = buildNotifier(xp: 0, streak: 3);
      notifier.addXpForDog(makeDog(baseXp: 100), 1);
      expect(notifier.state.xp, (100 * 1.1).round());
    });

    test('streak 12: multiplier is capped at 2.0, XP = 200', () {
      final notifier = buildNotifier(xp: 0, streak: 12);
      notifier.addXpForDog(makeDog(baseXp: 100), 1);
      expect(notifier.state.xp, (100 * 2.0).round());
    });
  });

  // =========================================================================
  // addXpForDog — return value (newly unlocked list)
  // =========================================================================

  group('PlayerNotifier.addXpForDog — return value', () {
    test('returns empty list when no achievements unlocked', () {
      final notifier = buildNotifier(
        achievements: ['first_dog'],
      );
      // kennelCount 0 — no new collection milestones, common rarity, no streak
      final result = notifier.addXpForDog(makeDog(), 0);
      expect(result, isEmpty);
    });

    test('returns list of newly unlocked keys', () {
      final notifier = buildNotifier();
      final result = notifier.addXpForDog(makeDog(rarity: Rarity.legendary), 1);
      expect(result, containsAll(['first_dog', 'rare_find', 'legendary_find']));
    });

    test('does not include previously unlocked achievements in return', () {
      final notifier = buildNotifier(
        achievements: ['first_dog', 'rare_find', 'legendary_find'],
      );
      final result = notifier.addXpForDog(makeDog(rarity: Rarity.legendary), 1);
      for (final key in ['first_dog', 'rare_find', 'legendary_find']) {
        expect(result, isNot(contains(key)));
      }
    });
  });
}
