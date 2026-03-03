import 'package:flutter_test/flutter_test.dart';
import 'package:aviquest/services/player_service.dart';
import 'package:aviquest/constants.dart';

void main() {
  group('PlayerState.title', () {
    test('returns Fledgling for levels 0-2', () {
      expect(const PlayerState(level: 1).title, 'Fledgling');
      expect(const PlayerState(level: 2).title, 'Fledgling');
    });

    test('returns Nestling for levels 3-5', () {
      expect(const PlayerState(level: 3).title, 'Nestling');
      expect(const PlayerState(level: 4).title, 'Nestling');
      expect(const PlayerState(level: 5).title, 'Nestling');
    });

    test('returns Sparrow for levels 6-9', () {
      expect(const PlayerState(level: 6).title, 'Sparrow');
      expect(const PlayerState(level: 9).title, 'Sparrow');
    });

    test('returns Warbler for levels 10-14', () {
      expect(const PlayerState(level: 10).title, 'Warbler');
      expect(const PlayerState(level: 14).title, 'Warbler');
    });

    test('returns Songweaver for levels 15-19', () {
      expect(const PlayerState(level: 15).title, 'Songweaver');
      expect(const PlayerState(level: 19).title, 'Songweaver');
    });

    test('returns Falconer for levels 20-29', () {
      expect(const PlayerState(level: 20).title, 'Falconer');
      expect(const PlayerState(level: 29).title, 'Falconer');
    });

    test('returns Eagle Scout for levels 30-39', () {
      expect(const PlayerState(level: 30).title, 'Eagle Scout');
      expect(const PlayerState(level: 39).title, 'Eagle Scout');
    });

    test('returns Master Birder for level 40 and above', () {
      expect(const PlayerState(level: 40).title, 'Master Birder');
      expect(const PlayerState(level: 50).title, 'Master Birder');
      expect(const PlayerState(level: 100).title, 'Master Birder');
    });

    test('boundary transitions are correct', () {
      expect(const PlayerState(level: 2).title, 'Fledgling');
      expect(const PlayerState(level: 3).title, 'Nestling');
      expect(const PlayerState(level: 5).title, 'Nestling');
      expect(const PlayerState(level: 6).title, 'Sparrow');
      expect(const PlayerState(level: 9).title, 'Sparrow');
      expect(const PlayerState(level: 10).title, 'Warbler');
      expect(const PlayerState(level: 14).title, 'Warbler');
      expect(const PlayerState(level: 15).title, 'Songweaver');
      expect(const PlayerState(level: 19).title, 'Songweaver');
      expect(const PlayerState(level: 20).title, 'Falconer');
      expect(const PlayerState(level: 29).title, 'Falconer');
      expect(const PlayerState(level: 30).title, 'Eagle Scout');
      expect(const PlayerState(level: 39).title, 'Eagle Scout');
      expect(const PlayerState(level: 40).title, 'Master Birder');
    });
  });

  group('PlayerState.xpForNextLevel', () {
    test('returns positive value for level 1', () {
      expect(const PlayerState(level: 1).xpForNextLevel, greaterThan(0));
    });

    test('level 1 requires 1000 XP', () {
      expect(const PlayerState(level: 1).xpForNextLevel, 1000);
    });

    test('increases monotonically with level', () {
      int prev = 0;
      for (int lvl = 1; lvl <= 50; lvl++) {
        final current = PlayerState(level: lvl).xpForNextLevel;
        expect(current, greaterThan(prev),
            reason: 'XP should increase from level ${lvl - 1} to $lvl');
        prev = current;
      }
    });

    test('higher levels require significantly more XP', () {
      final level1 = const PlayerState(level: 1).xpForNextLevel;
      final level10 = const PlayerState(level: 10).xpForNextLevel;
      final level20 = const PlayerState(level: 20).xpForNextLevel;

      expect(level10, greaterThan(level1 * 10));
      expect(level20, greaterThan(level10));
    });
  });
}
