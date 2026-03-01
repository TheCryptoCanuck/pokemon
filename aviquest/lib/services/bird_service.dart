import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import '../constants.dart';
import '../models/bird.dart';

final _log = Logger('BirdService');

class BirdService {
  late final List<Bird> _birds;
  late final Map<String, Bird> _index;

  List<Bird> get all => _birds;
  Map<String, Bird> get index => _index;

  Future<void> load() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/birds.json');
      final List<dynamic> jsonList = json.decode(jsonStr) as List<dynamic>;
      _birds = jsonList
          .map((e) => Bird.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
      _index = {for (final b in _birds) b.name: b};
      _log.info('Loaded ${_birds.length} birds');
    } catch (e, st) {
      _log.severe('Failed to load birds.json', e, st);
      rethrow;
    }
  }

  Bird? lookup(String name) => _index[name];

  Bird unknownBird(String name) => Bird(
    name: name,
    scientificName: 'Species not yet in database',
    imageUrl: '',
    audioUrl: '',
    lore: 'You found something we\'ve never seen before! This species isn\'t in our database yet. '
        'Your discovery has been logged and will help us grow AviQuest.',
    habitat: 'Unknown',
    conservationStatus: 'Unknown',
    rarity: Rarity.unknown,
    baseXp: 100,
  );

  /// Weighted random bird pick: common 60%, uncommon 25%, rare 12%, legendary 3%
  Bird weightedRandomBird(Random rng) {
    final r = rng.nextDouble();
    late Rarity rarity;
    if (r < 0.60) {
      rarity = Rarity.common;
    } else if (r < 0.85) {
      rarity = Rarity.uncommon;
    } else if (r < 0.97) {
      rarity = Rarity.rare;
    } else {
      rarity = Rarity.legendary;
    }
    final pool = _birds.where((b) => b.rarity == rarity).toList();
    return pool[rng.nextInt(pool.length)];
  }

  List<Bird> filter({Rarity? rarity, String search = ''}) {
    return _birds.where((b) {
      final matchRarity = rarity == null || b.rarity == rarity;
      final matchSearch = search.isEmpty ||
          b.name.toLowerCase().contains(search.toLowerCase()) ||
          b.scientificName.toLowerCase().contains(search.toLowerCase());
      return matchRarity && matchSearch;
    }).toList();
  }
}

final birdServiceProvider = Provider<BirdService>((ref) {
  throw UnimplementedError('birdServiceProvider must be overridden after loading');
});
