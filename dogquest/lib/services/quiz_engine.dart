import 'dart:math';

import 'package:flutter/material.dart';

import '../models/dog.dart';
import '../services/dog_group_service.dart' show families;

// ─── Quiz Types ──────────────────────────────────────────────────────────────

enum QuizType {
  nameFromPhoto,
  photoFromName,
  sizeFromPhoto,
  traitMatch,
  oddOneOut,
  groupFromBreed,
  lifespanGuess,
  silhouetteRound,
  exerciseFromPhoto,
  weightGuess,
  originFromBreed,
  breedFromClue,
  compareBreeds,
}

extension QuizTypeX on QuizType {
  int get xpValue => switch (this) {
        QuizType.nameFromPhoto => 15,
        QuizType.photoFromName => 15,
        QuizType.sizeFromPhoto => 20,
        QuizType.traitMatch => 20,
        QuizType.groupFromBreed => 20,
        QuizType.exerciseFromPhoto => 20,
        QuizType.weightGuess => 25,
        QuizType.originFromBreed => 25,
        QuizType.lifespanGuess => 25,
        QuizType.breedFromClue => 30,
        QuizType.oddOneOut => 30,
        QuizType.compareBreeds => 30,
        QuizType.silhouetteRound => 35,
      };

  String get label => switch (this) {
        QuizType.nameFromPhoto => 'Easy',
        QuizType.photoFromName => 'Easy',
        QuizType.sizeFromPhoto => 'Medium',
        QuizType.traitMatch => 'Medium',
        QuizType.groupFromBreed => 'Medium',
        QuizType.exerciseFromPhoto => 'Medium',
        QuizType.weightGuess => 'Hard',
        QuizType.originFromBreed => 'Hard',
        QuizType.lifespanGuess => 'Hard',
        QuizType.breedFromClue => 'Hard',
        QuizType.oddOneOut => 'Hard',
        QuizType.compareBreeds => 'Expert',
        QuizType.silhouetteRound => 'Expert',
      };

  Color get color => switch (this) {
        QuizType.nameFromPhoto || QuizType.photoFromName => Colors.green,
        QuizType.sizeFromPhoto ||
        QuizType.traitMatch ||
        QuizType.groupFromBreed ||
        QuizType.exerciseFromPhoto =>
          Colors.orange,
        QuizType.lifespanGuess ||
        QuizType.oddOneOut ||
        QuizType.weightGuess ||
        QuizType.originFromBreed ||
        QuizType.breedFromClue =>
          Colors.red,
        QuizType.silhouetteRound || QuizType.compareBreeds => Colors.purple,
      };

  String get prompt => switch (this) {
        QuizType.nameFromPhoto => 'Which breed is this?',
        QuizType.photoFromName => 'Which photo shows this breed?',
        QuizType.sizeFromPhoto => 'What size is this breed?',
        QuizType.traitMatch => 'Which trait fits this breed?',
        QuizType.oddOneOut => 'Which breed is the odd one out?',
        QuizType.groupFromBreed => 'What group does this breed belong to?',
        QuizType.lifespanGuess => 'What is this breed\'s typical lifespan?',
        QuizType.silhouetteRound => 'Guess the breed from its silhouette!',
        QuizType.exerciseFromPhoto => 'How much exercise does this breed need?',
        QuizType.weightGuess => 'How heavy is this breed?',
        QuizType.originFromBreed => 'Where does this breed originate?',
        QuizType.breedFromClue => 'Which breed matches this description?',
        QuizType.compareBreeds => 'Which breed lives longer?',
      };

  IconData get icon => switch (this) {
        QuizType.nameFromPhoto => Icons.photo_camera,
        QuizType.photoFromName => Icons.photo_library,
        QuizType.sizeFromPhoto => Icons.straighten,
        QuizType.traitMatch => Icons.psychology,
        QuizType.oddOneOut => Icons.help_outline,
        QuizType.groupFromBreed => Icons.category,
        QuizType.lifespanGuess => Icons.timer,
        QuizType.silhouetteRound => Icons.visibility_off,
        QuizType.exerciseFromPhoto => Icons.directions_run,
        QuizType.weightGuess => Icons.fitness_center,
        QuizType.originFromBreed => Icons.public,
        QuizType.breedFromClue => Icons.auto_stories,
        QuizType.compareBreeds => Icons.compare_arrows,
      };
}

