import 'package:flutter_test/flutter_test.dart';
import 'package:aviquest/services/player_service.dart';

void main() {
  group('PlayerState', () {
    test('default values are correct', () {
      const state = PlayerState();
      expect(state.level, 1);
      expect(state.xp, 0);
      expect(state.streak, 0);
      expect(state.bestStreak, 0);
      expect(state.streakSavers, 0);
      expect(state.unlockedAchievements, isEmpty);
      expect(state.quizzesCompleted, 0);
      expect(state.quizPerfectScores, 0);
      expect(state.totalSightings, 0);
    });

    test('copyWith preserves unchanged fields', () {
      const original = PlayerState(
        level: 5,
        xp: 100,
        streak: 3,
        bestStreak: 7,
        streakSavers: 2,
        quizzesCompleted: 2,
        quizPerfectScores: 1,
        totalSightings: 10,
      );
      final updated = original.copyWith(level: 6);
      expect(updated.level, 6);
      expect(updated.xp, 100);
      expect(updated.streak, 3);
      expect(updated.bestStreak, 7);
      expect(updated.streakSavers, 2);
      expect(updated.quizzesCompleted, 2);
      expect(updated.totalSightings, 10);
    });

    test('title progression is correct', () {
      expect(const PlayerState(level: 1).title, 'Fledgling');
      expect(const PlayerState(level: 2).title, 'Fledgling');
      expect(const PlayerState(level: 3).title, 'Nestling');
      expect(const PlayerState(level: 6).title, 'Sparrow');
      expect(const PlayerState(level: 10).title, 'Warbler');
      expect(const PlayerState(level: 15).title, 'Songweaver');
      expect(const PlayerState(level: 20).title, 'Falconer');
      expect(const PlayerState(level: 30).title, 'Eagle Scout');
      expect(const PlayerState(level: 40).title, 'Master Birder');
    });

    test('xpForNextLevel increases with level', () {
      final level1 = const PlayerState(level: 1).xpForNextLevel;
      final level5 = const PlayerState(level: 5).xpForNextLevel;
      final level10 = const PlayerState(level: 10).xpForNextLevel;
      expect(level5, greaterThan(level1));
      expect(level10, greaterThan(level5));
    });

    test('xpProgress is clamped between 0 and 1', () {
      expect(const PlayerState(level: 1, xp: 0).xpProgress, 0.0);
      expect(const PlayerState(level: 1, xp: 500).xpProgress, greaterThan(0.0));
      expect(const PlayerState(level: 1, xp: 500).xpProgress, lessThanOrEqualTo(1.0));
    });
  });

  group('Streak XP multiplier', () {
    test('no bonus for streak <= 2', () {
      expect(const PlayerState(streak: 0).streakXpMultiplier, 1.0);
      expect(const PlayerState(streak: 1).streakXpMultiplier, 1.0);
      expect(const PlayerState(streak: 2).streakXpMultiplier, 1.0);
    });

    test('bonus starts at day 3', () {
      expect(const PlayerState(streak: 3).streakXpMultiplier, 1.1);
    });

    test('bonus scales by 10% per day', () {
      expect(const PlayerState(streak: 4).streakXpMultiplier, 1.2);
      expect(const PlayerState(streak: 5).streakXpMultiplier, closeTo(1.3, 0.01));
      expect(const PlayerState(streak: 7).streakXpMultiplier, closeTo(1.5, 0.01));
    });

    test('bonus caps at 2.0x (day 12+)', () {
      expect(const PlayerState(streak: 12).streakXpMultiplier, 2.0);
      expect(const PlayerState(streak: 20).streakXpMultiplier, 2.0);
      expect(const PlayerState(streak: 100).streakXpMultiplier, 2.0);
    });
  });

  group('Best streak and streak savers', () {
    test('bestStreak tracks via copyWith', () {
      const state = PlayerState(streak: 5, bestStreak: 10);
      expect(state.bestStreak, 10);
      final updated = state.copyWith(bestStreak: 12);
      expect(updated.bestStreak, 12);
    });

    test('streakSavers tracks via copyWith', () {
      const state = PlayerState(streakSavers: 2);
      expect(state.streakSavers, 2);
      final updated = state.copyWith(streakSavers: 1);
      expect(updated.streakSavers, 1);
    });
  });
}
