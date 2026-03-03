import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aviquest/constants.dart';

void main() {
  group('Rarity', () {
    test('all game rarities have a color', () {
      for (final r in Rarity.values) {
        expect(r.color, isA<Color>());
      }
    });

    test('label returns uppercase name or NEW DISCOVERY for unknown', () {
      expect(Rarity.common.label, 'COMMON');
      expect(Rarity.uncommon.label, 'UNCOMMON');
      expect(Rarity.rare.label, 'RARE');
      expect(Rarity.legendary.label, 'LEGENDARY');
      expect(Rarity.unknown.label, 'NEW DISCOVERY');
    });

    test('values.byName round-trips all rarity names', () {
      for (final r in Rarity.values) {
        expect(Rarity.values.byName(r.name), r);
      }
    });
  });
}
