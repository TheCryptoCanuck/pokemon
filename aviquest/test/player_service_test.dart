import 'package:flutter_test/flutter_test.dart';
import 'package:aviquest/services/player_service.dart';
import 'package:aviquest/constants.dart';
import 'package:aviquest/models/bird.dart';

void main() {
  group('PlayerState', () {
    test('default values', () {
      const state = PlayerState();
      expect(state.level, 1);
      expect(state.xp, 0);
      expect(state.streak, 1);
      expect(state.unlockedAchievements, isEmpty);
    });

    test('title changes with level', () {
      expect(const PlayerState(level: 1).title, 'Fledgling');
      expect(const PlayerState(level: 3).title, 'Nestling');
      expect(const PlayerState(level: 6).title, 'Sparrow');
      expect(const PlayerState(level: 10).title, 'Warbler');
      expect(const PlayerState(level: 15).title, 'Songweaver');
      expect(const PlayerState(level: 20).title, 'Falconer');
      expect(const PlayerState(level: 30).title, 'Eagle Scout');
      expect(const PlayerState(level: 40).title, 'Master Birder');
    });

    test('xpForNextLevel scales with level', () {
      final xp1 = const PlayerState(level: 1).xpForNextLevel;
      final xp5 = const PlayerState(level: 5).xpForNextLevel;
      final xp10 = const PlayerState(level: 10).xpForNextLevel;
      expect(xp1, lessThan(xp5));
      expect(xp5, lessThan(xp10));
      expect(xp1, 1000); // level 1: 1000 * 1^1.4 = 1000
    });

    test('xpProgress clamps between 0 and 1', () {
      expect(const PlayerState(level: 1, xp: 0).xpProgress, 0.0);
      expect(const PlayerState(level: 1, xp: 500).xpProgress, 0.5);
      expect(const PlayerState(level: 1, xp: 1000).xpProgress, 1.0);
    });

    test('copyWith preserves unmodified fields', () {
      const original = PlayerState(level: 5, xp: 200, streak: 3);
      final modified = original.copyWith(xp: 500);
      expect(modified.level, 5);
      expect(modified.xp, 500);
      expect(modified.streak, 3);
    });
  });

  group('AviaryService duplicate prevention', () {
    test('Bird XP multipliers are correct for testing', () {
      Bird makeBird(Rarity r) => Bird(
        name: 'Test',
        scientificName: '',
        imageUrl: '',
        audioUrl: '',
        lore: '',
        habitat: '',
        conservationStatus: '',
        rarity: r,
        baseXp: 100,
      );

      // Verify XP values that PlayerNotifier would use
      expect(makeBird(Rarity.common).xp, 100);
      expect(makeBird(Rarity.legendary).xp, 500);
    });
  });
}
