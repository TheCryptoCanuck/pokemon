import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bird.dart';
import 'aviary_service.dart';
import 'bird_service.dart';

/// A thematic family grouping of birds.
class BirdFamily {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final Color color;

  /// Keywords that match bird names to this family (case-insensitive).
  final List<String> nameKeywords;

  /// Exact bird names that belong to this family (overrides keyword match).
  final List<String> exactMembers;

  const BirdFamily({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.color,
    this.nameKeywords = const [],
    this.exactMembers = const [],
  });

  /// Check if a bird belongs to this family.
  bool containsBird(Bird bird) {
    final lowerName = bird.name.toLowerCase();
    if (exactMembers.any((m) => m.toLowerCase() == lowerName)) return true;
    return nameKeywords.any((kw) => lowerName.contains(kw.toLowerCase()));
  }
}

/// Mastery level for a bird family.
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

/// Progress snapshot for a single bird family.
class FamilyProgress {
  final BirdFamily family;
  final List<Bird> allMembers;
  final List<Bird> collectedMembers;

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

/// All bird families defined in the game.
const families = <BirdFamily>[
  BirdFamily(
    id: 'raptors',
    name: 'Raptors',
    emoji: '🦅',
    description: 'Eagles, hawks, falcons, and kites',
    color: Color(0xFFFF5722),
    nameKeywords: ['eagle', 'hawk', 'falcon', 'kite', 'osprey', 'harrier', 'buzzard', 'vulture', 'secretary'],
  ),
  BirdFamily(
    id: 'owls',
    name: 'Owls',
    emoji: '🦉',
    description: 'Nocturnal hunters of the night',
    color: Color(0xFF7E57C2),
    nameKeywords: ['owl'],
  ),
  BirdFamily(
    id: 'waterfowl',
    name: 'Waterfowl',
    emoji: '🦆',
    description: 'Ducks, geese, swans, and grebes',
    color: Color(0xFF29B6F6),
    nameKeywords: ['duck', 'goose', 'swan', 'grebe', 'mallard', 'teal', 'merganser', 'wigeon', 'mandarin'],
  ),
  BirdFamily(
    id: 'waders',
    name: 'Waders & Shorebirds',
    emoji: '🦩',
    description: 'Herons, storks, flamingos, and sandpipers',
    color: Color(0xFFEC407A),
    nameKeywords: ['heron', 'egret', 'stork', 'flamingo', 'ibis', 'spoonbill', 'avocet', 'sandpiper', 'plover', 'bittern', 'crane', 'jacana', 'snipe', 'curlew', 'rail'],
  ),
  BirdFamily(
    id: 'songbirds',
    name: 'Songbirds',
    emoji: '🎵',
    description: 'Warblers, thrushes, and finches',
    color: Color(0xFF66BB6A),
    nameKeywords: ['warbler', 'thrush', 'finch', 'sparrow', 'bunting', 'canary', 'goldfinch', 'siskin', 'linnet', 'chaffinch', 'brambling', 'crossbill'],
  ),
  BirdFamily(
    id: 'corvids',
    name: 'Corvids',
    emoji: '🐦‍⬛',
    description: 'Crows, ravens, jays, and magpies',
    color: Color(0xFF455A64),
    nameKeywords: ['crow', 'raven', 'jay', 'magpie', 'jackdaw', 'rook', 'chough', 'currawong'],
  ),
  BirdFamily(
    id: 'woodpeckers',
    name: 'Woodpeckers',
    emoji: '🪵',
    description: 'Tree-drilling percussionists',
    color: Color(0xFF8D6E63),
    nameKeywords: ['woodpecker', 'flicker', 'sapsucker', 'wryneck'],
  ),
  BirdFamily(
    id: 'kingfishers',
    name: 'Kingfishers & Bee-eaters',
    emoji: '💎',
    description: 'Jewel-toned dive specialists',
    color: Color(0xFF00BCD4),
    nameKeywords: ['kingfisher', 'bee-eater', 'roller', 'hoopoe'],
  ),
  BirdFamily(
    id: 'parrots',
    name: 'Parrots & Cockatoos',
    emoji: '🦜',
    description: 'Colorful, intelligent mimics',
    color: Color(0xFF4CAF50),
    nameKeywords: ['parrot', 'macaw', 'cockatoo', 'lorikeet', 'parakeet', 'budgerigar', 'cockatiel', 'kea', 'kakapo', 'galah'],
  ),
  BirdFamily(
    id: 'pigeons',
    name: 'Pigeons & Doves',
    emoji: '🕊️',
    description: 'Gentle cooing messengers',
    color: Color(0xFF90A4AE),
    nameKeywords: ['pigeon', 'dove'],
  ),
  BirdFamily(
    id: 'birds_of_paradise',
    name: 'Birds of Paradise',
    emoji: '✨',
    description: 'Nature\'s most spectacular displays',
    color: Colors.amber,
    nameKeywords: ['bird-of-paradise', 'bird of paradise', 'lyrebird', 'bowerbird', 'riflebird'],
  ),
  BirdFamily(
    id: 'seabirds',
    name: 'Seabirds',
    emoji: '🌊',
    description: 'Pelicans, gulls, terns, and albatross',
    color: Color(0xFF0288D1),
    nameKeywords: ['pelican', 'gull', 'tern', 'albatross', 'booby', 'gannet', 'puffin', 'cormorant', 'petrel', 'frigatebird', 'skua'],
  ),
  BirdFamily(
    id: 'flycatchers',
    name: 'Flycatchers & Fantails',
    emoji: '🪶',
    description: 'Agile aerial insect catchers',
    color: Color(0xFFAB47BC),
    nameKeywords: ['flycatcher', 'fantail', 'drongo', 'monarch'],
  ),
  BirdFamily(
    id: 'wrens_tits',
    name: 'Wrens & Tits',
    emoji: '🪺',
    description: 'Tiny, energetic garden visitors',
    color: Color(0xFFFFA726),
    nameKeywords: ['wren', ' tit', 'chickadee', 'nuthatch', 'treecreeper', 'chiffchaff'],
    exactMembers: ['Coal Tit', 'Eurasian Blue Tit', 'Great Tit', 'Long-tailed Tit', 'Marsh Tit'],
  ),
];

/// Service that manages bird family classification and progress tracking.
class BirdFamilyService {
  final BirdService _birdService;
  final AviaryService _aviaryService;

