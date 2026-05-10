/// Result of a breed group certification exam attempt.
class ExamResult {
  final String groupId;
  final ExamTier tier;
  final int score;
  final int totalQuestions;
  final bool passed;
  final DateTime timestamp;

  const ExamResult({
    required this.groupId,
    required this.tier,
    required this.score,
    required this.totalQuestions,
    required this.passed,
    required this.timestamp,
  });

  double get percentage => totalQuestions == 0 ? 0.0 : score / totalQuestions;

  /// Serialize for Hive storage.
  Map<String, dynamic> toMap() => {
        'groupId': groupId,
        'tier': tier.name,
        'score': score,
        'totalQuestions': totalQuestions,
        'passed': passed,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ExamResult.fromMap(Map<dynamic, dynamic> map) => ExamResult(
        groupId: map['groupId'] as String,
        tier: ExamTier.values.byName(map['tier'] as String),
        score: map['score'] as int,
        totalQuestions: map['totalQuestions'] as int,
        passed: map['passed'] as bool,
        timestamp: DateTime.parse(map['timestamp'] as String),
      );
}

/// Certification tier — determines question difficulty pool and pass threshold.
enum ExamTier {
  bronze,
  silver,
  gold;

  /// Minimum correct-answer ratio to pass.
  double get passThreshold => switch (this) {
        ExamTier.bronze => 0.70,
        ExamTier.silver => 0.80,
        ExamTier.gold => 0.90,
      };

  /// Number of questions in this tier's exam.
  int get questionCount => switch (this) {
        ExamTier.bronze => 10,
        ExamTier.silver => 15,
        ExamTier.gold => 20,
      };

  /// XP multiplier granted for passing (applied to future identifications
  /// of breeds in the certified group). Takes precedence over collection-based
  /// family bonus via `max(collectionBonus, examBonus)`.
  double get xpMultiplier => switch (this) {
        ExamTier.bronze => 1.10,
        ExamTier.silver => 1.25,
        ExamTier.gold => 1.50,
      };

  /// Cooldown before the exam can be retaken after a failed attempt.
  Duration get cooldown => switch (this) {
        ExamTier.bronze => const Duration(hours: 1),
        ExamTier.silver => const Duration(hours: 4),
        ExamTier.gold => const Duration(hours: 12),
      };

  /// Display label.
  String get label => switch (this) {
        ExamTier.bronze => 'Bronze',
        ExamTier.silver => 'Silver',
        ExamTier.gold => 'Gold',
      };

  /// Display emoji.
  String get emoji => switch (this) {
        ExamTier.bronze => '🥉',
        ExamTier.silver => '🥈',
        ExamTier.gold => '🥇',
      };

  /// The next tier up, or `null` for gold.
  ExamTier? get next => switch (this) {
        ExamTier.bronze => ExamTier.silver,
        ExamTier.silver => ExamTier.gold,
        ExamTier.gold => null,
      };
}
