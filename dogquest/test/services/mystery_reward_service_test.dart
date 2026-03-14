import 'package:flutter_test/flutter_test.dart';
import 'package:dogquest/services/mystery_reward_service.dart';

void main() {
  group('MysteryRewardType', () {
    test('has 5 types', () {
      expect(MysteryRewardType.values.length, 5);
    });
  });

  group('MysteryReward', () {
    test('bonusXp displayText shows XP amount', () {
      const r = MysteryReward(type: MysteryRewardType.bonusXp, value: 100);
      expect(r.displayText, '+100 XP');
    });

    test('streakSaver displayText', () {
      const r = MysteryReward(type: MysteryRewardType.streakSaver);
      expect(r.displayText, 'Streak Saver Earned!');
    });

    test('xpMultiplier displayText shows multiplier', () {
      const r = MysteryReward(type: MysteryRewardType.xpMultiplier, value: 3);
      expect(r.displayText, 'Next ID: 3x XP!');
    });

    test('rarityBoost displayText', () {
      const r = MysteryReward(type: MysteryRewardType.rarityBoost, value: 3);
      expect(r.displayText, 'Rare Boost Active!');
    });

    test('titleUnlock displayText shows title', () {
      const r = MysteryReward(
        type: MysteryRewardType.titleUnlock,
        title: 'Pack Leader',
      );
      expect(r.displayText, 'New Title: Pack Leader');
    });

    test('toMap/fromMap round-trip', () {
      const original = MysteryReward(
        type: MysteryRewardType.titleUnlock,
        value: 0,
        title: 'Golden Eye',
      );
      final restored = MysteryReward.fromMap(original.toMap());
      expect(restored.type, MysteryRewardType.titleUnlock);
      expect(restored.title, 'Golden Eye');
    });

    test('fromMap handles missing fields', () {
      final r = MysteryReward.fromMap({});
      expect(r.type, MysteryRewardType.bonusXp); // index 0
      expect(r.value, 0);
      expect(r.title, isNull);
    });
  });

  group('MysteryRewardState', () {
    test('default state has correct values', () {
      const state = MysteryRewardState();
      expect(state.pendingMultiplier, 1.0);
      expect(state.rarityBoostRemaining, 0);
      expect(state.unlockedTitles, isEmpty);
      expect(state.pityCounter, 0);
      expect(state.streakSaverTokens, 0);
    });

    test('copyWith creates new state with updated fields', () {
      const original = MysteryRewardState();
      final updated = original.copyWith(
        pendingMultiplier: 2.0,
        pityCounter: 3,
        streakSaverTokens: 1,
      );
      expect(updated.pendingMultiplier, 2.0);
      expect(updated.pityCounter, 3);
      expect(updated.streakSaverTokens, 1);
      // Unchanged fields
      expect(updated.rarityBoostRemaining, 0);
      expect(updated.unlockedTitles, isEmpty);
    });

    test('copyWith preserves original state', () {
      const original = MysteryRewardState(pityCounter: 5);
      final updated = original.copyWith(pityCounter: 0);
      expect(original.pityCounter, 5);
      expect(updated.pityCounter, 0);
    });

    test('copyWith with unlockedTitles', () {
      const original = MysteryRewardState();
      final updated = original.copyWith(
        unlockedTitles: {'Pack Leader', 'Golden Eye'},
      );
      expect(updated.unlockedTitles.length, 2);
      expect(updated.unlockedTitles, contains('Pack Leader'));
    });
  });
}
