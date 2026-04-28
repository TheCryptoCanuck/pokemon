import 'package:flutter/material.dart';
import 'package:dogquest/constants.dart';

class XpBar extends StatelessWidget {
  final int level;
  final int xp;
  final int xpForNext;
  final double streakMultiplier;

  const XpBar({
    required this.level,
    required this.xp,
    required this.xpForNext,
    this.streakMultiplier = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final progress = xpForNext > 0 ? xp / xpForNext : 0.0;
    final clampedProgress = progress.clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Level on left, XP on right
          Row(
            children: [
              Text(
                'Level $level',
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                'XP: $xp / $xpForNext',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: clampedProgress,
              minHeight: 8,
              backgroundColor:
                  Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                accent,
              ),
            ),
          ),
          if (streakMultiplier > 1.0) ...[
            const SizedBox(height: 6),
            Text(
              '🔥 ${streakMultiplier}x streak bonus',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
