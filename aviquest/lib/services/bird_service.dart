import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import '../models/bird.dart';

class BirdService {
  static List<Bird> _birds = [];

  static List<Bird> get birds => _birds;

  static Future<void> load() async {
    if (_birds.isNotEmpty) return;
    final json = await rootBundle.loadString('assets/data/birds.json');
    final List<dynamic> list = jsonDecode(json) as List<dynamic>;
    _birds = list
        .map((e) => Bird.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Weighted random bird pick: common 60%, uncommon 25%, rare 12%, legendary 3%
  static Bird weightedRandom(Random rng) {
    final r = rng.nextDouble();
    late String rarity;
    if (r < 0.60) {
      rarity = 'common';
    } else if (r < 0.85) {
      rarity = 'uncommon';
    } else if (r < 0.97) {
      rarity = 'rare';
    } else {
      rarity = 'legendary';
    }
    final pool = _birds.where((b) => b.rarity == rarity).toList();
    return pool[rng.nextInt(pool.length)];
  }

  static Bird findByName(String name) {
    return _birds.firstWhere(
      (b) => b.name == name,
      orElse: () => unknownBird(name),
    );
  }
}
