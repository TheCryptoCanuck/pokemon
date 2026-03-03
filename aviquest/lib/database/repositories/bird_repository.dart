import 'package:sqflite/sqflite.dart';

import '../database_config.dart';
import '../database_service.dart';
import '../models/bird_model.dart';

/// Repository for bird species CRUD operations.
///
/// Provides typed access to the birds table with query helpers
/// for filtering by rarity, habitat, and search terms.
class BirdRepository {
  final DatabaseService _dbService;

  BirdRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService.instance;

  Future<Database> get _db => _dbService.database;

  /// Insert a single bird record.
  Future<int> insert(BirdRecord bird) async {
    final db = await _db;
    return db.insert(
      DatabaseConfig.tableBirds,
      bird.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Bulk-insert bird records efficiently using a batch.
  Future<void> insertAll(List<BirdRecord> birds) async {
    final db = await _db;
    final batch = db.batch();
    for (final bird in birds) {
      batch.insert(
        DatabaseConfig.tableBirds,
        bird.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Get all birds.
  Future<List<BirdRecord>> getAll() async {
    final db = await _db;
    final maps = await db.query(DatabaseConfig.tableBirds, orderBy: 'name ASC');
    return maps.map(BirdRecord.fromMap).toList();
  }

  /// Get a bird by name.
  Future<BirdRecord?> getByName(String name) async {
    final db = await _db;
    final maps = await db.query(
      DatabaseConfig.tableBirds,
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return BirdRecord.fromMap(maps.first);
  }

  /// Get a bird by ID.
  Future<BirdRecord?> getById(int id) async {
    final db = await _db;
    final maps = await db.query(
      DatabaseConfig.tableBirds,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return BirdRecord.fromMap(maps.first);
  }

  /// Get birds filtered by rarity.
  Future<List<BirdRecord>> getByRarity(String rarity) async {
    final db = await _db;
    final maps = await db.query(
      DatabaseConfig.tableBirds,
      where: 'rarity = ?',
      whereArgs: [rarity],
      orderBy: 'name ASC',
    );
    return maps.map(BirdRecord.fromMap).toList();
  }

  /// Search birds by name or scientific name.
  Future<List<BirdRecord>> search(String query, {String? rarity}) async {
    final db = await _db;
    final where = StringBuffer('(name LIKE ? OR scientific_name LIKE ?)');
    final args = <dynamic>['%$query%', '%$query%'];

    if (rarity != null && rarity != 'all') {
      where.write(' AND rarity = ?');
      args.add(rarity);
    }

    final maps = await db.query(
      DatabaseConfig.tableBirds,
      where: where.toString(),
      whereArgs: args,
      orderBy: 'name ASC',
    );
    return maps.map(BirdRecord.fromMap).toList();
  }

  /// Get bird count per rarity tier.
  Future<Map<String, int>> getCountByRarity() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT rarity, COUNT(*) as count FROM ${DatabaseConfig.tableBirds} GROUP BY rarity',
    );
    return {for (final row in result) row['rarity'] as String: row['count'] as int};
  }

  /// Get total number of bird species in the catalog.
  Future<int> getCount() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseConfig.tableBirds}',
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Update a bird record.
  Future<int> update(BirdRecord bird) async {
    final db = await _db;
    return db.update(
      DatabaseConfig.tableBirds,
      bird.toMap(),
      where: 'id = ?',
      whereArgs: [bird.id],
    );
  }

  /// Delete a bird by ID.
  Future<int> delete(int id) async {
    final db = await _db;
    return db.delete(
      DatabaseConfig.tableBirds,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Check if the birds table has been seeded.
  Future<bool> isSeeded() async {
    final count = await getCount();
    return count > 0;
  }
}
