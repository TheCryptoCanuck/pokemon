import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Streak count badge shown when the player has 3+ correct answers in a row.
class QuizStreakBadge extends StatelessWidget {
  final int streakCount;

  const QuizStreakBadge({super.key, required this.streakCount});

  @override
  Widget build(BuildContext context) {
    if (streakCount < 3) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('\u{1F525}', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            '$streakCount streak!',
            style: const TextStyle(
              color: Colors.orange,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ).animate().scale(
          begin: const Offset(0.8, 0.8),
          curve: Curves.elasticOut,
          duration: 400.ms,
        );
  }
}

/// Floating XP toast that appears after a correct answer.
class QuizXpToast extends StatelessWidget {
  final int xpAwarded;
  final int streakCount;
  final bool visible;

  const QuizXpToast({
    super.key,
    required this.xpAwarded,
    required this.streakCount,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
      ),
      child: Text(
        '+$xpAwarded XP${streakCount >= 3 ? ' \u{1F525}' : ''}',
        style: const TextStyle(
          color: Colors.amber,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    )
        .animate()
        .fadeIn()
        .slideY(begin: 0.3, duration: 300.ms)
        .then()
        .fadeOut(delay: 1000.ms);
  }
}
