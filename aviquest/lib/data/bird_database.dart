import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/bird.dart';

// ─── Bird Database ────────────────────────────────────────────────────────────
// 385 species loaded from assets/birds.json at startup.
// Use [birdIndex] for O(1) lookups by name.

/// All birds, populated by [loadBirds] before the first frame.
late final List<Bird> birds;

/// O(1) lookup by bird name, populated alongside [birds].
late final Map<String, Bird> birdIndex;

/// Load bird data from the bundled JSON asset.
/// Must be called once during app initialisation (after ensureInitialized).
Future<void> loadBirds() async {
  final jsonStr = await rootBundle.loadString('assets/birds.json');
  final List<dynamic> jsonList = json.decode(jsonStr) as List<dynamic>;
  birds = jsonList
      .map((e) => Bird.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
  birdIndex = {for (final b in birds) b.name: b};
}
