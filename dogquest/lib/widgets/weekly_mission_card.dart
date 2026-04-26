import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dogquest/constants.dart';
import 'package:dogquest/services/daily_challenge_service.dart';

/// A prominent card displaying the current weekly mission with countdown timer,
/// progress bar, and percentage indicator.
class WeeklyMissionCard extends ConsumerWidget {
  const WeeklyMissionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dailyChallengeProvider);
    final notifier = ref.read(dailyChallengeProvider.notifier);
    final mission = state.weeklyMission;

    if (mission == null) return const SizedBox.shrink();

    final completed = mission.completed;
    final progress = mission.progressFraction;
    final percentage = (progress * 100).round();
    final daysLeft = notifier.daysUntilWeeklyReset;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            completed
                ? Colors.green.withValues(alpha: 0.15)
                : const Color(0xFF7C4DFF).withValues(alpha: 0.12),
            bgCard,
          ],
        ),
        border: Border.all(
          color: completed
              ? Colors.green.withValues(alpha: 0.3)
              : const Color(0xFF7C4DFF).withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header Row ────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: completed
                        ? Colors.green.withValues(alpha: 0.2)
                        : const Color(0xFF7C4DFF).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        completed ? Icons.check_circle : Icons.flag,
                        color:
                            completed ? Colors.green : const Color(0xFF7C4DFF),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Weekly Mission',
                        style: TextStyle(
                          color: completed
                              ? Colors.green
                              : const Color(0xFF7C4DFF),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Days remaining countdown
                _DaysRemainingBadge(daysLeft: daysLeft, completed: completed),
              ],
            ),

            const SizedBox(height: 14),

            // ─── Mission Title + Description ───────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Large icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: completed
                          ? [
                              Colors.green.withValues(alpha: 0.2),
                              Colors.green.withValues(alpha: 0.1),
                            ]
                          : [
                              const Color(0xFF7C4DFF).withValues(alpha: 0.2),
                              Colors.amber.withValues(alpha: 0.1),
                            ],
                    ),
                    border: Border.all(
                      color: completed
                          ? Colors.green.withValues(alpha: 0.3)
                          : const Color(0xFF7C4DFF).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    _missionIcon(mission.id),
                    color: completed ? Colors.green : const Color(0xFF7C4DFF),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mission.title,
                        style: TextStyle(
                          color: completed ? Colors.white54 : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          decoration:
                              completed ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mission.description,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ─── Progress Bar ──────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            completed ? Colors.green : const Color(0xFF7C4DFF),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Progress text
                      Row(
                        children: [
                          Text(
                            '${mission.progress}/${mission.target}',
                            style: TextStyle(
                              color: completed
                                  ? Colors.green
                                  : const Color(0xFF7C4DFF),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$percentage%',
                            style: TextStyle(
                              color: completed
                                  ? Colors.green.withValues(alpha: 0.7)
                                  : Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // XP reward badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: completed
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: completed
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.amber.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '+${mission.xpReward}',
                        style: TextStyle(
                          color: completed ? Colors.green : Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'XP',
                        style: TextStyle(
                          color: completed
                              ? Colors.green.withValues(alpha: 0.7)
                              : Colors.amber.withValues(alpha: 0.7),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05);
  }

  IconData _missionIcon(String missionId) {
    if (missionId.contains('unique')) return Icons.catching_pokemon;
    if (missionId.contains('families')) return Icons.account_tree;
    if (missionId.contains('streak')) return Icons.local_fire_department;
    if (missionId.contains('sightings')) return Icons.visibility;
    if (missionId.contains('rare')) return Icons.auto_awesome;
    if (missionId.contains('quizzes')) return Icons.school;
    return Icons.flag;
  }
}

// ─── Days Remaining Badge ────────────────────────────────────────────────────

class _DaysRemainingBadge extends StatelessWidget {
  final int daysLeft;
  final bool completed;

  const _DaysRemainingBadge({
    required this.daysLeft,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    final urgent = daysLeft <= 2 && !completed;
    final color = completed
        ? Colors.green
        : urgent
            ? Colors.red
            : Colors.white38;
    final bgColor = completed
        ? Colors.green.withValues(alpha: 0.15)
        : urgent
            ? Colors.red.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.06);

    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: urgent
            ? Border.all(color: Colors.red.withValues(alpha: 0.4))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            completed ? Icons.check : Icons.timer,
            color: color,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            completed
                ? 'Complete'
                : daysLeft == 1
                    ? 'Last day!'
                    : '$daysLeft days left',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );

    if (urgent) {
      badge = badge
          .animate(
            onPlay: (c) => c.repeat(reverse: true),
          )
          .fadeIn(duration: 600.ms)
          .then()
          .fade(
            begin: 1.0,
            end: 0.7,
            duration: 800.ms,
          );
    }

    return badge;
  }
}
