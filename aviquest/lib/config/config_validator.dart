/// Core configuration validator for AviQuest.
///
/// Validates application configuration values against the schemas defined
/// in [config_schema.dart]. Designed to run at app startup (debug mode)
/// and in CI test suites to catch configuration errors early.
library;

import 'config_schema.dart';

// ─── Validation Result ───────────────────────────────────────────────────────

enum Severity { info, warning, error, critical }

class ValidationIssue {
  final String path;
  final String message;
  final Severity severity;
  final String? rule;

  const ValidationIssue({
    required this.path,
    required this.message,
    this.severity = Severity.error,
    this.rule,
  });

  @override
  String toString() =>
      '[${severity.name.toUpperCase()}] $path: $message${rule != null ? ' ($rule)' : ''}';
}

class ValidationResult {
  final List<ValidationIssue> issues;

  const ValidationResult(this.issues);

  bool get isValid => !issues.any((i) => i.severity == Severity.error || i.severity == Severity.critical);
  bool get hasWarnings => issues.any((i) => i.severity == Severity.warning);
  List<ValidationIssue> get errors =>
      issues.where((i) => i.severity == Severity.error || i.severity == Severity.critical).toList();
  List<ValidationIssue> get warnings =>
      issues.where((i) => i.severity == Severity.warning).toList();

  @override
  String toString() {
    if (issues.isEmpty) return 'Configuration valid.';
    return issues.map((i) => i.toString()).join('\n');
  }
}

// ─── Config Validator ────────────────────────────────────────────────────────

class ConfigValidator {
  final List<ValidationIssue> _issues = [];

  /// Validate a complete application configuration map.
  ///
  /// The [config] map can contain keys like `environment`, `hiveBoxName`,
  /// `debug`, etc. Returns a [ValidationResult] with all found issues.
  ValidationResult validateAppConfig(Map<String, dynamic> config) {
    _issues.clear();

    _validateEnvironment(config);
    _validateHiveBoxName(config);
    _validateProductionGuards(config);

    return ValidationResult(List.unmodifiable(_issues));
  }

  /// Validate a single bird data entry.
  ValidationResult validateBird(Map<String, dynamic> birdData, {int? index}) {
    _issues.clear();
    final prefix = index != null ? 'birds[$index]' : 'bird';

    // Required string fields
    for (final field in ['name', 'scientificName', 'lore', 'habitat', 'conservationStatus', 'rarity']) {
      final value = birdData[field];
      if (value == null || (value is String && value.isEmpty)) {
        _issues.add(ValidationIssue(
          path: '$prefix.$field',
          message: 'Required field is missing or empty',
          severity: Severity.error,
          rule: 'required_field',
        ));
      }
    }

    // Name length
    final name = birdData['name'];
    if (name is String && name.length > BirdSchema.maxNameLength) {
      _issues.add(ValidationIssue(
        path: '$prefix.name',
        message: 'Name exceeds ${BirdSchema.maxNameLength} characters',
        severity: Severity.warning,
        rule: 'max_length',
      ));
    }

    // Rarity validation
    final rarity = birdData['rarity'];
    if (rarity is String && !RarityConfig.allRarities.contains(rarity)) {
      _issues.add(ValidationIssue(
        path: '$prefix.rarity',
        message: 'Invalid rarity "$rarity". Must be one of: ${RarityConfig.allRarities.join(', ')}',
        severity: Severity.error,
        rule: 'valid_rarity',
      ));
    }

    // Conservation status validation
    final status = birdData['conservationStatus'];
    if (status is String && !ConservationConfig.validStatuses.contains(status)) {
      _issues.add(ValidationIssue(
        path: '$prefix.conservationStatus',
        message: 'Invalid conservation status "$status"',
        severity: Severity.warning,
        rule: 'valid_conservation_status',
      ));
    }

    // Base XP validation
    final baseXp = birdData['baseXp'];
    if (baseXp == null) {
      _issues.add(ValidationIssue(
        path: '$prefix.baseXp',
        message: 'Required field is missing',
        severity: Severity.error,
        rule: 'required_field',
      ));
    } else if (baseXp is int) {
      if (baseXp < BirdSchema.minBaseXp || baseXp > BirdSchema.maxBaseXp) {
        _issues.add(ValidationIssue(
          path: '$prefix.baseXp',
          message: 'baseXp $baseXp out of range [${BirdSchema.minBaseXp}, ${BirdSchema.maxBaseXp}]',
          severity: Severity.error,
          rule: 'range',
        ));
      }
    } else {
      _issues.add(ValidationIssue(
        path: '$prefix.baseXp',
        message: 'baseXp must be an integer, got ${baseXp.runtimeType}',
        severity: Severity.error,
        rule: 'type',
      ));
    }

    // Lore length
    final lore = birdData['lore'];
    if (lore is String && lore.isNotEmpty && lore.length < BirdSchema.minLoreLength) {
      _issues.add(ValidationIssue(
        path: '$prefix.lore',
        message: 'Lore is too short (${lore.length} chars, minimum ${BirdSchema.minLoreLength})',
        severity: Severity.warning,
        rule: 'min_length',
      ));
    }

    // URL format checks (warnings, not errors — empty URLs are allowed)
    _validateUrl(birdData['imageUrl'], '$prefix.imageUrl');
    _validateUrl(birdData['audioUrl'], '$prefix.audioUrl');

    return ValidationResult(List.unmodifiable(_issues));
  }

