import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database_config.dart';
import '../database_service.dart';
import '../migration_runner.dart';

/// Database administration utilities for AviQuest.
///
/// Provides health checks, backup/restore, diagnostics, and
/// data export capabilities for operational management.
class DbAdmin {
  final DatabaseService _dbService;

  DbAdmin([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService.instance;

  // ─── Health Checks ──────────────────────────────────────────────────────────

  /// Run a comprehensive health check and return a diagnostic report.
  Future<HealthReport> runHealthCheck() async {
    final checks = <HealthCheck>[];

    // 1. Database connectivity
    checks.add(await _checkConnectivity());

    // 2. Integrity check
    checks.add(await _checkIntegrity());

    // 3. Schema version
    checks.add(await _checkSchemaVersion());

    // 4. Table row counts
    checks.add(await _checkTableCounts());

    // 5. Database file size
    checks.add(await _checkDatabaseSize());

    // 6. Foreign key integrity
    checks.add(await _checkForeignKeys());

    final allPassed = checks.every((c) => c.passed);
    return HealthReport(
      timestamp: DateTime.now(),
      passed: allPassed,
      checks: checks,
    );
  }

  Future<HealthCheck> _checkConnectivity() async {
    try {
      final db = await _dbService.database;
      await db.rawQuery('SELECT 1');
      return HealthCheck('connectivity', true, 'Database connection OK');
    } catch (e) {
      return HealthCheck('connectivity', false, 'Connection failed: $e');
    }
  }

  Future<HealthCheck> _checkIntegrity() async {
    try {
      final ok = await _dbService.integrityCheck();
      return HealthCheck('integrity', ok,
          ok ? 'PRAGMA integrity_check passed' : 'Integrity check FAILED');
    } catch (e) {
      return HealthCheck('integrity', false, 'Integrity check error: $e');
    }
  }

  Future<HealthCheck> _checkSchemaVersion() async {
    try {
      final db = await _dbService.database;
      final hasPending = await MigrationRunner.hasPendingMigrations(db);
      return HealthCheck('schema_version', !hasPending,
          hasPending ? 'Pending migrations exist' : 'Schema up to date (v${DatabaseConfig.schemaVersion})');
    } catch (e) {
      return HealthCheck('schema_version', false, 'Version check error: $e');
    }
  }

  Future<HealthCheck> _checkTableCounts() async {
    try {
      final db = await _dbService.database;
      final tables = [
        DatabaseConfig.tableBirds,
        DatabaseConfig.tableAviary,
        DatabaseConfig.tablePlayerStats,
        DatabaseConfig.tableAchievements,
      ];

      final counts = <String, int>{};
      for (final table in tables) {
        final result = await db.rawQuery('SELECT COUNT(*) as c FROM $table');
        counts[table] = (result.first['c'] as int?) ?? 0;
      }

      final detail = counts.entries.map((e) => '${e.key}: ${e.value}').join(', ');
      return HealthCheck('table_counts', true, detail);
    } catch (e) {
      return HealthCheck('table_counts', false, 'Table count error: $e');
    }
  }

  Future<HealthCheck> _checkDatabaseSize() async {
    try {
      final path = await _dbService.getDatabasePath();
      final file = File(path);
      if (!await file.exists()) {
        return HealthCheck('database_size', false, 'Database file not found');
      }
      final size = await file.length();
      final sizeMB = (size / (1024 * 1024)).toStringAsFixed(2);
      final withinLimit = size < DatabaseConfig.maxDbSizeBytes;
      return HealthCheck('database_size', withinLimit,
          '${sizeMB}MB${withinLimit ? '' : ' (EXCEEDS ${DatabaseConfig.maxDbSizeBytes ~/ (1024 * 1024)}MB limit)'}');
    } catch (e) {
      return HealthCheck('database_size', false, 'Size check error: $e');
    }
  }

  Future<HealthCheck> _checkForeignKeys() async {
    try {
      final db = await _dbService.database;
      final result = await db.rawQuery('PRAGMA foreign_key_check');
      final ok = result.isEmpty;
      return HealthCheck('foreign_keys', ok,
          ok ? 'No foreign key violations' : '${result.length} violation(s) found');
    } catch (e) {
      return HealthCheck('foreign_keys', false, 'FK check error: $e');
    }
  }

  // ─── Backup & Restore ───────────────────────────────────────────────────────

  /// Create a database backup.
  ///
  /// Returns the backup file path on success.
  Future<String> createBackup() async {
    final dbPath = await _dbService.getDatabasePath();
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      throw Exception('Database file not found at $dbPath');
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final backupDirPath = p.join(docsDir.path, DatabaseConfig.backupDir);
    final backupDir = Directory(backupDirPath);
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupFileName = '${DatabaseConfig.backupPrefix}_$timestamp.db';
    final backupPath = p.join(backupDirPath, backupFileName);

    await dbFile.copy(backupPath);
    debugPrint('[DB Admin] Backup created: $backupPath');

    // Prune old backups
    await _pruneBackups(backupDir);

    return backupPath;
  }

  /// List available backup files.
  Future<List<FileSystemEntity>> listBackups() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final backupDirPath = p.join(docsDir.path, DatabaseConfig.backupDir);
    final backupDir = Directory(backupDirPath);

    if (!await backupDir.exists()) return [];

    final backups = await backupDir
        .list()
        .where((f) =>
            f is File && p.basename(f.path).startsWith(DatabaseConfig.backupPrefix))
        .toList();
    backups.sort((a, b) => b.path.compareTo(a.path)); // newest first
    return backups;
  }

  /// Restore the database from a backup file.
  Future<void> restoreFromBackup(String backupPath) async {
    final backupFile = File(backupPath);
    if (!await backupFile.exists()) {
      throw Exception('Backup file not found: $backupPath');
    }

    // Close current database
    await _dbService.close();

    // Replace with backup
    final dbPath = await _dbService.getDatabasePath();
    await backupFile.copy(dbPath);

    // Re-initialize
    await _dbService.initialize();
    debugPrint('[DB Admin] Database restored from: $backupPath');
  }

  /// Remove old backups beyond the retention limit.
  Future<void> _pruneBackups(Directory backupDir) async {
    final backups = await listBackups();
    if (backups.length > DatabaseConfig.maxBackupRetention) {
      for (final old in backups.skip(DatabaseConfig.maxBackupRetention)) {
        await old.delete();
        debugPrint('[DB Admin] Pruned old backup: ${old.path}');
      }
    }
  }

  // ─── Data Export ────────────────────────────────────────────────────────────

  /// Export the aviary collection as JSON.
  Future<String> exportAviaryAsJson() async {
    final db = await _dbService.database;
    final sightings = await db.query(
      DatabaseConfig.tableAviary,
      orderBy: 'sighted_at DESC',
    );
    final stats = await db.query(DatabaseConfig.tablePlayerStats, where: 'id = 1');
    final achievements = await db.query(DatabaseConfig.tableAchievements);

    final exportData = {
      'exported_at': DateTime.now().toIso8601String(),
      'app_version': '1.0.0',
      'schema_version': DatabaseConfig.schemaVersion,
      'player_stats': stats.isNotEmpty ? stats.first : {},
      'achievements': achievements.map((a) => a['key']).toList(),
      'sightings': sightings,
    };

    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  /// Export aviary data to a JSON file and return the file path.
  Future<String> exportAviaryToFile() async {
    final json = await exportAviaryAsJson();
    final docsDir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final exportPath = p.join(docsDir.path, 'aviquest_export_$timestamp.json');
    await File(exportPath).writeAsString(json);
    debugPrint('[DB Admin] Data exported to: $exportPath');
    return exportPath;
  }

  // ─── Diagnostics ────────────────────────────────────────────────────────────

  /// Get detailed database statistics.
  Future<Map<String, dynamic>> getDiagnostics() async {
    final db = await _dbService.database;
    final dbPath = await _dbService.getDatabasePath();

    // File size
    final file = File(dbPath);
    final fileSize = await file.exists() ? await file.length() : 0;

    // SQLite version
    final versionResult = await db.rawQuery('SELECT sqlite_version() as v');
    final sqliteVersion = versionResult.first['v'] as String;

    // Journal mode
    final journalResult = await db.rawQuery('PRAGMA journal_mode');
    final journalMode = journalResult.first.values.first as String;

    // Page info
    final pageSizeResult = await db.rawQuery('PRAGMA page_size');
    final pageSize = pageSizeResult.first.values.first as int;
    final pageCountResult = await db.rawQuery('PRAGMA page_count');
    final pageCount = pageCountResult.first.values.first as int;

    // Free pages
    final freeResult = await db.rawQuery('PRAGMA freelist_count');
    final freePages = freeResult.first.values.first as int;

    // Migration history
    final migrations = await MigrationRunner.getAppliedMigrations(db);

    return {
      'database_path': dbPath,
      'file_size_bytes': fileSize,
      'file_size_mb': (fileSize / (1024 * 1024)).toStringAsFixed(2),
      'sqlite_version': sqliteVersion,
      'schema_version': await db.getVersion(),
      'journal_mode': journalMode,
      'page_size': pageSize,
      'page_count': pageCount,
      'free_pages': freePages,
      'fragmentation_pct':
          pageCount > 0 ? ((freePages / pageCount) * 100).toStringAsFixed(1) : '0.0',
      'migrations_applied': migrations.length,
      'migration_history': migrations,
    };
  }

  /// Compact the database by running VACUUM.
  Future<void> vacuum() async {
    final db = await _dbService.database;
    await db.execute('VACUUM');
    debugPrint('[DB Admin] Database vacuumed');
  }

  /// Analyze tables for query optimizer statistics.
  Future<void> analyze() async {
    final db = await _dbService.database;
    await db.execute('ANALYZE');
    debugPrint('[DB Admin] Database analyzed');
  }

  /// Run VACUUM and ANALYZE for routine maintenance.
  Future<void> runMaintenance() async {
    await vacuum();
    await analyze();
    debugPrint('[DB Admin] Maintenance complete');
  }
}

// ─── Health Check Models ──────────────────────────────────────────────────────

class HealthCheck {
  final String name;
  final bool passed;
  final String detail;

  const HealthCheck(this.name, this.passed, this.detail);

  @override
  String toString() => '${passed ? "PASS" : "FAIL"} [$name] $detail';
}

class HealthReport {
  final DateTime timestamp;
  final bool passed;
  final List<HealthCheck> checks;

  const HealthReport({
    required this.timestamp,
    required this.passed,
    required this.checks,
  });

  @override
  String toString() {
    final status = passed ? 'HEALTHY' : 'UNHEALTHY';
    final lines = checks.map((c) => '  $c').join('\n');
    return '=== AviQuest DB Health Report ($status) ===\n'
        'Timestamp: ${timestamp.toIso8601String()}\n'
        '$lines\n'
        '==========================================';
  }
}
