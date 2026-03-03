/// Bird database integrity validator for AviQuest.
///
/// Provides deep validation of the bird data list, checking for data
/// consistency, URL reachability hints, scientific name format, and
/// cross-entry uniqueness. Intended for use in CI and debug-mode startup.
library;

import 'config_schema.dart';
import 'config_validator.dart';

// ─── Bird Data Validator ─────────────────────────────────────────────────────

class BirdDataValidator {
  final ConfigValidator _validator = ConfigValidator();

  /// Scientific name should follow binomial nomenclature: "Genus species"
  /// or trinomial: "Genus species subspecies". First word capitalised.
  static final _scientificNamePattern = RegExp(
    r'^[A-Z][a-z]+ [a-z]+( [a-z]+)?$',
  );

  /// Validate the full bird list and return a comprehensive result.
  BirdValidationReport validate(List<BirdEntry> birds) {
    final issues = <ValidationIssue>[];

    // Structural validation via ConfigValidator
    final structuralResult = _validator.validateBirdDatabase(
      birds.map((b) => b.toMap()).toList(),
    );
    issues.addAll(structuralResult.issues);

    // Deep validation
    final nameIndex = <String, int>{};
    final sciNameIndex = <String, int>{};
    var totalXp = 0;
    final rarityCounts = <String, int>{};

    for (var i = 0; i < birds.length; i++) {
      final bird = birds[i];
      final prefix = 'birds[$i]';

      // Scientific name format
      if (bird.scientificName.isNotEmpty &&
          !_scientificNamePattern.hasMatch(bird.scientificName)) {
        issues.add(ValidationIssue(
          path: '$prefix.scientificName',
          message: 'Scientific name "${bird.scientificName}" does not follow '
              'binomial nomenclature (expected "Genus species")',
          severity: Severity.warning,
          rule: 'scientific_name_format',
        ));
      }

      // Image URL should use HTTPS
      if (bird.imageUrl.isNotEmpty && bird.imageUrl.startsWith('http://')) {
        issues.add(ValidationIssue(
          path: '$prefix.imageUrl',
          message: 'Image URL uses HTTP instead of HTTPS',
          severity: Severity.warning,
          rule: 'prefer_https',
        ));
      }

      // Audio URL should use HTTPS
      if (bird.audioUrl.isNotEmpty && bird.audioUrl.startsWith('http://')) {
        issues.add(ValidationIssue(
          path: '$prefix.audioUrl',
          message: 'Audio URL uses HTTP instead of HTTPS',
          severity: Severity.warning,
          rule: 'prefer_https',
        ));
      }

      // Track stats
      totalXp += bird.baseXp;
      rarityCounts[bird.rarity] = (rarityCounts[bird.rarity] ?? 0) + 1;

      // Check for near-duplicate names (case-insensitive)
      final lowerName = bird.name.toLowerCase();
      if (nameIndex.containsKey(lowerName)) {
        issues.add(ValidationIssue(
          path: '$prefix.name',
          message: 'Near-duplicate of birds[${nameIndex[lowerName]}] '
              '(case-insensitive match: "${bird.name}")',
          severity: Severity.warning,
          rule: 'near_duplicate',
        ));
      }
      nameIndex[lowerName] = i;

      final lowerSciName = bird.scientificName.toLowerCase();
      if (lowerSciName.isNotEmpty) {
        sciNameIndex[lowerSciName] = i;
      }
    }

    return BirdValidationReport(
      issues: issues,
      totalBirds: birds.length,
      rarityCounts: rarityCounts,
      averageBaseXp: birds.isEmpty ? 0 : totalXp ~/ birds.length,
      birdsWithAudio: birds.where((b) => b.audioUrl.isNotEmpty).length,
      birdsWithImages: birds.where((b) => b.imageUrl.isNotEmpty).length,
    );
  }
}

// ─── Bird Entry ──────────────────────────────────────────────────────────────

/// Lightweight data class for validation purposes.
/// Mirrors the Bird class fields without Flutter dependencies.
class BirdEntry {
  final String name;
  final String scientificName;
  final String imageUrl;
  final String audioUrl;
  final String lore;
  final String habitat;
  final String conservationStatus;
  final String rarity;
  final int baseXp;

  const BirdEntry({
    required this.name,
    required this.scientificName,
    this.imageUrl = '',
    this.audioUrl = '',
    required this.lore,
    required this.habitat,
    required this.conservationStatus,
    required this.rarity,
    required this.baseXp,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'scientificName': scientificName,
        'imageUrl': imageUrl,
        'audioUrl': audioUrl,
        'lore': lore,
        'habitat': habitat,
        'conservationStatus': conservationStatus,
        'rarity': rarity,
        'baseXp': baseXp,
      };
}

// ─── Validation Report ───────────────────────────────────────────────────────

class BirdValidationReport {
  final List<ValidationIssue> issues;
  final int totalBirds;
  final Map<String, int> rarityCounts;
  final int averageBaseXp;
  final int birdsWithAudio;
  final int birdsWithImages;

  const BirdValidationReport({
    required this.issues,
    required this.totalBirds,
    required this.rarityCounts,
    required this.averageBaseXp,
    required this.birdsWithAudio,
    required this.birdsWithImages,
  });

  bool get isValid => !issues.any(
        (i) => i.severity == Severity.error || i.severity == Severity.critical,
      );

  int get errorCount => issues
      .where((i) => i.severity == Severity.error || i.severity == Severity.critical)
      .length;

  int get warningCount => issues.where((i) => i.severity == Severity.warning).length;

  double get audioCoverage =>
      totalBirds == 0 ? 0 : birdsWithAudio / totalBirds;

  double get imageCoverage =>
      totalBirds == 0 ? 0 : birdsWithImages / totalBirds;

  @override
  String toString() {
    final buf = StringBuffer()
      ..writeln('=== Bird Database Validation Report ===')
      ..writeln('Total birds: $totalBirds')
      ..writeln('Rarity distribution: $rarityCounts')
      ..writeln('Average base XP: $averageBaseXp')
      ..writeln('Image coverage: ${(imageCoverage * 100).toStringAsFixed(1)}%')
      ..writeln('Audio coverage: ${(audioCoverage * 100).toStringAsFixed(1)}%')
      ..writeln('Errors: $errorCount | Warnings: $warningCount')
      ..writeln('Status: ${isValid ? "PASS" : "FAIL"}');

    if (issues.isNotEmpty) {
      buf.writeln('\nIssues:');
      for (final issue in issues) {
        buf.writeln('  $issue');
      }
    }

    return buf.toString();
  }
}
