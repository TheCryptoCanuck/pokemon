import 'package:flutter_test/flutter_test.dart';
import 'package:aviquest/helpers/date_helpers.dart';

void main() {
  group('formatDateKey', () {
    test('formats single-digit month and day with leading zeros', () {
      expect(formatDateKey(DateTime(2026, 3, 3)), '2026-03-03');
    });

    test('formats double-digit month and day without extra padding', () {
      expect(formatDateKey(DateTime(2025, 12, 25)), '2025-12-25');
    });

    test('handles January 1st', () {
      expect(formatDateKey(DateTime(2024, 1, 1)), '2024-01-01');
    });

    test('handles December 31st', () {
      expect(formatDateKey(DateTime(2024, 12, 31)), '2024-12-31');
    });

    test('same date always produces same key', () {
      final d = DateTime(2026, 6, 15);
      expect(formatDateKey(d), formatDateKey(d));
    });

    test('different dates produce different keys', () {
      expect(
        formatDateKey(DateTime(2026, 3, 3)),
        isNot(formatDateKey(DateTime(2026, 3, 4))),
      );
    });

    test('matches DailyBirdService expected format (YYYY-MM-DD)', () {
      final key = formatDateKey(DateTime(2026, 3, 3));
      expect(key, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });
  });
}
