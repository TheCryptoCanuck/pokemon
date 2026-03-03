import 'package:flutter_test/flutter_test.dart';
import 'package:aviquest/services/player_service.dart';

/// Unit tests for level-up detection logic.
/// Widget tests require a full Flutter test harness.
void main() {
  group('Level-up detection', () {
    test('detects level increase', () {
      const oldLevel = 3;
      const newState = PlayerState(level: 4);
      expect(newState.level > oldLevel, isTrue);
    });

    test('no level-up when level unchanged', () {
      const oldLevel = 3;
      const newState = PlayerState(level: 3);
      expect(newState.level > oldLevel, isFalse);
    });

    test('title changes at level boundaries', () {
      expect(const PlayerState(level: 2).title, 'Fledgling');
      expect(const PlayerState(level: 3).title, 'Nestling');
      expect(const PlayerState(level: 6).title, 'Sparrow');
      expect(const PlayerState(level: 10).title, 'Warbler');
    });
  });
}
