import 'package:flutter_test/flutter_test.dart';
import 'package:aviquest/helpers/game_helpers.dart';

void main() {
  group('Achievement definitions', () {
    test('has at least 26 achievements (22 base + 4 quiz)', () {
      expect(achievements.length, greaterThanOrEqualTo(26));
    });

    test('every achievement has non-empty emoji, name, and description', () {
      for (final entry in achievements.entries) {
        final (emoji, name, desc) = entry.value;
        expect(emoji, isNotEmpty, reason: '${entry.key} should have emoji');
        expect(name, isNotEmpty, reason: '${entry.key} should have name');
        expect(desc, isNotEmpty, reason: '${entry.key} should have description');
      }
    });

    test('all expected collection milestones exist', () {
      final keys = achievements.keys.toSet();
      expect(keys.contains('first_bird'), isTrue);
      expect(keys.contains('five_species'), isTrue);
      expect(keys.contains('ten_species'), isTrue);
      expect(keys.contains('twenty_species'), isTrue);
      expect(keys.contains('fifty_species'), isTrue);
      expect(keys.contains('hundred_species'), isTrue);
      expect(keys.contains('two_hundred_species'), isTrue);
    });

    test('all expected rarity achievements exist', () {
      final keys = achievements.keys.toSet();
      expect(keys.contains('rare_find'), isTrue);
      expect(keys.contains('legendary_find'), isTrue);
      expect(keys.contains('five_rare'), isTrue);
      expect(keys.contains('five_legendary'), isTrue);
    });

    test('all expected level achievements exist', () {
      final keys = achievements.keys.toSet();
      expect(keys.contains('level_5'), isTrue);
      expect(keys.contains('level_10'), isTrue);
      expect(keys.contains('level_20'), isTrue);
      expect(keys.contains('level_30'), isTrue);
    });

    test('all expected streak achievements exist', () {
      final keys = achievements.keys.toSet();
      expect(keys.contains('streak_3'), isTrue);
      expect(keys.contains('streak_7'), isTrue);
      expect(keys.contains('streak_30'), isTrue);
    });

    test('all expected conservation achievements exist', () {
      final keys = achievements.keys.toSet();
      expect(keys.contains('endangered_spotter'), isTrue);
      expect(keys.contains('conservation_hero'), isTrue);
    });

    test('all expected quiz achievements exist', () {
      final keys = achievements.keys.toSet();
      expect(keys.contains('first_quiz'), isTrue);
      expect(keys.contains('ten_quizzes'), isTrue);
      expect(keys.contains('perfect_quiz'), isTrue);
      expect(keys.contains('five_perfect'), isTrue);
    });

    test('all_common and all_uncommon collection goals exist', () {
      final keys = achievements.keys.toSet();
      expect(keys.contains('all_common'), isTrue);
      expect(keys.contains('all_uncommon'), isTrue);
    });
  });

  group('Achievement unique keys', () {
    test('no duplicate achievement keys', () {
      final keys = achievements.keys.toList();
      expect(keys.toSet().length, keys.length, reason: 'All keys should be unique');
    });
  });
}
