import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dog.dart';
import 'kennel_service.dart';
import 'dog_service.dart';

/// A thematic grouping of dog breeds by AKC breed group.
class DogGroup {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final Color color;

  /// Keywords that match dog names to this family (case-insensitive).
  final List<String> nameKeywords;

  /// Exact dog names that belong to this family (overrides keyword match).
  final List<String> exactMembers;

  const DogGroup({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.color,
    this.nameKeywords = const [],
    this.exactMembers = const [],
  });

  /// Check if a dog belongs to this family.
  bool containsDog(Dog dog) {
    final lowerName = dog.name.toLowerCase();
    if (exactMembers.any((m) => m.toLowerCase() == lowerName)) return true;
    return nameKeywords.any((kw) => lowerName.contains(kw.toLowerCase()));
  }
}

/// Mastery level for a dog family.
enum FamilyMastery { none, bronze, silver, gold }

extension FamilyMasteryExt on FamilyMastery {
  String get label {
    switch (this) {
      case FamilyMastery.none:
        return '';
      case FamilyMastery.bronze:
        return 'Bronze';
      case FamilyMastery.silver:
        return 'Silver';
      case FamilyMastery.gold:
        return 'Gold';
    }
  }

  Color get color {
    switch (this) {
      case FamilyMastery.none:
        return Colors.white24;
      case FamilyMastery.bronze:
        return const Color(0xFFCD7F32);
      case FamilyMastery.silver:
        return const Color(0xFFC0C0C0);
      case FamilyMastery.gold:
        return Colors.amber;
    }
  }

  String get emoji {
    switch (this) {
      case FamilyMastery.none:
        return '';
      case FamilyMastery.bronze:
        return '🥉';
      case FamilyMastery.silver:
        return '🥈';
      case FamilyMastery.gold:
        return '🥇';
    }
  }
}

/// Progress snapshot for a single dog family.
class FamilyProgress {
  final DogGroup family;
  final List<Dog> allMembers;
  final List<Dog> collectedMembers;

  const FamilyProgress({
    required this.family,
    required this.allMembers,
    required this.collectedMembers,
  });

  int get total => allMembers.length;
  int get collected => collectedMembers.length;
  double get progress => total == 0 ? 0.0 : collected / total;
  bool get isComplete => collected >= total && total > 0;

  FamilyMastery get mastery {
    if (isComplete) return FamilyMastery.gold;
    if (progress >= 0.5) return FamilyMastery.silver;
    if (progress >= 0.25) return FamilyMastery.bronze;
    return FamilyMastery.none;
  }

  /// XP bonus multiplier based on mastery level.
  double get xpBonus {
    switch (mastery) {
      case FamilyMastery.gold:
        return 1.15;
      case FamilyMastery.silver:
        return 1.10;
      case FamilyMastery.bronze:
        return 1.05;
      case FamilyMastery.none:
        return 1.0;
    }
  }
}

