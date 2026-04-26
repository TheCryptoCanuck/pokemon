import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dogquest/constants.dart';
import 'package:dogquest/services/kennel_service.dart';
import 'package:dogquest/services/dog_mastery_service.dart';
import 'package:dogquest/services/dog_service.dart';
import 'package:dogquest/services/player_service.dart';
import 'package:dogquest/services/recommendation_service.dart';
import 'package:dogquest/services/sighting_service.dart';

/// Displays 2-3 personalized insights about the player's journey,
/// with staggered fade-in animations.
class PersonalInsightsCard extends ConsumerWidget {
  const PersonalInsightsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recSvc = ref.read(recommendationServiceProvider);
    final player = ref.watch(playerProvider);
    final kennelSvc = ref.read(kennelServiceProvider);
    final dogSvc = ref.read(dogServiceProvider);
    final mastery = ref.watch(dogMasteryProvider);
    final sightingSvc = ref.read(sightingServiceProvider);

    final insights = recSvc.generateInsights(
      player,
      kennelSvc,
      dogSvc,
      mastery,
      sightingSvc,
    );

    if (insights.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header ──────────────────────────────────────────────
          Row(
            children: [
              Icon(
                Icons.explore,
                color: Colors.white.withValues(alpha: 0.7),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Your Journey',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ─── Insights ────────────────────────────────────────────
          ...insights.asMap().entries.map((entry) {
            final index = entry.key;
            final insight = entry.value;
            return _InsightRow(insight: insight, index: index);
          }),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.04);
  }
}

// ─── Insight Row ──────────────────────────────────────────────────────────────

class _InsightRow extends StatelessWidget {
  final PersonalInsight insight;
  final int index;

  const _InsightRow({required this.insight, required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: index < 2 ? 12 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: insight.color.withValues(alpha: 0.15),
            ),
            child: Icon(
              insight.icon,
              size: 15,
              color: insight.color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.text,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                if (insight.actionLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    insight.actionLabel!,
                    style: TextStyle(
                      color: insight.color.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: 200 + index * 150))
        .fadeIn(duration: 350.ms)
        .slideX(begin: 0.03);
  }
}