  late final Map<String, List<Bird>> _familyMembers;

  BirdFamilyService(this._birdService, this._aviaryService) {
    _buildIndex();
  }

  void _buildIndex() {
    _familyMembers = {};
    for (final family in families) {
      _familyMembers[family.id] = _birdService.all
          .where((b) => family.containsBird(b))
          .toList();
    }
  }

  /// Get all family progress snapshots, sorted by progress descending.
  List<FamilyProgress> get allProgress {
    final collected = _aviaryService.all.toSet();
    return families
        .map((f) {
          final members = _familyMembers[f.id] ?? [];
          final owned = members.where((b) => collected.contains(b.name)).toList();
          return FamilyProgress(family: f, allMembers: members, collectedMembers: owned);
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
    final collected = _aviaryService.all.toSet();
    final owned = members.where((b) => collected.contains(b.name)).toList();
    return FamilyProgress(family: family, allMembers: members, collectedMembers: owned);
  }

  /// Find which family a bird belongs to (first match).
  BirdFamily? familyOf(Bird bird) {
    for (final family in families) {
      if (family.containsBird(bird)) return family;
    }
    return null;
  }

  /// Total families with gold mastery.
  int get completedFamilies =>
      allProgress.where((fp) => fp.mastery == FamilyMastery.gold).length;
}

final birdFamilyServiceProvider = Provider<BirdFamilyService>((ref) {
  throw UnimplementedError('birdFamilyServiceProvider must be overridden');
});
