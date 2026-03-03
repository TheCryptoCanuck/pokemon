import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:aviquest/main.dart';

void main() {
  group('levelTitle', () {
    test('returns Fledgling for levels 0-2', () {
      expect(levelTitle(0), 'Fledgling');
      expect(levelTitle(1), 'Fledgling');
      expect(levelTitle(2), 'Fledgling');
    });

    test('returns Nestling for levels 3-5', () {
      expect(levelTitle(3), 'Nestling');
      expect(levelTitle(4), 'Nestling');
      expect(levelTitle(5), 'Nestling');
    });

    test('returns Sparrow for levels 6-9', () {
      expect(levelTitle(6), 'Sparrow');
      expect(levelTitle(9), 'Sparrow');
    });

    test('returns Warbler for levels 10-14', () {
      expect(levelTitle(10), 'Warbler');
      expect(levelTitle(14), 'Warbler');
    });

    test('returns Songweaver for levels 15-19', () {
      expect(levelTitle(15), 'Songweaver');
      expect(levelTitle(19), 'Songweaver');
    });

    test('returns Falconer for levels 20-29', () {
      expect(levelTitle(20), 'Falconer');
      expect(levelTitle(29), 'Falconer');
    });

    test('returns Eagle Scout for levels 30-39', () {
      expect(levelTitle(30), 'Eagle Scout');
      expect(levelTitle(39), 'Eagle Scout');
    });

    test('returns Master Birder for level 40 and above', () {
      expect(levelTitle(40), 'Master Birder');
      expect(levelTitle(50), 'Master Birder');
      expect(levelTitle(100), 'Master Birder');
    });

    test('boundary transitions are correct', () {
      // Each boundary should transition cleanly
      expect(levelTitle(2), 'Fledgling');
      expect(levelTitle(3), 'Nestling');
      expect(levelTitle(5), 'Nestling');
      expect(levelTitle(6), 'Sparrow');
      expect(levelTitle(9), 'Sparrow');
      expect(levelTitle(10), 'Warbler');
      expect(levelTitle(14), 'Warbler');
      expect(levelTitle(15), 'Songweaver');
      expect(levelTitle(19), 'Songweaver');
      expect(levelTitle(20), 'Falconer');
      expect(levelTitle(29), 'Falconer');
      expect(levelTitle(30), 'Eagle Scout');
      expect(levelTitle(39), 'Eagle Scout');
      expect(levelTitle(40), 'Master Birder');
    });
  });

  group('xpForNextLevel', () {
    test('returns positive value for level 1', () {
      expect(xpForNextLevel(1), greaterThan(0));
    });

    test('follows the formula (1000 * level^1.4).round()', () {
      for (int lvl = 1; lvl <= 10; lvl++) {
        final expected = (1000 * pow(lvl, 1.4)).round();
        expect(xpForNextLevel(lvl), expected,
            reason: 'Failed at level $lvl');
      }
    });

    test('increases monotonically with level', () {
      int prev = 0;
      for (int lvl = 1; lvl <= 50; lvl++) {
        final current = xpForNextLevel(lvl);
        expect(current, greaterThan(prev),
            reason: 'XP should increase from level ${lvl - 1} to $lvl');
        prev = current;
      }
    });

    test('level 1 requires 1000 XP', () {
      expect(xpForNextLevel(1), 1000);
    });

    test('higher levels require significantly more XP', () {
      final level1 = xpForNextLevel(1);
      final level10 = xpForNextLevel(10);
      final level20 = xpForNextLevel(20);

      expect(level10, greaterThan(level1 * 10));
      expect(level20, greaterThan(level10));
    });
  });

  group('unknownBird', () {
    test('creates a Bird with the given name', () {
      final bird = unknownBird('Mystery Warbler');
      expect(bird.name, 'Mystery Warbler');
    });

    test('has unknown rarity', () {
      final bird = unknownBird('Mystery');
      expect(bird.rarity, 'unknown');
    });

    test('has empty imageUrl and audioUrl', () {
      final bird = unknownBird('Mystery');
      expect(bird.imageUrl, isEmpty);
      expect(bird.audioUrl, isEmpty);
    });

    test('has placeholder scientific name', () {
      final bird = unknownBird('Mystery');
      expect(bird.scientificName, 'Species not yet in database');
    });

    test('has 100 baseXp as reward', () {
      final bird = unknownBird('Mystery');
      expect(bird.baseXp, 100);
    });

    test('lore mentions database not yet updated', () {
      final bird = unknownBird('Mystery');
      expect(bird.lore, contains('database'));
    });

    test('habitat is Unknown', () {
      final bird = unknownBird('Mystery');
      expect(bird.habitat, 'Unknown');
    });

    test('conservationStatus is Unknown', () {
      final bird = unknownBird('Mystery');
      expect(bird.conservationStatus, 'Unknown');
    });
  });
}
