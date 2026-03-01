import 'package:sqflite/sqflite.dart';

import '../database_config.dart';
import '../database_service.dart';

/// Repository for player stats and achievement persistence.
///
/// Manages the singleton player_stats row and achievements table,
/// ensuring progression data survives app restarts.
class PlayerRepository {
  final DatabaseService _dbService;

  PlayerRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService.instance;

  Future<Database> get _db => _dbService.database;

  // ─── Player Stats ─────────────────────────────────────────────────────────

  /// Get current player stats.
  Future<Map<String, dynamic>> getStats() async {
    final db = await _db;
    final result = await db.query(
      DatabaseConfig.tablePlayerStats,
      where: 'id = 1',
      limit: 1,
    );
    if (result.isEmpty) {
      // Re-insert the singleton row if missing
      await db.insert(DatabaseConfig.tablePlayerStats, {
        'id': 1,
        'level': 1,
        'xp': 0,
        'streak': 1,
        'total_sightings': 0,
        'last_active': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      return getStats();
    }
    return result.first;
  }

  /// Update player stats.
  Future<void> updateStats({
    int? level,
    int? xp,
    int? streak,
    int? totalSightings,
  }) async {
    final db = await _db;
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
      'last_active': DateTime.now().toIso8601String(),
    };
    if (level != null) updates['level'] = level;
    if (xp != null) updates['xp'] = xp;
    if (streak != null) updates['streak'] = streak;
    if (totalSightings != null) updates['total_sightings'] = totalSightings;

    await db.update(
      DatabaseConfig.tablePlayerStats,
      updates,
      where: 'id = 1',
    );
  }

  /// Increment total sightings counter.
  Future<void> incrementSightings() async {
    final db = await _db;
    await db.rawUpdate(
      'UPDATE ${DatabaseConfig.tablePlayerStats} SET total_sightings = total_sightings + 1, updated_at = ? WHERE id = 1',
      [DateTime.now().toIso8601String()],
    );
  }

  // ─── Achievements ─────────────────────────────────────────────────────────

  /// Unlock an achievement.
  Future<void> unlockAchievement(String key) async {
    final db = await _db;
    await db.insert(
      DatabaseConfig.tableAchievements,
      {
        'key': key,
        'unlocked_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Get all unlocked achievement keys.
  Future<Set<String>> getUnlockedAchievements() async {
    final db = await _db;
    final result = await db.query(DatabaseConfig.tableAchievements);
    return result.map((r) => r['key'] as String).toSet();
  }

  /// Check if a specific achievement is unlocked.
  Future<bool> isAchievementUnlocked(String key) async {
    final db = await _db;
    final result = await db.query(
      DatabaseConfig.tableAchievements,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Get count of unlocked achievements.
  Future<int> getAchievementCount() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseConfig.tableAchievements}',
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Reset all player data (stats + achievements).
  Future<void> resetAll() async {
    final db = await _db;
    final batch = db.batch();
    batch.delete(DatabaseConfig.tableAchievements);
    batch.update(DatabaseConfig.tablePlayerStats, {
      'level': 1,
      'xp': 0,
      'streak': 1,
      'total_sightings': 0,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = 1');
    await batch.commit(noResult: true);
  }
}
