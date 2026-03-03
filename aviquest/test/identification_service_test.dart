import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:aviquest/services/identification_service.dart';
import 'package:aviquest/services/bird_service.dart';
import 'package:aviquest/constants.dart';
import 'package:aviquest/models/bird.dart';

/// A minimal BirdService stub for testing identification without loading assets.
class _StubBirdService extends BirdService {
  final List<Bird> _testBirds;

  _StubBirdService(this._testBirds);

  @override
  List<Bird> get all => _testBirds;

  @override
  Bird weightedRandomBird(rng) {
    return _testBirds[rng.nextInt(_testBirds.length)];
  }
}

Bird _makeBird(String name, Rarity rarity, {int baseXp = 50}) => Bird(
  name: name,
  scientificName: 'Testus ${name.toLowerCase().replaceAll(' ', '')}',
  imageUrl: 'https://example.com/$name.jpg',
  audioUrl: '',
  lore: 'Test bird $name',
  habitat: 'Test',
  conservationStatus: 'Least Concern',
  rarity: rarity,
  baseXp: baseXp,
);

void main() {
  group('IdentificationResult', () {
    test('stores bird, confidence, and source', () {
      final bird = _makeBird('Robin', Rarity.common);
      const result = IdentificationResult(
        bird: Bird(
          name: 'Robin',
          scientificName: 'Turdus migratorius',
          imageUrl: '',
          audioUrl: '',
          lore: '',
          habitat: '',
          conservationStatus: '',
          rarity: Rarity.common,
          baseXp: 40,
        ),
        confidence: 0.87,
        source: 'ml',
      );
      expect(result.confidence, 0.87);
      expect(result.source, 'ml');
      expect(result.bird.name, 'Robin');
    });
  });

  group('MockIdentificationService', () {
    late MockIdentificationService service;

    setUp(() {
      final birds = [
        _makeBird('Robin', Rarity.common),
        _makeBird('Blue Jay', Rarity.common),
        _makeBird('Eagle', Rarity.rare),
        _makeBird('Phoenix', Rarity.legendary),
      ];
      final birdSvc = _StubBirdService(birds);
      service = MockIdentificationService(birdSvc);
    });

    test('isModelLoaded returns false', () {
      expect(service.isModelLoaded, isFalse);
    });

    test('identify returns 3 results', () async {
      final results = await service.identify(File('test.jpg'));
      expect(results.length, 3);
    });

    test('results have decreasing confidence', () async {
      final results = await service.identify(File('test.jpg'));
      expect(results[0].confidence, greaterThan(results[1].confidence));
      expect(results[1].confidence, greaterThan(results[2].confidence));
    });

    test('all results have source "mock"', () async {
      final results = await service.identify(File('test.jpg'));
      for (final r in results) {
        expect(r.source, 'mock');
      }
    });

    test('results contain unique birds', () async {
      final results = await service.identify(File('test.jpg'));
      final names = results.map((r) => r.bird.name).toSet();
      expect(names.length, results.length);
    });

    test('identifyByAudio returns same format as identify', () async {
      final results = await service.identifyByAudio(File('test.wav'));
      expect(results.length, 3);
      for (final r in results) {
        expect(r.source, 'mock');
      }
    });
  });
}