// ─── Quiz Question ───────────────────────────────────────────────────────────

class QuizQuestion {
  final Dog correctDog;
  final List<String> options;
  final int correctIndex;
  final QuizType type;
  final List<Dog>? photoDogs;

  /// Extra text for clue-based questions or comparison prompts.
  final String? clueText;
  bool hintUsed = false;

  QuizQuestion({
    required this.correctDog,
    required this.options,
    required this.correctIndex,
    required this.type,
    this.photoDogs,
    this.clueText,
  });
}

// ─── Quiz Difficulty ─────────────────────────────────────────────────────────

enum QuizDifficulty {
  beginner,
  normal,
  expert;

  String get label => switch (this) {
        QuizDifficulty.beginner => 'Beginner',
        QuizDifficulty.normal => 'Normal',
        QuizDifficulty.expert => 'Expert',
      };

  String get description => switch (this) {
        QuizDifficulty.beginner =>
          'Common breeds, visual questions, more lifelines',
        QuizDifficulty.normal => 'Adapts to your level, mixed question types',
        QuizDifficulty.expert => 'All breeds, all types, silhouette rounds',
      };

  String get emoji => switch (this) {
        QuizDifficulty.beginner => '\u{1F436}',
        QuizDifficulty.normal => '\u{1F415}',
        QuizDifficulty.expert => '\u{1F3C6}',
      };

  Color get color => switch (this) {
        QuizDifficulty.beginner => Colors.green,
        QuizDifficulty.normal => Colors.amber,
        QuizDifficulty.expert => Colors.red,
      };

  double get xpMultiplier => switch (this) {
        QuizDifficulty.beginner => 0.75,
        QuizDifficulty.normal => 1.0,
        QuizDifficulty.expert => 1.5,
      };
}

// ─── Quiz Engine ─────────────────────────────────────────────────────────────

class QuizEngine {
  final Random rng;

  QuizEngine(this.rng);

  bool tooSimilar(String a, String b) {
    final aLow = a.toLowerCase();
    final bLow = b.toLowerCase();
    if (aLow.contains(bLow) || bLow.contains(aLow)) return true;
    final aWords = aLow.split(' ');
    final bWords = bLow.split(' ');
    if (aWords.length > 1 && bWords.length > 1 && aWords.last == bWords.last)
      return true;
    return false;
  }

  /// Parse the origin country/region from the habitat field.
  /// Format: "Sporting Group | Origin: Canada" → "Canada"
  String parseOrigin(String habitat) {
    final match = RegExp(r'Origin:\s*(.+)').firstMatch(habitat);
    return match?.group(1)?.trim() ?? 'Unknown';
  }

