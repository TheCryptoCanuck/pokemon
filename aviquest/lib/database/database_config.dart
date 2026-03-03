/// Database configuration constants and settings for AviQuest.
///
/// Centralizes all database-related configuration to ensure consistency
/// across the application and simplify operational management.
library;

class DatabaseConfig {
  DatabaseConfig._();

  // ─── Core Settings ──────────────────────────────────────────────────────────

  /// SQLite database file name.
  static const String databaseName = 'aviquest.db';

  /// Current schema version — increment on every migration.
  static const int schemaVersion = 1;

  /// Hive box name for the aviary collection (legacy, kept for migration).
  static const String hiveAviaryBox = 'aviary_v2';

  /// Hive box name for player preferences and quick-access state.
  static const String hivePrefsBox = 'aviquest_prefs';

  // ─── Connection Pool ────────────────────────────────────────────────────────

  /// Enable WAL mode for better concurrent read performance.
  static const bool enableWAL = true;

  /// SQLite busy timeout in milliseconds.
  static const int busyTimeoutMs = 5000;

  /// SQLite cache size in pages (negative = KiB).
  static const int cacheSize = -2000; // 2 MB

  // ─── Backup Settings ────────────────────────────────────────────────────────

  /// Maximum number of backup files to retain.
  static const int maxBackupRetention = 5;

  /// Backup file name prefix.
  static const String backupPrefix = 'aviquest_backup';

  /// Backup subdirectory name.
  static const String backupDir = 'db_backups';

  // ─── Table Names ────────────────────────────────────────────────────────────

  static const String tableBirds = 'birds';
  static const String tableAviary = 'aviary';
  static const String tablePlayerStats = 'player_stats';
  static const String tableAchievements = 'achievements';
  static const String tableMigrations = 'schema_migrations';

  // ─── Health Check Thresholds ────────────────────────────────────────────────

  /// Maximum acceptable database file size in bytes (100 MB).
  static const int maxDbSizeBytes = 100 * 1024 * 1024;

  /// Maximum acceptable query time in milliseconds.
  static const int slowQueryThresholdMs = 500;

  /// Minimum free space required on device in bytes (50 MB).
  static const int minFreeSpaceBytes = 50 * 1024 * 1024;
}
