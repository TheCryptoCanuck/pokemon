import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:dogquest/services/quiz_engine.dart';
import 'package:dogquest/models/dog.dart';
import 'package:dogquest/constants.dart';

Dog _makeDog(
  String name, {
  String sizeCategory = 'medium',
  String habitat = 'Non-Sporting Group | Origin: Unknown',
  String imageUrl = 'https://example.com/dog.jpg',
  String lifespan = '10-13 years',
  String weight = '15-25 kg',
  String exerciseNeeds = 'moderate',
  String groomingNeeds = 'moderate',
  String lore = 'A great dog with a wonderful history spanning many centuries.',
  List<String> temperamentTraits = const ['Friendly', 'Loyal'],
  List<String> healthPredispositions = const ['Hip dysplasia'],
  Rarity rarity = Rarity.common,
}) =>
    Dog(
      name: name,
      scientificName: 'Canis lupus familiaris',
      imageUrl: imageUrl,
      audioUrl: '',
      lore: lore,
      habitat: habitat,
      conservationStatus: 'Domesticated',
      rarity: rarity,
      baseXp: 20,
      lifespan: lifespan,
      sizeCategory: sizeCategory,
      weight: weight,
      exerciseNeeds: exerciseNeeds,
      groomingNeeds: groomingNeeds,
      temperamentTraits: temperamentTraits,
      healthPredispositions: healthPredispositions,
    );

/// A pool of 12 dogs with varied sizes, habitats, traits, origins, weights, and image URLs.
final List<Dog> testPool = [
  _makeDog(
    'Labrador Retriever',
    sizeCategory: 'large',
    habitat: 'Sporting Group | Origin: Canada',
    imageUrl: 'https://example.com/labrador.jpg',
    lifespan: '10-12 years',
    weight: '25-36 kg',
    exerciseNeeds: 'high',
    lore:
        'The most popular dog breed for over 30 years. Originally bred to help fishermen haul nets.',
    temperamentTraits: ['Friendly', 'Active', 'Outgoing'],
  ),
  _makeDog(
    'German Shepherd',
    sizeCategory: 'large',
    habitat: 'Herding Group | Origin: Germany',
    imageUrl: 'https://example.com/gsd.jpg',
    lifespan: '9-13 years',
    weight: '30-40 kg',
    exerciseNeeds: 'high',
    lore:
        'Renowned for intelligence and versatility. Serves as police dogs and search-and-rescue heroes.',
    temperamentTraits: ['Confident', 'Courageous', 'Smart'],
  ),
  _makeDog(
    'Chihuahua',
    sizeCategory: 'small',
    habitat: 'Toy Group | Origin: Mexico',
    imageUrl: 'https://example.com/chihuahua.jpg',
    lifespan: '14-16 years',
    weight: '1-3 kg',
    exerciseNeeds: 'low',
    lore:
        'Named after the Mexican state of Chihuahua. The smallest recognized dog breed in the world.',
    temperamentTraits: ['Alert', 'Lively', 'Devoted'],
  ),
  _makeDog(
    'Beagle',
    sizeCategory: 'medium',
    habitat: 'Hound Group | Origin: England',
    imageUrl: 'https://example.com/beagle.jpg',
    lifespan: '10-15 years',
    weight: '9-11 kg',
    exerciseNeeds: 'high',
    lore:
        'One of the most popular hound breeds, known for their incredible sense of smell.',
    temperamentTraits: ['Merry', 'Friendly', 'Curious'],
  ),
  _makeDog(
    'Bulldog',
    sizeCategory: 'medium',
    habitat: 'Non-Sporting Group | Origin: England',
    imageUrl: 'https://example.com/bulldog.jpg',
    lifespan: '8-10 years',
    weight: '18-23 kg',
    exerciseNeeds: 'low',
    lore:
        'Originally bred for bull-baiting in 13th century England, now a gentle companion.',
    temperamentTraits: ['Calm', 'Courageous', 'Friendly'],
  ),
  _makeDog(
    'Poodle',
    sizeCategory: 'medium',
    habitat: 'Non-Sporting Group | Origin: Germany',
    imageUrl: 'https://example.com/poodle.jpg',
    lifespan: '10-18 years',
    weight: '20-32 kg',
    exerciseNeeds: 'high',
    groomingNeeds: 'high',
    lore:
        'Despite their fancy appearance, Poodles were originally water retrievers for duck hunters.',
    temperamentTraits: ['Intelligent', 'Active', 'Alert'],
  ),
  _makeDog(
    'Rottweiler',
    sizeCategory: 'large',
    habitat: 'Working Group | Origin: Germany',
    imageUrl: 'https://example.com/rottweiler.jpg',
    lifespan: '9-10 years',
    weight: '36-60 kg',
    exerciseNeeds: 'high',
    lore:
        'Descended from Roman drover dogs. Used to pull carts for butchers in medieval Germany.',
    temperamentTraits: ['Loyal', 'Confident', 'Loving'],
  ),
  _makeDog(
    'Yorkshire Terrier',
    sizeCategory: 'small',
    habitat: 'Toy Group | Origin: England',
    imageUrl: 'https://example.com/yorkie.jpg',
    lifespan: '11-15 years',
    weight: '2-3 kg',
    exerciseNeeds: 'moderate',
    groomingNeeds: 'high',
    lore:
        'Originally bred in Yorkshire to catch rats in clothing mills during the Industrial Revolution.',
    temperamentTraits: ['Affectionate', 'Sprightly', 'Tomboyish'],
  ),
  _makeDog(
    'Great Dane',
    sizeCategory: 'giant',
    habitat: 'Working Group | Origin: Germany',
    imageUrl: 'https://example.com/greatdane.jpg',
    lifespan: '7-10 years',
    weight: '50-80 kg',
    exerciseNeeds: 'moderate',
    lore:
        'Known as the Apollo of Dogs. Despite their size, they are gentle giants who love lap time.',
    temperamentTraits: ['Friendly', 'Patient', 'Dependable'],
  ),
  _makeDog(
    'Dachshund',
    sizeCategory: 'small',
    habitat: 'Hound Group | Origin: Germany',
    imageUrl: 'https://example.com/dachshund.jpg',
    lifespan: '12-16 years',
    weight: '7-14 kg',
    exerciseNeeds: 'moderate',
    lore:
        'Bred in Germany to hunt badgers. Their name literally means badger dog in German.',
    temperamentTraits: ['Clever', 'Stubborn', 'Devoted'],
  ),
  _makeDog(
    'Shih Tzu',
    sizeCategory: 'small',
    habitat: 'Toy Group | Origin: China',
    imageUrl: 'https://example.com/shihtzu.jpg',
    lifespan: '10-18 years',
    weight: '4-7 kg',
    exerciseNeeds: 'low',
    groomingNeeds: 'high',
    lore:
        'An ancient breed raised in Chinese imperial palaces. Their name means little lion.',
    temperamentTraits: ['Affectionate', 'Playful', 'Outgoing'],
  ),
  _makeDog(
    'Boxer',
    sizeCategory: 'large',
    habitat: 'Working Group | Origin: Germany',
    imageUrl: 'https://example.com/boxer.jpg',
    lifespan: '10-12 years',
    weight: '25-32 kg',
    exerciseNeeds: 'very high',
    lore:
        'Descended from war dogs of the Assyrian Empire. Named for their tendency to play with their front paws.',
    temperamentTraits: ['Fun-Loving', 'Bright', 'Active'],
  ),
];

