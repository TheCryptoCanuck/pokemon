import 'package:flutter_test/flutter_test.dart';
import 'package:dogquest/models/dog_friendship.dart';

void main() {
  group('FriendshipLevel', () {
    test('visitsRequired increase with level', () {
      expect(FriendshipLevel.newNeighbor.visitsRequired, 0);
      expect(FriendshipLevel.acquaintance.visitsRequired, 3);
      expect(FriendshipLevel.friend.visitsRequired, 7);
      expect(FriendshipLevel.bestFriend.visitsRequired, 14);
    });

    test('xpBonus increases with level', () {
      expect(FriendshipLevel.newNeighbor.xpBonus, 0);
      expect(FriendshipLevel.acquaintance.xpBonus, 0.05);
      expect(FriendshipLevel.friend.xpBonus, 0.10);
      expect(FriendshipLevel.bestFriend.xpBonus, 0.20);
    });

    test('every level has a non-empty label', () {
      for (final level in FriendshipLevel.values) {
        expect(level.label, isNotEmpty);
        expect(level.emoji, isNotEmpty);
      }
    });
  });

  group('DogFriendship', () {
    test('level returns correct level based on visits', () {
      DogFriendship makeF(int visits) => DogFriendship(
            myDogName: 'Rex',
            neighborDogName: 'Buddy',
            neighborBreed: 'Pug',
            neighborEmoji: '\u{1F436}',
            visits: visits,
            lastVisit: DateTime(2026, 1, 1),
            createdAt: DateTime(2026, 1, 1),
          );

      expect(makeF(0).level, FriendshipLevel.newNeighbor);
      expect(makeF(2).level, FriendshipLevel.newNeighbor);
      expect(makeF(3).level, FriendshipLevel.acquaintance);
      expect(makeF(6).level, FriendshipLevel.acquaintance);
      expect(makeF(7).level, FriendshipLevel.friend);
      expect(makeF(13).level, FriendshipLevel.friend);
      expect(makeF(14).level, FriendshipLevel.bestFriend);
      expect(makeF(100).level, FriendshipLevel.bestFriend);
    });

    test('visitsToNextLevel is correct', () {
      final f = DogFriendship(
        myDogName: 'Rex',
        neighborDogName: 'Buddy',
        neighborBreed: 'Pug',
        neighborEmoji: '\u{1F436}',
        visits: 5, // acquaintance, next is friend at 7
        lastVisit: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      );
      expect(f.visitsToNextLevel, 2);
    });

    test('visitsToNextLevel is 0 at max level', () {
      final f = DogFriendship(
        myDogName: 'Rex',
        neighborDogName: 'Buddy',
        neighborBreed: 'Pug',
        neighborEmoji: '\u{1F436}',
        visits: 20,
        lastVisit: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      );
      expect(f.visitsToNextLevel, 0);
    });

    test('progressToNextLevel is 1.0 at max level', () {
      final f = DogFriendship(
        myDogName: 'Rex',
        neighborDogName: 'Buddy',
        neighborBreed: 'Pug',
        neighborEmoji: '\u{1F436}',
        visits: 14,
        lastVisit: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      );
      expect(f.progressToNextLevel, 1.0);
    });

    test('progressToNextLevel mid-level', () {
      final f = DogFriendship(
        myDogName: 'Rex',
        neighborDogName: 'Buddy',
        neighborBreed: 'Pug',
        neighborEmoji: '\u{1F436}',
        visits: 5, // acquaintance (3), next friend (7), progress = (5-3)/(7-3) = 0.5
        lastVisit: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      );
      expect(f.progressToNextLevel, 0.5);
    });

    test('canVisitToday returns true for past visits', () {
      final f = DogFriendship(
        myDogName: 'Rex',
        neighborDogName: 'Buddy',
        neighborBreed: 'Pug',
        neighborEmoji: '\u{1F436}',
        visits: 3,
        lastVisit: DateTime(2025, 1, 1), // long ago
        createdAt: DateTime(2025, 1, 1),
      );
      expect(f.canVisitToday, isTrue);
    });

    test('canVisitToday returns false for today', () {
      final now = DateTime.now();
      final f = DogFriendship(
        myDogName: 'Rex',
        neighborDogName: 'Buddy',
        neighborBreed: 'Pug',
        neighborEmoji: '\u{1F436}',
        visits: 3,
        lastVisit: now,
        createdAt: DateTime(2025, 1, 1),
      );
      expect(f.canVisitToday, isFalse);
    });

    test('toJson/fromJson round-trip', () {
      final original = DogFriendship(
        myDogName: 'Rex',
        neighborDogName: 'Buddy',
        neighborBreed: 'Pug',
        neighborEmoji: '\u{1F436}',
        visits: 7,
        lastVisit: DateTime(2026, 3, 10),
        createdAt: DateTime(2026, 3, 1),
      );
      final restored = DogFriendship.fromJson(original.toJson());
      expect(restored.myDogName, 'Rex');
      expect(restored.neighborDogName, 'Buddy');
      expect(restored.neighborBreed, 'Pug');
      expect(restored.visits, 7);
      expect(restored.level, FriendshipLevel.friend);
    });

    test('fromJson handles missing fields', () {
      final f = DogFriendship.fromJson({});
      expect(f.myDogName, '');
      expect(f.visits, 0);
      expect(f.neighborEmoji, '\u{1F436}');
    });

    test('copyWith updates visits and lastVisit', () {
      final original = DogFriendship(
        myDogName: 'Rex',
        neighborDogName: 'Buddy',
        neighborBreed: 'Pug',
        neighborEmoji: '\u{1F436}',
        visits: 3,
        lastVisit: DateTime(2026, 3, 1),
        createdAt: DateTime(2026, 2, 1),
      );
      final updated = original.copyWith(visits: 4, lastVisit: DateTime(2026, 3, 2));
      expect(updated.visits, 4);
      expect(updated.lastVisit, DateTime(2026, 3, 2));
      // Unchanged
      expect(updated.myDogName, 'Rex');
      expect(updated.createdAt, DateTime(2026, 2, 1));
    });
  });

  group('NeighborhoodDog', () {
    test('toJson/fromJson round-trip', () {
      const dog = NeighborhoodDog(
        name: 'Buddy',
        breed: 'Golden Retriever',
        emoji: '\u{1F436}',
        gridX: 2,
        gridY: 3,
        personality: 'loves fetch',
      );
      final restored = NeighborhoodDog.fromJson(dog.toJson());
      expect(restored.name, 'Buddy');
      expect(restored.breed, 'Golden Retriever');
      expect(restored.gridX, 2);
      expect(restored.gridY, 3);
      expect(restored.personality, 'loves fetch');
    });

    test('fromJson handles missing fields', () {
      final dog = NeighborhoodDog.fromJson({});
      expect(dog.name, '');
      expect(dog.gridX, 0);
      expect(dog.personality, '');
    });
  });

  group('Neighborhood data', () {
    test('neighborhoodDogNames has enough entries', () {
      expect(neighborhoodDogNames.length, greaterThanOrEqualTo(8));
    });

    test('neighborhoodPersonalities has enough entries', () {
      expect(neighborhoodPersonalities.length, greaterThanOrEqualTo(8));
    });
  });
}
