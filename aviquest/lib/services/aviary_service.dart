import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AviaryService {
  final Box<String> _box;

  AviaryService(this._box);

  Box<String> get box => _box;
  int get count => _box.length;
  List<String> get all => _box.values.toList();
  bool contains(String birdName) => _box.values.contains(birdName);

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
