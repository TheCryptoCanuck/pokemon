import 'package:flutter_test/flutter_test.dart';
import 'package:dogquest/services/dog_mastery_service.dart';

/// Tests for DogMasteryState collection-tracking behavior.
/// The BreedCollectionService relies on DogMasteryState for tracking,
/// so we test the underlying state logic directly.
void main() {
  group('Collection tracking via DogMasteryState', () {
    test('empty state has zero counts', () {
      const state = DogMasteryState();
      expect(state.totalSpotted, 0);
      expect(state.totalFamiliar, 0);
      expect(state.totalExpert, 0);
      expect(state.totalMastered, 0);
    });

    test('adding breeds increases spotted count', () {
      const state = DogMasteryState(
        sightingCounts: {
          'Pug': 1,
          'Beagle': 2,
          'Corgi': 1,
        },
      );
      expect(state.totalSpotted, 3);
    });

    test('progression through all tiers', () {
      const state = DogMasteryState(
        sightingCounts: {
          'A': 1, // spotted
          'B': 3, // familiar
          'C': 5, // expert
          'D': 10, // master
        },
      );
      expect(state.totalSpotted, 4); // all have 1+
      expect(state.totalFamiliar, 3); // B, C, D have 3+
      expect(state.totalExpert, 2); // C, D have 5+
      expect(state.totalMastered, 1); // only D has 10+
    });

    test('copyWith creates new state with updated counts', () {
      const original = DogMasteryState(sightingCounts: {'A': 1});
      final updated = original.copyWith(sightingCounts: {'A': 5, 'B': 2});
      expect(updated.sightingCounts['A'], 5);
      expect(updated.sightingCounts['B'], 2);
      // Original unchanged
      expect(original.sightingCounts['A'], 1);
      expect(original.sightingCounts.containsKey('B'), isFalse);
    });
  });
}
