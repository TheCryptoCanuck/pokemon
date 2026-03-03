import 'package:flutter/foundation.dart';

import '../database_service.dart';
import '../models/bird_model.dart';
import '../repositories/bird_repository.dart';

/// Seeds the bird catalog from the in-app bird list into SQLite.
///
/// Designed to run once on first launch. Checks if data exists before
/// inserting to prevent duplicates on subsequent launches.
class BirdSeeder {
  final BirdRepository _repo;

  BirdSeeder([BirdRepository? repo]) : _repo = repo ?? BirdRepository();

  /// Seed the birds table from a list of bird data maps.
  ///
  /// Pass the existing `birds` list from main.dart converted to maps.
  /// Only inserts if the table is empty (idempotent).
  Future<SeedResult> seed(List<Map<String, dynamic>> birdData) async {
    final alreadySeeded = await _repo.isSeeded();
    if (alreadySeeded) {
      final count = await _repo.getCount();
      debugPrint('[Seeder] Birds table already seeded ($count records)');
      return SeedResult(
        seeded: false,
        recordCount: count,
        message: 'Already seeded',
      );
    }

    final now = DateTime.now();
    final records = birdData.map((data) => BirdRecord(
      name: data['name'] as String,
      scientificName: data['scientificName'] as String,
      imageUrl: data['imageUrl'] as String,
      audioUrl: data['audioUrl'] as String,
      lore: data['lore'] as String,
      habitat: data['habitat'] as String,
      conservationStatus: data['conservationStatus'] as String,
      rarity: data['rarity'] as String,
      baseXp: data['baseXp'] as int,
      createdAt: now,
      updatedAt: now,
    )).toList();

    debugPrint('[Seeder] Seeding ${records.length} bird species...');
    await _repo.insertAll(records);

    final count = await _repo.getCount();
    debugPrint('[Seeder] Seeding complete: $count records inserted');

    return SeedResult(
      seeded: true,
      recordCount: count,
      message: 'Seeded $count bird species',
    );
  }

  /// Seed from Bird objects directly (for integration with existing code).
  ///
  /// Accepts objects that have the same fields as the Bird class in main.dart.
  Future<SeedResult> seedFromBirds(List<dynamic> birds) async {
    final birdData = birds.map((b) => {
      'name': b.name as String,
      'scientificName': b.scientificName as String,
      'imageUrl': b.imageUrl as String,
      'audioUrl': b.audioUrl as String,
      'lore': b.lore as String,
      'habitat': b.habitat as String,
      'conservationStatus': b.conservationStatus as String,
      'rarity': b.rarity as String,
      'baseXp': b.baseXp as int,
    }).toList();

    return seed(birdData);
  }
}

class SeedResult {
  final bool seeded;
  final int recordCount;
  final String message;

  const SeedResult({
    required this.seeded,
    required this.recordCount,
    required this.message,
  });

  @override
  String toString() => 'SeedResult(seeded: $seeded, count: $recordCount, $message)';
}
