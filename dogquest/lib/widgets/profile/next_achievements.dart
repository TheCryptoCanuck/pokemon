import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../constants.dart';
import '../../helpers/game_helpers.dart';
import '../../services/dog_service.dart';
import '../../services/kennel_service.dart';
import '../../services/player_service.dart';

class _AchievementHint {
  final String key;
  final double progress;
  final String hint;

  const _AchievementHint(
      {required this.key, required this.progress, required this.hint});
}

class NextAchievements extends StatelessWidget {
  final PlayerState playerState;
  final KennelService kennelSvc;
  final DogService dogSvc;

  const NextAchievements({
    required this.playerState,
    required this.kennelSvc,
    required this.dogSvc,
    super.key,
  });

  List<_AchievementHint> _buildHints() {
    final unlocked = playerState.unlockedAchievements;
    final hints = <_AchievementHint>[];

    final count = kennelSvc.count;
    final milestones = [
      (5, 'five_species'),
      (10, 'ten_species'),
      (20, 'twenty_species'),
      (50, 'fifty_species'),
      (100, 'hundred_species'),
      (200, 'two_hundred_species'),
    ];
    for (final (target, key) in milestones) {
      if (!unlocked.contains(key) && count > 0) {
        final remaining = target - count;
        if (remaining > 0 && remaining <= target) {
          hints.add(_AchievementHint(
              key: key,
              progress: count / target,
              hint: '$remaining more species'));
        }
        break;
      }
    }

    final collectedDogs = kennelSvc.collectedDogs;
    final rareCount =
        collectedDogs.where((b) => b.rarity == Rarity.rare).length;
    if (!unlocked.contains('five_rare') && rareCount > 0) {
      hints.add(_AchievementHint(
          key: 'five_rare',
          progress: rareCount / 5,
          hint: '${5 - rareCount} more rare'));
    }
    final legendaryCount =
        collectedDogs.where((b) => b.rarity == Rarity.legendary).length;
    if (!unlocked.contains('five_legendary') && legendaryCount > 0) {
      hints.add(_AchievementHint(
          key: 'five_legendary',
          progress: legendaryCount / 5,
          hint: '${5 - legendaryCount} more legendary'));
    }

    final streak = playerState.streak;
    final streakMilestones = [
      (3, 'streak_3'),
      (7, 'streak_7'),
      (30, 'streak_30')
    ];
    for (final (target, key) in streakMilestones) {
      if (!unlocked.contains(key) && streak > 0) {
        hints.add(_AchievementHint(
            key: key,
            progress: streak / target,
            hint: '${target - streak} more days'));
        break;
      }
    }

    final quizzes = playerState.quizzesCompleted;
    if (!unlocked.contains('ten_quizzes') && quizzes > 0 && quizzes < 10) {
      hints.add(_AchievementHint(
          key: 'ten_quizzes',
          progress: quizzes / 10,
          hint: '${10 - quizzes} more quizzes'));
    }

    return hints;
  }

  @override
  Widget build(BuildContext context) {
    final hints = _buildHints();
    if (hints.isEmpty) return const SizedBox.shrink();

    hints.sort((a, b) => b.progress.compareTo(a.progress));
    final displayHints = hints.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.track_changes, color: Colors.amber, size: 16),
            SizedBox(width: 6),
            Text('Next Up',
                style: TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ]),
          const SizedBox(height: 10),
          ...displayHints.map((hint) {
            final achievement = achievements[hint.key];
            if (achievement == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Text(achievement.$1, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(achievement.$2,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: hint.progress.clamp(0.0, 1.0),
                            minHeight: 5,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.05),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              hint.progress >= 0.75
                                  ? Colors.amber
                                  : Colors.white38,
                            ),
                          ),
                        ),
                      ]),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${(hint.progress * 100).round()}%',
                        style: TextStyle(
                          color: hint.progress >= 0.75
                              ? Colors.amber
                              : Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        )),
                    Text(hint.hint,
                        style: const TextStyle(
                            color: Colors.white30, fontSize: 9)),
                  ],
                ),
              ]),
            );
          }),
        ],
      ),
    ).animate().fadeIn(delay: 320.ms);
  }
}
