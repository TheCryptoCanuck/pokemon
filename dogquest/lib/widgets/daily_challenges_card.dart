import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import '../services/daily_challenge_service.dart';

/// A card displaying the 3 daily challenges with progress bars and
/// an animated "Daily Sweep" indicator.
class DailyChallengesCard extends ConsumerWidget {
  const DailyChallengesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dailyChallengeProvider);
    final notifier = ref.read(dailyChallengeProvider.notifier);
    final challenges = state.challenges;

    if (challenges.isEmpty) return const SizedBox.shrink();

    final completedCount = state.completedDailyCount;
    final allDone = state.allDailyCompleted;
    final sweepClaimed = state.dailySweepClaimed;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.amber.withValues(alpha: 0.12),
            bgCard,
          ],
        ),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt, color: Colors.amber, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Daily Challenges',
                        style: TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Countdown to reset
                _ResetCountdown(resetDuration: notifier.timeUntilDailyReset),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ─── Challenge List ──────────────────────────────────────
          ...challenges.asMap().entries.map((entry) {
            final index = entry.key;
            final challenge = entry.value;
            return _ChallengeRow(
              challenge: challenge,
              index: index,
            );
          }),

          // ─── Daily Sweep Section ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: _DailySweepRow(
              completedCount: completedCount,
              totalCount: challenges.length,
              allDone: allDone,
              claimed: sweepClaimed,
              onClaim: () {
                HapticFeedback.heavyImpact();
                notifier.claimDailySweep();
              },
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05);
  }
}

// ─── Challenge Row ───────────────────────────────────────────────────────────

class _ChallengeRow extends StatelessWidget {
  final DailyChallenge challenge;
  final int index;

  const _ChallengeRow({required this.challenge, required this.index});

  IconData get _icon {
    switch (challenge.type) {
      case ChallengeType.identifyDogs:
        return Icons.camera_alt;
      case ChallengeType.findRareDog:
        return Icons.auto_awesome;
      case ChallengeType.completeQuiz:
        return Icons.quiz;
      case ChallengeType.identifyFamily:
        return Icons.family_restroom;
      case ChallengeType.identifyUnique:
        return Icons.diversity_3;
      case ChallengeType.findLegendary:
        return Icons.star;
      case ChallengeType.quizPerfect:
        return Icons.emoji_events;
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed = challenge.completed;
    final accentColor = completed ? Colors.green : Colors.amber;

    Widget row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Status icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: completed ? 0.25 : 0.12),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Icon(
              completed ? Icons.check : _icon,
              size: 16,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 12),
          // Title + description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge.title,
                  style: TextStyle(
                    color: completed ? Colors.white54 : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    decoration: completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  challenge.description,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: challenge.progressFraction,
                    minHeight: 4,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Progress text + XP
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${challenge.progress}/${challenge.target}',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${challenge.xpReward} XP',
                  style: TextStyle(
                    color: accentColor.withValues(alpha: 0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // Animate completion with a scale bounce
    if (completed) {
      row = row.animate(delay: (100 * index).ms).fadeIn(duration: 300.ms);
    } else {
      row = row
          .animate(delay: (100 * index).ms)
          .fadeIn(duration: 300.ms)
          .slideX(begin: 0.03);
    }

    return row;
  }
}

// ─── Daily Sweep Row ─────────────────────────────────────────────────────────

class _DailySweepRow extends StatelessWidget {
  final int completedCount;
  final int totalCount;
  final bool allDone;
  final bool claimed;
  final VoidCallback onClaim;

  const _DailySweepRow({
    required this.completedCount,
    required this.totalCount,
    required this.allDone,
    required this.claimed,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: allDone
            ? (claimed
                ? Colors.green.withValues(alpha: 0.08)
                : Colors.amber.withValues(alpha: 0.1))
            : bgDeep.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: allDone
              ? (claimed
                  ? Colors.green.withValues(alpha: 0.3)
                  : Colors.amber.withValues(alpha: 0.4))
              : Colors.white10,
        ),
      ),
      child: Row(
        children: [
          // Trophy icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: allDone
                  ? LinearGradient(colors: [
                      Colors.amber.withValues(alpha: 0.3),
                      Colors.orange.withValues(alpha: 0.3),
                    ])
                  : null,
              color: allDone ? null : Colors.white10,
            ),
            child: Icon(
              claimed ? Icons.check_circle : Icons.emoji_events,
              color: allDone
                  ? (claimed ? Colors.green : Colors.amber)
                  : Colors.white30,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Sweep',
                  style: TextStyle(
                    color: allDone ? Colors.amber : Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  claimed
                      ? 'Completed! See you tomorrow.'
                      : allDone
                          ? 'All challenges complete! Claim your reward.'
                          : 'Complete all 3 challenges for a bonus reward',
                  style: TextStyle(
                    color: allDone ? Colors.white70 : Colors.white30,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                // Sweep progress dots
                Row(
                  children: List.generate(totalCount, (i) {
                    final filled = i < completedCount;
                    return Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled
                            ? (claimed ? Colors.green : Colors.amber)
                            : Colors.white12,
                        border: Border.all(
                          color: filled
                              ? (claimed
                                  ? Colors.green.withValues(alpha: 0.6)
                                  : Colors.amber.withValues(alpha: 0.6))
                              : Colors.white10,
                          width: 1,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          if (allDone && !claimed)
            GestureDetector(
              onTap: onClaim,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.amber, Colors.orange],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'CLAIM',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      '+300 XP',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
                  .animate(
                    onPlay: (c) => c.repeat(reverse: true),
                  )
                  .scaleXY(begin: 1.0, end: 1.05, duration: 800.ms),
            )
          else if (claimed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, color: Colors.green, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Claimed',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          else
            // Locked reward preview
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$completedCount/$totalCount',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const Text(
                    '+300 XP',
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Reset Countdown ─────────────────────────────────────────────────────────

class _ResetCountdown extends StatelessWidget {
  final Duration resetDuration;

  const _ResetCountdown({required this.resetDuration});

  @override
  Widget build(BuildContext context) {
    final hours = resetDuration.inHours;
    final minutes = resetDuration.inMinutes.remainder(60);
    final timeText = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, color: Colors.white38, size: 11),
          const SizedBox(width: 4),
          Text(
            timeText,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
