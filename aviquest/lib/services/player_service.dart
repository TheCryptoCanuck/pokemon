import 'package:hive_flutter/hive_flutter.dart';

/// Persists player stats (level, XP, streak, achievements) across sessions.
class PlayerService {
  static late Box _statsBox;

  static Future<void> init() async {
    _statsBox = await Hive.openBox('player_stats');
  }

  static int get level => _statsBox.get('level', defaultValue: 1) as int;
  static set level(int v) => _statsBox.put('level', v);

  static int get xp => _statsBox.get('xp', defaultValue: 0) as int;
  static set xp(int v) => _statsBox.put('xp', v);

  static int get streak => _statsBox.get('streak', defaultValue: 1) as int;
  static set streak(int v) => _statsBox.put('streak', v);

  static Set<String> get unlockedAchievements {
    final list = _statsBox.get('achievements', defaultValue: <String>[]);
    return Set<String>.from(list as List);
  }

  static set unlockedAchievements(Set<String> v) =>
      _statsBox.put('achievements', v.toList());

  static void unlockAchievement(String key) {
    final current = unlockedAchievements;
    current.add(key);
    unlockedAchievements = current;
  }
}
