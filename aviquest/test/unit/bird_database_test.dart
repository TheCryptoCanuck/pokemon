import 'package:flutter_test/flutter_test.dart';
import 'package:aviquest/main.dart';
import '../helpers/bird_test_helpers.dart';

void main() {
  group('Bird database integrity', () {
    test('contains 393 species', () {
      expect(birds.length, 393);
    });

    test('every bird has a non-empty name', () {
      for (final bird in birds) {
        expect(bird.name, isNotEmpty,
            reason: 'Bird at index ${birds.indexOf(bird)} has empty name');
      }
    });

    test('every bird has a non-empty scientific name', () {
      for (final bird in birds) {
        expect(bird.scientificName, isNotEmpty,
            reason: '${bird.name} has empty scientificName');
      }
    });

    test('every bird has a non-empty imageUrl', () {
      for (final bird in birds) {
        expect(bird.imageUrl, isNotEmpty,
            reason: '${bird.name} has empty imageUrl');
      }
    });

    test('every bird has a valid rarity', () {
      for (final bird in birds) {
        expect(validRarities, contains(bird.rarity),
            reason: '${bird.name} has invalid rarity "${bird.rarity}"');
      }
    });

    test('every bird has positive baseXp', () {
      for (final bird in birds) {
        expect(bird.baseXp, greaterThan(0),
            reason: '${bird.name} has non-positive baseXp: ${bird.baseXp}');
      }
    });

    test('every bird has a non-empty lore', () {
      for (final bird in birds) {
        expect(bird.lore, isNotEmpty,
            reason: '${bird.name} has empty lore');
      }
    });

    test('every bird has a non-empty habitat', () {
      for (final bird in birds) {
        expect(bird.habitat, isNotEmpty,
            reason: '${bird.name} has empty habitat');
      }
    });

    test('every bird has a non-empty conservation status', () {
      for (final bird in birds) {
        expect(bird.conservationStatus, isNotEmpty,
            reason: '${bird.name} has empty conservationStatus');
      }
    });

    test('all bird names are unique', () {
      final names = birds.map((b) => b.name).toSet();
      expect(names.length, birds.length,
          reason: 'Duplicate bird names detected');
    });

    group('rarity distribution', () {
      test('has common birds (majority of pool)', () {
        final common = birds.where((b) => b.rarity == 'common').length;
        expect(common, greaterThan(0));
        expect(common, greaterThan(birds.length * 0.4),
            reason: 'Common birds should represent a large portion');
      });

      test('has uncommon birds', () {
        final uncommon = birds.where((b) => b.rarity == 'uncommon').length;
        expect(uncommon, greaterThan(0));
      });

      test('has rare birds', () {
        final rare = birds.where((b) => b.rarity == 'rare').length;
        expect(rare, greaterThan(0));
      });

      test('has legendary birds', () {
        final legendary = birds.where((b) => b.rarity == 'legendary').length;
        expect(legendary, greaterThan(0));
      });

      test('rarity tiers descend in count (common > uncommon > rare > legendary)', () {
        final common = birds.where((b) => b.rarity == 'common').length;
        final uncommon = birds.where((b) => b.rarity == 'uncommon').length;
        final rare = birds.where((b) => b.rarity == 'rare').length;
        final legendary = birds.where((b) => b.rarity == 'legendary').length;

        expect(common, greaterThan(uncommon),
            reason: 'Common ($common) should exceed uncommon ($uncommon)');
        expect(uncommon, greaterThan(rare),
            reason: 'Uncommon ($uncommon) should exceed rare ($rare)');
        expect(rare, greaterThan(legendary),
            reason: 'Rare ($rare) should exceed legendary ($legendary)');
      });
    });

    group('XP ranges by rarity', () {
      test('common birds have reasonable baseXp range', () {
        final commonBirds = birds.where((b) => b.rarity == 'common');
        for (final bird in commonBirds) {
          expect(bird.baseXp, inInclusiveRange(10, 200),
              reason: '${bird.name} (common) baseXp ${bird.baseXp} seems off');
        }
      });

      test('legendary birds have higher baseXp than common average', () {
        final commonAvg = birds
            .where((b) => b.rarity == 'common')
            .map((b) => b.baseXp)
            .reduce((a, b) => a + b) ~/
            birds.where((b) => b.rarity == 'common').length;

        final legendaryBirds = birds.where((b) => b.rarity == 'legendary');
        for (final bird in legendaryBirds) {
          expect(bird.baseXp, greaterThan(commonAvg),
              reason: '${bird.name} (legendary) should have higher baseXp than common avg ($commonAvg)');
        }
      });
    });

    test('imageUrls look like valid URLs', () {
      final urlPattern = RegExp(r'^https?://');
      for (final bird in birds) {
        expect(bird.imageUrl, matches(urlPattern),
            reason: '${bird.name} imageUrl does not look like a URL: ${bird.imageUrl}');
      }
    });

    test('non-empty audioUrls look like valid URLs', () {
      final urlPattern = RegExp(r'^https?://');
      for (final bird in birds) {
        if (bird.audioUrl.isNotEmpty) {
          expect(bird.audioUrl, matches(urlPattern),
              reason: '${bird.name} audioUrl does not look like a URL: ${bird.audioUrl}');
        }
      }
    });
  });
}
