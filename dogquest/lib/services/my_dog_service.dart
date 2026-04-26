import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dogquest/models/my_dog_profile.dart';

/// Persists the user's personal dog profiles to Hive.
class MyDogService {
  final Box _box;
  static const _key = 'my_dogs';

  MyDogService(this._box);

  /// All registered dog profiles.
  List<MyDogProfile> get dogs {
    final raw = _box.get(_key) as String?;
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => MyDogProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Whether the user has registered at least one dog.
  bool get hasDogs => dogs.isNotEmpty;

  /// Get a specific dog by name.
  MyDogProfile? getDog(String name) {
    try {
      return dogs.firstWhere((d) => d.name == name);
    } catch (_) {
      return null;
    }
  }

  /// Add a new dog profile.
  void addDog(MyDogProfile dog) {
    final current = dogs;
    current.add(dog);
    _save(current);
  }

  /// Update an existing dog profile by name.
  void updateDog(String originalName, MyDogProfile updated) {
    final current = dogs;
    final idx = current.indexWhere((d) => d.name == originalName);
    if (idx >= 0) {
      current[idx] = updated;
      _save(current);
    }
  }

  /// Remove a dog profile.
  void removeDog(String name) {
    final current = dogs;
    current.removeWhere((d) => d.name == name);
    _save(current);
  }

  void _save(List<MyDogProfile> profiles) {
    _box.put(_key, jsonEncode(profiles.map((d) => d.toJson()).toList()));
  }
}

final myDogServiceProvider = Provider<MyDogService>((ref) {
  throw UnimplementedError(
    'myDogServiceProvider must be overridden after Hive init',
  );
});
