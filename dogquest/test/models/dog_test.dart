import 'package:flutter_test/flutter_test.dart';
import 'package:dogquest/models/dog.dart';
import 'package:dogquest/constants.dart';

void main() {
  group('Dog.fromJson', () {
    test('parses a complete, well-formed JSON object', () {
      final json = {
        'name': 'Labrador Retriever',
        'scientificName': 'Canis lupus familiaris (Sporting)',
        'imageUrl': 'https://example.com/lab.jpg',
        'audioUrl': 'https://example.com/lab.mp3',
        'lore': 'The world\'s most popular dog breed for over 30 years.',
        'habitat': 'Sporting Group | Origin: Canada',
        'conservationStatus': 'Domesticated',
        'rarity': 'common',
        'baseXp': 20,
      };

      final dog = Dog.fromJson(json);

      expect(dog.name, equals('Labrador Retriever'));
      expect(dog.scientificName, equals('Canis lupus familiaris (Sporting)'));
      expect(dog.imageUrl, equals('https://example.com/lab.jpg'));
      expect(dog.audioUrl, equals('https://example.com/lab.mp3'));
      expect(
        dog.lore,
        equals('The world\'s most popular dog breed for over 30 years.'),
      );
      expect(dog.habitat, equals('Sporting Group | Origin: Canada'));
      expect(dog.conservationStatus, equals('Domesticated'));
      expect(dog.rarity, equals(Rarity.common));
      expect(dog.baseXp, equals(20));
    });

    test('parses uncommon rarity correctly', () {
      final json = {
        'name': 'Bernese Mountain Dog',
        'scientificName': 'Canis lupus familiaris (Working)',
        'imageUrl': '',
        'audioUrl': '',
        'lore': 'Swiss farm dogs.',
        'habitat': 'Working Group | Origin: Switzerland',
        'conservationStatus': 'Domesticated',
        'rarity': 'uncommon',
        'baseXp': 35,
      };

      final dog = Dog.fromJson(json);

      expect(dog.rarity, equals(Rarity.uncommon));
      expect(dog.baseXp, equals(35));
    });

    test('parses rare rarity correctly', () {
      final json = {
        'name': 'Afghan Hound',
        'scientificName': 'Canis lupus familiaris (Hound)',
        'imageUrl': '',
        'audioUrl': '',
        'lore': 'One of the oldest dog breeds.',
        'habitat': 'Hound Group | Origin: Afghanistan',
        'conservationStatus': 'Domesticated',
        'rarity': 'rare',
        'baseXp': 50,
      };

      final dog = Dog.fromJson(json);

      expect(dog.rarity, equals(Rarity.rare));
      expect(dog.baseXp, equals(50));
    });

    test('parses legendary rarity correctly', () {
      final json = {
        'name': 'Catalburun',
        'scientificName': 'Canis lupus familiaris (Sporting)',
        'imageUrl': '',
        'audioUrl': '',
        'lore': 'One of only three breeds with a split nose.',
        'habitat': 'Sporting Group | Origin: Turkey',
        'conservationStatus': 'Domesticated',
        'rarity': 'legendary',
        'baseXp': 80,
      };

      final dog = Dog.fromJson(json);

      expect(dog.rarity, equals(Rarity.legendary));
      expect(dog.baseXp, equals(80));
    });

    test('parses unknown rarity correctly when explicitly set', () {
      final json = {
        'name': 'Mystery Dog',
        'scientificName': '',
        'imageUrl': '',
        'audioUrl': '',
        'lore': '',
        'habitat': '',
        'conservationStatus': '',
        'rarity': 'unknown',
        'baseXp': 100,
      };

      final dog = Dog.fromJson(json);

      expect(dog.rarity, equals(Rarity.unknown));
    });

    test('applies default name when name field is null', () {
      final json = <String, dynamic>{
        'scientificName': 'Canis lupus familiaris',
        'rarity': 'common',
        'baseXp': 20,
      };

      final dog = Dog.fromJson(json);

      expect(dog.name, equals('Unknown Breed'));
    });

    test('applies empty string defaults for optional string fields', () {
      final json = <String, dynamic>{
        'name': 'Test Dog',
        'rarity': 'common',
        'baseXp': 20,
      };

      final dog = Dog.fromJson(json);

      expect(dog.scientificName, equals(''));
      expect(dog.imageUrl, equals(''));
      expect(dog.audioUrl, equals(''));
    });

    test('applies default lore when lore field is null', () {
      final json = <String, dynamic>{
        'name': 'Test Dog',
        'rarity': 'common',
        'baseXp': 20,
      };

      final dog = Dog.fromJson(json);

      expect(dog.lore, equals('No information available.'));
    });

    test(
        'applies Unknown defaults for habitat and conservationStatus when absent',
        () {
      final json = <String, dynamic>{
        'name': 'Test Dog',
        'rarity': 'common',
        'baseXp': 20,
      };

      final dog = Dog.fromJson(json);

      expect(dog.habitat, equals('Unknown'));
      expect(dog.conservationStatus, equals('Unknown'));
    });

    test('defaults to Rarity.common when rarity field is absent', () {
      final json = <String, dynamic>{
        'name': 'Test Dog',
        'baseXp': 20,
      };

      final dog = Dog.fromJson(json);

      expect(dog.rarity, equals(Rarity.common));
    });

    test(
        'defaults to Rarity.common when rarity field is an unrecognised string',
        () {
      final json = <String, dynamic>{
        'name': 'Test Dog',
        'rarity': 'super_ultra_mega',
        'baseXp': 20,
      };

      final dog = Dog.fromJson(json);

      expect(dog.rarity, equals(Rarity.common));
    });

    test('defaults baseXp to 20 when baseXp field is null', () {
      final json = <String, dynamic>{
        'name': 'Test Dog',
        'rarity': 'common',
      };

      final dog = Dog.fromJson(json);

      expect(dog.baseXp, equals(20));
    });

    test('coerces numeric baseXp represented as double via num cast', () {
      // JSON numbers can arrive as doubles (e.g. 25.0); toInt() must be called.
      final json = <String, dynamic>{
        'name': 'Test Dog',
        'rarity': 'common',
        'baseXp': 30.0,
      };

      final dog = Dog.fromJson(json);

      expect(dog.baseXp, equals(30));
    });

    test('handles completely empty JSON map with all defaults', () {
      final dog = Dog.fromJson({});

      expect(dog.name, equals('Unknown Breed'));
      expect(dog.scientificName, equals(''));
      expect(dog.imageUrl, equals(''));
      expect(dog.audioUrl, equals(''));
      expect(dog.lore, equals('No information available.'));
      expect(dog.habitat, equals('Unknown'));
      expect(dog.conservationStatus, equals('Unknown'));
      expect(dog.rarity, equals(Rarity.common));
      expect(dog.baseXp, equals(20));
    });
  });

  group('Dog.toJson', () {
    test('serialises all fields to the expected keys and values', () {
      const dog = Dog(
        name: 'Labrador Retriever',
        scientificName: 'Canis lupus familiaris (Sporting)',
        imageUrl: 'https://example.com/lab.jpg',
        audioUrl: 'https://example.com/lab.mp3',
        lore: 'The world\'s most popular dog breed.',
        habitat: 'Sporting Group | Origin: Canada',
        conservationStatus: 'Domesticated',
        rarity: Rarity.common,
        baseXp: 20,
      );

      final json = dog.toJson();

      expect(json['name'], equals('Labrador Retriever'));
      expect(
        json['scientificName'],
        equals('Canis lupus familiaris (Sporting)'),
      );
      expect(json['imageUrl'], equals('https://example.com/lab.jpg'));
      expect(json['audioUrl'], equals('https://example.com/lab.mp3'));
      expect(json['lore'], equals('The world\'s most popular dog breed.'));
      expect(json['habitat'], equals('Sporting Group | Origin: Canada'));
      expect(json['conservationStatus'], equals('Domesticated'));
      expect(json['rarity'], equals('common'));
      expect(json['baseXp'], equals(20));
    });

    test('rarity is serialised as its enum name string', () {
      for (final rarity in [
        Rarity.common,
        Rarity.uncommon,
        Rarity.rare,
        Rarity.legendary,
        Rarity.unknown,
      ]) {
        final dog = Dog(
          name: 'Test',
          scientificName: '',
          imageUrl: '',
          audioUrl: '',
          lore: '',
          habitat: '',
          conservationStatus: '',
          rarity: rarity,
          baseXp: 20,
        );

        expect(dog.toJson()['rarity'], equals(rarity.name));
      }
    });

    test('fromJson roundtrip preserves all fields identically', () {
      final originalJson = {
        'name': 'Afghan Hound',
        'scientificName': 'Canis lupus familiaris (Hound)',
        'imageUrl':
            'https://commons.wikimedia.org/w/thumb.php?f=Afghan_Hound.jpg&w=400',
        'audioUrl': '',
        'lore': 'One of the oldest dog breeds.',
        'habitat': 'Hound Group | Origin: Afghanistan',
        'conservationStatus': 'Domesticated',
        'rarity': 'rare',
        'baseXp': 50,
        'lifespan': '12-14 years',
        'sizeCategory': 'large',
        'weight': '23-27 kg',
        'exerciseNeeds': 'high',
        'groomingNeeds': 'high',
        'healthPredispositions': ['Hip dysplasia', 'Cataracts'],
        'temperamentTraits': ['Dignified', 'Aloof', 'Independent'],
        'dietNotes': 'High-quality diet with lean protein.',
      };

      final roundtripped = Dog.fromJson(originalJson).toJson();

      expect(roundtripped, equals(originalJson));
    });
  });

  group('Dog.xp', () {
    Dog makeDog({required Rarity rarity, required int baseXp}) => Dog(
          name: 'Test',
          scientificName: '',
          imageUrl: '',
          audioUrl: '',
          lore: '',
          habitat: '',
          conservationStatus: '',
          rarity: rarity,
          baseXp: baseXp,
        );

    test('common rarity returns baseXp unchanged', () {
      expect(makeDog(rarity: Rarity.common, baseXp: 20).xp, equals(20));
      expect(makeDog(rarity: Rarity.common, baseXp: 25).xp, equals(25));
    });

    test('uncommon rarity returns baseXp * 1.5 rounded to nearest int', () {
      // 35 * 1.5 = 52.5 → rounds to 53
      expect(makeDog(rarity: Rarity.uncommon, baseXp: 35).xp, equals(53));
      // 40 * 1.5 = 60 exactly
      expect(makeDog(rarity: Rarity.uncommon, baseXp: 40).xp, equals(60));
      // 20 * 1.5 = 30 exactly
      expect(makeDog(rarity: Rarity.uncommon, baseXp: 20).xp, equals(30));
    });

    test('rare rarity returns exactly baseXp * 2', () {
      expect(makeDog(rarity: Rarity.rare, baseXp: 50).xp, equals(100));
      expect(makeDog(rarity: Rarity.rare, baseXp: 55).xp, equals(110));
    });

    test('legendary rarity returns exactly baseXp * 5', () {
      expect(makeDog(rarity: Rarity.legendary, baseXp: 80).xp, equals(400));
      expect(makeDog(rarity: Rarity.legendary, baseXp: 100).xp, equals(500));
    });

    test('unknown rarity falls through to the default branch, returning baseXp',
        () {
      // The switch default covers Rarity.unknown (and Rarity.common).
      expect(makeDog(rarity: Rarity.unknown, baseXp: 100).xp, equals(100));
    });

    test(
        'uncommon rounding: odd-half values round to nearest even per Dart .round()',
        () {
      // Dart's .round() uses half-up rounding.
      // 1 * 1.5 = 1.5 → rounds to 2
      expect(makeDog(rarity: Rarity.uncommon, baseXp: 1).xp, equals(2));
      // 3 * 1.5 = 4.5 → rounds to 5
      expect(makeDog(rarity: Rarity.uncommon, baseXp: 3).xp, equals(5));
    });
  });
}
