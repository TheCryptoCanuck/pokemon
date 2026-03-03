import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import '../services/seasonal_event_service.dart';

/// A banner that appears when a seasonal event is active.
class SeasonalEventBanner extends ConsumerWidget {
  const SeasonalEventBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventSvc = ref.read(seasonalEventServiceProvider);
    final event = eventSvc.primaryEvent;

    if (event == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          event.themeColor.withOpacity(0.2),
          event.themeColor.withOpacity(0.08),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: event.themeColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Text(event.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.name,
                    style: TextStyle(
                        color: event.themeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                Text(event.description,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: event.themeColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${event.xpMultiplier.toStringAsFixed(0)}x XP',
              style: TextStyle(
                  color: event.themeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.05);
  }
}
