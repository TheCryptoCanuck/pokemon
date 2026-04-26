import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dogquest/services/kennel_service.dart';

/// A themed collection of dog breeds the player can complete for XP.
class BreedCollection {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final List<String> breeds;
  final int xpReward;
  final Color color;

  const BreedCollection({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.breeds,
    required this.xpReward,
    this.color = Colors.amber,
  });
}

/// Progress snapshot for a single themed collection.
class CollectionProgress {
  final BreedCollection collection;
  final List<String> collectedBreeds;

  const CollectionProgress({
    required this.collection,
    required this.collectedBreeds,
  });

  int get total => collection.breeds.length;
  int get collected => collectedBreeds.length;
  double get progress => total == 0 ? 0.0 : collected / total;
  bool get isComplete => collected >= total && total > 0;
}

/// All themed breed collections.
/// Every breed name here has been verified against dogs.json.
const themedCollections = <BreedCollection>[
  BreedCollection(
    id: 'snow_dogs',
    name: 'Snow Dogs',
    emoji: '\u2744\uFE0F', // snowflake
    description: 'Built for blizzards and frozen trails',
    color: Color(0xFF64B5F6),
    xpReward: 200,
    breeds: [
      'Siberian Husky',
      'Alaskan Malamute',
      'Samoyed',
      'Saint Bernard',
      'Bernese Mountain Dog',
      'Great Pyrenees',
    ],
  ),
  BreedCollection(
    id: 'tiny_titans',
    name: 'Tiny Titans',
    emoji: '\u{1F43E}', // paw prints
    description: 'Small dogs with enormous attitudes',
    color: Color(0xFFEC407A),
    xpReward: 200,
    breeds: [
      'Chihuahua',
      'Pomeranian',
      'Yorkshire Terrier',
      'Maltese',
      'Papillon',
      'Toy Poodle',
    ],
  ),
  BreedCollection(
    id: 'german_engineering',
    name: 'German Engineering',
    emoji: '\u{1F1E9}\u{1F1EA}', // DE flag
    description: 'Precision, power, and purpose',
    color: Color(0xFFFFD54F),
    xpReward: 250,
    breeds: [
      'German Shepherd',
      'Doberman Pinscher',
      'Rottweiler',
      'Dachshund',
      'Boxer',
      'Great Dane',
      'Weimaraner',
    ],
  ),
  BreedCollection(
    id: 'british_royalty',
    name: 'British Royalty',
    emoji: '\u{1F451}', // crown
    description: 'Breeds fit for the palace',
    color: Color(0xFFAB47BC),
    xpReward: 200,
    breeds: [
      'Pembroke Welsh Corgi',
      'Cardigan Welsh Corgi',
      'Cavalier King Charles Spaniel',
      'English Springer Spaniel',
      'English Setter',
    ],
  ),
  BreedCollection(
    id: 'ancient_breeds',
    name: 'Ancient Breeds',
    emoji: '\u{1F3DB}\uFE0F', // classical building
    description: 'Unchanged for thousands of years',
    color: Color(0xFFBCAAA4),
    xpReward: 300,
    breeds: [
      'Basenji',
      'Akita',
      'Chow Chow',
      'Afghan Hound',
      'Saluki',
      'Lhasa Apso',
    ],
  ),
  BreedCollection(
    id: 'water_dogs',
    name: 'Water Dogs',
    emoji: '\u{1F30A}', // wave
    description: 'Born to swim and retrieve',
    color: Color(0xFF4FC3F7),
    xpReward: 200,
    breeds: [
      'Labrador Retriever',
      'Golden Retriever',
      'Irish Water Spaniel',
      'Chesapeake Bay Retriever',
      'Newfoundland',
    ],
  ),
  BreedCollection(
    id: 'speed_demons',
    name: 'Speed Demons',
    emoji: '\u{1F4A8}', // dash
    description: 'The fastest dogs on four legs',
    color: Color(0xFF81C784),
    xpReward: 250,
    breeds: [
      'Whippet',
      'Italian Greyhound',
      'Borzoi',
      'Saluki',
      'Afghan Hound',
      'Rhodesian Ridgeback',
    ],
  ),
  BreedCollection(
    id: 'guardian_giants',
    name: 'Guardian Giants',
    emoji: '\u{1F6E1}\uFE0F', // shield
    description: 'Massive protectors with gentle hearts',
    color: Color(0xFF7986CB),
    xpReward: 250,
    breeds: [
      'Great Dane',
      'Bullmastiff',
      'Tibetan Mastiff',
      'Saint Bernard',
      'Newfoundland',
      'Leonberger',
    ],
  ),
  BreedCollection(
    id: 'terrier_pack',
    name: 'Terrier Pack',
    emoji: '\u26A1', // lightning
    description: 'Feisty, fearless, and full of fire',
    color: Color(0xFFFF8A65),
    xpReward: 200,
    breeds: [
      'Bull Terrier',
      'Jack Russell Terrier',
      'Yorkshire Terrier',
      'Scottish Terrier',
      'West Highland White Terrier',
      'Airedale Terrier',
    ],
  ),
  BreedCollection(
    id: 'spotted_squad',
    name: 'Spotted & Unique',
    emoji: '\u{1F43E}', // paw prints
    description: 'Coats that turn heads everywhere',
    color: Color(0xFFE0E0E0),
    xpReward: 200,
    breeds: [
      'Dalmatian',
      'Australian Kelpie',
      'English Setter',
      'Rhodesian Ridgeback',
    ],
  ),
];

/// Manages themed breed collection progress and completion tracking.
class BreedCollectionService {
  final Box _box;
  final KennelService _kennelService;

  BreedCollectionService(this._box, this._kennelService);

  Box get box => _box;

  /// Get all collections with current progress.
  List<CollectionProgress> getCollections() {
    final collected = _kennelService.all.toSet();
    return themedCollections.map((c) {
      final owned = c.breeds.where((b) => collected.contains(b)).toList();
      return CollectionProgress(collection: c, collectedBreeds: owned);
    }).toList();
  }

  /// Check if adding a breed completes any collections.
  /// Returns list of newly completed collections (not previously marked complete).
  List<BreedCollection> checkNewCompletions(String dogName) {
    final collected = _kennelService.all.toSet();
    final completed = <BreedCollection>[];

    for (final collection in themedCollections) {
      if (!collection.breeds.contains(dogName)) continue;
      // Already marked as complete — skip
      if (_box.get(collection.id) == true) continue;
      // Check if all breeds are now collected
      final allCollected =
          collection.breeds.every((b) => collected.contains(b));
      if (allCollected) {
        _box.put(collection.id, true);
        completed.add(collection);
      }
    }

    return completed;
  }

  /// Number of fully completed collections.
  int get completedCount {
    return getCollections().where((cp) => cp.isComplete).length;
  }
}

final breedCollectionServiceProvider = Provider<BreedCollectionService>((ref) {
  throw UnimplementedError('breedCollectionServiceProvider must be overridden');
});
