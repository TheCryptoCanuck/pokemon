import 'package:aviquest/models/bird.dart';
import 'package:aviquest/constants.dart';

/// Factory for creating test Bird instances with sensible defaults.
Bird makeBird({
  String name = 'Test Bird',
  String scientificName = 'Testus birdus',
  String imageUrl = 'https://example.com/bird.jpg',
  String audioUrl = '',
  String lore = 'A test bird for unit testing.',
  String habitat = 'Test Lab',
  String conservationStatus = 'Least Concern',
  Rarity rarity = Rarity.common,
  int baseXp = 100,
}) {
  return Bird(
    name: name,
    scientificName: scientificName,
    imageUrl: imageUrl,
    audioUrl: audioUrl,
    lore: lore,
    habitat: habitat,
    conservationStatus: conservationStatus,
    rarity: rarity,
    baseXp: baseXp,
  );
}

/// Pre-built birds for common test scenarios.
final commonBird = makeBird(rarity: Rarity.common, baseXp: 50);
final uncommonBird = makeBird(rarity: Rarity.uncommon, baseXp: 100);
final rareBird = makeBird(rarity: Rarity.rare, baseXp: 200);
final legendaryBird = makeBird(rarity: Rarity.legendary, baseXp: 500);

/// Valid rarity values recognised by the Bird model.
const validRarities = [Rarity.common, Rarity.uncommon, Rarity.rare, Rarity.legendary];
