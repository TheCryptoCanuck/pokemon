import 'package:sqflite/sqflite.dart';

import '../database_config.dart';
import '../database_service.dart';

/// Repository for aviary (bird collection/sightings) operations.
///
/// Manages the user's collected bird sightings with support for
/// geolocation and notes.
class AviaryRepository {
  final DatabaseService _dbService;

  AviaryRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService.instance;

  Future<Database> get _db => _dbService.database;

  /// Add a bird sighting to the aviary.
  Future<int> addSighting({
    required String birdName,
    double? latitude,
    double? longitude,
    String? notes,
  }) async {
    final db = await _db;
    return db.insert(DatabaseConfig.tableAviary, {
      'bird_name': birdName,
      'sighted_at': DateTime.now().toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes ?? '',
    });
  }

  /// Get all sightings, newest first.
  Future<List<Map<String, dynamic>>> getAllSightings() async {
    final db = await _db;
    return db.query(
      DatabaseConfig.tableAviary,
      orderBy: 'sighted_at DESC',
    );
  }

  /// Get all sightings for a specific bird.
  Future<List<Map<String, dynamic>>> getSightingsForBird(String birdName) async {
    final db = await _db;
    return db.query(
      DatabaseConfig.tableAviary,
      where: 'bird_name = ?',
      whereArgs: [birdName],
      orderBy: 'sighted_at DESC',
    );
  }

  /// Get distinct bird names the user has collected.
  Future<List<String>> getCollectedBirdNames() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT DISTINCT bird_name FROM ${DatabaseConfig.tableAviary} ORDER BY bird_name ASC',
    );
    return result.map((r) => r['bird_name'] as String).toList();
  }

  /// Get total number of sightings (including duplicates).
  Future<int> getTotalSightings() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseConfig.tableAviary}',
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Get number of unique species collected.
  Future<int> getUniqueSpeciesCount() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(DISTINCT bird_name) as count FROM ${DatabaseConfig.tableAviary}',
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Get sighting counts grouped by rarity (requires join with birds table).
  Future<Map<String, int>> getSightingsByRarity() async {
    final db = await _db;
    final result = await db.rawQuery('''
      SELECT b.rarity, COUNT(*) as count
      FROM ${DatabaseConfig.tableAviary} a
      JOIN ${DatabaseConfig.tableBirds} b ON a.bird_name = b.name
      GROUP BY b.rarity
    ''');
    return {for (final row in result) row['rarity'] as String: row['count'] as int};
  }

  /// Get the most recently sighted birds.
  Future<List<Map<String, dynamic>>> getRecentSightings({int limit = 10}) async {
    final db = await _db;
    return db.query(
      DatabaseConfig.tableAviary,
      orderBy: 'sighted_at DESC',
      limit: limit,
    );
  }

  /// Remove a sighting by ID.
  Future<int> removeSighting(int id) async {
    final db = await _db;
    return db.delete(
      DatabaseConfig.tableAviary,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Clear the entire aviary.
  Future<int> clearAll() async {
    final db = await _db;
    return db.delete(DatabaseConfig.tableAviary);
  }
}
