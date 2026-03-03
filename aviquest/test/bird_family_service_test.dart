import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:aviquest/services/bird_family_service.dart';
import 'package:aviquest/models/bird.dart';
import 'package:aviquest/constants.dart';

Bird _bird(String name, {Rarity rarity = Rarity.common}) => Bird(
  name: name,
  scientificName: 'Sci $name',
  imageUrl: '',
  audioUrl: '',
  lore: 'A bird',
  habitat: 'Forest',
  conservationStatus: 'Least Concern',
  rarity: rarity,
  baseXp: 20,
);

void main() {
  group('BirdFamily.containsBird', () {
    test('matches by name keyword', () {
      const raptor = BirdFamily(
        id: 'test',
        name: 'Test',
        emoji: '🦅',
        description: '',
        color: Color(0xFFFFFFFF),
        nameKeywords: ['eagle', 'hawk'],
      );
      expect(raptor.containsBird(_bird('Bald Eagle')), isTrue);
      expect(raptor.containsBird(_bird('Red-tailed Hawk')), isTrue);
      expect(raptor.containsBird(_bird('House Sparrow')), isFalse);
    });

    test('matches by exact member', () {
      const family = BirdFamily(
        id: 'test',
        name: 'Test',
        emoji: '🐦',
        description: '',
        color: Color(0xFFFFFFFF),
        exactMembers: ['Coal Tit', 'Great Tit'],
      );
      expect(family.containsBird(_bird('Coal Tit')), isTrue);
      expect(family.containsBird(_bird('Great Tit')), isTrue);
      expect(family.containsBird(_bird('Random Bird')), isFalse);
    });

    test('keyword matching is case-insensitive', () {
      const family = BirdFamily(
        id: 'test',
        name: 'Test',
        emoji: '🦉',
        description: '',
        color: Color(0xFFFFFFFF),
        nameKeywords: ['owl'],
      );
      expect(family.containsBird(_bird('Barn Owl')), isTrue);
      expect(family.containsBird(_bird('OWL CITY')), isTrue);
    });
  });

  group('FamilyProgress', () {
    test('calculates progress correctly', () {
      final fp = FamilyProgress(
        family: families.first,
        allMembers: [_bird('A'), _bird('B'), _bird('C'), _bird('D')],
        collectedMembers: [_bird('A'), _bird('B')],
      );
      expect(fp.total, 4);
      expect(fp.collected, 2);
      expect(fp.progress, 0.5);
      expect(fp.isComplete, isFalse);
      expect(fp.mastery, FamilyMastery.silver);
    });

    test('gold mastery when complete', () {
      final fp = FamilyProgress(
        family: families.first,
        allMembers: [_bird('A'), _bird('B')],
        collectedMembers: [_bird('A'), _bird('B')],
      );
      expect(fp.isComplete, isTrue);
      expect(fp.mastery, FamilyMastery.gold);
      expect(fp.xpBonus, 1.15);
    });

    test('bronze mastery at 25%', () {
      final fp = FamilyProgress(
        family: families.first,
        allMembers: List.generate(4, (i) => _bird('Bird $i')),
        collectedMembers: [_bird('Bird 0')],
      );
      expect(fp.mastery, FamilyMastery.bronze);
      expect(fp.xpBonus, 1.05);
    });

    test('no mastery below 25%', () {
      final fp = FamilyProgress(
        family: families.first,
        allMembers: List.generate(10, (i) => _bird('Bird $i')),
        collectedMembers: [_bird('Bird 0')],
      );
      expect(fp.mastery, FamilyMastery.none);
      expect(fp.xpBonus, 1.0);
    });

    test('zero total birds gives zero progress', () {
      final fp = FamilyProgress(
        family: families.first,
        allMembers: [],
        collectedMembers: [],
      );
      expect(fp.progress, 0.0);
      expect(fp.isComplete, isFalse);
    });
  });

  group('families constant', () {
    test('has at least 10 families defined', () {
      expect(families.length, greaterThanOrEqualTo(10));
    });

    test('each family has unique ID', () {
      final ids = families.map((f) => f.id).toSet();
      expect(ids.length, families.length);
    });

    test('each family has non-empty emoji and name', () {
      for (final f in families) {
        expect(f.emoji, isNotEmpty, reason: '${f.id} should have emoji');
        expect(f.name, isNotEmpty, reason: '${f.id} should have name');
      }
    });
  });

  group('FamilyMastery extension', () {
    test('labels are correct', () {
      expect(FamilyMastery.none.label, '');
      expect(FamilyMastery.bronze.label, 'Bronze');
      expect(FamilyMastery.silver.label, 'Silver');
      expect(FamilyMastery.gold.label, 'Gold');
    });

    test('emojis are correct', () {
      expect(FamilyMastery.none.emoji, '');
      expect(FamilyMastery.bronze.emoji, '🥉');
      expect(FamilyMastery.silver.emoji, '🥈');
      expect(FamilyMastery.gold.emoji, '🥇');
    });
  });
}
