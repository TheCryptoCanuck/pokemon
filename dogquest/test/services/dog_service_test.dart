// test/services/dog_service_test.dart
//
// Comprehensive unit tests for DogService, covering:
//   - load() — data integrity checks against the real dogs.json asset
//   - lookup() — exact case-sensitive lookup
//   - lookupByCommonName() — all four resolution strategies
//   - Alias coverage — every entry in _nameAliases resolves to a non-null Dog
//   - Dead-label aliases — dingo, dhole, african hunting dog
//   - Case-insensitive lookup
//   - Normalized word-order matching
//   - Poodle variant grouping via poodleAlternative()
//   - Unknown breed sentinel via unknownDog()
//   - weightedRandomDog() — distribution and determinism
//   - filter() and searchBreeds()

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:dogquest/constants.dart';
import 'package:dogquest/services/dog_service.dart';

void main() {
  // Initialise the Flutter test binding — required for rootBundle access.
  TestWidgetsFlutterBinding.ensureInitialized();

  late DogService service;

  setUpAll(() async {
    service = DogService();
    // Point the test bundle at the real asset tree so rootBundle can resolve
    // 'assets/dogs.json' exactly as the app does at runtime.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    await service.load();
  });

  // ─── load() ─────────────────────────────────────────────────────────────────

  group('DogService.load()', () {
    test('populates the dogs list with at least one entry', () {
      expect(service.all, isNotEmpty);
    });

    test('every Dog has a non-empty name', () {
      for (final dog in service.all) {
        expect(dog.name, isNotEmpty,
            reason: 'Dog with empty name found in dogs.json');
      }
    });

    test('every Dog has a valid Rarity (not Rarity.unknown from malformed JSON)', () {
      final validRarities = {
        Rarity.common,
        Rarity.uncommon,
        Rarity.rare,
        Rarity.legendary,
      };
      for (final dog in service.all) {
        expect(validRarities, contains(dog.rarity),
            reason: '${dog.name} has unexpected rarity: ${dog.rarity}');
      }
    });

    test('index map keys match each dog\'s own name exactly', () {
      for (final entry in service.index.entries) {
        expect(entry.key, equals(entry.value.name));
      }
    });

    test('all four rarity tiers are represented in the loaded data', () {
      final rarities = service.all.map((d) => d.rarity).toSet();
      expect(rarities, containsAll([
        Rarity.common,
        Rarity.uncommon,
        Rarity.rare,
        Rarity.legendary,
      ]));
    });

    test('loads at least 100 breeds (sanity check for dogs.json completeness)', () {
      expect(service.all.length, greaterThanOrEqualTo(100));
    });
  });

  // ─── lookup() ───────────────────────────────────────────────────────────────

  group('DogService.lookup()', () {
    test('returns the correct dog for an exact case-sensitive name', () {
      final dog = service.lookup('Labrador Retriever');
      expect(dog, isNotNull);
      expect(dog!.name, equals('Labrador Retriever'));
    });

    test('returns null when the name has wrong casing', () {
      expect(service.lookup('labrador retriever'), isNull);
      expect(service.lookup('LABRADOR RETRIEVER'), isNull);
    });

    test('returns null for a name not present in the dataset', () {
      expect(service.lookup('NonexistentBreed123'), isNull);
    });

    test('returns null for an empty string', () {
      expect(service.lookup(''), isNull);
    });

    test('returns dogs of each rarity tier by exact name', () {
      expect(service.lookup('German Shepherd')?.rarity, equals(Rarity.common));
      expect(service.lookup('Bernese Mountain Dog')?.rarity, equals(Rarity.uncommon));
      expect(service.lookup('Afghan Hound')?.rarity, equals(Rarity.rare));
      expect(service.lookup('Catalburun')?.rarity, equals(Rarity.legendary));
    });
  });

  // ─── lookupByCommonName() — resolution strategies ───────────────────────────

  group('DogService.lookupByCommonName()', () {
    test('returns null for an empty string', () {
      expect(service.lookupByCommonName(''), isNull);
    });

    // Strategy 1 — exact match (case-sensitive)
    test('strategy 1: resolves an exact-case name', () {
      final dog = service.lookupByCommonName('Golden Retriever');
      expect(dog, isNotNull);
      expect(dog!.name, equals('Golden Retriever'));
    });

    // Strategy 2 — case-insensitive (includes aliases)
    test('strategy 2: resolves a lowercased name', () {
      final dog = service.lookupByCommonName('golden retriever');
      expect(dog, isNotNull);
      expect(dog!.name, equals('Golden Retriever'));
    });

    test('strategy 2: resolves a fully uppercased name', () {
      final dog = service.lookupByCommonName('BEAGLE');
      expect(dog, isNotNull);
      expect(dog!.name, equals('Beagle'));
    });

    test('strategy 2: resolves an ImageNet alias (japanese spaniel -> Japanese Chin)', () {
      final dog = service.lookupByCommonName('japanese spaniel');
      expect(dog, isNotNull);
      expect(dog!.name, equals('Japanese Chin'));
    });

    test('strategy 2: resolves alias "basset" -> Basset Hound', () {
      final dog = service.lookupByCommonName('basset');
      expect(dog, isNotNull);
      expect(dog!.name, equals('Basset Hound'));
    });

    test('strategy 2: resolves alias "malamute" -> Alaskan Malamute', () {
      final dog = service.lookupByCommonName('malamute');
      expect(dog, isNotNull);
      expect(dog!.name, equals('Alaskan Malamute'));
    });

    test('strategy 2: resolves alias "pembroke" -> Pembroke Welsh Corgi', () {
      final dog = service.lookupByCommonName('pembroke');
      expect(dog, isNotNull);
      expect(dog!.name, equals('Pembroke Welsh Corgi'));
    });

    test('strategy 2: resolves alias "airedale" -> Airedale Terrier', () {
      final dog = service.lookupByCommonName('airedale');
      expect(dog, isNotNull);
      expect(dog!.name, equals('Airedale Terrier'));
    });

    // Strategy 3 — normalised word-order match
    test('strategy 3: resolves word-order variant (Retriever Labrador -> Labrador Retriever)', () {
      final dog = service.lookupByCommonName('Retriever Labrador');
      expect(dog, isNotNull);
      expect(dog!.name, equals('Labrador Retriever'));
    });

    test('strategy 3: resolves hyphenated alias with normalisation', () {
      final dog = service.lookupByCommonName('flat-coated retriever');
      expect(dog, isNotNull);
      expect(dog!.name, equals('Flat-Coated Retriever'));
    });

    // Strategy 4 — partial / substring match
    test('strategy 4: resolves a partial name that is a substring of a full dog name', () {
      final dog = service.lookupByCommonName('wolfhound');
      expect(dog, isNotNull);
    });

    test('returns null for a name with no match at any strategy level', () {
      expect(service.lookupByCommonName('XyzNoSuchBreed999'), isNull);
    });
  });

  // ─── Alias coverage — every _nameAliases entry ──────────────────────────────

  group('DogService alias coverage — all _nameAliases resolve', () {
    // The full alias table from dog_service.dart. Any new alias added to the
    // source must be added here too so the test catches regressions.
    //
    // Each entry is [inputLabel, expectedBreedName].
    const aliasCases = <List<String>>[
      ['japanese spaniel', 'Japanese Chin'],
      ['maltese dog', 'Maltese'],
      ['pekinese', 'Pekingese'],
      ['shih-tzu', 'Shih Tzu'],
      ['toy terrier', 'Toy Terrier'],
      ['rhodesian ridgeback', 'Rhodesian Ridgeback'],
      ['afghan hound', 'Afghan Hound'],
      ['basset', 'Basset Hound'],
      ['bluetick', 'Bluetick Coonhound'],
      ['black-and-tan coonhound', 'Black and Tan Coonhound'],
      ['walker hound', 'Walker Hound'],
      ['english foxhound', 'English Foxhound'],
      ['redbone', 'Redbone Coonhound'],
      ['irish wolfhound', 'Irish Wolfhound'],
      ['italian greyhound', 'Italian Greyhound'],
      ['ibizan hound', 'Ibizan Hound'],
      ['norwegian elkhound', 'Norwegian Elkhound'],
      ['scottish deerhound', 'Scottish Deerhound'],
      ['staffordshire bullterrier', 'Staffordshire Bull Terrier'],
      ['american staffordshire terrier', 'American Staffordshire Terrier'],
      ['bedlington terrier', 'Bedlington Terrier'],
      ['border terrier', 'Border Terrier'],
      ['kerry blue terrier', 'Kerry Blue Terrier'],
      ['irish terrier', 'Irish Terrier'],
      ['norfolk terrier', 'Norfolk Terrier'],
      ['norwich terrier', 'Norwich Terrier'],
      ['yorkshire terrier', 'Yorkshire Terrier'],
      ['wire-haired fox terrier', 'Wire Fox Terrier'],
      ['lakeland terrier', 'Lakeland Terrier'],
      ['sealyham terrier', 'Sealyham Terrier'],
      ['airedale', 'Airedale Terrier'],
      ['cairn', 'Cairn Terrier'],
      ['australian terrier', 'Australian Terrier'],
      ['dandie dinmont', 'Dandie Dinmont Terrier'],
      ['boston bull', 'Boston Terrier'],
      ['miniature schnauzer', 'Miniature Schnauzer'],
      ['giant schnauzer', 'Giant Schnauzer'],
      ['standard schnauzer', 'Standard Schnauzer'],
      ['scotch terrier', 'Scottish Terrier'],
      ['tibetan terrier', 'Tibetan Terrier'],
      ['silky terrier', 'Silky Terrier'],
      ['soft-coated wheaten terrier', 'Soft-Coated Wheaten Terrier'],
      ['west highland white terrier', 'West Highland White Terrier'],
      ['lhasa', 'Lhasa Apso'],
      ['flat-coated retriever', 'Flat-Coated Retriever'],
      ['curly-coated retriever', 'Curly-Coated Retriever'],
      ['golden retriever', 'Golden Retriever'],
      ['labrador retriever', 'Labrador Retriever'],
      ['chesapeake bay retriever', 'Chesapeake Bay Retriever'],
      ['german short-haired pointer', 'German Shorthaired Pointer'],
      ['english setter', 'English Setter'],
      ['irish setter', 'Irish Setter'],
      ['gordon setter', 'Gordon Setter'],
      ['brittany spaniel', 'Brittany'],
      ['clumber', 'Clumber Spaniel'],
      ['english springer', 'English Springer Spaniel'],
      ['welsh springer spaniel', 'Welsh Springer Spaniel'],
      ['cocker spaniel', 'Cocker Spaniel'],
      ['sussex spaniel', 'Sussex Spaniel'],
      ['irish water spaniel', 'Irish Water Spaniel'],
      ['groenendael', 'Belgian Sheepdog'],
      ['malinois', 'Belgian Malinois'],
      ['kelpie', 'Australian Kelpie'],
      ['old english sheepdog', 'Old English Sheepdog'],
      ['shetland sheepdog', 'Shetland Sheepdog'],
      ['border collie', 'Border Collie'],
      ['bouvier des flandres', 'Bouvier des Flandres'],
      ['german shepherd', 'German Shepherd'],
      ['doberman', 'Doberman Pinscher'],
      ['miniature pinscher', 'Miniature Pinscher'],
      ['greater swiss mountain dog', 'Greater Swiss Mountain Dog'],
      ['bernese mountain dog', 'Bernese Mountain Dog'],
      ['appenzeller', 'Appenzeller Sennenhund'],
      ['entlebucher', 'Entlebucher Mountain Dog'],
      ['bull mastiff', 'Bullmastiff'],
      ['tibetan mastiff', 'Tibetan Mastiff'],
      ['french bulldog', 'French Bulldog'],
      ['great dane', 'Great Dane'],
      ['saint bernard', 'Saint Bernard'],
      ['eskimo dog', 'Siberian Husky'],
      ['malamute', 'Alaskan Malamute'],
      ['siberian husky', 'Siberian Husky'],
      ['leonberg', 'Leonberger'],
      ['great pyrenees', 'Great Pyrenees'],
      ['chow', 'Chow Chow'],
      ['brabancon griffon', 'Brussels Griffon'],
      ['pembroke', 'Pembroke Welsh Corgi'],
      ['cardigan', 'Cardigan Welsh Corgi'],
      ['toy poodle', 'Toy Poodle'],
      ['miniature poodle', 'Miniature Poodle'],
      ['standard poodle', 'Standard Poodle'],
      ['mexican hairless', 'Xoloitzcuintli'],
      ['collie', 'Collie'],
      ['boxer', 'Boxer'],
      ['beagle', 'Beagle'],
      ['bloodhound', 'Bloodhound'],
      ['borzoi', 'Borzoi'],
      ['whippet', 'Whippet'],
      ['vizsla', 'Vizsla'],
      ['dalmatian', 'Dalmatian'],
      ['affenpinscher', 'Affenpinscher'],
      ['basenji', 'Basenji'],
      ['pug', 'Pug'],
      ['chihuahua', 'Chihuahua'],
      ['papillon', 'Papillon'],
      ['rottweiler', 'Rottweiler'],
      ['samoyed', 'Samoyed'],
      ['pomeranian', 'Pomeranian'],
      ['keeshond', 'Keeshond'],
      ['kuvasz', 'Kuvasz'],
      ['briard', 'Briard'],
      ['komondor', 'Komondor'],
      ['newfoundland', 'Newfoundland'],
      ['schipperke', 'Schipperke'],
      ['weimaraner', 'Weimaraner'],
      ['otterhound', 'Otterhound'],
      ['bulldog', 'Bulldog'],
      ['akita', 'Akita'],
      ['dachshund', 'Dachshund'],
      ['poodle', 'Poodle'],
      ['bull terrier', 'Bull Terrier'],
    ];

    for (final pair in aliasCases) {
      final input = pair[0];
      final expected = pair[1];
      test('alias "$input" resolves to "$expected"', () {
        final dog = service.lookupByCommonName(input);
        expect(dog, isNotNull,
            reason: 'alias "$input" returned null — '
                '"$expected" may be missing from dogs.json');
        expect(dog!.name, equals(expected),
            reason: 'alias "$input" resolved to "${dog.name}" '
                'instead of "$expected"');
      });
    }
  });

  // ─── Dead label aliases ──────────────────────────────────────────────────────

  group('DogService dead-label aliases', () {
    test('"dingo" alias maps to Carolina Dog', () {
      final dog = service.lookupByCommonName('dingo');
      expect(dog, isNotNull, reason: '"dingo" alias returned null');
      expect(dog!.name, equals('Carolina Dog'));
    });

    test('"dhole" alias maps to Canaan Dog', () {
      final dog = service.lookupByCommonName('dhole');
      expect(dog, isNotNull, reason: '"dhole" alias returned null');
      expect(dog!.name, equals('Canaan Dog'));
    });

    test('"african hunting dog" alias maps to Pharaoh Hound', () {
      final dog = service.lookupByCommonName('african hunting dog');
      expect(dog, isNotNull, reason: '"african hunting dog" alias returned null');
      expect(dog!.name, equals('Pharaoh Hound'));
    });

    test('"eskimo dog" alias maps to Siberian Husky (not American Eskimo)', () {
      final dog = service.lookupByCommonName('eskimo dog');
      expect(dog, isNotNull, reason: '"eskimo dog" alias returned null');
      expect(dog!.name, equals('Siberian Husky'),
          reason: 'ImageNet "Eskimo dog" labels sled dogs, not American Eskimo');
    });
  });

  // ─── Case-insensitive lookup ─────────────────────────────────────────────────

  group('DogService case-insensitive lookup', () {
    test('lookupByCommonName is case-insensitive for canonical breed names', () {
      for (final variant in ['labrador retriever', 'LABRADOR RETRIEVER', 'Labrador Retriever', 'lAbRaDor rEtRiEvEr']) {
        final dog = service.lookupByCommonName(variant);
        expect(dog, isNotNull, reason: 'variant "$variant" returned null');
        expect(dog!.name, equals('Labrador Retriever'),
            reason: 'variant "$variant" resolved to wrong breed');
      }
    });

    test('alias lookup is case-insensitive (exact alias key is lowercase)', () {
      // Aliases are registered with lowercase keys; the code lowercases the
      // input at strategy-2. Confirm the alias key convention holds.
      final dog = service.lookupByCommonName('MALAMUTE');
      expect(dog, isNotNull);
      expect(dog!.name, equals('Alaskan Malamute'));
    });

    test('strategy 2 resolves mixed-case breed name', () {
      final dog = service.lookupByCommonName('GermAn ShEPherd');
      expect(dog, isNotNull);
      expect(dog!.name, equals('German Shepherd'));
    });
  });

  // ─── Normalized word-order matching ─────────────────────────────────────────

  group('DogService._normalizeCommonName (via lookupByCommonName)', () {
    test('strips commas and sorts words for lookup', () {
      final dog = service.lookupByCommonName('Retriever, Golden');
      expect(dog, isNotNull);
      expect(dog!.name, equals('Golden Retriever'));
    });

    test('strips hyphens and sorts words for lookup', () {
      // "Coated-Flat Retriever" → normalized → "coated flat retriever" → matches
      // "Flat-Coated Retriever" which normalizes identically.
      final dog = service.lookupByCommonName('Coated-Flat Retriever');
      expect(dog, isNotNull);
      expect(dog!.name, equals('Flat-Coated Retriever'));
    });

    test('word-order inversion: "Terrier Airedale" resolves to Airedale Terrier', () {
      final dog = service.lookupByCommonName('Terrier Airedale');
      expect(dog, isNotNull);
      expect(dog!.name, equals('Airedale Terrier'));
    });

    test('word-order inversion: "Hound Basset" resolves to Basset Hound', () {
      final dog = service.lookupByCommonName('Hound Basset');
      expect(dog, isNotNull);
      expect(dog!.name, equals('Basset Hound'));
    });

    test('word-order inversion: "Shepherd German" resolves to German Shepherd', () {
      final dog = service.lookupByCommonName('Shepherd German');
      expect(dog, isNotNull);
      expect(dog!.name, equals('German Shepherd'));
    });
  });

  // ─── Poodle variant grouping ─────────────────────────────────────────────────

  group('DogService.poodleAlternative()', () {
    test('"Toy Poodle" offers generic Poodle as alternative', () {
      final alt = service.poodleAlternative('Toy Poodle');
      expect(alt, isNotNull, reason: '"Poodle" must exist in dogs.json');
      expect(alt!.name, equals('Poodle'));
    });

    test('"Miniature Poodle" offers generic Poodle as alternative', () {
      final alt = service.poodleAlternative('Miniature Poodle');
      expect(alt, isNotNull);
      expect(alt!.name, equals('Poodle'));
    });

    test('"Standard Poodle" offers generic Poodle as alternative', () {
      final alt = service.poodleAlternative('Standard Poodle');
      expect(alt, isNotNull);
      expect(alt!.name, equals('Poodle'));
    });

    test('variant lookup is case-insensitive (lowercase input)', () {
      final alt = service.poodleAlternative('toy poodle');
      expect(alt, isNotNull);
      expect(alt!.name, equals('Poodle'));
    });

    test('"Poodle" returns null (no redundant alternative)', () {
      final alt = service.poodleAlternative('Poodle');
      expect(alt, isNull);
    });

    test('non-poodle breed returns null', () {
      expect(service.poodleAlternative('Beagle'), isNull);
      expect(service.poodleAlternative('German Shepherd'), isNull);
      expect(service.poodleAlternative('Golden Retriever'), isNull);
    });

    test('empty string returns null', () {
      expect(service.poodleAlternative(''), isNull);
    });
  });

  // ─── unknownDog() ───────────────────────────────────────────────────────────

  group('DogService.unknownDog()', () {
    test('returns a Dog whose name equals the supplied string', () {
      final dog = service.unknownDog('Mystery Mutt');
      expect(dog.name, equals('Mystery Mutt'));
    });

    test('returns a Dog with Rarity.unknown', () {
      final dog = service.unknownDog('Any Name');
      expect(dog.rarity, equals(Rarity.unknown));
    });

    test('returns a Dog with baseXp of 100', () {
      final dog = service.unknownDog('Any Name');
      expect(dog.baseXp, equals(100));
    });

    test('lore mentions DogQuest by name', () {
      final dog = service.unknownDog('Any Name');
      expect(dog.lore, contains('DogQuest'));
    });

    test('scientificName indicates species is not yet in the database', () {
      final dog = service.unknownDog('Any Name');
      expect(dog.scientificName, isNotEmpty);
      expect(dog.scientificName.toLowerCase(), contains('not yet'));
    });

    test('returns distinct Dog objects for different input names', () {
      final a = service.unknownDog('Alpha');
      final b = service.unknownDog('Beta');
      expect(a.name, isNot(equals(b.name)));
    });

    test('imageUrl and audioUrl are empty strings', () {
      final dog = service.unknownDog('Test');
      expect(dog.imageUrl, equals(''));
      expect(dog.audioUrl, equals(''));
    });
  });

  // ─── weightedRandomDog() ────────────────────────────────────────────────────

  group('DogService.weightedRandomDog()', () {
    test('always returns a Dog that exists in the all list', () {
      final rng = Random(42);
      final names = service.all.map((d) => d.name).toSet();
      for (var i = 0; i < 50; i++) {
        final dog = service.weightedRandomDog(rng);
        expect(names, contains(dog.name));
      }
    });

    test('returns a dog with Rarity.common when RNG value is below 0.60', () {
      final rng = _FixedRandom(0.30);
      final dog = service.weightedRandomDog(rng);
      expect(dog.rarity, equals(Rarity.common));
    });

    test('returns a dog with Rarity.uncommon when RNG value is in [0.60, 0.85)', () {
      final rng = _FixedRandom(0.70);
      final dog = service.weightedRandomDog(rng);
      expect(dog.rarity, equals(Rarity.uncommon));
    });

    test('returns a dog with Rarity.rare when RNG value is in [0.85, 0.97)', () {
      final rng = _FixedRandom(0.90);
      final dog = service.weightedRandomDog(rng);
      expect(dog.rarity, equals(Rarity.rare));
    });

    test('returns a dog with Rarity.legendary when RNG value is >= 0.97', () {
      final rng = _FixedRandom(0.99);
      final dog = service.weightedRandomDog(rng);
      expect(dog.rarity, equals(Rarity.legendary));
    });

    test('distribution over 1000 samples roughly matches intended weights', () {
      final rng = Random(0);
      final counts = <Rarity, int>{
        Rarity.common: 0,
        Rarity.uncommon: 0,
        Rarity.rare: 0,
        Rarity.legendary: 0,
      };
      const n = 1000;
      for (var i = 0; i < n; i++) {
        final rarity = service.weightedRandomDog(rng).rarity;
        counts[rarity] = (counts[rarity] ?? 0) + 1;
      }
      // Allow ±8% tolerance around the target proportions.
      expect(counts[Rarity.common]!, inInclusiveRange(520, 680));    // target 60%
      expect(counts[Rarity.uncommon]!, inInclusiveRange(170, 330));  // target 25%
      expect(counts[Rarity.rare]!, inInclusiveRange(40, 200));       // target 12%
      expect(counts[Rarity.legendary]!, inInclusiveRange(0, 110));   // target  3%
    });
  });

  // ─── filter() ───────────────────────────────────────────────────────────────

  group('DogService.filter()', () {
    test('returns all dogs when called with no arguments', () {
      final results = service.filter();
      expect(results.length, equals(service.all.length));
    });

    test('filters to only common dogs when rarity is Rarity.common', () {
      final results = service.filter(rarity: Rarity.common);
      expect(results, isNotEmpty);
      for (final dog in results) {
        expect(dog.rarity, equals(Rarity.common));
      }
    });

    test('filters to only uncommon dogs when rarity is Rarity.uncommon', () {
      final results = service.filter(rarity: Rarity.uncommon);
      expect(results, isNotEmpty);
      for (final dog in results) {
        expect(dog.rarity, equals(Rarity.uncommon));
      }
    });

    test('filters to only rare dogs when rarity is Rarity.rare', () {
      final results = service.filter(rarity: Rarity.rare);
      expect(results, isNotEmpty);
      for (final dog in results) {
        expect(dog.rarity, equals(Rarity.rare));
      }
    });

    test('filters to only legendary dogs when rarity is Rarity.legendary', () {
      final results = service.filter(rarity: Rarity.legendary);
      expect(results, isNotEmpty);
      for (final dog in results) {
        expect(dog.rarity, equals(Rarity.legendary));
      }
    });

    test('search matches by common name (case-insensitive)', () {
      final results = service.filter(search: 'retriever');
      expect(results, isNotEmpty);
      for (final dog in results) {
        expect(
          dog.name.toLowerCase().contains('retriever') ||
              dog.scientificName.toLowerCase().contains('retriever'),
          isTrue,
          reason: '${dog.name} should match search "retriever"',
        );
      }
    });

    test('search matches by scientific name fragment', () {
      final results = service.filter(search: 'Canis');
      expect(results, isNotEmpty);
    });

    test('search combined with rarity returns only matching rarity dogs', () {
      final results = service.filter(rarity: Rarity.rare, search: 'hound');
      for (final dog in results) {
        expect(dog.rarity, equals(Rarity.rare));
        expect(
          dog.name.toLowerCase().contains('hound') ||
              dog.scientificName.toLowerCase().contains('hound'),
          isTrue,
        );
      }
    });

    test('search for a name that does not exist returns an empty list', () {
      final results = service.filter(search: 'XyzNoSuchBreed999');
      expect(results, isEmpty);
    });

    test('search is case-insensitive: uppercase and lowercase give same count', () {
      final upper = service.filter(search: 'TERRIER');
      final lower = service.filter(search: 'terrier');
      expect(upper.length, equals(lower.length));
    });

    test('empty search string with rarity returns all dogs of that rarity', () {
      final byRarity = service.filter(rarity: Rarity.uncommon, search: '');
      final byRarityOnly = service.filter(rarity: Rarity.uncommon);
      expect(byRarity.length, equals(byRarityOnly.length));
    });

    test('returned list does not include dogs outside the selected rarity', () {
      final results = service.filter(rarity: Rarity.legendary);
      for (final dog in results) {
        expect(dog.rarity, isNot(equals(Rarity.common)));
        expect(dog.rarity, isNot(equals(Rarity.uncommon)));
        expect(dog.rarity, isNot(equals(Rarity.rare)));
      }
    });
  });

  // ─── searchBreeds() ──────────────────────────────────────────────────────────

  group('DogService.searchBreeds()', () {
    test('empty query returns up to the default limit (20)', () {
      final results = service.searchBreeds('');
      expect(results.length, lessThanOrEqualTo(20));
      expect(results, isNotEmpty);
    });

    test('custom limit is respected', () {
      final results = service.searchBreeds('', limit: 5);
      expect(results.length, lessThanOrEqualTo(5));
    });

    test('query "retriever" returns only breeds whose name contains "retriever"', () {
      final results = service.searchBreeds('retriever', limit: 50);
      expect(results, isNotEmpty);
      for (final dog in results) {
        expect(dog.name.toLowerCase(), contains('retriever'));
      }
    });

    test('query is case-insensitive', () {
      final lower = service.searchBreeds('terrier', limit: 100);
      final upper = service.searchBreeds('TERRIER', limit: 100);
      expect(lower.length, equals(upper.length));
    });

    test('query with no matches returns an empty list', () {
      expect(service.searchBreeds('XyzNoMatch9999'), isEmpty);
    });

    test('results respect the limit parameter', () {
      final results = service.searchBreeds('e', limit: 3);
      expect(results.length, lessThanOrEqualTo(3));
    });
  });
}

// ─── Test helpers ─────────────────────────────────────────────────────────────

/// A [Random] implementation that always returns [_value] from [nextDouble]
/// and delegates [nextInt] / [nextBool] to a seeded real [Random].
class _FixedRandom implements Random {
  _FixedRandom(this._value) : _inner = Random(0);

  final double _value;
  final Random _inner;

  @override
  double nextDouble() => _value;

  @override
  int nextInt(int max) => _inner.nextInt(max);

  @override
  bool nextBool() => _inner.nextBool();
}
