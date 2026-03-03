import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';
import 'package:aviquest/services/aviary_service.dart';
import 'package:aviquest/services/bird_service.dart';
import 'package:aviquest/models/bird.dart';
import 'package:aviquest/constants.dart';
import 'helpers/bird_test_helpers.dart';

/// A minimal BirdService substitute for testing collectedBirds.
/// Loads birds from a hand-built list instead of rootBundle.
class _TestBirdService extends BirdService {
  final Map<String, Bird> _testIndex;
  _TestBirdService(List<Bird> birds)
      : _testIndex = {for (final b in birds) b.name: b};

  @override
  Bird? lookup(String name) => _testIndex[name];

  @override
  List<Bird> get all => _testIndex.values.toList();
}

void main() {
  late Directory tempDir;
  late Box<String> box;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('aviary_test_');
    Hive.init(tempDir.path);
    box = await Hive.openBox<String>('test_aviary');
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AviaryService.collectedBirds', () {
    test('returns empty list when birdService not set', () {
      final svc = AviaryService(box);
      expect(svc.collectedBirds, isEmpty);
    });

    test('returns empty list when aviary is empty', () {
      final birds = [makeBird(name: 'Robin')];
      final birdSvc = _TestBirdService(birds);
      final svc = AviaryService(box);
      svc.setBirdService(birdSvc);

      expect(svc.collectedBirds, isEmpty);
    });

    test('resolves collected bird names to Bird objects', () {
      final robin = makeBird(name: 'Robin', rarity: Rarity.common);
      final eagle = makeBird(name: 'Eagle', rarity: Rarity.rare);
      final birdSvc = _TestBirdService([robin, eagle]);
      final svc = AviaryService(box);
      svc.setBirdService(birdSvc);

      svc.add('Robin');
      svc.add('Eagle');

      final collected = svc.collectedBirds;
      expect(collected.length, 2);
      expect(collected.map((b) => b.name), containsAll(['Robin', 'Eagle']));
    });

    test('skips names not found in BirdService', () {
      final robin = makeBird(name: 'Robin');
      final birdSvc = _TestBirdService([robin]);
      final svc = AviaryService(box);
      svc.setBirdService(birdSvc);

      svc.add('Robin');
      svc.add('DeletedBird'); // not in BirdService

      final collected = svc.collectedBirds;
      expect(collected.length, 1);
      expect(collected.first.name, 'Robin');
    });

    test('preserves rarity on collected birds', () {
      final legendary = makeBird(name: 'Phoenix', rarity: Rarity.legendary);
      final birdSvc = _TestBirdService([legendary]);
      final svc = AviaryService(box);
      svc.setBirdService(birdSvc);

      svc.add('Phoenix');

      expect(svc.collectedBirds.first.rarity, Rarity.legendary);
    });
  });

  group('AviaryService.setBirdService', () {
    test('can be called multiple times (updates reference)', () {
      final robin = makeBird(name: 'Robin');
      final eagle = makeBird(name: 'Eagle');
      final svc = AviaryService(box);

      svc.setBirdService(_TestBirdService([robin]));
      svc.add('Robin');
      expect(svc.collectedBirds.length, 1);

      // Switch to a different BirdService that doesn't know Robin
      svc.setBirdService(_TestBirdService([eagle]));
      expect(svc.collectedBirds, isEmpty); // Robin no longer resolves
    });
  });
}
