import 'package:flutter_test/flutter_test.dart';
import 'package:dogquest/services/dog_mastery_service.dart';

void main() {
  group('DogMasteryLevel', () {
    test('requiredSightings increase with level', () {
      expect(DogMasteryLevel.unseen.requiredSightings, 0);
      expect(DogMasteryLevel.spotted.requiredSightings, 1);
      expect(DogMasteryLevel.familiar.requiredSightings, 3);
      expect(DogMasteryLevel.expert.requiredSightings, 5);
      expect(DogMasteryLevel.master.requiredSightings, 10);
    });

    test('xpBonus increases with level', () {
      expect(DogMasteryLevel.unseen.xpBonus, 0);
      expect(DogMasteryLevel.spotted.xpBonus, 25);
      expect(DogMasteryLevel.familiar.xpBonus, 75);
      expect(DogMasteryLevel.expert.xpBonus, 150);
      expect(DogMasteryLevel.master.xpBonus, 300);
    });

    test('next returns next level or null for master', () {
      expect(DogMasteryLevel.unseen.next, DogMasteryLevel.spotted);
      expect(DogMasteryLevel.spotted.next, DogMasteryLevel.familiar);
      expect(DogMasteryLevel.familiar.next, DogMasteryLevel.expert);
      expect(DogMasteryLevel.expert.next, DogMasteryLevel.master);
      expect(DogMasteryLevel.master.next, isNull);
    });

    test('every level has a non-empty label', () {
      for (final level in DogMasteryLevel.values) {
        expect(level.label, isNotEmpty);
      }
    });
  });

  group('DogMasteryInfo', () {
    test('progressToNext is 1.0 for mastered dog', () {
      const info = DogMasteryInfo(
        dogName: 'Beagle',
        sightingCount: 10,
        level: DogMasteryLevel.master,
      );
      expect(info.progressToNext, 1.0);
      expect(info.isMastered, isTrue);
      expect(info.sightingsToNextLevel, 0);
    });

    test('progressToNext is 0.0 at start of a level', () {
      const info = DogMasteryInfo(
        dogName: 'Pug',
        sightingCount: 1,
        level: DogMasteryLevel.spotted,
      );
      expect(info.progressToNext, 0.0);
      expect(info.sightingsToNextLevel, 2); // need 3 for familiar
    });

    test('progressToNext is between 0 and 1 mid-level', () {
      const info = DogMasteryInfo(
        dogName: 'Corgi',
        sightingCount: 2,
        level: DogMasteryLevel.spotted,
      );
      expect(info.progressToNext, 0.5); // (2-1)/(3-1) = 0.5
    });

    test('isMastered is false below master level', () {
      const info = DogMasteryInfo(
        dogName: 'Husky',
        sightingCount: 5,
        level: DogMasteryLevel.expert,
      );
      expect(info.isMastered, isFalse);
    });
  });

  group('DogMasteryState', () {
    test('levelFor returns unseen for unknown dog', () {
      const state = DogMasteryState();
      expect(state.levelFor('Unknown'), DogMasteryLevel.unseen);
    });

    test('levelFor returns correct level based on count', () {
      const state = DogMasteryState(sightingCounts: {
        'Dog1': 1,
        'Dog3': 3,
        'Dog5': 5,
        'Dog10': 10,
      });
      expect(state.levelFor('Dog1'), DogMasteryLevel.spotted);
      expect(state.levelFor('Dog3'), DogMasteryLevel.familiar);
      expect(state.levelFor('Dog5'), DogMasteryLevel.expert);
      expect(state.levelFor('Dog10'), DogMasteryLevel.master);
    });

    test('totalMastered counts only dogs with 10+ sightings', () {
      const state = DogMasteryState(sightingCounts: {
        'A': 10,
        'B': 15,
        'C': 9,
        'D': 5,
      });
      expect(state.totalMastered, 2);
    });

    test('totalExpert counts dogs with 5+ sightings', () {
      const state = DogMasteryState(sightingCounts: {
        'A': 10,
        'B': 5,
        'C': 4,
      });
      expect(state.totalExpert, 2);
    });

    test('masteredDogs returns names of dogs with 10+ sightings', () {
      const state = DogMasteryState(sightingCounts: {
        'Alpha': 10,
        'Beta': 5,
        'Gamma': 12,
      });
      expect(state.masteredDogs, containsAll(['Alpha', 'Gamma']));
      expect(state.masteredDogs, isNot(contains('Beta')));
    });

    test('infoFor returns correct DogMasteryInfo', () {
      const state = DogMasteryState(sightingCounts: {'Rex': 7});
      final info = state.infoFor('Rex');
      expect(info.dogName, 'Rex');
      expect(info.sightingCount, 7);
      expect(info.level, DogMasteryLevel.expert);
    });
  });
}
