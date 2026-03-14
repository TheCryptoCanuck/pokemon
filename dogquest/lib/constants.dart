import 'package:flutter/material.dart';

const appName = 'DogQuest';

// ─── Rarity Enum ──────────────────────────────────────────────────────────────

enum Rarity {
  common,
  uncommon,
  rare,
  legendary,
  unknown;

  Color get color => _rarityColors[this]!;

  String get label => this == unknown ? 'NEW DISCOVERY' : name.toUpperCase();
}

const _rarityColors = <Rarity, Color>{
  Rarity.common: Colors.white70,
  Rarity.uncommon: Color(0xFFD4874E),
  Rarity.rare: Color(0xFF2196F3),
  Rarity.legendary: Colors.amber,
  Rarity.unknown: Color(0xFFCE93D8),
};

// ─── Theme Colors ─────────────────────────────────────────────────────────────

const bgDeep = Color(0xFF1A0F0A);
const bgCard = Color(0xFF2A1F1A);
const bgNav = Color(0xFF1F0F0A);
const accent = Color(0xFFD4874E);
const accentLight = Color(0xFFE8A96E);
const textPrimary = Colors.white;
const textSecondary = Colors.white70;

// ─── Unlockable Avatars ──────────────────────────────────────────────────────

class AvatarOption {
  final String id;
  final String emoji;
  final String name;
  final String description;
  final Color bgColor;
  /// Unlock condition check: takes (level, kennelCount, achievements, streak, totalSightings).
  final bool Function(int level, int kennelCount, Set<String> achievements, int streak, int totalSightings) isUnlocked;

  const AvatarOption({
    required this.id,
    required this.emoji,
    required this.name,
    required this.description,
    required this.bgColor,
    required this.isUnlocked,
  });
}

final List<AvatarOption> avatarOptions = [
  // Always unlocked
  AvatarOption(
    id: 'default',
    emoji: '🐶',
    name: 'Puppy',
    description: 'Every dog lover starts here',
    bgColor: const Color(0xFFD4874E),
    isUnlocked: (_, __, ___, ____, _____) => true,
  ),
  // Collection milestones
  AvatarOption(
    id: 'good_boy',
    emoji: '🐕',
    name: 'Good Boy',
    description: 'A faithful companion',
    bgColor: const Color(0xFFE57373),
    isUnlocked: (_, kennel, __, ___, ____) => kennel >=1,
  ),
  AvatarOption(
    id: 'guard_dog',
    emoji: '🐕‍🦺',
    name: 'Guard Dog',
    description: 'Always on watch',
    bgColor: const Color(0xFF7E57C2),
    isUnlocked: (_, kennel, __, ___, ____) => kennel >=10,
  ),
  AvatarOption(
    id: 'bloodhound',
    emoji: '🦮',
    name: 'Bloodhound',
    description: 'Nothing escapes your nose',
    bgColor: const Color(0xFF8D6E63),
    isUnlocked: (_, kennel, __, ___, ____) => kennel >=20,
  ),
  AvatarOption(
    id: 'show_champion',
    emoji: '🐩',
    name: 'Show Champion',
    description: 'Best in show',
    bgColor: const Color(0xFF66BB6A),
    isUnlocked: (_, kennel, __, ___, ____) => kennel >=50,
  ),
  AvatarOption(
    id: 'top_dog',
    emoji: '🏆',
    name: 'Top Dog',
    description: 'The ultimate canine expert',
    bgColor: const Color(0xFFFF7043),
    isUnlocked: (_, kennel, __, ___, ____) => kennel >=100,
  ),
  // Level milestones
  AvatarOption(
    id: 'star',
    emoji: '⭐',
    name: 'Rising Star',
    description: 'Reach level 5',
    bgColor: const Color(0xFFFDD835),
    isUnlocked: (level, _, __, ___, ____) => level >= 5,
  ),
  AvatarOption(
    id: 'crown',
    emoji: '🐺',
    name: 'Pack Alpha',
    description: 'Leader of the pack',
    bgColor: const Color(0xFFFFB300),
    isUnlocked: (level, _, __, ___, ____) => level >= 20,
  ),
  // Streak milestones
  AvatarOption(
    id: 'flame',
    emoji: '🔥',
    name: 'Streak Master',
    description: 'Maintain a 7-day streak',
    bgColor: const Color(0xFFEF5350),
    isUnlocked: (_, __, ___, streak, ____) => streak >= 7,
  ),
  AvatarOption(
    id: 'lightning',
    emoji: '⚡',
    name: 'Unstoppable',
    description: '30-day streak',
    bgColor: const Color(0xFFFFCA28),
    isUnlocked: (_, __, ___, streak, ____) => streak >= 30,
  ),
  // Rarity finds
  AvatarOption(
    id: 'diamond',
    emoji: '💎',
    name: 'Gem Hunter',
    description: 'Find a rare dog',
    bgColor: const Color(0xFF42A5F5),
    isUnlocked: (_, __, achievements, ___, ____) => achievements.contains('rare_find'),
  ),
  AvatarOption(
    id: 'legend',
    emoji: '✨',
    name: 'Legendary',
    description: 'Find a legendary dog',
    bgColor: const Color(0xFFAB47BC),
    isUnlocked: (_, __, achievements, ___, ____) => achievements.contains('legendary_find'),
  ),
  // Special achievements
  AvatarOption(
    id: 'scholar',
    emoji: '🎓',
    name: 'Scholar',
    description: 'Complete 10 quizzes',
    bgColor: const Color(0xFF26A69A),
    isUnlocked: (_, __, achievements, ___, ____) => achievements.contains('ten_quizzes'),
  ),
  AvatarOption(
    id: 'shield',
    emoji: '🛡️',
    name: 'Guardian',
    description: 'Spot an endangered dog',
    bgColor: const Color(0xFF5C6BC0),
    isUnlocked: (_, __, achievements, ___, ____) => achievements.contains('endangered_spotter'),
  ),
  // Sighting milestone
  AvatarOption(
    id: 'binoculars',
    emoji: '🔭',
    name: 'Field Expert',
    description: 'Log 50 total sightings',
    bgColor: const Color(0xFF78909C),
    isUnlocked: (_, __, ___, ____, sightings) => sightings >= 50,
  ),
];
