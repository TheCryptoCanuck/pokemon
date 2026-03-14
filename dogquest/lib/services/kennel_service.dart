import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/dog.dart';
import 'dog_service.dart';

class KennelService {
  final Box<String> _box;
  DogService? _dogSvc;

  KennelService(this._box);

  /// Inject after both services are initialised in main.dart.
  void setDogService(DogService svc) => _dogSvc = svc;

  Box<String> get box => _box;
  int get count => _box.length;
  List<String> get all => _box.values.toList();
  bool contains(String dogName) => _box.containsKey(dogName);

  /// All collected dogs resolved to [Dog] objects.
  /// Requires [setDogService] to have been called first.
  List<Dog> get collectedDogs {
    final svc = _dogSvc;
    if (svc == null) return [];
    return _box.values
        .map((name) => svc.lookup(name))
        .whereType<Dog>()
        .toList();
  }

  /// Adds a dog to the kennel. Returns true if added, false if duplicate.
  bool add(String dogName) {
    if (contains(dogName)) return false;
    // Use dog name as key for O(1) contains() lookups
    _box.put(dogName, dogName);
    return true;
  }
}

final kennelServiceProvider = Provider<KennelService>((ref) {
  throw UnimplementedError('kennelServiceProvider must be overridden after Hive init');
});
