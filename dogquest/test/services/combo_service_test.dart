import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dogquest/services/combo_service.dart';

void main() {
  late Box box;
  late ComboNotifier notifier;

  setUp(() async {
    Hive.init('./test_hive_combo');
    box = await Hive.openBox(
      'test_combo_${DateTime.now().millisecondsSinceEpoch}',
    );
    notifier = ComboNotifier(box);
  });

  tearDown(() async {
    notifier.dispose();
    await box.deleteFromDisk();
  });

  group('ComboNotifier', () {
    test('starts with inactive combo state', () {
      expect(notifier.isActive, isFalse);
      expect(notifier.currentMultiplier, 1.0);
      expect(notifier.state.count, 0);
    });

    test('recordIdentification activates combo', () {
      notifier.recordIdentification();
      expect(notifier.isActive, isTrue);
      expect(notifier.state.count, 1);
      expect(notifier.currentMultiplier, 1.0);
    });

    test('second identification gives 1.2x multiplier', () {
      notifier.recordIdentification();
      notifier.recordIdentification();
      expect(notifier.state.count, 2);
      expect(notifier.currentMultiplier, 1.2);
    });

    test('third identification gives 1.5x multiplier', () {
      for (var i = 0; i < 3; i++) {
        notifier.recordIdentification();
      }
      expect(notifier.state.count, 3);
      expect(notifier.currentMultiplier, 1.5);
    });

    test('four or more identifications give 2.0x multiplier', () {
      for (var i = 0; i < 5; i++) {
        notifier.recordIdentification();
      }
      expect(notifier.state.count, 5);
      expect(notifier.currentMultiplier, 2.0);
    });

    test('combo expiry is set to 24 hours from now', () {
      notifier.recordIdentification();
      final expiry = notifier.state.expiresAt!;
      final diff = expiry.difference(DateTime.now()).inSeconds;
      // Should be roughly 86400 seconds (24h), allow 5s tolerance
      expect(diff, greaterThan(86390));
      expect(diff, lessThanOrEqualTo(86400));
    });

    test('persists combo count to Hive box', () {
      notifier.recordIdentification();
      notifier.recordIdentification();
      expect(box.get('combo_count'), 2);
      expect(box.get('combo_expires_ms'), isNotNull);
    });

    test('secondsRemaining returns 0 when inactive', () {
      expect(notifier.state.secondsRemaining, 0);
    });

    test('secondsRemaining returns positive value when active', () {
      notifier.recordIdentification();
      expect(notifier.state.secondsRemaining, greaterThan(0));
    });
  });
}
