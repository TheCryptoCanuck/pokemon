import 'package:flutter_test/flutter_test.dart';
import 'package:aviquest/models/bird.dart';
import 'package:aviquest/constants.dart';

void main() {
  group('Bird', () {
    test('fromJson / toJson round-trips correctly', () {
      final json = {
        'name': 'Test Bird',
        'scientificName': 'Testus birdus',
        'imageUrl': 'https://example.com/bird.jpg',
        'audioUrl': 'https://example.com/bird.mp3',
        'lore': 'A test bird.',
        'habitat': 'Test habitat',
        'conservationStatus': 'Least Concern',
        'rarity': 'common',
        'baseXp': 50,
      };

      final bird = Bird.fromJson(json);
      expect(bird.name, 'Test Bird');
      expect(bird.scientificName, 'Testus birdus');
      expect(bird.rarity, Rarity.common);
      expect(bird.baseXp, 50);

      final roundTripped = Bird.fromJson(bird.toJson());
      expect(roundTripped.name, bird.name);
      expect(roundTripped.rarity, bird.rarity);
      expect(roundTripped.baseXp, bird.baseXp);
    });

    test('xp multiplier applies correctly per rarity', () {
      Bird makeBird(Rarity r) => Bird(
        name: 'Test',
        scientificName: '',
        imageUrl: '',
        audioUrl: '',
        lore: '',
        habitat: '',
        conservationStatus: '',
        rarity: r,
        baseXp: 100,
      );

      expect(makeBird(Rarity.common).xp, 100);
      expect(makeBird(Rarity.uncommon).xp, 150);
      expect(makeBird(Rarity.rare).xp, 200);
      expect(makeBird(Rarity.legendary).xp, 500);
      expect(makeBird(Rarity.unknown).xp, 100);
    });

    test('fromJson throws on invalid rarity', () {
      final json = {
        'name': 'Bad',
        'scientificName': '',
        'imageUrl': '',
        'audioUrl': '',
        'lore': '',
        'habitat': '',
        'conservationStatus': '',
        'rarity': 'mythical',
        'baseXp': 0,
      };
      expect(() => Bird.fromJson(json), throwsA(isA<ArgumentError>()));
    });
  });
}
