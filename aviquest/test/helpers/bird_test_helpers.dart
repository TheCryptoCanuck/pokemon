import 'package:aviquest/main.dart';

/// Factory for creating test Bird instances with sensible defaults.
Bird makeBird({
  String name = 'Test Bird',
  String scientificName = 'Testus birdus',
  String imageUrl = 'https://example.com/bird.jpg',
  String audioUrl = '',
  String lore = 'A test bird for unit testing.',
  String habitat = 'Test Lab',
  String conservationStatus = 'Least Concern',
  String rarity = 'common',
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
final commonBird = makeBird(rarity: 'common', baseXp: 50);
final uncommonBird = makeBird(rarity: 'uncommon', baseXp: 100);
final rareBird = makeBird(rarity: 'rare', baseXp: 200);
final legendaryBird = makeBird(rarity: 'legendary', baseXp: 500);

/// Valid rarity values recognised by the Bird model.
const validRarities = ['common', 'uncommon', 'rare', 'legendary'];
