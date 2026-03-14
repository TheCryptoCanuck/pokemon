import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dogquest/models/dog.dart';
import 'package:dogquest/constants.dart';
import 'package:dogquest/services/dog_service.dart';
import 'package:dogquest/services/kennel_service.dart';

// ---------------------------------------------------------------------------
// Fakes / Mocks
// ---------------------------------------------------------------------------

/// Mocktail mock for the Hive Box<String> type.
///
/// Box<String> is a concrete Hive class with no abstract interface, so we
/// extend Mock and mix in the generic type directly. Mocktail stubs are set
/// per-test so each test controls exactly what the box reports.
class MockBox extends Mock implements Box<String> {}

/// Mocktail mock for DogService.
///
/// DogService is a concrete class. We only need to stub [lookup] in the
/// collectedDogs tests; all other methods can remain un-stubbed.
class MockDogService extends Mock implements DogService {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a minimal [Dog] fixture with sensible defaults for any field that
/// is not under test.
Dog _makeDog(String name, {Rarity rarity = Rarity.common}) => Dog(
      name: name,
      scientificName: 'Canis lupus $name',
      imageUrl: '',
      audioUrl: '',
      lore: '',
      habitat: 'Domestic',
      conservationStatus: 'LC',
      rarity: rarity,
      baseXp: 20,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockBox box;
  late KennelService service;

  setUp(() {
    box = MockBox();
    service = KennelService(box);
  });

  // ─── add() ────────────────────────────────────────────────────────────────

  group('add()', () {
    test('returns true and stores the dog when the name is new', () {
      const dogName = 'Golden Retriever';

      // The box does not yet contain this key.
      when(() => box.containsKey(dogName)).thenReturn(false);
      // put() is a void async method; we stub it as a no-op.
      when(() => box.put(dogName, dogName)).thenAnswer((_) async {});

      final result = service.add(dogName);

      expect(result, isTrue);
      // Verify the name was stored with itself as both key and value.
      verify(() => box.put(dogName, dogName)).called(1);
    });

    test('returns false and does NOT call put() when the name is a duplicate',
        () {
      const dogName = 'Labrador Retriever';

      when(() => box.containsKey(dogName)).thenReturn(true);

      final result = service.add(dogName);

      expect(result, isFalse);
      // put() must never be called for a duplicate.
      verifyNever(() => box.put(any(), any()));
    });
  });

  // ─── contains() ───────────────────────────────────────────────────────────

  group('contains()', () {
    test('returns true when the box has the key', () {
      when(() => box.containsKey('Poodle')).thenReturn(true);

      expect(service.contains('Poodle'), isTrue);
    });

    test('returns false when the box does not have the key', () {
      when(() => box.containsKey('Dachshund')).thenReturn(false);

      expect(service.contains('Dachshund'), isFalse);
    });
  });

  // ─── count ────────────────────────────────────────────────────────────────

  group('count', () {
    test('reflects the number of entries in the box', () {
      when(() => box.length).thenReturn(3);

      expect(service.count, 3);
    });

    test('returns 0 when the box is empty', () {
      when(() => box.length).thenReturn(0);

      expect(service.count, 0);
    });

    test('updates as simulated additions grow the reported length', () {
      // First call: box has 1 entry; second call: 2 entries.
      var callCount = 0;
      when(() => box.length).thenAnswer((_) => ++callCount);

      expect(service.count, 1);
      expect(service.count, 2);
    });
  });

  // ─── all ──────────────────────────────────────────────────────────────────

  group('all', () {
    test('returns every value from the box as a List<String>', () {
      const stored = ['Beagle', 'Boxer', 'Bulldog'];
      when(() => box.values).thenReturn(stored);

      expect(service.all, equals(stored));
    });

    test('returns an empty list when the box is empty', () {
      when(() => box.values).thenReturn([]);

      expect(service.all, isEmpty);
    });

    test('returns a new list instance on each access (values.toList())', () {
      when(() => box.values).thenReturn(['Beagle']);

      final first = service.all;
      final second = service.all;

      // toList() produces a fresh List each time; the two references differ.
      expect(identical(first, second), isFalse);
      expect(first, equals(second));
    });
  });

  // ─── collectedDogs ────────────────────────────────────────────────────────

  group('collectedDogs', () {
    test('returns empty list when setDogService has never been called', () {
      // Even if the box has values, without a DogService we get nothing.
      when(() => box.values).thenReturn(['Poodle', 'Husky']);

      expect(service.collectedDogs, isEmpty);
    });

    test('resolves stored names to Dog objects via DogService.lookup()', () {
      final mockDogSvc = MockDogService();
      final poodle = _makeDog('Poodle');
      final husky = _makeDog('Siberian Husky', rarity: Rarity.uncommon);

      when(() => box.values).thenReturn(['Poodle', 'Siberian Husky']);
      when(() => mockDogSvc.lookup('Poodle')).thenReturn(poodle);
      when(() => mockDogSvc.lookup('Siberian Husky')).thenReturn(husky);

      service.setDogService(mockDogSvc);

      final result = service.collectedDogs;

      expect(result, hasLength(2));
      expect(result[0].name, 'Poodle');
      expect(result[1].name, 'Siberian Husky');
    });

    test('silently drops names that lookup() cannot resolve (returns null)', () {
      final mockDogSvc = MockDogService();
      final golden = _makeDog('Golden Retriever');

      when(() => box.values).thenReturn(['Golden Retriever', 'UnknownBreed']);
      when(() => mockDogSvc.lookup('Golden Retriever')).thenReturn(golden);
      // Simulates a stored name that no longer maps to a known Dog.
      when(() => mockDogSvc.lookup('UnknownBreed')).thenReturn(null);

      service.setDogService(mockDogSvc);

      final result = service.collectedDogs;

      expect(result, hasLength(1));
      expect(result.first.name, 'Golden Retriever');
    });

    test('returns empty list when box is empty even with DogService set', () {
      final mockDogSvc = MockDogService();

      when(() => box.values).thenReturn([]);

      service.setDogService(mockDogSvc);

      expect(service.collectedDogs, isEmpty);
      // lookup() must not be called at all when there are no stored names.
      verifyNever(() => mockDogSvc.lookup(any()));
    });

    test('calls lookup() exactly once per stored name', () {
      final mockDogSvc = MockDogService();
      final corgi = _makeDog('Pembroke Welsh Corgi');

      when(() => box.values).thenReturn(['Pembroke Welsh Corgi']);
      when(() => mockDogSvc.lookup('Pembroke Welsh Corgi')).thenReturn(corgi);

      service.setDogService(mockDogSvc);
      service.collectedDogs;

      verify(() => mockDogSvc.lookup('Pembroke Welsh Corgi')).called(1);
    });
  });
}
