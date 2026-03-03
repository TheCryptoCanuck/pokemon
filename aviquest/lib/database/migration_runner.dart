import 'package:sqflite/sqflite.dart';

import 'migrations/v1_initial_schema.dart';

/// Manages database schema migrations with version tracking.
///
/// Runs migrations sequentially, records applied versions in the
/// `schema_migrations` table, and supports rollback for recovery.
class MigrationRunner {
  /// All registered migrations in order.
  static final List<_Migration> _migrations = [
    _Migration(
      version: V1InitialSchema.version,
      description: V1InitialSchema.description,
      up: V1InitialSchema.up,
      down: V1InitialSchema.down,
    ),
    // Add future migrations here:
    // _Migration(version: 2, description: '...', up: V2Xyz.up, down: V2Xyz.down),
  ];

  /// Run all pending migrations up to [targetVersion].
  static Future<MigrationResult> migrate(Database db, {int? targetVersion}) async {
    final target = targetVersion ?? _migrations.last.version;
    final current = await _getCurrentVersion(db);
    final applied = <int>[];

    for (final m in _migrations) {
      if (m.version > current && m.version <= target) {
        try {
          await m.up(db);
          applied.add(m.version);
        } catch (e) {
          return MigrationResult(
            success: false,
            fromVersion: current,
            toVersion: m.version - 1,
            appliedVersions: applied,
            error: 'Migration v${m.version} failed: $e',
          );
        }
      }
    }

    return MigrationResult(
      success: true,
      fromVersion: current,
      toVersion: applied.isEmpty ? current : applied.last,
      appliedVersions: applied,
    );
  }

  /// Rollback the most recently applied migration.
  static Future<MigrationResult> rollback(Database db) async {
    final current = await _getCurrentVersion(db);
    if (current == 0) {
      return MigrationResult(
        success: true,
        fromVersion: 0,
        toVersion: 0,
        appliedVersions: [],
        error: 'No migrations to rollback',
      );
    }

    final migration = _migrations.firstWhere(
      (m) => m.version == current,
      orElse: () => throw StateError('Migration v$current not found'),
    );

    try {
      await migration.down(db);
      await db.delete('schema_migrations',
          where: 'version = ?', whereArgs: [current]);
      return MigrationResult(
        success: true,
        fromVersion: current,
        toVersion: current - 1,
        appliedVersions: [current],
      );
    } catch (e) {
      return MigrationResult(
        success: false,
        fromVersion: current,
        toVersion: current,
        appliedVersions: [],
        error: 'Rollback of v$current failed: $e',
      );
    }
  }

  /// Get the current schema version from the database.
  static Future<int> _getCurrentVersion(Database db) async {
    try {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='schema_migrations'",
      );
      if (tables.isEmpty) return 0;

      final result = await db.rawQuery(
        'SELECT MAX(version) as version FROM schema_migrations',
      );
      return (result.first['version'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Get list of all applied migration versions.
  static Future<List<Map<String, dynamic>>> getAppliedMigrations(Database db) async {
    try {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='schema_migrations'",
      );
      if (tables.isEmpty) return [];

      return db.query('schema_migrations', orderBy: 'version ASC');
    } catch (_) {
      return [];
    }
  }

  /// Check if there are pending migrations.
  static Future<bool> hasPendingMigrations(Database db) async {
    final current = await _getCurrentVersion(db);
    return _migrations.any((m) => m.version > current);
  }

  /// Get the latest available migration version.
  static int get latestVersion => _migrations.last.version;
}

class _Migration {
  final int version;
  final String description;
  final Future<void> Function(Database db) up;
  final Future<void> Function(Database db) down;

  const _Migration({
    required this.version,
    required this.description,
    required this.up,
    required this.down,
  });
}

/// Result of a migration operation.
class MigrationResult {
  final bool success;
  final int fromVersion;
  final int toVersion;
  final List<int> appliedVersions;
  final String? error;

  const MigrationResult({
    required this.success,
    required this.fromVersion,
    required this.toVersion,
    required this.appliedVersions,
    this.error,
  });

  @override
  String toString() {
    final status = success ? 'SUCCESS' : 'FAILED';
    final versions = appliedVersions.isEmpty ? 'none' : appliedVersions.join(', ');
    return 'MigrationResult($status, v$fromVersion -> v$toVersion, applied: [$versions]'
        '${error != null ? ', error: $error' : ''})';
  }
}
