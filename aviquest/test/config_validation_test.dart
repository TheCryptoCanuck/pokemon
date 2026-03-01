import 'package:test/test.dart';
import 'package:aviquest/config/config_schema.dart';
import 'package:aviquest/config/config_validator.dart';
import 'package:aviquest/config/bird_data_validator.dart';
import 'package:aviquest/config/app_config.dart';

void main() {
  late ConfigValidator validator;

  setUp(() {
    validator = ConfigValidator();
  });

  // ─── App Config Validation ───────────────────────────────────────────────

  group('AppConfig validation', () {
    test('valid development config passes', () {
      final config = AppConfig.development();
      final result = config.validate();
      expect(result.isValid, isTrue);
    });

    test('valid production config passes', () {
      final config = AppConfig.production();
      final result = config.validate();
      expect(result.isValid, isTrue);
    });

    test('valid staging config passes', () {
      final config = AppConfig.staging();
      final result = config.validate();
      expect(result.isValid, isTrue);
    });

    test('invalid environment is rejected', () {
      final result = validator.validateAppConfig({
        'environment': 'invalid_env',
      });
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.rule == 'valid_environment'), isTrue);
    });

    test('debug in production is critical', () {
      final result = validator.validateAppConfig({
        'environment': 'production',
        'debug': true,
      });
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.rule == 'production_guard'), isTrue);
    });

    test('showDebugBanner in production is critical', () {
      final result = validator.validateAppConfig({
        'environment': 'production',
        'showDebugBanner': true,
      });
      expect(result.isValid, isFalse);
    });

    test('mockIdentification in production is critical', () {
      final result = validator.validateAppConfig({
        'environment': 'production',
        'mockIdentification': true,
      });
      expect(result.isValid, isFalse);
    });

    test('invalid hive box name is rejected', () {
      final result = validator.validateAppConfig({
        'environment': 'development',
        'hiveBoxName': 'Invalid Box Name!',
      });
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.rule == 'box_name_format'), isTrue);
    });

    test('valid hive box name with version suffix passes', () {
      final result = validator.validateAppConfig({
        'environment': 'development',
        'hiveBoxName': 'aviary_v2',
      });
      expect(result.isValid, isTrue);
    });
  });

  // ─── Bird Validation ─────────────────────────────────────────────────────

  group('Bird validation', () {
    Map<String, dynamic> validBird() => {
          'name': 'Black-capped Chickadee',
          'scientificName': 'Poecile atricapillus',
          'imageUrl': 'https://example.com/bird.jpg',
          'audioUrl': 'https://example.com/bird.mp3',
          'lore': 'A cheerful winter friend that remembers thousands of cache locations!',
          'habitat': 'Deciduous and mixed forests, parks, suburbs',
          'conservationStatus': 'Least Concern',
          'rarity': 'common',
          'baseXp': 50,
        };

    test('valid bird passes validation', () {
      final result = validator.validateBird(validBird());
      expect(result.isValid, isTrue);
    });

    test('missing name fails', () {
      final bird = validBird()..remove('name');
      final result = validator.validateBird(bird);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.path.contains('name')), isTrue);
    });

    test('empty name fails', () {
      final bird = validBird()..['name'] = '';
      final result = validator.validateBird(bird);
      expect(result.isValid, isFalse);
    });

    test('invalid rarity fails', () {
      final bird = validBird()..['rarity'] = 'mythical';
      final result = validator.validateBird(bird);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.rule == 'valid_rarity'), isTrue);
    });

    test('unknown rarity (internal) is accepted', () {
      final bird = validBird()..['rarity'] = 'unknown';
      final result = validator.validateBird(bird);
      expect(result.isValid, isTrue);
    });

    test('baseXp below minimum fails', () {
      final bird = validBird()..['baseXp'] = 0;
      final result = validator.validateBird(bird);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.rule == 'range'), isTrue);
    });

    test('baseXp above maximum fails', () {
      final bird = validBird()..['baseXp'] = 9999;
      final result = validator.validateBird(bird);
      expect(result.isValid, isFalse);
    });

    test('non-integer baseXp fails', () {
      final bird = validBird()..['baseXp'] = 'fifty';
      final result = validator.validateBird(bird);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.rule == 'type'), isTrue);
    });

    test('short lore produces warning', () {
      final bird = validBird()..['lore'] = 'Short';
      final result = validator.validateBird(bird);
      expect(result.isValid, isTrue); // warning, not error
      expect(result.hasWarnings, isTrue);
    });

    test('empty imageUrl is allowed', () {
      final bird = validBird()..['imageUrl'] = '';
      final result = validator.validateBird(bird);
      expect(result.isValid, isTrue);
    });

    test('empty audioUrl is allowed', () {
      final bird = validBird()..['audioUrl'] = '';
      final result = validator.validateBird(bird);
      expect(result.isValid, isTrue);
    });

    test('invalid conservation status produces warning', () {
      final bird = validBird()..['conservationStatus'] = 'Super Safe';
      final result = validator.validateBird(bird);
      expect(result.isValid, isTrue); // warning, not error
      expect(result.warnings.any((e) => e.rule == 'valid_conservation_status'), isTrue);
    });
  });

  // ─── Bird Database Validation ────────────────────────────────────────────

  group('Bird database validation', () {
    List<Map<String, dynamic>> sampleDatabase() => [
          {
            'name': 'Chickadee',
            'scientificName': 'Poecile atricapillus',
            'imageUrl': '',
            'audioUrl': '',
            'lore': 'A small but mighty forest bird.',
            'habitat': 'Forests',
            'conservationStatus': 'Least Concern',
            'rarity': 'common',
            'baseXp': 50,
          },
          {
            'name': 'Barred Owl',
            'scientificName': 'Strix varia',
            'imageUrl': '',
            'audioUrl': '',
            'lore': 'Known for its distinctive hooting call.',
            'habitat': 'Dense forests',
            'conservationStatus': 'Least Concern',
            'rarity': 'uncommon',
            'baseXp': 75,
          },
          {
            'name': 'Peregrine Falcon',
            'scientificName': 'Falco peregrinus',
            'imageUrl': '',
            'audioUrl': '',
            'lore': 'The fastest animal on Earth during a stoop.',
            'habitat': 'Cliffs, cities',
            'conservationStatus': 'Least Concern',
            'rarity': 'rare',
            'baseXp': 100,
          },
          {
            'name': 'Ivory-billed Woodpecker',
            'scientificName': 'Campephilus principalis',
            'imageUrl': '',
            'audioUrl': '',
            'lore': 'The legendary ghost bird of southern swamps.',
            'habitat': 'Bottomland swamps',
            'conservationStatus': 'Critically Endangered',
            'rarity': 'legendary',
            'baseXp': 200,
          },
        ];

    test('valid database with all rarities passes', () {
      final result = validator.validateBirdDatabase(sampleDatabase());
      expect(result.isValid, isTrue);
    });

    test('empty database fails with critical severity', () {
      final result = validator.validateBirdDatabase([]);
      expect(result.isValid, isFalse);
      expect(result.errors.first.severity, Severity.critical);
    });

    test('duplicate names are rejected', () {
      final db = sampleDatabase();
      db.add({...db[0], 'scientificName': 'Poecile other'});
      final result = validator.validateBirdDatabase(db);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.rule == 'unique_name'), isTrue);
    });

    test('missing rarity tier produces critical issue', () {
      // Remove all legendary birds
      final db = sampleDatabase()..removeWhere((b) => b['rarity'] == 'legendary');
      final result = validator.validateBirdDatabase(db);
      expect(
        result.issues.any((e) => e.rule == 'rarity_coverage'),
        isTrue,
      );
    });
  });

  // ─── Achievement Validation ──────────────────────────────────────────────

  group('Achievement validation', () {
    Map<String, (String, String, String)> validAchievements() => {
          'first_bird': ('icon', 'First Feather', 'Identify your first bird'),
          'five_species': ('icon', 'Nature Curious', 'Collect 5 different species'),
          'ten_species': ('icon', 'Avid Birder', 'Collect 10 different species'),
          'twenty_species': ('icon', 'Wing Watcher', 'Collect 20 different species'),
          'rare_find': ('icon', 'Rare Encounter', 'Identify a rare bird'),
          'legendary_find': ('icon', 'Legend Spotter', 'Identify a legendary bird'),
          'level_5': ('icon', 'Rising Birder', 'Reach level 5'),
          'level_10': ('icon', 'Expert Nester', 'Reach level 10'),
          'level_20': ('icon', 'Sky Master', 'Reach level 20'),
        };

    test('valid achievements pass', () {
      final result = validator.validateAchievements(validAchievements());
      expect(result.isValid, isTrue);
    });

    test('missing required achievement fails', () {
      final achievements = validAchievements()..remove('first_bird');
      final result = validator.validateAchievements(achievements);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.rule == 'required_achievement'), isTrue);
    });

    test('invalid key format fails', () {
      final achievements = validAchievements();
      achievements['Invalid-Key!'] = ('icon', 'Bad Key', 'This key is invalid');
      final result = validator.validateAchievements(achievements);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.rule == 'key_format'), isTrue);
    });

    test('short title produces warning', () {
      final achievements = validAchievements();
      achievements['first_bird'] = ('icon', 'X', 'Identify your first bird');
      final result = validator.validateAchievements(achievements);
      expect(result.hasWarnings, isTrue);
    });
  });

  // ─── Leveling Validation ─────────────────────────────────────────────────

  group('Leveling validation', () {
    test('default leveling config passes', () {
      final result = validator.validateLeveling(
        baseMultiplier: 1000,
        exponent: 1.4,
        tierBoundaries: [3, 6, 10, 15, 20, 30, 40],
        tierNames: [
          'Fledgling', 'Nestling', 'Sparrow', 'Warbler',
          'Songweaver', 'Falconer', 'Eagle Scout', 'Master Birder',
        ],
      );
      expect(result.isValid, isTrue);
    });

    test('base multiplier below minimum fails', () {
      final result = validator.validateLeveling(
        baseMultiplier: 50,
        exponent: 1.4,
        tierBoundaries: [3],
        tierNames: ['Low', 'High'],
      );
      expect(result.isValid, isFalse);
    });

    test('exponent above maximum fails', () {
      final result = validator.validateLeveling(
        baseMultiplier: 1000,
        exponent: 5.0,
        tierBoundaries: [3],
        tierNames: ['Low', 'High'],
      );
      expect(result.isValid, isFalse);
    });

    test('non-ascending tier boundaries fail', () {
      final result = validator.validateLeveling(
        baseMultiplier: 1000,
        exponent: 1.4,
        tierBoundaries: [10, 5, 20],
        tierNames: ['A', 'B', 'C', 'D'],
      );
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.rule == 'ascending_order'), isTrue);
    });

    test('mismatched tier names count fails', () {
      final result = validator.validateLeveling(
        baseMultiplier: 1000,
        exponent: 1.4,
        tierBoundaries: [3, 6, 10],
        tierNames: ['A', 'B'], // should be 4
      );
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.rule == 'tier_count'), isTrue);
    });

    test('empty tier name fails', () {
      final result = validator.validateLeveling(
        baseMultiplier: 1000,
        exponent: 1.4,
        tierBoundaries: [3],
        tierNames: ['Good', ''],
      );
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.rule == 'non_empty'), isTrue);
    });
  });

  // ─── Bird Data Validator (deep checks) ───────────────────────────────────

  group('BirdDataValidator', () {
    late BirdDataValidator birdValidator;

    setUp(() {
      birdValidator = BirdDataValidator();
    });

    test('valid entries produce a clean report', () {
      final birds = [
        BirdEntry(
          name: 'Test Bird',
          scientificName: 'Testus birdus',
          imageUrl: 'https://example.com/img.jpg',
          audioUrl: 'https://example.com/audio.mp3',
          lore: 'A fascinating test specimen found only in unit tests.',
          habitat: 'Test environments',
          conservationStatus: 'Least Concern',
          rarity: 'common',
          baseXp: 50,
        ),
        BirdEntry(
          name: 'Rare Bird',
          scientificName: 'Rarus findus',
          lore: 'Extremely rare bird only seen during test runs.',
          habitat: 'CI pipelines',
          conservationStatus: 'Endangered',
          rarity: 'rare',
          baseXp: 150,
        ),
        BirdEntry(
          name: 'Uncommon Bird',
          scientificName: 'Uncommona birdicus',
          lore: 'Moderately rare, spotted in staging environments.',
          habitat: 'Staging servers',
          conservationStatus: 'Near Threatened',
          rarity: 'uncommon',
          baseXp: 75,
        ),
        BirdEntry(
          name: 'Legendary Bird',
          scientificName: 'Legendarius maximus',
          lore: 'The stuff of legends, rarely glimpsed in production.',
          habitat: 'Mythical forests',
          conservationStatus: 'Data Deficient',
          rarity: 'legendary',
          baseXp: 300,
        ),
      ];

      final report = birdValidator.validate(birds);
      expect(report.isValid, isTrue);
      expect(report.totalBirds, 4);
      expect(report.rarityCounts['common'], 1);
      expect(report.rarityCounts['legendary'], 1);
    });

    test('invalid scientific name format produces warning', () {
      final birds = [
        BirdEntry(
          name: 'Bad Sci Name',
          scientificName: 'not valid',
          lore: 'Has a badly formatted scientific name.',
          habitat: 'Everywhere',
          conservationStatus: 'Least Concern',
          rarity: 'common',
          baseXp: 50,
        ),
        BirdEntry(
          name: 'Filler Uncommon',
          scientificName: 'Fillera uncommona',
          lore: 'Filler bird for rarity coverage.',
          habitat: 'Fields',
          conservationStatus: 'Least Concern',
          rarity: 'uncommon',
          baseXp: 60,
        ),
        BirdEntry(
          name: 'Filler Rare',
          scientificName: 'Fillera rarus',
          lore: 'Filler bird for rarity coverage.',
          habitat: 'Mountains',
          conservationStatus: 'Least Concern',
          rarity: 'rare',
          baseXp: 100,
        ),
        BirdEntry(
          name: 'Filler Legendary',
          scientificName: 'Fillera legendus',
          lore: 'Filler bird for rarity coverage.',
          habitat: 'Clouds',
          conservationStatus: 'Least Concern',
          rarity: 'legendary',
          baseXp: 200,
        ),
      ];

      final report = birdValidator.validate(birds);
      expect(
        report.issues.any((i) => i.rule == 'scientific_name_format'),
        isTrue,
      );
    });

    test('HTTP image URL produces warning', () {
      final birds = [
        BirdEntry(
          name: 'HTTP Bird',
          scientificName: 'Httpa birdus',
          imageUrl: 'http://example.com/insecure.jpg',
          lore: 'This bird uses an insecure image URL.',
          habitat: 'Insecure servers',
          conservationStatus: 'Least Concern',
          rarity: 'common',
          baseXp: 50,
        ),
        BirdEntry(
          name: 'Filler U',
          scientificName: 'Fillera una',
          lore: 'Filler for rarity coverage.',
          habitat: 'Fields',
          conservationStatus: 'Least Concern',
          rarity: 'uncommon',
          baseXp: 60,
        ),
        BirdEntry(
          name: 'Filler R',
          scientificName: 'Fillera rara',
          lore: 'Filler for rarity coverage.',
          habitat: 'Mountains',
          conservationStatus: 'Least Concern',
          rarity: 'rare',
          baseXp: 100,
        ),
        BirdEntry(
          name: 'Filler L',
          scientificName: 'Fillera lega',
          lore: 'Filler for rarity coverage.',
          habitat: 'Clouds',
          conservationStatus: 'Least Concern',
          rarity: 'legendary',
          baseXp: 200,
        ),
      ];

      final report = birdValidator.validate(birds);
      expect(
        report.issues.any((i) => i.rule == 'prefer_https'),
        isTrue,
      );
    });

    test('report statistics are accurate', () {
      final birds = [
        BirdEntry(
          name: 'With Audio',
          scientificName: 'Audius birdus',
          imageUrl: 'https://example.com/img.jpg',
          audioUrl: 'https://example.com/audio.mp3',
          lore: 'This bird has both image and audio.',
          habitat: 'Studio',
          conservationStatus: 'Least Concern',
          rarity: 'common',
          baseXp: 50,
        ),
        BirdEntry(
          name: 'No Media',
          scientificName: 'Silentus birdus',
          lore: 'This bird has no media attached.',
          habitat: 'Quiet places',
          conservationStatus: 'Least Concern',
          rarity: 'uncommon',
          baseXp: 60,
        ),
        BirdEntry(
          name: 'Filler R2',
          scientificName: 'Fillera rarus',
          lore: 'Filler for rarity coverage.',
          habitat: 'Mountains',
          conservationStatus: 'Least Concern',
          rarity: 'rare',
          baseXp: 100,
        ),
        BirdEntry(
          name: 'Filler L2',
          scientificName: 'Fillera legendus',
          lore: 'Filler for rarity coverage.',
          habitat: 'Clouds',
          conservationStatus: 'Least Concern',
          rarity: 'legendary',
          baseXp: 200,
        ),
      ];

      final report = birdValidator.validate(birds);
      expect(report.totalBirds, 4);
      expect(report.birdsWithAudio, 1);
      expect(report.birdsWithImages, 1);
      expect(report.audioCoverage, 0.25);
      expect(report.imageCoverage, 0.25);
      expect(report.averageBaseXp, 102); // (50+60+100+200)/4
    });
  });

  // ─── GameConfig Unit Tests ───────────────────────────────────────────────

  group('GameConfig', () {
    test('xpForNextLevel returns increasing values', () {
      final config = GameConfig();
      var prev = 0;
      for (var level = 1; level <= 50; level++) {
        final xp = config.xpForNextLevel(level);
        expect(xp, greaterThan(prev), reason: 'XP at level $level should exceed level ${level - 1}');
        prev = xp;
      }
    });

    test('levelTitle returns correct tier names', () {
      final config = GameConfig();
      expect(config.levelTitle(1), 'Fledgling');
      expect(config.levelTitle(5), 'Nestling');
      expect(config.levelTitle(10), 'Warbler');
      expect(config.levelTitle(20), 'Songweaver');
      expect(config.levelTitle(40), 'Master Birder');
    });

    test('rarityFromRoll maps correctly', () {
      final config = GameConfig();
      expect(config.rarityFromRoll(0.0), 'common');
      expect(config.rarityFromRoll(0.59), 'common');
      expect(config.rarityFromRoll(0.60), 'uncommon');
      expect(config.rarityFromRoll(0.84), 'uncommon');
      expect(config.rarityFromRoll(0.85), 'rare');
      expect(config.rarityFromRoll(0.96), 'rare');
      expect(config.rarityFromRoll(0.97), 'legendary');
      expect(config.rarityFromRoll(0.99), 'legendary');
    });
  });

  // ─── Schema Constants ────────────────────────────────────────────────────

  group('Schema constants', () {
    test('RarityConfig has all expected rarities', () {
      expect(RarityConfig.validRarities, contains('common'));
      expect(RarityConfig.validRarities, contains('uncommon'));
      expect(RarityConfig.validRarities, contains('rare'));
      expect(RarityConfig.validRarities, contains('legendary'));
      expect(RarityConfig.validRarities.length, 4);
    });

    test('weight ranges cover all valid rarities', () {
      for (final rarity in RarityConfig.validRarities) {
        expect(RarityConfig.weightRanges, contains(rarity));
      }
    });

    test('achievement required keys are valid snake_case', () {
      for (final key in AchievementSchema.requiredKeys) {
        expect(AchievementSchema.keyPattern.hasMatch(key), isTrue,
            reason: 'Key "$key" should be valid snake_case');
      }
    });

    test('leveling defaults are internally consistent', () {
      expect(
        LevelingSchema.defaultTierNames.length,
        LevelingSchema.defaultTierBoundaries.length + 1,
      );

      for (var i = 1; i < LevelingSchema.defaultTierBoundaries.length; i++) {
        expect(
          LevelingSchema.defaultTierBoundaries[i],
          greaterThan(LevelingSchema.defaultTierBoundaries[i - 1]),
        );
      }
    });

    test('conservation statuses include IUCN categories', () {
      expect(ConservationConfig.validStatuses, contains('Least Concern'));
      expect(ConservationConfig.validStatuses, contains('Critically Endangered'));
      expect(ConservationConfig.validStatuses, contains('Extinct'));
    });
  });
}
