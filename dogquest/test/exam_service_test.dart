import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:dogquest/models/exam_result.dart';
import 'package:dogquest/services/exam_service.dart';

void main() {
  late Box box;
  late ExamService svc;

  setUp(() async {
    Hive.init('./test_hive_exams');
    box = await Hive.openBox(
        'test_exams_${DateTime.now().millisecondsSinceEpoch}');
    svc = ExamService(box);
  });

  tearDown(() async {
    await box.deleteFromDisk();
  });

  group('ExamResult model', () {
    test('serializes and deserializes correctly', () {
      final result = ExamResult(
        groupId: 'sporting',
        tier: ExamTier.bronze,
        score: 8,
        totalQuestions: 10,
        passed: true,
        timestamp: DateTime(2026, 5, 10, 14, 30),
      );
      final map = result.toMap();
      final restored = ExamResult.fromMap(map);

      expect(restored.groupId, 'sporting');
      expect(restored.tier, ExamTier.bronze);
      expect(restored.score, 8);
      expect(restored.totalQuestions, 10);
      expect(restored.passed, true);
      expect(restored.timestamp, DateTime(2026, 5, 10, 14, 30));
    });

    test('percentage calculation', () {
      final result = ExamResult(
        groupId: 'hound',
        tier: ExamTier.silver,
        score: 12,
        totalQuestions: 15,
        passed: true,
        timestamp: DateTime.now(),
      );
      expect(result.percentage, 0.8);
    });

    test('percentage returns 0 for zero questions', () {
      final result = ExamResult(
        groupId: 'hound',
        tier: ExamTier.bronze,
        score: 0,
        totalQuestions: 0,
        passed: false,
        timestamp: DateTime.now(),
      );
      expect(result.percentage, 0.0);
    });
  });

  group('ExamTier', () {
    test('pass thresholds are correct', () {
      expect(ExamTier.bronze.passThreshold, 0.70);
      expect(ExamTier.silver.passThreshold, 0.80);
      expect(ExamTier.gold.passThreshold, 0.90);
    });

    test('question counts are correct', () {
      expect(ExamTier.bronze.questionCount, 10);
      expect(ExamTier.silver.questionCount, 15);
      expect(ExamTier.gold.questionCount, 20);
    });

    test('xp multipliers are correct', () {
      expect(ExamTier.bronze.xpMultiplier, 1.10);
      expect(ExamTier.silver.xpMultiplier, 1.25);
      expect(ExamTier.gold.xpMultiplier, 1.50);
    });

    test('next tier progression', () {
      expect(ExamTier.bronze.next, ExamTier.silver);
      expect(ExamTier.silver.next, ExamTier.gold);
      expect(ExamTier.gold.next, isNull);
    });
  });

  group('ExamService — tier gating', () {
    test('bronze is always unlocked', () {
      expect(svc.isTierUnlocked('sporting', ExamTier.bronze), true);
    });

    test('silver requires bronze pass', () {
      expect(svc.isTierUnlocked('sporting', ExamTier.silver), false);
    });

    test('silver unlocks after bronze pass', () async {
      await svc.recordResult(ExamResult(
        groupId: 'sporting',
        tier: ExamTier.bronze,
        score: 8,
        totalQuestions: 10,
        passed: true,
        timestamp: DateTime.now(),
      ));
      expect(svc.isTierUnlocked('sporting', ExamTier.silver), true);
      expect(svc.isTierUnlocked('sporting', ExamTier.gold), false);
    });

    test('gold requires silver pass', () async {
      await svc.recordResult(ExamResult(
        groupId: 'sporting',
        tier: ExamTier.bronze,
        score: 8,
        totalQuestions: 10,
        passed: true,
        timestamp: DateTime.now(),
      ));
      await svc.recordResult(ExamResult(
        groupId: 'sporting',
        tier: ExamTier.silver,
        score: 13,
        totalQuestions: 15,
        passed: true,
        timestamp: DateTime.now(),
      ));
      expect(svc.isTierUnlocked('sporting', ExamTier.gold), true);
    });
  });

  group('ExamService — highestTier / nextAvailableTier', () {
    test('returns null when no exams taken', () {
      expect(svc.highestTier('sporting'), isNull);
      expect(svc.nextAvailableTier('sporting'), ExamTier.bronze);
    });

    test('returns bronze after bronze pass', () async {
      await svc.recordResult(ExamResult(
        groupId: 'sporting',
        tier: ExamTier.bronze,
        score: 7,
        totalQuestions: 10,
        passed: true,
        timestamp: DateTime.now(),
      ));
      expect(svc.highestTier('sporting'), ExamTier.bronze);
      expect(svc.nextAvailableTier('sporting'), ExamTier.silver);
    });

    test('returns null next after gold pass', () async {
      for (final tier in ExamTier.values) {
        await svc.recordResult(ExamResult(
          groupId: 'hound',
          tier: tier,
          score: tier.questionCount,
          totalQuestions: tier.questionCount,
          passed: true,
          timestamp: DateTime.now(),
        ));
      }
      expect(svc.highestTier('hound'), ExamTier.gold);
      expect(svc.nextAvailableTier('hound'), isNull);
    });
  });

  group('ExamService — cooldown', () {
    test('no cooldown when no attempt', () {
      expect(svc.isOnCooldown('sporting', ExamTier.bronze), false);
      expect(svc.remainingCooldown('sporting', ExamTier.bronze), Duration.zero);
    });

    test('cooldown after failed attempt', () async {
      await svc.recordResult(ExamResult(
        groupId: 'sporting',
        tier: ExamTier.bronze,
        score: 3,
        totalQuestions: 10,
        passed: false,
        timestamp: DateTime.now(),
      ));
      expect(svc.isOnCooldown('sporting', ExamTier.bronze), true);
      expect(
        svc.remainingCooldown('sporting', ExamTier.bronze).inMinutes,
        greaterThan(50), // ~59 minutes of 1hr cooldown
      );
    });

    test('no cooldown after passed attempt', () async {
      await svc.recordResult(ExamResult(
        groupId: 'sporting',
        tier: ExamTier.bronze,
        score: 8,
        totalQuestions: 10,
        passed: true,
        timestamp: DateTime.now(),
      ));
      expect(svc.isOnCooldown('sporting', ExamTier.bronze), false);
    });

    test('cooldown expires after enough time', () async {
      await svc.recordResult(ExamResult(
        groupId: 'sporting',
        tier: ExamTier.bronze,
        score: 3,
        totalQuestions: 10,
        passed: false,
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      ));
      expect(svc.isOnCooldown('sporting', ExamTier.bronze), false);
    });
  });

  group('ExamService — multiplierForGroup', () {
    test('returns 1.0 with no exams', () {
      expect(svc.multiplierForGroup('sporting'), 1.0);
    });

    test('returns bronze multiplier', () async {
      await svc.recordResult(ExamResult(
        groupId: 'sporting',
        tier: ExamTier.bronze,
        score: 7,
        totalQuestions: 10,
        passed: true,
        timestamp: DateTime.now(),
      ));
      expect(svc.multiplierForGroup('sporting'), 1.10);
    });

    test('returns highest tier multiplier', () async {
      for (final tier in [ExamTier.bronze, ExamTier.silver]) {
        await svc.recordResult(ExamResult(
          groupId: 'sporting',
          tier: tier,
          score: tier.questionCount,
          totalQuestions: tier.questionCount,
          passed: true,
          timestamp: DateTime.now(),
        ));
      }
      expect(svc.multiplierForGroup('sporting'), 1.25);
    });
  });

  group('ExamService — aggregate queries', () {
    test('goldCount and isCanineScholar', () async {
      expect(svc.goldCount, 0);
      expect(svc.isCanineScholar, false);

      // Pass gold for all 7 groups
      final groupIds = [
        'sporting',
        'hound',
        'working',
        'terrier',
        'toy',
        'non_sporting',
        'herding',
      ];
      for (final gid in groupIds) {
        for (final tier in ExamTier.values) {
          await svc.recordResult(ExamResult(
            groupId: gid,
            tier: tier,
            score: tier.questionCount,
            totalQuestions: tier.questionCount,
            passed: true,
            timestamp: DateTime.now(),
          ));
        }
      }
      expect(svc.goldCount, 7);
      expect(svc.isCanineScholar, true);
      expect(svc.totalCertifications, 21); // 7 groups × 3 tiers
    });
  });

  group('ExamService — failed attempt does not grant tier', () {
    test('failed bronze does not unlock silver', () async {
      await svc.recordResult(ExamResult(
        groupId: 'sporting',
        tier: ExamTier.bronze,
        score: 3,
        totalQuestions: 10,
        passed: false,
        timestamp: DateTime.now(),
      ));
      expect(svc.highestTier('sporting'), isNull);
      expect(svc.isTierUnlocked('sporting', ExamTier.silver), false);
    });
  });
}
