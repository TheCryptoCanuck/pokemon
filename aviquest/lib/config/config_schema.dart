/// Configuration schema definitions for AviQuest.
///
/// Defines validation rules, constraints, and expected types for all
/// configurable values in the application. Used by [ConfigValidator]
/// to ensure configuration integrity at startup and during testing.
library;

// ─── Field Constraints ───────────────────────────────────────────────────────

/// Describes a single configuration field's expected shape.
class FieldSchema {
  final String name;
  final Type type;
  final bool required;
  final dynamic defaultValue;
  final bool Function(dynamic value)? validate;
  final String? description;

  const FieldSchema({
    required this.name,
    required this.type,
    this.required = true,
    this.defaultValue,
    this.validate,
    this.description,
  });
}

// ─── Allowed Values ──────────────────────────────────────────────────────────

/// Valid rarity tiers and their expected weight distribution bounds.
class RarityConfig {
  static const validRarities = ['common', 'uncommon', 'rare', 'legendary'];

  /// Internal-only rarity used for birds not found in the database.
  static const internalRarities = ['unknown'];

  static const allRarities = [...validRarities, ...internalRarities];

  /// Expected weight ranges (lower, upper) for each rarity tier.
  /// Values are cumulative probability thresholds.
  static const weightRanges = {
    'common': (min: 0.40, max: 0.80),
    'uncommon': (min: 0.10, max: 0.40),
    'rare': (min: 0.05, max: 0.25),
    'legendary': (min: 0.01, max: 0.10),
  };
}

/// Valid conservation status values (IUCN Red List categories).
class ConservationConfig {
  static const validStatuses = [
    'Least Concern',
    'Near Threatened',
    'Vulnerable',
    'Endangered',
    'Critically Endangered',
    'Extinct in the Wild',
    'Extinct',
    'Data Deficient',
    'Not Evaluated',
    'Unknown', // for placeholder birds
  ];
}

// ─── Bird Schema ─────────────────────────────────────────────────────────────

/// Validation schema for individual bird entries.
class BirdSchema {
  static const fields = [
    FieldSchema(
      name: 'name',
      type: String,
      description: 'Common English name of the bird species',
    ),
    FieldSchema(
      name: 'scientificName',
      type: String,
      description: 'Binomial nomenclature (Genus species)',
    ),
    FieldSchema(
      name: 'imageUrl',
      type: String,
      required: false,
      description: 'URL to a representative image (Wikimedia Commons preferred)',
    ),
    FieldSchema(
      name: 'audioUrl',
      type: String,
      required: false,
      description: 'URL to a bird call audio file (Xeno-Canto preferred)',
    ),
    FieldSchema(
      name: 'lore',
      type: String,
      description: 'Fun fact or description shown to the player',
    ),
    FieldSchema(
      name: 'habitat',
      type: String,
      description: 'Comma-separated habitat types',
    ),
    FieldSchema(
      name: 'conservationStatus',
      type: String,
      description: 'IUCN Red List conservation status',
    ),
    FieldSchema(
      name: 'rarity',
      type: String,
      description: 'Game rarity tier: common | uncommon | rare | legendary',
    ),
    FieldSchema(
      name: 'baseXp',
      type: int,
      description: 'Base experience points awarded for identification',
    ),
  ];

  /// XP must be positive and within a sane range.
  static const minBaseXp = 1;
  static const maxBaseXp = 1000;

  /// Lore should be meaningful — not just a few characters.
  static const minLoreLength = 10;

  /// Names should not be excessively long.
  static const maxNameLength = 100;
}

// ─── Achievement Schema ──────────────────────────────────────────────────────

/// Validation schema for achievement definitions.
class AchievementSchema {
  /// Every achievement key must be a non-empty lowercase_snake string.
  static final keyPattern = RegExp(r'^[a-z][a-z0-9_]*$');

  /// Each achievement tuple: (emoji, title, description).
  static const minTitleLength = 2;
  static const maxTitleLength = 50;
  static const minDescriptionLength = 5;

  /// Known achievement keys that the game logic references.
  /// If these are missing, features will silently break.
  static const requiredKeys = [
    'first_bird',
    'five_species',
    'ten_species',
    'twenty_species',
    'rare_find',
    'legendary_find',
    'level_5',
    'level_10',
    'level_20',
  ];
}

// ─── Leveling Schema ─────────────────────────────────────────────────────────

/// Constraints for the leveling / XP system.
class LevelingSchema {
  static const minLevel = 1;
  static const maxLevel = 100;

  /// XP formula exponent must produce a monotonically increasing curve.
  static const minExponent = 1.0;
  static const maxExponent = 3.0;

  /// XP base multiplier.
  static const minBaseXpMultiplier = 100;
  static const maxBaseXpMultiplier = 10000;

  /// Level title tier boundaries (must be strictly ascending).
  static const defaultTierBoundaries = [3, 6, 10, 15, 20, 30, 40];

  /// Expected tier names in ascending order.
  static const defaultTierNames = [
    'Fledgling',
    'Nestling',
    'Sparrow',
    'Warbler',
    'Songweaver',
    'Falconer',
    'Eagle Scout',
    'Master Birder',
  ];
}

// ─── App Config Schema ───────────────────────────────────────────────────────

/// Top-level application configuration constraints.
class AppConfigSchema {
  /// Hive box name must be a valid identifier.
  static final boxNamePattern = RegExp(r'^[a-z][a-z0-9_]*(_v\d+)?$');

  /// Valid environment names for environment-specific validation.
  static const validEnvironments = ['development', 'staging', 'production'];

  /// Production environment disallows these settings.
  static const productionDisallowed = {
    'debug': true,
    'showDebugBanner': true,
    'mockIdentification': true,
  };

  /// Required Android permissions for core features.
  static const requiredPermissions = [
    'android.permission.INTERNET',
    'android.permission.CAMERA',
  ];

  /// Optional permissions that enhance functionality.
  static const optionalPermissions = [
    'android.permission.RECORD_AUDIO',
  ];
}
