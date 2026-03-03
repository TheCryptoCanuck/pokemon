import 'dart:math';
import 'models/bird.dart';
import 'data/birds.dart';

String levelTitle(int level) {
  if (level < 3) return 'Fledgling';
  if (level < 6) return 'Nestling';
  if (level < 10) return 'Sparrow';
  if (level < 15) return 'Warbler';
  if (level < 20) return 'Songweaver';
  if (level < 30) return 'Falconer';
  if (level < 40) return 'Eagle Scout';
  return 'Master Birder';
}

int xpForNextLevel(int level) => (1000 * pow(level, 1.4)).round();

/// Returns a placeholder Bird for any species name not found in [birds].
/// The stored Hive name is preserved so the real data can be filled in
/// when the database is updated — no silent data corruption.
Bird unknownBird(String name) => Bird(
  name: name,
  scientificName: 'Species not yet in database',
  imageUrl: '',
  audioUrl: '',
  lore: 'You found something we\'ve never seen before! This species isn\'t in our database yet. '
      'Your discovery has been logged and will help us grow AviQuest.',
  habitat: 'Unknown',
  conservationStatus: 'Unknown',
  rarity: 'unknown',
  baseXp: 100, // reward curiosity
);

/// Weighted random bird pick: common 60%, uncommon 25%, rare 12%, legendary 3%
Bird weightedRandomBird(Random rng) {
  final r = rng.nextDouble();
  late String rarity;
  if (r < 0.60) {
    rarity = 'common';
  } else if (r < 0.85) {
    rarity = 'uncommon';
  } else if (r < 0.97) {
    rarity = 'rare';
  } else {
    rarity = 'legendary';
  }
  final pool = birds.where((b) => b.rarity == rarity).toList();
  return pool[rng.nextInt(pool.length)];
}

const achievements = {
  'first_bird': ('🐦', 'First Feather', 'Identify your first bird'),
  'five_species': ('🌿', 'Nature Curious', 'Collect 5 different species'),
  'ten_species': ('🏆', 'Avid Birder', 'Collect 10 different species'),
  'twenty_species': ('🦅', 'Wing Watcher', 'Collect 20 different species'),
  'rare_find': ('💎', 'Rare Encounter', 'Identify a rare bird'),
  'legendary_find': ('✨', 'Legend Spotter', 'Identify a legendary bird'),
  'level_5': ('⭐', 'Rising Birder', 'Reach level 5'),
  'level_10': ('🌟', 'Expert Nester', 'Reach level 10'),
  'level_20': ('🌠', 'Sky Master', 'Reach level 20'),
};
