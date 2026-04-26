import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:dogquest/services/player_service.dart';
import 'package:dogquest/services/seasonal_event_service.dart';

class ActiveBonuses extends StatelessWidget {
  final PlayerState playerState;
  final SeasonalEventService seasonalSvc;

  const ActiveBonuses({
    required this.playerState,
    required this.seasonalSvc,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final event = seasonalSvc.primaryEvent;
    final hasStreakBonus = playerState.streakXpMultiplier > 1.0;
    final hasEvent = event != null;

    if (!hasStreakBonus && !hasEvent) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (hasStreakBonus) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.withValues(alpha: 0.12),
                  Colors.red.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Text(
                  '+${((playerState.streakXpMultiplier - 1) * 100).round()}% XP from streak',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms),
        ],
        if (hasEvent) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  event.themeColor.withValues(alpha: 0.12),
                  event.themeColor.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: event.themeColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Text(event.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${event.name} — ${event.xpMultiplier}x XP (${event.daysRemaining}d left)',
                    style: TextStyle(
                      color: event.themeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 220.ms),
        ],
      ],
    );
  }
}
