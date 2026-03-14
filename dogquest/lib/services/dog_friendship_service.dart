import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/dog.dart';
import '../models/dog_friendship.dart';
import 'dog_service.dart';

/// Manages dog friendships and neighborhood dog generation.
class DogFriendshipService {
  final Box _box;
  final DogService _dogSvc;
  static const _friendshipsKey = 'dog_friendships';
  static const _neighborhoodKey = 'neighborhood_dogs';
  static const _neighborhoodDateKey = 'neighborhood_generated_date';

  DogFriendshipService(this._box, this._dogSvc);

  // ─── Friendships ─────────────────────────────────────────────────

  List<DogFriendship> get friendships {
    final raw = _box.get(_friendshipsKey) as String?;
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => DogFriendship.fromJson(e as Map<String, dynamic>)).toList();
  }

  List<DogFriendship> friendshipsFor(String myDogName) {
    return friendships.where((f) => f.myDogName == myDogName).toList();
  }

  DogFriendship? getFriendship(String myDogName, String neighborName) {
    try {
      return friendships.firstWhere(
        (f) => f.myDogName == myDogName && f.neighborDogName == neighborName,
      );
    } catch (_) {
      return null;
    }
  }

  int get totalFriendships => friendships.length;
  int get bestFriendCount => friendships.where((f) => f.level == FriendshipLevel.bestFriend).length;

  /// Start a friendship between the user's dog and a neighborhood dog.
  void befriend(String myDogName, NeighborhoodDog neighbor) {
    final existing = getFriendship(myDogName, neighbor.name);
    if (existing != null) return;

    final all = friendships;
    all.add(DogFriendship(
      myDogName: myDogName,
      neighborDogName: neighbor.name,
      neighborBreed: neighbor.breed,
      neighborEmoji: neighbor.emoji,
      visits: 1,
      lastVisit: DateTime.now(),
      createdAt: DateTime.now(),
    ));
    _saveFriendships(all);
  }

  /// Visit a friend dog (once per day). Returns true if visit was recorded.
  bool visit(String myDogName, String neighborName) {
    final all = friendships;
    final idx = all.indexWhere(
      (f) => f.myDogName == myDogName && f.neighborDogName == neighborName,
    );
    if (idx < 0) return false;

    final friendship = all[idx];
    if (!friendship.canVisitToday) return false;

    all[idx] = friendship.copyWith(
      visits: friendship.visits + 1,
      lastVisit: DateTime.now(),
    );
    _saveFriendships(all);
    return true;
  }

  /// Remove a friendship.
  void removeFriendship(String myDogName, String neighborName) {
    final all = friendships;
    all.removeWhere((f) => f.myDogName == myDogName && f.neighborDogName == neighborName);
    _saveFriendships(all);
  }

  void _saveFriendships(List<DogFriendship> list) {
    _box.put(_friendshipsKey, jsonEncode(list.map((f) => f.toJson()).toList()));
  }

  // ─── Neighborhood Dogs ───────────────────────────────────────────

  /// Get or generate neighborhood dogs. Refreshes weekly.
  List<NeighborhoodDog> getNeighborhoodDogs() {
    final now = DateTime.now();
    final weekKey = _weekKey(now);
    final storedWeek = _box.get(_neighborhoodDateKey) as String?;

    if (storedWeek == weekKey) {
      final raw = _box.get(_neighborhoodKey) as String?;
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        return list.map((e) => NeighborhoodDog.fromJson(e as Map<String, dynamic>)).toList();
      }
    }

    // Generate new neighborhood
    final dogs = _generateNeighborhood();
    _box.put(_neighborhoodKey, jsonEncode(dogs.map((d) => d.toJson()).toList()));
    _box.put(_neighborhoodDateKey, weekKey);
    return dogs;
  }

  List<NeighborhoodDog> _generateNeighborhood() {
    final rng = Random(DateTime.now().millisecondsSinceEpoch ~/ 604800000); // seed by week
    final allBreeds = _dogSvc.all;
    if (allBreeds.isEmpty) return [];

    // Pick 8 random breeds for the neighborhood
    final shuffledBreeds = List<Dog>.from(allBreeds)..shuffle(rng);
    final selectedBreeds = shuffledBreeds.take(8).toList();

    // Available grid positions (4x4 grid, but skip center 2x2 for "home")
    final positions = <(int, int)>[
      (0, 0), (1, 0), (2, 0), (3, 0),
      (0, 1),                 (3, 1),
      (0, 2),                 (3, 2),
      (0, 3), (1, 3), (2, 3), (3, 3),
    ];
    positions.shuffle(rng);

    final shuffledNames = List<(String, String)>.from(neighborhoodDogNames)..shuffle(rng);
    final shuffledPersonalities = List<String>.from(neighborhoodPersonalities)..shuffle(rng);

    return List.generate(selectedBreeds.length.clamp(0, positions.length), (i) {
      final breed = selectedBreeds[i];
      final pos = positions[i];
      final nameEntry = shuffledNames[i % shuffledNames.length];
      return NeighborhoodDog(
        name: nameEntry.$1,
        breed: breed.name,
        emoji: nameEntry.$2,
        gridX: pos.$1,
        gridY: pos.$2,
        personality: shuffledPersonalities[i % shuffledPersonalities.length],
      );
    });
  }

  String _weekKey(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }
}

final dogFriendshipServiceProvider = Provider<DogFriendshipService>((ref) {
  throw UnimplementedError('dogFriendshipServiceProvider must be overridden after Hive init');
});
