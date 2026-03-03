import 'package:sqflite/sqflite.dart';

/// V1: Initial database schema for AviQuest.
///
/// Creates the core tables:
/// - birds: Master bird species catalog
/// - aviary: User's collected bird sightings
/// - player_stats: Player progression data
/// - achievements: Unlocked achievement records
class V1InitialSchema {
  static const int version = 1;
  static const String description = 'Initial schema — birds, aviary, player stats, achievements';

  static Future<void> up(Database db) async {
    final batch = db.batch();

    // ── Birds catalog table ───────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS birds (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        name          TEXT    NOT NULL UNIQUE,
        scientific_name TEXT  NOT NULL,
        image_url     TEXT    NOT NULL DEFAULT '',
        audio_url     TEXT    NOT NULL DEFAULT '',
        lore          TEXT    NOT NULL DEFAULT '',
        habitat       TEXT    NOT NULL DEFAULT '',
        conservation_status TEXT NOT NULL DEFAULT 'Unknown',
        rarity        TEXT    NOT NULL DEFAULT 'common'
                      CHECK (rarity IN ('common', 'uncommon', 'rare', 'legendary', 'unknown')),
        base_xp       INTEGER NOT NULL DEFAULT 10,
        created_at    TEXT    NOT NULL DEFAULT (datetime('now')),
        updated_at    TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // Indexes for common query patterns
    batch.execute('CREATE INDEX IF NOT EXISTS idx_birds_rarity ON birds(rarity)');
    batch.execute('CREATE INDEX IF NOT EXISTS idx_birds_name ON birds(name)');
    batch.execute('CREATE INDEX IF NOT EXISTS idx_birds_habitat ON birds(habitat)');

    // ── Aviary table (user's collected sightings) ─────────────────────────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS aviary (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        bird_name     TEXT    NOT NULL,
        sighted_at    TEXT    NOT NULL DEFAULT (datetime('now')),
        latitude      REAL,
        longitude     REAL,
        notes         TEXT    DEFAULT '',
        FOREIGN KEY (bird_name) REFERENCES birds(name) ON DELETE CASCADE
      )
    ''');

    batch.execute('CREATE INDEX IF NOT EXISTS idx_aviary_bird_name ON aviary(bird_name)');
    batch.execute('CREATE INDEX IF NOT EXISTS idx_aviary_sighted_at ON aviary(sighted_at)');

    // ── Player stats table ────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS player_stats (
        id            INTEGER PRIMARY KEY CHECK (id = 1),
        level         INTEGER NOT NULL DEFAULT 1,
        xp            INTEGER NOT NULL DEFAULT 0,
        streak        INTEGER NOT NULL DEFAULT 1,
        last_active   TEXT    NOT NULL DEFAULT (datetime('now')),
        total_sightings INTEGER NOT NULL DEFAULT 0,
        created_at    TEXT    NOT NULL DEFAULT (datetime('now')),
        updated_at    TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // Insert default player stats row (singleton)
    batch.execute('''
      INSERT OR IGNORE INTO player_stats (id, level, xp, streak)
      VALUES (1, 1, 0, 1)
    ''');

    // ── Achievements table ────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS achievements (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        key           TEXT    NOT NULL UNIQUE,
        unlocked_at   TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    batch.execute('CREATE INDEX IF NOT EXISTS idx_achievements_key ON achievements(key)');

    // ── Schema migrations tracking table ──────────────────────────────────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version       INTEGER PRIMARY KEY,
        description   TEXT    NOT NULL,
        applied_at    TEXT    NOT NULL DEFAULT (datetime('now')),
        checksum      TEXT
      )
    ''');

    await batch.commit(noResult: true);

    // Record this migration
    await db.insert('schema_migrations', {
      'version': version,
      'description': description,
      'applied_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> down(Database db) async {
    final batch = db.batch();
    batch.execute('DROP TABLE IF EXISTS schema_migrations');
    batch.execute('DROP TABLE IF EXISTS achievements');
    batch.execute('DROP TABLE IF EXISTS player_stats');
    batch.execute('DROP TABLE IF EXISTS aviary');
    batch.execute('DROP TABLE IF EXISTS birds');
    await batch.commit(noResult: true);
  }
}