/// All dog breed groups defined in the game (AKC classification).
const families = <DogGroup>[
  DogGroup(
    id: 'sporting',
    name: 'Sporting Group',
    emoji: '🏃',
    description: 'Retrievers, spaniels, setters, and pointers',
    color: Color(0xFF66BB6A),
    nameKeywords: [
      'retriever',
      'spaniel',
      'setter',
      'pointer',
      'vizsla',
      'weimaraner',
      'brittany'
    ],
  ),
  DogGroup(
    id: 'hound',
    name: 'Hound Group',
    emoji: '🔍',
    description: 'Scent hounds, sight hounds, and trackers',
    color: Colors.amber,
    nameKeywords: [
      'hound',
      'beagle',
      'dachshund',
      'basset',
      'greyhound',
      'whippet',
      'bloodhound',
      'borzoi',
      'saluki',
      'basenji',
      'rhodesian'
    ],
  ),
  DogGroup(
    id: 'working',
    name: 'Working Group',
    emoji: '💪',
    description: 'Guard dogs, sled dogs, and rescue dogs',
    color: Color(0xFF42A5F5),
    nameKeywords: [
      'rottweiler',
      'boxer',
      'great dane',
      'mastiff',
      'bernese',
      'newfoundland',
      'saint bernard',
      'doberman',
      'husky',
      'malamute',
      'akita',
      'samoyed',
      'leonberger',
      'komondor',
      'kuvasz'
    ],
  ),
  DogGroup(
    id: 'terrier',
    name: 'Terrier Group',
    emoji: '⚡',
    description: 'Feisty, energetic, and determined diggers',
    color: Color(0xFFFF9800),
    nameKeywords: ['terrier', 'schnauzer'],
  ),
  DogGroup(
    id: 'toy',
    name: 'Toy Group',
    emoji: '🎀',
    description: 'Small companions with big personalities',
    color: Color(0xFFEC407A),
    nameKeywords: [
      'chihuahua',
      'pomeranian',
      'pug',
      'maltese',
      'papillon',
      'pekingese',
      'shih tzu',
      'cavalier',
      'havanese',
      'toy',
      'affenpinscher',
      'italian greyhound'
    ],
  ),
  DogGroup(
    id: 'non_sporting',
    name: 'Non-Sporting Group',
    emoji: '🌟',
    description: 'A diverse group of sturdy companions',
    color: Color(0xFFAB47BC),
    nameKeywords: [
      'bulldog',
      'poodle',
      'dalmatian',
      'chow',
      'shar pei',
      'shiba',
      'lhasa',
      'bichon',
      'keeshond',
      'schipperke'
    ],
  ),
  DogGroup(
    id: 'herding',
    name: 'Herding Group',
    emoji: '🐑',
    description: 'Intelligent herders and flock guardians',
    color: Color(0xFF009688),
    nameKeywords: [
      'shepherd',
      'collie',
      'corgi',
      'sheepdog',
      'cattle',
      'bouvier',
      'briard',
      'malinois',
      'cardigan'
    ],
  ),
];

/// Service that manages dog family classification and progress tracking.
class DogGroupService {
  final DogService _dogService;
  final KennelService _kennelService;

  late final Map<String, List<Dog>> _familyMembers;

  DogGroupService(this._dogService, this._kennelService) {
    _buildIndex();
  }

  void _buildIndex() {
    _familyMembers = {};
    for (final family in families) {
      _familyMembers[family.id] =
          _dogService.all.where((b) => family.containsDog(b)).toList();
    }
  }

  /// Get all family progress snapshots, sorted by progress descending.
  List<FamilyProgress> get allProgress {
    final collected = _kennelService.all.toSet();
    return families
        .map((f) {
          final members = _familyMembers[f.id] ?? [];
          final owned =
              members.where((b) => collected.contains(b.name)).toList();
          return FamilyProgress(
              family: f, allMembers: members, collectedMembers: owned);
        })
        .where((fp) => fp.total > 0)
        .toList()
      ..sort((a, b) => b.progress.compareTo(a.progress));
  }

  /// Get progress for a specific family.
  FamilyProgress? progressFor(String familyId) {
    final family = families.where((f) => f.id == familyId).firstOrNull;
    if (family == null) return null;
    final members = _familyMembers[familyId] ?? [];
    final collected = _kennelService.all.toSet();
    final owned = members.where((b) => collected.contains(b.name)).toList();
    return FamilyProgress(
        family: family, allMembers: members, collectedMembers: owned);
  }

  /// Find which family a dog belongs to (first match).
  DogGroup? familyOf(Dog dog) {
    for (final family in families) {
      if (family.containsDog(dog)) return family;
    }
    return null;
  }

  /// Total families with gold mastery.
  int get completedFamilies =>
      allProgress.where((fp) => fp.mastery == FamilyMastery.gold).length;
}

final dogGroupServiceProvider = Provider<DogGroupService>((ref) {
  throw UnimplementedError('dogGroupServiceProvider must be overridden');
});
