import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';

import 'package:dogquest/models/exam_result.dart';
import 'package:dogquest/services/dog_group_service.dart' show families;

final _log = Logger('ExamService');

/// Manages breed-group certification exams — persistence, tier gating,
/// cooldowns, and XP multiplier lookups.
///
/// Hive box: `dogquest_exams`
/// Key format: `{groupId}_{tier}` (e.g. `sporting_bronze`)
class ExamService {
  final Box _box;

  ExamService(this._box);

  // ─── Queries ──────────────────────────────────────────────────────────

  /// Highest tier passed for [groupId], or `null` if no exam passed.
  ExamTier? highestTier(String groupId) {
    // Check from gold downward.
    for (final tier in ExamTier.values.reversed) {
      final result = _getResult(groupId, tier);
      if (result != null && result.passed) return tier;
    }
    return null;
  }

  /// The next tier available to attempt for [groupId].
  /// Returns `null` if gold is already earned.
  ExamTier? nextAvailableTier(String groupId) {
    final highest = highestTier(groupId);
    if (highest == null) return ExamTier.bronze;
    return highest.next;
  }

  /// Whether [groupId] at [tier] is currently unlocked for attempt.
  /// Bronze is always unlocked; silver requires bronze pass; gold requires silver pass.
  bool isTierUnlocked(String groupId, ExamTier tier) {
    if (tier == ExamTier.bronze) return true;
    final prerequisite =
        tier == ExamTier.silver ? ExamTier.bronze : ExamTier.silver;
    final prereqResult = _getResult(groupId, prerequisite);
    return prereqResult != null && prereqResult.passed;
  }

  /// Whether the cooldown for a failed attempt is still active.
  bool isOnCooldown(String groupId, ExamTier tier) {
    final result = _getResult(groupId, tier);
    if (result == null || result.passed) return false;
    return DateTime.now().difference(result.timestamp) < tier.cooldown;
  }

  /// Remaining cooldown duration (zero if not on cooldown).
  Duration remainingCooldown(String groupId, ExamTier tier) {
    final result = _getResult(groupId, tier);
    if (result == null || result.passed) return Duration.zero;
    final elapsed = DateTime.now().difference(result.timestamp);
    final remaining = tier.cooldown - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Whether the exam at [groupId]/[tier] has been passed.
  bool hasPassed(String groupId, ExamTier tier) {
    final result = _getResult(groupId, tier);
    return result != null && result.passed;
  }

  /// Get the stored result for [groupId]/[tier], or `null`.
  ExamResult? getResult(String groupId, ExamTier tier) =>
      _getResult(groupId, tier);

  /// XP multiplier for identifications in [groupId] based on exams.
  /// Returns 1.0 if no exam passed.
  double multiplierForGroup(String groupId) {
    final tier = highestTier(groupId);
    return tier?.xpMultiplier ?? 1.0;
  }

  /// Total gold certifications across all groups.
  int get goldCount =>
      families.where((g) => hasPassed(g.id, ExamTier.gold)).length;

  /// Total certifications (any tier) across all groups.
  int get totalCertifications {
    int count = 0;
    for (final group in families) {
      for (final tier in ExamTier.values) {
        if (hasPassed(group.id, tier)) count++;
      }
    }
    return count;
  }

  /// Whether all 7 groups have gold certification.
  bool get isCanineScholar => goldCount == families.length;

  /// Exam-based prestige title, or `null` if no certification earned.
  ///
  /// Priority:
  /// 1. "Canine Scholar" — all 7 groups at Gold
  /// 2. "{Group} Specialist" — first single-group Gold (alphabetical tiebreak)
  /// 3. `null` — no Gold certifications
  String? get prestigeTitle {
    if (isCanineScholar) return 'Canine Scholar';
    final goldGroups =
        families.where((g) => hasPassed(g.id, ExamTier.gold)).toList();
    if (goldGroups.isNotEmpty) {
      final groupName = goldGroups.first.name.replaceAll(' Group', '');
      return '$groupName Specialist';
    }
    return null;
  }

  /// Summary of all group exam states.
  List<GroupExamSummary> get allGroupSummaries => families.map((g) {
        return GroupExamSummary(
          groupId: g.id,
          groupName: g.name,
          groupEmoji: g.emoji,
          highestTier: highestTier(g.id),
          nextTier: nextAvailableTier(g.id),
          isOnCooldown: nextAvailableTier(g.id) != null &&
              isOnCooldown(g.id, nextAvailableTier(g.id)!),
        );
      }).toList();

  // ─── Mutations ────────────────────────────────────────────────────────

  /// Record an exam attempt. Overwrites any previous result for the same
  /// group/tier combination (we only keep the latest attempt per slot).
  Future<void> recordResult(ExamResult result) async {
    final key = _key(result.groupId, result.tier);
    await _box.put(key, result.toMap());
    _log.info(
      '${result.passed ? "PASSED" : "FAILED"} '
      '${result.groupId}/${result.tier.label} '
      '(${result.score}/${result.totalQuestions})',
    );
  }

  // ─── Internals ────────────────────────────────────────────────────────

  ExamResult? _getResult(String groupId, ExamTier tier) {
    final raw = _box.get(_key(groupId, tier));
    if (raw == null) return null;
    return ExamResult.fromMap(raw as Map);
  }

  static String _key(String groupId, ExamTier tier) =>
      '${groupId}_${tier.name}';
}

/// Lightweight summary for UI display.
class GroupExamSummary {
  final String groupId;
  final String groupName;
  final String groupEmoji;
  final ExamTier? highestTier;
  final ExamTier? nextTier;
  final bool isOnCooldown;

  const GroupExamSummary({
    required this.groupId,
    required this.groupName,
    required this.groupEmoji,
    required this.highestTier,
    required this.nextTier,
    required this.isOnCooldown,
  });
}

// ─── Provider ────────────────────────────────────────────────────────────────

final examServiceProvider = Provider<ExamService>((ref) {
  throw UnimplementedError('examServiceProvider must be overridden');
});
