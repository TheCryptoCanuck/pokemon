import 'package:flutter_test/flutter_test.dart';
import 'package:aviquest/services/player_service.dart';
import 'package:aviquest/helpers/game_helpers.dart';

void main() {
  group('Streak achievements', () {
    test('streak_7 and streak_30 are defined in achievements map', () {
      expect(achievements.containsKey('streak_7'), isTrue);
      expect(achievements.containsKey('streak_30'), isTrue);
    });

    test('streak_7 has correct metadata', () {
      final (emoji, name, desc) = achievements['streak_7']!;
      expect(emoji, isNotEmpty);
      expect(name, 'Week Warrior');
      expect(desc, contains('7'));
    });

    test('streak_30 has correct metadata', () {
      final (emoji, name, desc) = achievements['streak_30']!;
      expect(emoji, isNotEmpty);
      expect(name, 'Dedicated Birder');
      expect(desc, contains('30'));
    });
  });

  group('PlayerState streak default', () {
    test('new PlayerState starts with streak 0', () {
      const state = PlayerState();
      expect(state.streak, 0);
    });

    test('copyWith updates streak', () {
      const state = PlayerState(streak: 5);
      final updated = state.copyWith(streak: 10);
      expect(updated.streak, 10);
    });

    test('copyWith preserves streak when not specified', () {
      const state = PlayerState(streak: 7);
      final updated = state.copyWith(xp: 100);
      expect(updated.streak, 7);
    });
  });

  group('Achievement count', () {
    test('total achievements is 11 (9 original + 2 streak)', () {
      expect(achievements.length, 11);
    });

    test('all achievement keys are snake_case', () {
      final pattern = RegExp(r'^[a-z][a-z0-9_]*$');
      for (final key in achievements.keys) {
        expect(pattern.hasMatch(key), isTrue, reason: 'Key "$key" is not snake_case');
      }
    });

    test('all achievements have non-empty emoji, name, and description', () {
      for (final entry in achievements.entries) {
        final (emoji, name, desc) = entry.value;
        expect(emoji, isNotEmpty, reason: '${entry.key} has empty emoji');
        expect(name, isNotEmpty, reason: '${entry.key} has empty name');
        expect(desc, isNotEmpty, reason: '${entry.key} has empty description');
      }
    });
  });
}