  /// Validate the full bird database for structural and data integrity.
  ValidationResult validateBirdDatabase(List<Map<String, dynamic>> birds) {
    _issues.clear();

    if (birds.isEmpty) {
      _issues.add(const ValidationIssue(
        path: 'birds',
        message: 'Bird database is empty',
        severity: Severity.critical,
        rule: 'non_empty',
      ));
      return ValidationResult(List.unmodifiable(_issues));
    }

    // Check for duplicate names
    final names = <String>{};
    final scientificNames = <String>{};

    for (var i = 0; i < birds.length; i++) {
      final bird = birds[i];
      final name = bird['name'] as String?;
      final sciName = bird['scientificName'] as String?;

      if (name != null && !names.add(name)) {
        _issues.add(ValidationIssue(
          path: 'birds[$i].name',
          message: 'Duplicate bird name: "$name"',
          severity: Severity.error,
          rule: 'unique_name',
        ));
      }

      if (sciName != null && sciName.isNotEmpty && !scientificNames.add(sciName)) {
        _issues.add(ValidationIssue(
          path: 'birds[$i].scientificName',
          message: 'Duplicate scientific name: "$sciName"',
          severity: Severity.warning,
          rule: 'unique_scientific_name',
        ));
      }

      // Validate each bird individually
      final birdResult = ConfigValidator().validateBird(bird, index: i);
      _issues.addAll(birdResult.issues);
    }

    // Check rarity distribution
    _validateRarityDistribution(birds);

    return ValidationResult(List.unmodifiable(_issues));
  }

  /// Validate achievement definitions.
  ValidationResult validateAchievements(Map<String, (String, String, String)> achievements) {
    _issues.clear();

    // Check required keys exist
    for (final key in AchievementSchema.requiredKeys) {
      if (!achievements.containsKey(key)) {
        _issues.add(ValidationIssue(
          path: 'achievements.$key',
          message: 'Required achievement "$key" is missing',
          severity: Severity.error,
          rule: 'required_achievement',
        ));
      }
    }

    // Validate each achievement entry
    for (final entry in achievements.entries) {
      final key = entry.key;
      final (emoji, title, description) = entry.value;

      if (!AchievementSchema.keyPattern.hasMatch(key)) {
        _issues.add(ValidationIssue(
          path: 'achievements.$key',
          message: 'Achievement key must be lowercase_snake_case',
          severity: Severity.error,
          rule: 'key_format',
        ));
      }

      if (emoji.isEmpty) {
        _issues.add(ValidationIssue(
          path: 'achievements.$key.emoji',
          message: 'Achievement emoji is empty',
          severity: Severity.warning,
          rule: 'non_empty',
        ));
      }

      if (title.length < AchievementSchema.minTitleLength ||
          title.length > AchievementSchema.maxTitleLength) {
        _issues.add(ValidationIssue(
          path: 'achievements.$key.title',
          message: 'Title length ${title.length} out of range '
              '[${AchievementSchema.minTitleLength}, ${AchievementSchema.maxTitleLength}]',
          severity: Severity.warning,
          rule: 'title_length',
        ));
      }

      if (description.length < AchievementSchema.minDescriptionLength) {
        _issues.add(ValidationIssue(
          path: 'achievements.$key.description',
          message: 'Description too short (${description.length} chars)',
          severity: Severity.warning,
          rule: 'description_length',
        ));
      }
    }

    return ValidationResult(List.unmodifiable(_issues));
  }

