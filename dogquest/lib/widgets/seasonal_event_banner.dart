import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dogquest/services/seasonal_event_service.dart';

/// A banner that appears when a seasonal event is active.
class SeasonalEventBanner extends ConsumerWidget {
  const SeasonalEventBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventSvc = ref.watch(seasonalEventServiceProvider);
    final event = eventSvc.primaryEvent;

    if (event == null) return const SizedBox.shrink();

    final daysLeft = event.daysRemaining;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            event.themeColor.withValues(alpha: 0.2),
            event.themeColor.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: event.themeColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Text(event.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        event.name,
                        style: TextStyle(
                          color: event.themeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (daysLeft <= 3) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          daysLeft <= 1 ? 'LAST DAY!' : '$daysLeft days left',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  event.description,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (daysLeft > 3)
                  Text(
                    '$daysLeft days remaining',
                    style: TextStyle(
                      color: event.themeColor.withValues(alpha: 0.6),
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: event.themeColor.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: event.themeColor.withValues(alpha: 0.4)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${event.xpMultiplier.toStringAsFixed(0)}x',
                  style: TextStyle(
                    color: event.themeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'XP',
                  style: TextStyle(
                    color: event.themeColor.withValues(alpha: 0.7),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.05);
  }
}
