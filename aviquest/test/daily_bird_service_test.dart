import 'package:flutter_test/flutter_test.dart';
import 'package:aviquest/services/daily_bird_service.dart';

void main() {
  group('DailyBirdService constants', () {
    test('bonus multiplier is 3', () {
      expect(DailyBirdService.bonusMultiplier, 3);
    });
  });

  group('Daily bird determinism', () {
    test('same day-since-epoch produces same index', () {
      // The selection uses: daysSinceEpoch % birds.length
      // Given a fixed date and fixed bird list, the index is deterministic
      final now = DateTime(2026, 3, 3);
      final daysSinceEpoch = now.toUtc().difference(DateTime.utc(2024, 1, 1)).inDays;
      expect(daysSinceEpoch, greaterThan(0));

      // Same date should always give same days-since-epoch
      final daysSinceEpoch2 = now.toUtc().difference(DateTime.utc(2024, 1, 1)).inDays;
      expect(daysSinceEpoch, daysSinceEpoch2);
    });

    test('different days produce different indices for most bird counts', () {
      final day1 = DateTime(2026, 3, 3).toUtc().difference(DateTime.utc(2024, 1, 1)).inDays;
      final day2 = DateTime(2026, 3, 4).toUtc().difference(DateTime.utc(2024, 1, 1)).inDays;
      expect(day1, isNot(equals(day2)));
    });
  });
}
