import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'database_config.dart';
import 'migration_runner.dart';

/// Singleton database service managing the SQLite connection lifecycle.
///
/// Handles initialization, connection pooling (WAL mode), migrations,
/// and graceful shutdown. All database access goes through this service.
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _database;
  bool _isInitialized = false;
  final Completer<void> _initCompleter = Completer<void>();

  /// Whether the database is fully initialized and ready.
  bool get isInitialized => _isInitialized;

  /// Wait for initialization to complete.
  Future<void> get ready => _initCompleter.future;

  /// Get the database instance, initializing if needed.
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database with migrations.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _database = await _initDatabase();
      _isInitialized = true;
      if (!_initCompleter.isCompleted) _initCompleter.complete();
      debugPrint('[DB] Database initialized successfully');
    } catch (e) {
      if (!_initCompleter.isCompleted) _initCompleter.completeError(e);
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final path = join(documentsDir.path, DatabaseConfig.databaseName);

    debugPrint('[DB] Opening database at: $path');

    return openDatabase(
      path,
      version: DatabaseConfig.schemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
      onOpen: _onOpen,
    );
  }

  /// Configure SQLite pragmas for performance and reliability.
  Future<void> _onConfigure(Database db) async {
    if (DatabaseConfig.enableWAL) {
      await db.execute('PRAGMA journal_mode=WAL');
    }
    await db.execute('PRAGMA busy_timeout=${DatabaseConfig.busyTimeoutMs}');
    await db.execute('PRAGMA cache_size=${DatabaseConfig.cacheSize}');
    await db.execute('PRAGMA foreign_keys=ON');
    await db.execute('PRAGMA synchronous=NORMAL');
    debugPrint('[DB] SQLite pragmas configured (WAL=${DatabaseConfig.enableWAL})');
  }

  /// Run migrations on fresh database creation.
  Future<void> _onCreate(Database db, int version) async {
    debugPrint('[DB] Creating database schema v$version...');
    final result = await MigrationRunner.migrate(db, targetVersion: version);
    debugPrint('[DB] Migration result: $result');
    if (!result.success) {
      throw Exception('Database creation failed: ${result.error}');
    }
  }

  /// Run pending migrations on version upgrade.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('[DB] Upgrading database v$oldVersion -> v$newVersion...');
    final result = await MigrationRunner.migrate(db, targetVersion: newVersion);
    debugPrint('[DB] Migration result: $result');
    if (!result.success) {
      throw Exception('Database upgrade failed: ${result.error}');
    }
  }

  /// Post-open verification.
  Future<void> _onOpen(Database db) async {
    final version = await db.getVersion();
    debugPrint('[DB] Database opened, version: $version');
  }

  /// Close the database connection gracefully.
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      debugPrint('[DB] Database connection closed');
    }
    _database = null;
    _isInitialized = false;
  }

  /// Execute a raw SQL query (for admin operations).
  Future<List<Map<String, dynamic>>> rawQuery(String sql,
      [List<dynamic>? arguments]) async {
    final db = await database;
    return db.rawQuery(sql, arguments);
  }

  /// Execute a raw SQL statement (for admin operations).
  Future<int> rawExecute(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return db.rawInsert(sql, arguments);
  }

  /// Get the database file path.
  Future<String> getDatabasePath() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    return join(documentsDir.path, DatabaseConfig.databaseName);
  }

  /// Run an integrity check on the database.
  Future<bool> integrityCheck() async {
    final db = await database;
    final result = await db.rawQuery('PRAGMA integrity_check');
    final status = result.first.values.first as String;
    return status == 'ok';
  }
}