void main() {
  late QuizEngine engine;

  setUp(() {
    engine = QuizEngine(Random(42));
  });

  // ─── tooSimilar tests ───────────────────────────────────────────────────────

  group('tooSimilar', () {
    test('returns true when one name contains the other', () {
      expect(engine.tooSimilar('Standard Poodle', 'Poodle'), isTrue);
    });

    test('returns true when both names share the same last word', () {
      expect(engine.tooSimilar('Toy Poodle', 'Miniature Poodle'), isTrue);
    });

    test('returns false for completely different breed names', () {
      expect(
        engine.tooSimilar('Labrador Retriever', 'German Shepherd'),
        isFalse,
      );
    });

    test(
        'returns true for Golden Retriever vs Labrador Retriever (same last word)',
        () {
      expect(
        engine.tooSimilar('Golden Retriever', 'Labrador Retriever'),
        isTrue,
      );
    });
  });

  // ─── parseOrigin tests ──────────────────────────────────────────────────────

  group('parseOrigin', () {
    test('parses origin from standard habitat format', () {
      expect(
        engine.parseOrigin('Sporting Group | Origin: Canada'),
        equals('Canada'),
      );
      expect(
        engine.parseOrigin('Herding Group | Origin: Germany'),
        equals('Germany'),
      );
      expect(
        engine.parseOrigin('Toy Group | Origin: Mexico'),
        equals('Mexico'),
      );
    });

    test('returns Unknown for missing origin', () {
      expect(engine.parseOrigin('Companion'), equals('Unknown'));
      expect(engine.parseOrigin(''), equals('Unknown'));
    });
  });

  // ─── parseMidLifespan tests ─────────────────────────────────────────────────

  group('parseMidLifespan', () {
    test('computes midpoint of lifespan range', () {
      expect(engine.parseMidLifespan('10-14 years'), equals(12));
      expect(engine.parseMidLifespan('7-10 years'), equals(9));
      expect(engine.parseMidLifespan('14-16 years'), equals(15));
    });

    test('handles single number', () {
      expect(engine.parseMidLifespan('12 years'), equals(12));
    });

    test('returns default for empty string', () {
      expect(engine.parseMidLifespan(''), equals(11));
    });
  });

  // ─── pickDistractors tests ────────────────────────────────────────────────

  group('pickDistractors', () {
    test('returns exactly 3 distractors', () {
      final correct = testPool.first;
      final distractors = engine.pickDistractors(testPool, correct, 3);
      expect(distractors.length, equals(3));
    });

    test('none of the distractors match the correct dog name', () {
      final correct = testPool.first;
      final distractors = engine.pickDistractors(testPool, correct, 3);
      for (final d in distractors) {
        expect(d.name, isNot(equals(correct.name)));
      }
    });

    test('works with a small pool of exactly 4 breeds', () {
      final smallPool = testPool.sublist(0, 4);
      final correct = smallPool.first;
      final distractors = engine.pickDistractors(smallPool, correct, 3);
      expect(distractors.length, equals(3));
      for (final d in distractors) {
        expect(d.name, isNot(equals(correct.name)));
      }
    });
  });

  // ─── Question generation tests ────────────────────────────────────────────

  group('makeNameFromPhoto', () {
    test('produces valid question with 4 options and valid correctIndex', () {
      final q = engine.makeNameFromPhoto(testPool);
      expect(q.options.length, equals(4));
      expect(q.correctIndex, greaterThanOrEqualTo(0));
      expect(q.correctIndex, lessThan(4));
      expect(q.options[q.correctIndex], equals(q.correctDog.name));
      expect(q.type, equals(QuizType.nameFromPhoto));
    });
  });

  group('makePhotoFromName', () {
    test('produces question with photoDogs list of 4', () {
      final q = engine.makePhotoFromName(testPool);
      expect(q.photoDogs, isNotNull);
      expect(q.photoDogs!.length, equals(4));
      expect(q.options.length, equals(4));
      expect(q.correctIndex, greaterThanOrEqualTo(0));
      expect(q.correctIndex, lessThan(4));
      expect(q.photoDogs![q.correctIndex].name, equals(q.correctDog.name));
      expect(q.type, equals(QuizType.photoFromName));
    });
  });

  group('makeSizeFromPhoto', () {
    test('options are the four size categories', () {
      final q = engine.makeSizeFromPhoto(testPool);
      expect(q.options, equals(['small', 'medium', 'large', 'giant']));
      expect(q.type, equals(QuizType.sizeFromPhoto));
      final expectedSize = q.correctDog.sizeCategory.isEmpty
          ? 'medium'
          : q.correctDog.sizeCategory;
      expect(q.options[q.correctIndex], equals(expectedSize));
    });
  });

  group('makeTraitMatch', () {
    test('falls back to nameFromPhoto when dog has no traits', () {
      final noTraitPool = List.generate(
        10,
        (i) => _makeDog(
          'Breed$i',
          imageUrl: 'https://example.com/breed$i.jpg',
          temperamentTraits: const [],
        ),
      );
      final q = engine.makeTraitMatch(noTraitPool);
      expect(q.type, equals(QuizType.nameFromPhoto));
    });

    test('produces a traitMatch question when traits exist', () {
      final q = engine.makeTraitMatch(testPool);
      expect(
        q.type,
        anyOf(equals(QuizType.traitMatch), equals(QuizType.nameFromPhoto)),
      );
      if (q.type == QuizType.traitMatch) {
        expect(q.options.length, equals(4));
        expect(q.correctIndex, greaterThanOrEqualTo(0));
        expect(q.correctIndex, lessThan(4));
        expect(
          q.correctDog.temperamentTraits,
          contains(q.options[q.correctIndex]),
        );
      }
    });
  });

  group('makeOddOneOut', () {
    test('correctDog has different sizeCategory from majority', () {
      QuizQuestion? oddQ;
      for (var seed = 0; seed < 50; seed++) {
        final eng = QuizEngine(Random(seed));
        final q = eng.makeOddOneOut(testPool);
        if (q.type == QuizType.oddOneOut) {
          oddQ = q;
          break;
        }
      }
      expect(
        oddQ,
        isNotNull,
        reason: 'Should produce oddOneOut within 50 seeds',
      );
      if (oddQ != null) {
        expect(oddQ.photoDogs, isNotNull);
        expect(oddQ.photoDogs!.length, equals(4));
        final otherDogs = oddQ.photoDogs!
            .where((d) => d.name != oddQ!.correctDog.name)
            .toList();
        final majoritySize = otherDogs.first.sizeCategory;
        for (final d in otherDogs) {
          expect(d.sizeCategory, equals(majoritySize));
        }
        expect(oddQ.correctDog.sizeCategory, isNot(equals(majoritySize)));
      }
    });
  });

  group('makeLifespanGuess', () {
    test('options are lifespan buckets', () {
      final q = engine.makeLifespanGuess(testPool);
      const buckets = ['6-8 years', '9-11 years', '12-14 years', '15-18 years'];
      expect(q.type, equals(QuizType.lifespanGuess));
      expect(q.options.length, equals(4));
      for (final opt in q.options) {
        expect(buckets, contains(opt));
      }
      expect(q.options.toSet().length, equals(q.options.length));
    });
  });

  group('makeSilhouetteRound', () {
    test('type is QuizType.silhouetteRound', () {
      final q = engine.makeSilhouetteRound(testPool);
      expect(q.type, equals(QuizType.silhouetteRound));
      expect(q.options.length, equals(4));
      expect(q.options[q.correctIndex], equals(q.correctDog.name));
    });
  });

  // ─── New question type tests ────────────────────────────────────────────────

  group('makeExerciseFromPhoto', () {
    test('options are four exercise levels', () {
      final q = engine.makeExerciseFromPhoto(testPool);
      expect(q.type, equals(QuizType.exerciseFromPhoto));
      expect(q.options, equals(['Low', 'Moderate', 'High', 'Very High']));
      expect(q.correctIndex, greaterThanOrEqualTo(0));
      expect(q.correctIndex, lessThan(4));
    });

    test('correct answer matches dog exercise needs', () {
      final q = engine.makeExerciseFromPhoto(testPool);
      final expected = q.correctDog.exerciseNeeds
          .split(' ')
          .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
      expect(q.options[q.correctIndex], equals(expected));
    });
  });

  group('makeWeightGuess', () {
    test('produces question with weight buckets', () {
      final q = engine.makeWeightGuess(testPool);
      // May fall back to nameFromPhoto if weight is unparseable
      expect(
        q.type,
        anyOf(equals(QuizType.weightGuess), equals(QuizType.nameFromPhoto)),
      );
      if (q.type == QuizType.weightGuess) {
        expect(q.options.length, equals(4));
        expect(q.correctIndex, greaterThanOrEqualTo(0));
        expect(q.correctIndex, lessThan(4));
        // No duplicate options
        expect(q.options.toSet().length, equals(q.options.length));
      }
    });
  });

  group('makeOriginFromBreed', () {
    test('produces question with origin options', () {
      final q = engine.makeOriginFromBreed(testPool);
      expect(
        q.type,
        anyOf(
          equals(QuizType.originFromBreed),
          equals(QuizType.nameFromPhoto),
        ),
      );
      if (q.type == QuizType.originFromBreed) {
        expect(q.options.length, equals(4));
        expect(q.correctIndex, greaterThanOrEqualTo(0));
        expect(q.correctIndex, lessThan(4));
        // Correct answer should match the dog's parsed origin
        final correctOrigin = engine.parseOrigin(q.correctDog.habitat);
        expect(q.options[q.correctIndex], equals(correctOrigin));
      }
    });

    test('falls back when origin is Unknown', () {
      final noOriginPool = List.generate(
        10,
        (i) => _makeDog(
          'Breed$i',
          habitat: 'Companion',
          imageUrl: 'https://example.com/breed$i.jpg',
        ),
      );
      final q = engine.makeOriginFromBreed(noOriginPool);
      expect(q.type, equals(QuizType.nameFromPhoto));
    });
  });

  group('makeBreedFromClue', () {
    test('has clueText and 4 breed name options', () {
      final q = engine.makeBreedFromClue(testPool);
      expect(
        q.type,
        anyOf(
          equals(QuizType.breedFromClue),
          equals(QuizType.nameFromPhoto),
        ),
      );
      if (q.type == QuizType.breedFromClue) {
        expect(q.clueText, isNotNull);
        expect(q.clueText!.length, greaterThan(10));
        expect(q.options.length, equals(4));
        expect(q.options[q.correctIndex], equals(q.correctDog.name));
      }
    });

    test('falls back when lore is too short', () {
      final shortLorePool = List.generate(
        10,
        (i) => _makeDog(
          'Breed$i',
          lore: 'Short.',
          imageUrl: 'https://example.com/breed$i.jpg',
        ),
      );
      final q = engine.makeBreedFromClue(shortLorePool);
      expect(q.type, equals(QuizType.nameFromPhoto));
    });
  });

  group('makeCompareBreeds', () {
    test('produces question with 2 dogs and 2 options', () {
      // Try multiple seeds since comparison needs 3+ year lifespan difference
      QuizQuestion? compareQ;
      for (var seed = 0; seed < 50; seed++) {
        final eng = QuizEngine(Random(seed));
        final q = eng.makeCompareBreeds(testPool);
        if (q.type == QuizType.compareBreeds) {
          compareQ = q;
          break;
        }
      }
      expect(
        compareQ,
        isNotNull,
        reason: 'Should produce compareBreeds within 50 seeds',
      );
      if (compareQ != null) {
        expect(compareQ.options.length, equals(2));
        expect(compareQ.photoDogs, isNotNull);
        expect(compareQ.photoDogs!.length, equals(2));
        expect(
          compareQ.correctDog.name,
          equals(compareQ.options[compareQ.correctIndex]),
        );
        // The correct dog should have a longer lifespan
        final midA = engine.parseMidLifespan(compareQ.photoDogs![0].lifespan);
        final midB = engine.parseMidLifespan(compareQ.photoDogs![1].lifespan);
        final correctMid =
            engine.parseMidLifespan(compareQ.correctDog.lifespan);
        expect(correctMid, equals(midA >= midB ? midA : midB));
      }
    });
  });

  // ─── getFunFact tests ───────────────────────────────────────────────────────

  group('getFunFact', () {
    test('returns non-empty string for every question type', () {
      for (final type in QuizType.values) {
        final q = engine.makeQuestionOfType(
          type,
          testPool,
          10,
          QuizDifficulty.normal,
        );
        final fact = engine.getFunFact(q);
        expect(
          fact,
          isNotEmpty,
          reason: 'getFunFact should return non-empty for $type',
        );
        expect(
          fact.length,
          greaterThan(10),
          reason: 'Fun fact for $type should be substantial',
        );
      }
    });
  });

  // ─── makeQuestionOfType ─────────────────────────────────────────────────────

  group('makeQuestionOfType', () {
    test('dispatches correctly for each quiz type', () {
      const types = QuizType.values;
      for (final type in types) {
        final q = engine.makeQuestionOfType(
          type,
          testPool,
          10,
          QuizDifficulty.normal,
        );
        expect(
          q.type,
          anyOf(equals(type), equals(QuizType.nameFromPhoto)),
          reason:
              'makeQuestionOfType($type) returned unexpected type ${q.type}',
        );
        expect(q.options, isNotEmpty);
        expect(q.correctIndex, greaterThanOrEqualTo(0));
        expect(q.correctIndex, lessThan(q.options.length));
      }
    });
  });

  // ─── weightedTypes tests ──────────────────────────────────────────────────

  group('weightedTypes', () {
    test('beginner has more nameFromPhoto entries than other types', () {
      final types = engine.weightedTypes(1, QuizDifficulty.beginner);
      final nameCount = types.where((t) => t == QuizType.nameFromPhoto).length;
      for (final otherType in QuizType.values) {
        if (otherType == QuizType.nameFromPhoto) continue;
        final otherCount = types.where((t) => t == otherType).length;
        expect(
          nameCount,
          greaterThanOrEqualTo(otherCount),
          reason:
              'beginner should have nameFromPhoto >= $otherType ($nameCount vs $otherCount)',
        );
      }
    });

    test('expert includes silhouetteRound', () {
      final types = engine.weightedTypes(20, QuizDifficulty.expert);
      expect(types, contains(QuizType.silhouetteRound));
    });

    test('expert includes new question types', () {
      final types = engine.weightedTypes(20, QuizDifficulty.expert);
      expect(types, contains(QuizType.exerciseFromPhoto));
      expect(types, contains(QuizType.weightGuess));
      expect(types, contains(QuizType.originFromBreed));
      expect(types, contains(QuizType.breedFromClue));
      expect(types, contains(QuizType.compareBreeds));
    });

    test('normal mid-level includes origin and weight types', () {
      final types = engine.weightedTypes(10, QuizDifficulty.normal);
      expect(types, contains(QuizType.originFromBreed));
      expect(types, contains(QuizType.weightGuess));
      expect(types, contains(QuizType.breedFromClue));
    });
  });

  // ─── Edge cases ───────────────────────────────────────────────────────────

  group('Edge cases', () {
    test(
        'oddOneOut falls back to nameFromPhoto when all dogs have the same size',
        () {
      final sameSizePool = List.generate(
        10,
        (i) => _makeDog(
          'UniformBreed$i',
          sizeCategory: 'medium',
          imageUrl: 'https://example.com/uniform$i.jpg',
        ),
      );
      final q = engine.makeOddOneOut(sameSizePool);
      expect(q.type, equals(QuizType.nameFromPhoto));
    });

    test(
        'traitMatch falls back to nameFromPhoto when all dogs have empty traits',
        () {
      final noTraitPool = List.generate(
        10,
        (i) => _makeDog(
          'EmptyTraitBreed$i',
          imageUrl: 'https://example.com/empty$i.jpg',
          temperamentTraits: const [],
        ),
      );
      final q = engine.makeTraitMatch(noTraitPool);
      expect(q.type, equals(QuizType.nameFromPhoto));
    });

    test('weightGuess falls back when weight is empty', () {
      final noWeightPool = List.generate(
        10,
        (i) => _makeDog(
          'NoWeight$i',
          weight: '',
          imageUrl: 'https://example.com/noweight$i.jpg',
        ),
      );
      final q = engine.makeWeightGuess(noWeightPool);
      expect(q.type, equals(QuizType.nameFromPhoto));
    });
  });

  // ─── parseWeight tests ───────────────────────────────────────────────────

  group('parseWeight', () {
    test('parses first number from range string', () {
      expect(engine.parseWeight('25-36 kg'), equals(25));
      expect(engine.parseWeight('1-3 kg'), equals(1));
      expect(engine.parseWeight('50-80 kg'), equals(50));
    });

    test('parses single-value weight string', () {
      expect(engine.parseWeight('30 kg'), equals(30));
    });

    test('returns null for empty string', () {
      expect(engine.parseWeight(''), isNull);
    });

    test('returns null for non-numeric string', () {
      expect(engine.parseWeight('varies'), isNull);
    });
  });

  // ─── parseMidLifespan boundary tests ────────────────────────────────────

  group('parseMidLifespan boundaries', () {
    test('rounds half-values correctly (10-11 years = 11)', () {
      // (10 + 11) / 2 = 10.5 → rounds to 11
      expect(engine.parseMidLifespan('10-11 years'), equals(11));
    });

    test('handles lifespan with no unit word', () {
      // Plain range without "years"
      expect(engine.parseMidLifespan('8-12'), equals(10));
    });
  });

  // ─── tooSimilar boundary tests ───────────────────────────────────────────

  group('tooSimilar boundaries', () {
    test('returns false for two single-word unrelated names', () {
      expect(engine.tooSimilar('Beagle', 'Boxer'), isFalse);
    });

    test('returns true when single-word name is contained in multi-word name',
        () {
      // "Poodle" is contained in "Standard Poodle"
      expect(engine.tooSimilar('Poodle', 'Standard Poodle'), isTrue);
    });

    test('last-word check does not fire for single-word names', () {
      // Both single-word: last-word guard requires length > 1 on both
      // "Hound" vs "Hound" would return true via substring check, not last-word
      expect(engine.tooSimilar('Hound', 'Greyhound'), isTrue); // contains check
    });

    test('returns false when only first words match', () {
      // "German Shepherd" vs "German Pinscher" share first word, not last
      expect(engine.tooSimilar('German Shepherd', 'German Pinscher'), isFalse);
    });
  });

  // ─── makeSizeFromPhoto unknown size fallback ─────────────────────────────

  group('makeSizeFromPhoto unknown size', () {
    test('falls back to index 1 (medium) for unrecognized sizeCategory', () {
      final unknownSizePool = List.generate(
        5,
        (i) => _makeDog(
          'TinyBreed$i',
          sizeCategory: 'tiny',
          imageUrl: 'https://example.com/tiny$i.jpg',
        ),
      );
      final q = engine.makeSizeFromPhoto(unknownSizePool);
      expect(q.type, equals(QuizType.sizeFromPhoto));
      // "tiny" is not in ['small','medium','large','giant'] → idx == -1 → correctIndex == 1
      expect(q.correctIndex, equals(1));
      expect(q.options[q.correctIndex], equals('medium'));
    });
  });

  // ─── makeExerciseFromPhoto unknown exercise level fallback ───────────────

  group('makeExerciseFromPhoto unknown exercise level', () {
    test('falls back to index 1 (Moderate) for unrecognized exerciseNeeds', () {
      final unknownExPool = List.generate(
        5,
        (i) => _makeDog(
          'ExtremeBreed$i',
          exerciseNeeds: 'extreme',
          imageUrl: 'https://example.com/extreme$i.jpg',
        ),
      );
      final q = engine.makeExerciseFromPhoto(unknownExPool);
      expect(q.type, equals(QuizType.exerciseFromPhoto));
      // "Extreme" not in levels → idx == -1 → correctIndex == 1 (Moderate)
      expect(q.correctIndex, equals(1));
      expect(q.options[q.correctIndex], equals('Moderate'));
    });

    test('handles very high exercise level (two-word capitalisation)', () {
      final veryHighPool = List.generate(
        5,
        (i) => _makeDog(
          'ActiveBreed$i',
          exerciseNeeds: 'very high',
          imageUrl: 'https://example.com/active$i.jpg',
        ),
      );
      final q = engine.makeExerciseFromPhoto(veryHighPool);
      expect(q.type, equals(QuizType.exerciseFromPhoto));
      expect(q.options[q.correctIndex], equals('Very High'));
    });
  });

  // ─── makeGroupFromBreed tests ────────────────────────────────────────────

  group('makeGroupFromBreed', () {
    test('produces valid groupFromBreed question with 4 options', () {
      final q = engine.makeGroupFromBreed(testPool);
      expect(q.type, equals(QuizType.groupFromBreed));
      expect(q.options.length, equals(4));
      expect(q.correctIndex, greaterThanOrEqualTo(0));
      expect(q.correctIndex, lessThan(4));
    });

    test('correct option is a valid AKC group name', () {
      final q = engine.makeGroupFromBreed(testPool);
      final knownGroups = [
        'Sporting Group',
        'Hound Group',
        'Working Group',
        'Terrier Group',
        'Toy Group',
        'Non-Sporting Group',
        'Herding Group',
        'Non-Sporting',
      ];
      expect(knownGroups, contains(q.options[q.correctIndex]));
    });

    test('no duplicate options', () {
      final q = engine.makeGroupFromBreed(testPool);
      expect(q.options.toSet().length, equals(q.options.length));
    });

    test('dog with no family match defaults to Non-Sporting', () {
      // A dog whose name matches no keyword in any DogGroup
      final noGroupPool = List.generate(
        5,
        (i) => _makeDog(
          'MysteryBreed$i',
          imageUrl: 'https://example.com/mystery$i.jpg',
        ),
      );
      final q = engine.makeGroupFromBreed(noGroupPool);
      expect(q.type, equals(QuizType.groupFromBreed));
      expect(q.options[q.correctIndex], equals('Non-Sporting'));
    });
  });

  // ─── makeCompareBreeds minimum pool ──────────────────────────────────────

  group('makeCompareBreeds edge cases', () {
    test('falls back when fewer than 4 dogs have lifespans', () {
      final tinyPool = [
        _makeDog(
          'BriefA',
          lifespan: '8-10 years',
          imageUrl: 'https://example.com/a.jpg',
        ),
        _makeDog(
          'BriefB',
          lifespan: '10-12 years',
          imageUrl: 'https://example.com/b.jpg',
        ),
        _makeDog('BriefC', lifespan: '', imageUrl: 'https://example.com/c.jpg'),
      ];
      final q = engine.makeCompareBreeds(tinyPool);
      // Only 2 dogs have lifespans — candidates.length < 4 → fallback
      expect(q.type, equals(QuizType.nameFromPhoto));
    });

    test('falls back when no pair has lifespan difference >= 3 years', () {
      // All dogs within 2 years of each other
      final closeLongevityPool = List.generate(
        6,
        (i) => _makeDog(
          'SimilarLifespan$i',
          lifespan: '10-12 years',
          imageUrl: 'https://example.com/similar$i.jpg',
        ),
      );
      final q = engine.makeCompareBreeds(closeLongevityPool);
      expect(q.type, equals(QuizType.nameFromPhoto));
    });

    test('correctIndex is 0 or 1 and matches the longer-lived dog', () {
      // Guarantee a clear lifespan difference
      final clearPool = [
        _makeDog(
          'ShortLived',
          lifespan: '7-9 years',
          imageUrl: 'https://example.com/short.jpg',
        ),
        _makeDog(
          'LongLived',
          lifespan: '14-16 years',
          imageUrl: 'https://example.com/long.jpg',
        ),
        _makeDog(
          'MidLived',
          lifespan: '11-13 years',
          imageUrl: 'https://example.com/mid.jpg',
        ),
        _makeDog(
          'AnotherMid',
          lifespan: '10-12 years',
          imageUrl: 'https://example.com/anotherMid.jpg',
        ),
      ];
      // Try seeds until compareBreeds fires (RNG may pick different pairs)
      QuizQuestion? compareQ;
      for (var seed = 0; seed < 100; seed++) {
        final eng = QuizEngine(Random(seed));
        final q = eng.makeCompareBreeds(clearPool);
        if (q.type == QuizType.compareBreeds) {
          compareQ = q;
          break;
        }
      }
      expect(
        compareQ,
        isNotNull,
        reason: 'Should produce compareBreeds with clear lifespan difference',
      );
      if (compareQ != null) {
        expect(compareQ.correctIndex, anyOf(equals(0), equals(1)));
        final midCorrect =
            engine.parseMidLifespan(compareQ.correctDog.lifespan);
        final midOther = engine.parseMidLifespan(
          compareQ.photoDogs!
              .firstWhere((d) => d.name != compareQ!.correctDog.name)
              .lifespan,
        );
        expect(midCorrect, greaterThan(midOther));
      }
    });
  });

  // ─── getFunFact completeness tests ──────────────────────────────────────

  group('getFunFact completeness', () {
    test('nameFromPhoto variant selection uses lore when available', () {
      // Dog with lore but no known origin and no health conditions
      final q = QuizQuestion(
        correctDog: _makeDog(
          'LoreOnlyDog',
          habitat: 'Companion', // no "Origin:" → Unknown
          lore: 'A storied breed with a very long and interesting history.',
          healthPredispositions: const [],
        ),
        options: ['LoreOnlyDog', 'Other'],
        correctIndex: 0,
        type: QuizType.nameFromPhoto,
      );
      final fact = engine.getFunFact(q);
      expect(fact, isNotEmpty);
      expect(fact.length, greaterThan(10));
    });

    test('nameFromPhoto fallback when no lore, no origin, no health, no diet',
        () {
      final q = QuizQuestion(
        correctDog: _makeDog(
          'BareMinimumDog',
          habitat: 'Companion',
          lore: 'Short.',
          healthPredispositions: const [],
        ),
        options: ['BareMinimumDog', 'Other'],
        correctIndex: 0,
        type: QuizType.nameFromPhoto,
      );
      final fact = engine.getFunFact(q);
      // Variants list is empty → falls back to single-sentence fact
      expect(fact, contains('BareMinimumDog'));
      expect(fact, isNotEmpty);
    });

    test('exerciseFromPhoto fun fact appends dietNotes when present', () {
      const dogWithDiet = Dog(
        name: 'DietDog',
        scientificName: '',
        imageUrl: 'https://example.com/diet.jpg',
        audioUrl: '',
        lore: 'A diet-conscious breed.',
        habitat: 'Non-Sporting Group | Origin: France',
        conservationStatus: 'Domesticated',
        rarity: Rarity.common,
        baseXp: 20,
        exerciseNeeds: 'moderate',
        dietNotes: 'Needs low-fat food to avoid pancreatitis.',
      );
      final q = QuizQuestion(
        correctDog: dogWithDiet,
        options: ['Low', 'Moderate', 'High', 'Very High'],
        correctIndex: 1,
        type: QuizType.exerciseFromPhoto,
      );
      final fact = engine.getFunFact(q);
      expect(fact, contains('Needs low-fat food'));
    });

    test(
        'compareBreeds getFunFact falls back gracefully when photoDogs is null',
        () {
      final q = QuizQuestion(
        correctDog: _makeDog(
          'LongestLivedDog',
          lifespan: '14-16 years',
          imageUrl: 'https://example.com/longest.jpg',
        ),
        options: ['LongestLivedDog', 'Other'],
        correctIndex: 0,
        type: QuizType.compareBreeds,
        // photoDogs intentionally omitted (null)
      );
      final fact = engine.getFunFact(q);
      // Falls back to single-dog lifespan statement
      expect(fact, contains('LongestLivedDog'));
      expect(fact, contains('14-16 years'));
    });

    test('sizeFromPhoto fun fact includes weight and exercise', () {
      final q = QuizQuestion(
        correctDog:
            _makeDog('SizeDog', weight: '20-30 kg', exerciseNeeds: 'high'),
        options: ['small', 'medium', 'large', 'giant'],
        correctIndex: 2,
        type: QuizType.sizeFromPhoto,
      );
      final fact = engine.getFunFact(q);
      expect(fact, contains('20-30 kg'));
      expect(fact, contains('high'));
    });

    test('sizeFromPhoto fun fact notes high grooming requirement', () {
      final q = QuizQuestion(
        correctDog: _makeDog('Fluffy', groomingNeeds: 'high'),
        options: ['small', 'medium', 'large', 'giant'],
        correctIndex: 1,
        type: QuizType.sizeFromPhoto,
      );
      final fact = engine.getFunFact(q);
      expect(fact.toLowerCase(), contains('grooming'));
    });

    test('oddOneOut fun fact references majority size and oddity', () {
      final odd = _makeDog(
        'OddGiant',
        sizeCategory: 'giant',
        imageUrl: 'https://example.com/oddgiant.jpg',
      );
      final others = [
        _makeDog(
          'SmallA',
          sizeCategory: 'small',
          imageUrl: 'https://example.com/sa.jpg',
        ),
        _makeDog(
          'SmallB',
          sizeCategory: 'small',
          imageUrl: 'https://example.com/sb.jpg',
        ),
        _makeDog(
          'SmallC',
          sizeCategory: 'small',
          imageUrl: 'https://example.com/sc.jpg',
        ),
      ];
      final q = QuizQuestion(
        correctDog: odd,
        options: [odd.name, others[0].name, others[1].name, others[2].name],
        correctIndex: 0,
        type: QuizType.oddOneOut,
        photoDogs: [odd, ...others],
      );
      final fact = engine.getFunFact(q);
      expect(fact, contains('OddGiant'));
      expect(fact, contains('giant'));
      expect(fact, contains('small'));
    });
  });

  // ─── weightedTypes boundary levels ──────────────────────────────────────

  group('weightedTypes level boundaries', () {
    test('normal at level 4 (< 5) returns beginner-style types', () {
      final types = engine.weightedTypes(4, QuizDifficulty.normal);
      // Level < 5 should use the simplified pool without traitMatch
      expect(types, isNot(contains(QuizType.traitMatch)));
      expect(types, isNot(contains(QuizType.silhouetteRound)));
    });

    test('normal at level 5 (boundary) includes traitMatch', () {
      final types = engine.weightedTypes(5, QuizDifficulty.normal);
      expect(types, contains(QuizType.traitMatch));
    });

    test('normal at level 14 (< 15) does not include silhouetteRound', () {
      final types = engine.weightedTypes(14, QuizDifficulty.normal);
      expect(types, isNot(contains(QuizType.silhouetteRound)));
    });

    test('normal at level 15 (boundary) includes all types', () {
      final types = engine.weightedTypes(15, QuizDifficulty.normal);
      expect(types, containsAll(QuizType.values));
    });

    test('beginner never includes silhouetteRound or compareBreeds', () {
      final types = engine.weightedTypes(99, QuizDifficulty.beginner);
      expect(types, isNot(contains(QuizType.silhouetteRound)));
      expect(types, isNot(contains(QuizType.compareBreeds)));
    });
  });

  // ─── makeOriginFromBreed insufficient distractors ────────────────────────

  group('makeOriginFromBreed insufficient distractors', () {
    test('falls back when fewer than 3 distinct other origins exist', () {
      // All dogs share origin Germany, making it impossible to gather 3 wrong origins
      final sameOriginPool = List.generate(
        8,
        (i) => _makeDog(
          'GermanBreed$i',
          habitat: 'Working Group | Origin: Germany',
          imageUrl: 'https://example.com/german$i.jpg',
        ),
      );
      final q = engine.makeOriginFromBreed(sameOriginPool);
      // correctOrigin == 'Germany' but allOrigins is empty → fallback
      expect(q.type, equals(QuizType.nameFromPhoto));
    });

    test('succeeds when exactly 3 distinct other origins are available', () {
      final mixedOriginPool = [
        _makeDog(
          'GermanBreed',
          habitat: 'Herding Group | Origin: Germany',
          imageUrl: 'https://example.com/german.jpg',
        ),
        _makeDog(
          'FrenchBreed',
          habitat: 'Non-Sporting Group | Origin: France',
          imageUrl: 'https://example.com/french.jpg',
        ),
        _makeDog(
          'EnglishBreed',
          habitat: 'Hound Group | Origin: England',
          imageUrl: 'https://example.com/english.jpg',
        ),
        _makeDog(
          'MexicanBreed',
          habitat: 'Toy Group | Origin: Mexico',
          imageUrl: 'https://example.com/mexican.jpg',
        ),
      ];
      // Regardless of which dog is chosen as correct, the other 3 provide enough wrong origins
      bool gotOriginQuestion = false;
      for (var seed = 0; seed < 20; seed++) {
        final eng = QuizEngine(Random(seed));
        final q = eng.makeOriginFromBreed(mixedOriginPool);
        if (q.type == QuizType.originFromBreed) {
          gotOriginQuestion = true;
          expect(q.options.length, equals(4));
          expect(q.options.toSet().length, equals(4));
          break;
        }
      }
      expect(
        gotOriginQuestion,
        isTrue,
        reason: 'Should produce originFromBreed with 4 distinct origins',
      );
    });
  });

  // ─── makeBreedFromClue minimum candidates ────────────────────────────────

  group('makeBreedFromClue minimum candidates', () {
    test('falls back when fewer than 4 dogs have sufficient lore', () {
      // Only 3 dogs have lore >= 40 chars
      final mixedLorePool = [
        _makeDog(
          'GoodLore1',
          lore: 'This is a wonderful breed with an excellent long history.',
          imageUrl: 'https://example.com/gl1.jpg',
        ),
        _makeDog(
          'GoodLore2',
          lore: 'Another breed with a fantastic and very detailed background.',
          imageUrl: 'https://example.com/gl2.jpg',
        ),
        _makeDog(
          'GoodLore3',
          lore: 'Yet another great breed with interesting origins dating back.',
          imageUrl: 'https://example.com/gl3.jpg',
        ),
        _makeDog(
          'ShortLore1',
          lore: 'Too short.',
          imageUrl: 'https://example.com/sl1.jpg',
        ),
        _makeDog(
          'ShortLore2',
          lore: 'Also short.',
          imageUrl: 'https://example.com/sl2.jpg',
        ),
      ];
      final q = engine.makeBreedFromClue(mixedLorePool);
      // Only 3 candidates → candidates.length < 4 → fallback
      expect(q.type, equals(QuizType.nameFromPhoto));
    });

    test('succeeds when exactly 4 dogs have sufficient lore', () {
      final exactlyFourPool = List.generate(
        4,
        (i) => _makeDog(
          'WellDocumentedBreed$i',
          lore: 'This breed has a long and storied history in the mountains.',
          imageUrl: 'https://example.com/wd$i.jpg',
        ),
      );
      final q = engine.makeBreedFromClue(exactlyFourPool);
      expect(
        q.type,
        anyOf(
          equals(QuizType.breedFromClue),
          equals(QuizType.nameFromPhoto),
        ),
      );
      if (q.type == QuizType.breedFromClue) {
        expect(q.options.length, equals(4));
        expect(q.clueText, isNotNull);
      }
    });
  });

  // ─── pickDistractors with duplicate-prone pools ───────────────────────────

  group('pickDistractors robustness', () {
    test('never returns more distractors than requested', () {
      for (var seed = 0; seed < 20; seed++) {
        final eng = QuizEngine(Random(seed));
        final correct = testPool.first;
        final distractors = eng.pickDistractors(testPool, correct, 3);
        expect(distractors.length, lessThanOrEqualTo(3));
      }
    });

    test('handles pool where all other dogs are too similar to the correct dog',
        () {
      // All dogs named "Poodle Variant N" — tooSimilar will fire for most
      final poodlePool = [
        _makeDog('Standard Poodle', imageUrl: 'https://example.com/sp.jpg'),
        _makeDog('Miniature Poodle', imageUrl: 'https://example.com/mp.jpg'),
        _makeDog('Toy Poodle', imageUrl: 'https://example.com/tp.jpg'),
        _makeDog('Poodle Mix', imageUrl: 'https://example.com/pm.jpg'),
      ];
      final correct = poodlePool.first; // Standard Poodle
      // The fallback loop should still provide distractors despite tooSimilar constraints
      final distractors = engine.pickDistractors(poodlePool, correct, 3);
      expect(distractors, isNotEmpty);
      expect(distractors.every((d) => d.name != correct.name), isTrue);
    });
  });

  // ─── QuizQuestion.hintUsed default state ─────────────────────────────────

  group('QuizQuestion', () {
    test('hintUsed defaults to false on construction', () {
      final q = engine.makeNameFromPhoto(testPool);
      expect(q.hintUsed, isFalse);
    });

    test('hintUsed can be set to true', () {
      final q = engine.makeNameFromPhoto(testPool);
      q.hintUsed = true;
      expect(q.hintUsed, isTrue);
    });
  });

  // ─── QuizTypeX extension tests ────────────────────────────────────────────

  group('QuizTypeX extensions', () {
    test('xpValue is positive for all types', () {
      for (final type in QuizType.values) {
        expect(
          type.xpValue,
          greaterThan(0),
          reason: '${type.name} should have positive xpValue',
        );
      }
    });

    test('expert types have higher or equal xpValue than easy types', () {
      expect(
        QuizType.silhouetteRound.xpValue,
        greaterThanOrEqualTo(QuizType.nameFromPhoto.xpValue),
      );
      expect(
        QuizType.compareBreeds.xpValue,
        greaterThanOrEqualTo(QuizType.nameFromPhoto.xpValue),
      );
    });

    test('label is non-empty for all types', () {
      for (final type in QuizType.values) {
        expect(
          type.label,
          isNotEmpty,
          reason: '${type.name} should have non-empty label',
        );
      }
    });

    test('prompt is non-empty for all types', () {
      for (final type in QuizType.values) {
        expect(
          type.prompt,
          isNotEmpty,
          reason: '${type.name} should have non-empty prompt',
        );
      }
    });

    test('color is a valid Color for all types', () {
      for (final type in QuizType.values) {
        expect(
          type.color,
          isNotNull,
          reason: '${type.name} should have a color',
        );
      }
    });

    test('icon is a valid IconData for all types', () {
      for (final type in QuizType.values) {
        expect(
          type.icon,
          isNotNull,
          reason: '${type.name} should have an icon',
        );
      }
    });
  });
}