  /// Parse the first number from a weight string like "25-36 kg" → 25
  int? parseWeight(String weight) {
    final match = RegExp(r'(\d+)').firstMatch(weight);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  /// Parse mid-lifespan from "10-13 years" → 11
  int parseMidLifespan(String lifespan) {
    final matches = RegExp(r'(\d+)').allMatches(lifespan).toList();
    if (matches.isEmpty) return 11;
    if (matches.length >= 2) {
      final lo = int.parse(matches[0].group(1)!);
      final hi = int.parse(matches[1].group(1)!);
      return ((lo + hi) / 2).round();
    }
    return int.parse(matches[0].group(1)!);
  }

  List<Dog> pickDistractors(List<Dog> pool, Dog correct, int count) {
    final distractors = <Dog>[];
    final similar = pool
        .where((b) =>
            b.name != correct.name &&
            !tooSimilar(b.name, correct.name) &&
            b.imageUrl != correct.imageUrl &&
            b.habitat == correct.habitat)
        .toList();
    similar.shuffle(rng);
    for (final b in similar.take(count ~/ 2 + 1)) {
      if (!distractors.any((d) => d.name == b.name)) distractors.add(b);
    }
    final shuffled = List.of(pool)..shuffle(rng);
    for (final c in shuffled) {
      if (distractors.length >= count) break;
      if (c.name != correct.name &&
          !tooSimilar(c.name, correct.name) &&
          c.imageUrl != correct.imageUrl &&
          !distractors
              .any((d) => d.name == c.name || tooSimilar(d.name, c.name))) {
        distractors.add(c);
      }
    }
    var fallbackAttempts = 0;
    while (distractors.length < count && fallbackAttempts < 100) {
      fallbackAttempts++;
      final c = pool[rng.nextInt(pool.length)];
      if (c.name != correct.name && !distractors.any((d) => d.name == c.name)) {
        distractors.add(c);
      }
    }
    return distractors;
  }

  QuizQuestion makeNameFromPhoto(List<Dog> pool) {
    final correct = pool[rng.nextInt(pool.length)];
    final distractors = pickDistractors(pool, correct, 3);
    final options = [...distractors.map((d) => d.name), correct.name];
    options.shuffle(rng);
    return QuizQuestion(
      correctDog: correct,
      options: options,
      correctIndex: options.indexOf(correct.name),
      type: QuizType.nameFromPhoto,
    );
  }

  QuizQuestion makePhotoFromName(List<Dog> pool) {
    final correct = pool[rng.nextInt(pool.length)];
    final distractors = pickDistractors(pool, correct, 3);
    final dogs = [...distractors, correct];
    dogs.shuffle(rng);
    return QuizQuestion(
      correctDog: correct,
      options: dogs.map((d) => d.name).toList(),
      correctIndex: dogs.indexWhere((d) => d.name == correct.name),
      type: QuizType.photoFromName,
      photoDogs: dogs,
    );
  }

  QuizQuestion makeSizeFromPhoto(List<Dog> pool) {
    final correct = pool[rng.nextInt(pool.length)];
    const sizes = ['small', 'medium', 'large', 'giant'];
    final size = correct.sizeCategory.isEmpty ? 'medium' : correct.sizeCategory;
    final idx = sizes.indexOf(size);
    return QuizQuestion(
      correctDog: correct,
      options: sizes.toList(),
      correctIndex: idx >= 0 ? idx : 1,
      type: QuizType.sizeFromPhoto,
    );
  }

  QuizQuestion makeTraitMatch(List<Dog> pool) {
    final correct = pool[rng.nextInt(pool.length)];
    if (correct.temperamentTraits.isEmpty) return makeNameFromPhoto(pool);
    final correctTrait = correct
        .temperamentTraits[rng.nextInt(correct.temperamentTraits.length)];
    final wrongTraits = <String>{};
    for (final d in pool) {
      for (final t in d.temperamentTraits) {
        if (!correct.temperamentTraits.contains(t)) wrongTraits.add(t);
      }
      if (wrongTraits.length >= 10) break;
    }
    if (wrongTraits.length < 3) return makeNameFromPhoto(pool);
    final wrongList = wrongTraits.toList()..shuffle(rng);
    final options = [correctTrait, ...wrongList.take(3)];
    options.shuffle(rng);
    return QuizQuestion(
      correctDog: correct,
      options: options,
      correctIndex: options.indexOf(correctTrait),
      type: QuizType.traitMatch,
    );
  }

  QuizQuestion makeOddOneOut(List<Dog> pool) {
    final sizes = ['small', 'medium', 'large', 'giant'];
    final commonSize = sizes[rng.nextInt(sizes.length)];
    final matching = pool.where((d) => d.sizeCategory == commonSize).toList();
    final outliers = pool
        .where((d) => d.sizeCategory != commonSize && d.sizeCategory.isNotEmpty)
        .toList();
    if (matching.length < 3 || outliers.isEmpty) return makeNameFromPhoto(pool);
    matching.shuffle(rng);
    outliers.shuffle(rng);
    final oddDog = outliers.first;
    final dogs = [...matching.take(3), oddDog];
    dogs.shuffle(rng);
    return QuizQuestion(
      correctDog: oddDog,
      options: dogs.map((d) => d.name).toList(),
      correctIndex: dogs.indexOf(oddDog),
      type: QuizType.oddOneOut,
      photoDogs: dogs,
    );
  }

  QuizQuestion makeGroupFromBreed(List<Dog> pool) {
    final correct = pool[rng.nextInt(pool.length)];
    String? correctGroup;
    for (final g in families) {
      if (g.containsDog(correct)) {
        correctGroup = g.name;
        break;
      }
    }
    correctGroup ??= 'Non-Sporting';
    final wrongGroups = families
        .map((g) => g.name)
        .where((n) => n != correctGroup)
        .toList()
      ..shuffle(rng);
    final options = <String>[correctGroup, ...wrongGroups.take(3)];
    options.shuffle(rng);
    return QuizQuestion(
      correctDog: correct,
      options: options,
      correctIndex: options.indexOf(correctGroup),
      type: QuizType.groupFromBreed,
    );
  }

  QuizQuestion makeLifespanGuess(List<Dog> pool) {
    final correct = pool[rng.nextInt(pool.length)];
    final lifespan =
        correct.lifespan.isNotEmpty ? correct.lifespan : '10-13 years';
    final mid = parseMidLifespan(lifespan);
    const buckets = ['6-8 years', '9-11 years', '12-14 years', '15-18 years'];
    final correctBucket = mid <= 8
        ? buckets[0]
        : mid <= 11
            ? buckets[1]
            : mid <= 14
                ? buckets[2]
                : buckets[3];
    final wrongBuckets = buckets.where((b) => b != correctBucket).toList()
      ..shuffle(rng);
    final options = [correctBucket, ...wrongBuckets.take(3)];
    options.shuffle(rng);
    return QuizQuestion(
      correctDog: correct,
      options: options,
      correctIndex: options.indexOf(correctBucket),
      type: QuizType.lifespanGuess,
    );
  }

  QuizQuestion makeSilhouetteRound(List<Dog> pool) {
    final base = makeNameFromPhoto(pool);
    return QuizQuestion(
      correctDog: base.correctDog,
      options: base.options,
      correctIndex: base.correctIndex,
      type: QuizType.silhouetteRound,
    );
  }

  // ─── New Question Types ─────────────────────────────────────────────────────

  QuizQuestion makeExerciseFromPhoto(List<Dog> pool) {
    final correct = pool[rng.nextInt(pool.length)];
    const levels = ['Low', 'Moderate', 'High', 'Very High'];
    final exercise =
        correct.exerciseNeeds.isEmpty ? 'moderate' : correct.exerciseNeeds;
    // Capitalize to match options
    final correctAnswer = exercise
        .split(' ')
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
    final idx = levels.indexOf(correctAnswer);
    return QuizQuestion(
      correctDog: correct,
      options: levels.toList(),
      correctIndex: idx >= 0 ? idx : 1,
      type: QuizType.exerciseFromPhoto,
    );
  }

  QuizQuestion makeWeightGuess(List<Dog> pool) {
    final correct = pool[rng.nextInt(pool.length)];
    final w = parseWeight(correct.weight);
    if (w == null) return makeNameFromPhoto(pool);

    const buckets = [
      'Under 10 kg',
      '10-20 kg',
      '20-35 kg',
      '35-55 kg',
      'Over 55 kg'
    ];
    final correctBucket = w < 10
        ? buckets[0]
        : w < 20
            ? buckets[1]
            : w < 35
                ? buckets[2]
                : w < 55
                    ? buckets[3]
                    : buckets[4];

    // Pick 3 wrong buckets
    final wrongBuckets = buckets.where((b) => b != correctBucket).toList()
      ..shuffle(rng);
    final options = [correctBucket, ...wrongBuckets.take(3)];
    options.shuffle(rng);
    return QuizQuestion(
      correctDog: correct,
      options: options,
      correctIndex: options.indexOf(correctBucket),
      type: QuizType.weightGuess,
    );
  }

  QuizQuestion makeOriginFromBreed(List<Dog> pool) {
    final correct = pool[rng.nextInt(pool.length)];
    final correctOrigin = parseOrigin(correct.habitat);
    if (correctOrigin == 'Unknown') return makeNameFromPhoto(pool);

    // Gather other origins for wrong answers
    final allOrigins = <String>{};
    for (final d in pool) {
      final o = parseOrigin(d.habitat);
      if (o != 'Unknown' && o != correctOrigin) allOrigins.add(o);
    }
    if (allOrigins.length < 3) return makeNameFromPhoto(pool);

    final wrongList = allOrigins.toList()..shuffle(rng);
    final options = [correctOrigin, ...wrongList.take(3)];
    options.shuffle(rng);
    return QuizQuestion(
      correctDog: correct,
      options: options,
      correctIndex: options.indexOf(correctOrigin),
      type: QuizType.originFromBreed,
    );
  }

  QuizQuestion makeBreedFromClue(List<Dog> pool) {
    // Filter to dogs with good lore (at least 40 chars)
    final candidates = pool.where((d) => d.lore.length >= 40).toList();
    if (candidates.length < 4) return makeNameFromPhoto(pool);

    final correct = candidates[rng.nextInt(candidates.length)];
    final distractors = pickDistractors(candidates, correct, 3);
    final options = [...distractors.map((d) => d.name), correct.name];
    options.shuffle(rng);
    return QuizQuestion(
      correctDog: correct,
      options: options,
      correctIndex: options.indexOf(correct.name),
      type: QuizType.breedFromClue,
      clueText: correct.lore,
    );
  }

  QuizQuestion makeCompareBreeds(List<Dog> pool) {
    // Pick two dogs with different lifespans
    final candidates = pool.where((d) => d.lifespan.isNotEmpty).toList();
    if (candidates.length < 4) return makeNameFromPhoto(pool);

    candidates.shuffle(rng);
    Dog? dogA, dogB;
    int midA = 0, midB = 0;
    for (int i = 0; i < candidates.length - 1; i++) {
      for (int j = i + 1; j < candidates.length; j++) {
        final a = parseMidLifespan(candidates[i].lifespan);
        final b = parseMidLifespan(candidates[j].lifespan);
        if ((a - b).abs() >= 3 &&
            !tooSimilar(candidates[i].name, candidates[j].name)) {
          dogA = candidates[i];
          dogB = candidates[j];
          midA = a;
          midB = b;
          break;
        }
      }
      if (dogA != null) break;
    }
    if (dogA == null || dogB == null) return makeNameFromPhoto(pool);

    final longer = midA >= midB ? dogA : dogB;
    final options = [dogA.name, dogB.name];
    // Don't shuffle - show as A vs B in order
    return QuizQuestion(
      correctDog: longer,
      options: options,
      correctIndex: options.indexOf(longer.name),
      type: QuizType.compareBreeds,
      photoDogs: [dogA, dogB],
      clueText: 'Which breed typically lives longer?',
    );
  }

  // ─── Type Selection ─────────────────────────────────────────────────────────

  List<QuizType> weightedTypes(int level, QuizDifficulty diff) {
    if (diff == QuizDifficulty.beginner) {
      return [
        QuizType.nameFromPhoto,
        QuizType.nameFromPhoto,
        QuizType.nameFromPhoto,
        QuizType.photoFromName,
        QuizType.photoFromName,
        QuizType.sizeFromPhoto,
        QuizType.groupFromBreed,
        QuizType.exerciseFromPhoto,
      ];
    } else if (diff == QuizDifficulty.expert) {
      return [
        QuizType.nameFromPhoto,
        QuizType.photoFromName,
        QuizType.sizeFromPhoto,
        QuizType.traitMatch,
        QuizType.traitMatch,
        QuizType.oddOneOut,
        QuizType.oddOneOut,
        QuizType.groupFromBreed,
        QuizType.lifespanGuess,
        QuizType.lifespanGuess,
        QuizType.silhouetteRound,
        QuizType.silhouetteRound,
        QuizType.exerciseFromPhoto,
        QuizType.weightGuess,
        QuizType.weightGuess,
        QuizType.originFromBreed,
        QuizType.originFromBreed,
        QuizType.breedFromClue,
        QuizType.breedFromClue,
        QuizType.compareBreeds,
        QuizType.compareBreeds,
      ];
    } else {
      if (level < 5) {
        return [
          QuizType.nameFromPhoto,
          QuizType.nameFromPhoto,
          QuizType.nameFromPhoto,
          QuizType.photoFromName,
          QuizType.photoFromName,
          QuizType.sizeFromPhoto,
          QuizType.groupFromBreed,
          QuizType.exerciseFromPhoto,
        ];
      } else if (level < 15) {
        return [
          QuizType.nameFromPhoto,
          QuizType.nameFromPhoto,
          QuizType.photoFromName,
          QuizType.sizeFromPhoto,
          QuizType.traitMatch,
          QuizType.groupFromBreed,
          QuizType.oddOneOut,
          QuizType.lifespanGuess,
          QuizType.exerciseFromPhoto,
          QuizType.weightGuess,
          QuizType.originFromBreed,
          QuizType.breedFromClue,
        ];
      } else {
        return QuizType.values.toList();
      }
    }
  }

  QuizQuestion makeQuestionOfType(
      QuizType type, List<Dog> pool, int level, QuizDifficulty diff) {
    switch (type) {
      case QuizType.nameFromPhoto:
        return makeNameFromPhoto(pool);
      case QuizType.photoFromName:
        return makePhotoFromName(pool);
      case QuizType.sizeFromPhoto:
        return makeSizeFromPhoto(pool);
      case QuizType.traitMatch:
        return makeTraitMatch(pool);
      case QuizType.oddOneOut:
        return makeOddOneOut(pool);
      case QuizType.groupFromBreed:
        return makeGroupFromBreed(pool);
      case QuizType.lifespanGuess:
        return makeLifespanGuess(pool);
      case QuizType.silhouetteRound:
        return makeSilhouetteRound(pool);
      case QuizType.exerciseFromPhoto:
        return makeExerciseFromPhoto(pool);
      case QuizType.weightGuess:
        return makeWeightGuess(pool);
      case QuizType.originFromBreed:
        return makeOriginFromBreed(pool);
      case QuizType.breedFromClue:
        return makeBreedFromClue(pool);
      case QuizType.compareBreeds:
        return makeCompareBreeds(pool);
    }
  }

  // ─── Fun Facts ──────────────────────────────────────────────────────────────

  /// Generate a rich, educational fun fact for the answered question.
  String getFunFact(QuizQuestion q) {
    final dog = q.correctDog;
    final origin = parseOrigin(dog.habitat);

    switch (q.type) {
      case QuizType.nameFromPhoto:
      case QuizType.silhouetteRound:
      case QuizType.photoFromName:
        // Rotate between lore, origin fact, and health fact
        final variants = <String>[
          if (dog.lore.isNotEmpty && dog.lore.length > 10) dog.lore,
          if (origin != 'Unknown')
            '${dog.name} originated in $origin. They\'re a ${dog.sizeCategory} breed weighing ${dog.weight.isEmpty ? "varies" : dog.weight}.',
          if (dog.healthPredispositions.isNotEmpty)
            '${dog.name} owners should watch for ${dog.healthPredispositions.take(2).join(' and ')}. Regular vet checkups are key!',
          if (dog.dietNotes.isNotEmpty) dog.dietNotes,
        ];
        if (variants.isEmpty)
          return '${dog.name} is a ${dog.sizeCategory} ${dog.rarity.label.toLowerCase()} breed.';
        return variants[rng.nextInt(variants.length)];

      case QuizType.sizeFromPhoto:
        return '${dog.name} weighs ${dog.weight.isEmpty ? "varies by individual" : dog.weight} and needs ${dog.exerciseNeeds} exercise. ${dog.groomingNeeds == "high" ? "They also need frequent grooming!" : ""}';

      case QuizType.traitMatch:
        final allTraits = dog.temperamentTraits.join(', ');
        return '${dog.name} is known for being $allTraits. ${dog.exerciseNeeds == "high" || dog.exerciseNeeds == "very high" ? "They need plenty of activity to stay happy!" : "They are relatively easy-going."}';

      case QuizType.oddOneOut:
        final otherDogs =
            q.photoDogs?.where((d) => d.name != dog.name).toList() ?? [];
        final majoritySize =
            otherDogs.isNotEmpty ? otherDogs.first.sizeCategory : 'medium';
        return '${dog.name} is a ${dog.sizeCategory} breed among $majoritySize-sized dogs. Size affects lifespan: smaller breeds often live longer!';

      case QuizType.groupFromBreed:
        if (origin != 'Unknown') {
          return '${dog.name} from $origin belongs to the ${_extractGroup(dog.habitat)}. They were bred for specific working roles that shaped their temperament.';
        }
        return '${dog.name} belongs to the ${_extractGroup(dog.habitat)}. Breed groups help classify dogs by their original purpose.';

      case QuizType.lifespanGuess:
        return '${dog.name} typically lives ${dog.lifespan.isEmpty ? "10-13 years" : dog.lifespan}. ${dog.sizeCategory == "giant" || dog.sizeCategory == "large" ? "Larger breeds generally have shorter lifespans." : "Smaller breeds tend to live longer than larger ones."} Exercise needs: ${dog.exerciseNeeds}.';

      case QuizType.exerciseFromPhoto:
        final exerciseDesc = switch (dog.exerciseNeeds) {
          'low' => 'Short walks and indoor play are enough',
          'moderate' => 'Daily walks and regular play sessions are ideal',
          'high' => 'They need vigorous daily exercise like running or hiking',
          'very high' => 'Bred for endurance, they need intense daily activity',
          _ => 'Regular exercise is important',
        };
        return '$exerciseDesc for a ${dog.name}. ${dog.dietNotes.isNotEmpty ? dog.dietNotes : ""}';

      case QuizType.weightGuess:
        return '${dog.name} weighs ${dog.weight.isEmpty ? "varies" : dog.weight}. ${dog.sizeCategory == "giant" ? "Giant breeds need special nutrition for their joints." : dog.sizeCategory == "small" ? "Small breeds have faster metabolisms." : "Proper weight management prevents many health issues."}';

      case QuizType.originFromBreed:
        return '${dog.name} comes from $origin! ${dog.lore.isNotEmpty && dog.lore.length > 10 ? dog.lore : "Every breed carries traits shaped by its homeland."}';

      case QuizType.breedFromClue:
        if (dog.healthPredispositions.isNotEmpty) {
          return 'Health watch: ${dog.name} owners should be aware of ${dog.healthPredispositions.join(", ")}. Grooming: ${dog.groomingNeeds}.';
        }
        return '${dog.name} is a ${dog.sizeCategory} breed. Grooming: ${dog.groomingNeeds}. Exercise: ${dog.exerciseNeeds}.';

      case QuizType.compareBreeds:
        final dogs = q.photoDogs ?? [];
        if (dogs.length >= 2) {
          final a = dogs[0];
          final b = dogs[1];
          return '${a.name} lives ${a.lifespan.isEmpty ? "~12 years" : a.lifespan} while ${b.name} lives ${b.lifespan.isEmpty ? "~12 years" : b.lifespan}. Size matters: ${a.sizeCategory} vs ${b.sizeCategory}.';
        }
        return '${dog.name} typically lives ${dog.lifespan.isEmpty ? "10-13 years" : dog.lifespan}.';
    }
  }

  String _extractGroup(String habitat) {
    final match = RegExp(r'^(.+?)\s*\|').firstMatch(habitat);
    return match?.group(1)?.trim() ?? habitat;
  }

  /// Generate a hint string for the current question.
  String getHint(QuizQuestion q) {
    switch (q.type) {
      case QuizType.nameFromPhoto:
      case QuizType.silhouetteRound:
        return 'This is a ${q.correctDog.sizeCategory} ${q.correctDog.rarity.label.toLowerCase()} breed';
      case QuizType.photoFromName:
        return 'Look for a ${q.correctDog.sizeCategory}-sized dog';
      case QuizType.sizeFromPhoto:
        return 'Weight: ${q.correctDog.weight.isEmpty ? "check the build" : q.correctDog.weight}';
      case QuizType.traitMatch:
        final traits = q.correctDog.temperamentTraits;
        return traits.length > 1
            ? 'Also known for being ${traits.last}'
            : 'Think about this breed\'s personality';
      case QuizType.oddOneOut:
        final matchingDog = q.photoDogs?.firstWhere(
            (d) => d.name != q.correctDog.name,
            orElse: () => q.correctDog);
        return 'Three of these are ${matchingDog?.sizeCategory ?? "similar"}-sized';
      case QuizType.groupFromBreed:
        return 'Think about what this breed was originally bred for';
      case QuizType.lifespanGuess:
        return q.correctDog.sizeCategory == "giant" ||
                q.correctDog.sizeCategory == "large"
            ? "Larger breeds tend to live shorter"
            : "Smaller breeds tend to live longer";
      case QuizType.exerciseFromPhoto:
        return '${q.correctDog.name} is a ${q.correctDog.sizeCategory} breed from the ${parseOrigin(q.correctDog.habitat)}';
      case QuizType.weightGuess:
        return 'This is a ${q.correctDog.sizeCategory}-sized dog';
      case QuizType.originFromBreed:
        return 'Look at the breed name for clues about its country';
      case QuizType.breedFromClue:
        return 'This is a ${q.correctDog.sizeCategory} ${q.correctDog.rarity.label.toLowerCase()} breed';
      case QuizType.compareBreeds:
        return 'Smaller breeds generally live longer than larger ones';
    }
  }
}