  /// Validate leveling system parameters.
  ValidationResult validateLeveling({
    required int baseMultiplier,
    required double exponent,
    required List<int> tierBoundaries,
    required List<String> tierNames,
  }) {
    _issues.clear();

    // Base multiplier range
    if (baseMultiplier < LevelingSchema.minBaseXpMultiplier ||
        baseMultiplier > LevelingSchema.maxBaseXpMultiplier) {
      _issues.add(ValidationIssue(
        path: 'leveling.baseMultiplier',
        message: 'Base multiplier $baseMultiplier out of range '
            '[${LevelingSchema.minBaseXpMultiplier}, ${LevelingSchema.maxBaseXpMultiplier}]',
        severity: Severity.error,
        rule: 'range',
      ));
    }

    // Exponent range
    if (exponent < LevelingSchema.minExponent || exponent > LevelingSchema.maxExponent) {
      _issues.add(ValidationIssue(
        path: 'leveling.exponent',
        message: 'Exponent $exponent out of range '
            '[${LevelingSchema.minExponent}, ${LevelingSchema.maxExponent}]',
        severity: Severity.error,
        rule: 'range',
      ));
    }

    // Tier boundaries must be strictly ascending
    for (var i = 1; i < tierBoundaries.length; i++) {
      if (tierBoundaries[i] <= tierBoundaries[i - 1]) {
        _issues.add(ValidationIssue(
          path: 'leveling.tierBoundaries[$i]',
          message: 'Tier boundaries must be strictly ascending: '
              '${tierBoundaries[i]} <= ${tierBoundaries[i - 1]}',
          severity: Severity.error,
          rule: 'ascending_order',
        ));
      }
    }

    // Tier names must be one more than boundaries (the last tier has no upper bound)
    if (tierNames.length != tierBoundaries.length + 1) {
      _issues.add(ValidationIssue(
        path: 'leveling.tierNames',
        message: 'Expected ${tierBoundaries.length + 1} tier names, got ${tierNames.length}',
        severity: Severity.error,
        rule: 'tier_count',
      ));
    }

    // All tier names must be non-empty
    for (var i = 0; i < tierNames.length; i++) {
      if (tierNames[i].isEmpty) {
        _issues.add(ValidationIssue(
          path: 'leveling.tierNames[$i]',
          message: 'Tier name must not be empty',
          severity: Severity.error,
          rule: 'non_empty',
        ));
      }
    }

    return ValidationResult(List.unmodifiable(_issues));
  }

  // ─── Private Helpers ─────────────────────────────────────────────────────

  void _validateEnvironment(Map<String, dynamic> config) {
    final env = config['environment'];
    if (env != null && !AppConfigSchema.validEnvironments.contains(env)) {
      _issues.add(ValidationIssue(
        path: 'environment',
        message: 'Invalid environment "$env". '
            'Must be one of: ${AppConfigSchema.validEnvironments.join(', ')}',
        severity: Severity.error,
        rule: 'valid_environment',
      ));
    }
  }

  void _validateHiveBoxName(Map<String, dynamic> config) {
    final boxName = config['hiveBoxName'];
    if (boxName is String && !AppConfigSchema.boxNamePattern.hasMatch(boxName)) {
      _issues.add(ValidationIssue(
        path: 'hiveBoxName',
        message: 'Hive box name "$boxName" must match pattern: ${AppConfigSchema.boxNamePattern.pattern}',
        severity: Severity.error,
        rule: 'box_name_format',
      ));
    }
  }

  void _validateProductionGuards(Map<String, dynamic> config) {
    final env = config['environment'];
    if (env != 'production') return;

    for (final entry in AppConfigSchema.productionDisallowed.entries) {
      if (config[entry.key] == entry.value) {
        _issues.add(ValidationIssue(
          path: entry.key,
          message: '${entry.key}=${entry.value} is not allowed in production',
          severity: Severity.critical,
          rule: 'production_guard',
        ));
      }
    }
  }

  void _validateUrl(dynamic url, String path) {
    if (url == null || (url is String && url.isEmpty)) return;
    if (url is! String) {
      _issues.add(ValidationIssue(
        path: path,
        message: 'URL must be a string',
        severity: Severity.error,
        rule: 'type',
      ));
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || (!uri.hasScheme && url.contains('://'))) {
      _issues.add(ValidationIssue(
        path: path,
        message: 'Malformed URL: "$url"',
        severity: Severity.warning,
        rule: 'url_format',
      ));
    } else if (uri.hasScheme && uri.scheme != 'https' && uri.scheme != 'http') {
      _issues.add(ValidationIssue(
        path: path,
        message: 'URL uses unexpected scheme "${uri.scheme}"',
        severity: Severity.warning,
        rule: 'url_scheme',
      ));
    }
  }

  void _validateRarityDistribution(List<Map<String, dynamic>> birds) {
    final counts = <String, int>{};
    for (final bird in birds) {
      final rarity = bird['rarity'] as String?;
      if (rarity != null && RarityConfig.validRarities.contains(rarity)) {
        counts[rarity] = (counts[rarity] ?? 0) + 1;
      }
    }

    final total = counts.values.fold(0, (a, b) => a + b);
    if (total == 0) return;

    for (final rarity in RarityConfig.validRarities) {
      final count = counts[rarity] ?? 0;
      if (count == 0) {
        _issues.add(ValidationIssue(
          path: 'birds.rarity_distribution',
          message: 'No birds with rarity "$rarity" — weighted random selection will fail',
          severity: Severity.critical,
          rule: 'rarity_coverage',
        ));
      } else {
        final ratio = count / total;
        final range = RarityConfig.weightRanges[rarity]!;
        if (ratio < range.min * 0.5 || ratio > range.max * 2) {
          _issues.add(ValidationIssue(
            path: 'birds.rarity_distribution',
            message: '$rarity has $count/$total birds (${(ratio * 100).toStringAsFixed(1)}%). '
                'Expected roughly ${(range.min * 100).toStringAsFixed(0)}%-${(range.max * 100).toStringAsFixed(0)}%',
            severity: Severity.warning,
            rule: 'rarity_balance',
          ));
        }
      }
    }
  }
}
