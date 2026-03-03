import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/bird.dart';
import 'bird_service.dart';

class AviaryService {
  final Box<String> _box;
  BirdService? _birdSvc;

  AviaryService(this._box);

  /// Inject after both services are initialised in main.dart.
  void setBirdService(BirdService svc) => _birdSvc = svc;

  Box<String> get box => _box;
  int get count => _box.length;
  List<String> get all => _box.values.toList();
  bool contains(String birdName) => _box.values.contains(birdName);

  /// All collected birds resolved to [Bird] objects.
  /// Requires [setBirdService] to have been called first.
  List<Bird> get collectedBirds {
    final svc = _birdSvc;
    if (svc == null) return [];
    return _box.values
        .map((name) => svc.lookup(name))
        .whereType<Bird>()
        .toList();
  }

  /// Adds a bird to the aviary. Returns true if added, false if duplicate.
  bool add(String birdName) {
    if (contains(birdName)) return false;
    _box.add(birdName);
    return true;
  }
}

final aviaryServiceProvider = Provider<AviaryService>((ref) {
  throw UnimplementedError('aviaryServiceProvider must be overridden after Hive init');
});
