import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aviquest/models/bird.dart';
import 'package:aviquest/constants.dart';
import '../helpers/bird_test_helpers.dart';

void main() {
  group('Bird model', () {
    group('constructor', () {
      test('creates a Bird with all required fields', () {
        final bird = makeBird(
          name: 'Bald Eagle',
          scientificName: 'Haliaeetus leucocephalus',
          rarity: Rarity.rare,
          baseXp: 300,
        );

        expect(bird.name, 'Bald Eagle');
        expect(bird.scientificName, 'Haliaeetus leucocephalus');
        expect(bird.rarity, Rarity.rare);
        expect(bird.baseXp, 300);
      });

      test('stores empty audioUrl when none provided', () {
        final bird = makeBird(audioUrl: '');
        expect(bird.audioUrl, isEmpty);
      });

      test('stores non-empty audioUrl', () {
        final bird = makeBird(audioUrl: 'https://xeno-canto.org/test.mp3');
        expect(bird.audioUrl, 'https://xeno-canto.org/test.mp3');
      });
    });

    group('xp getter', () {
      test('returns baseXp for common rarity', () {
        final bird = makeBird(rarity: Rarity.common, baseXp: 100);
        expect(bird.xp, 100);
      });

      test('returns 1.5x baseXp for uncommon rarity', () {
        final bird = makeBird(rarity: Rarity.uncommon, baseXp: 100);
        expect(bird.xp, 150);
      });

      test('returns 2x baseXp for rare rarity', () {
        final bird = makeBird(rarity: Rarity.rare, baseXp: 100);
        expect(bird.xp, 200);
      });

      test('returns 5x baseXp for legendary rarity', () {
        final bird = makeBird(rarity: Rarity.legendary, baseXp: 100);
        expect(bird.xp, 500);
      });

      test('returns baseXp for unknown rarity (default case)', () {
        final bird = makeBird(rarity: Rarity.unknown, baseXp: 100);
        expect(bird.xp, 100);
      });

      test('rounds correctly for uncommon with odd baseXp', () {
        // 75 * 1.5 = 112.5 → 113 (rounds up)
        final bird = makeBird(rarity: Rarity.uncommon, baseXp: 75);
        expect(bird.xp, 113);
      });

      test('handles zero baseXp', () {
        final bird = makeBird(rarity: Rarity.legendary, baseXp: 0);
        expect(bird.xp, 0);
      });

      test('handles large baseXp values', () {
        final bird = makeBird(rarity: Rarity.legendary, baseXp: 10000);
        expect(bird.xp, 50000);
      });
    });

    group('rarity color', () {
      test('common is white70', () {
        expect(commonBird.rarity.color, Colors.white70);
      });

      test('uncommon is green', () {
        expect(uncommonBird.rarity.color, const Color(0xFF4CAF50));
      });

      test('rare is blue', () {
        expect(rareBird.rarity.color, const Color(0xFF2196F3));
      });

      test('legendary is amber', () {
        expect(legendaryBird.rarity.color, Colors.amber);
      });

      test('unknown is purple', () {
        final bird = makeBird(rarity: Rarity.unknown);
        expect(bird.rarity.color, const Color(0xFFCE93D8));
      });
    });
  });
}
