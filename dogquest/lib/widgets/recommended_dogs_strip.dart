import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dogquest/constants.dart';
import 'package:dogquest/models/dog.dart';
import 'package:dogquest/services/kennel_service.dart';
import 'package:dogquest/services/dog_service.dart';
import 'package:dogquest/services/recommendation_service.dart';

/// A horizontal scrollable strip of recommended dogs the user hasn't
/// collected yet, prioritized by achievability and habitat familiarity.
class RecommendedDogsStrip extends ConsumerWidget {
  const RecommendedDogsStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recSvc = ref.watch(recommendationServiceProvider);
    final dogSvc = ref.watch(dogServiceProvider);
    final kennelSvc = ref.watch(kennelServiceProvider);

    final dogs = recSvc.recommendedDogs(dogSvc, kennelSvc, count: 5);

    if (dogs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Header ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Icon(
                Icons.search,
                color: Colors.white.withValues(alpha: 0.7),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Dogs to Find',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        // ─── Discovery counter ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '${kennelSvc.count} of ${dogSvc.all.length} breeds discovered',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // ─── Horizontal Dog Cards ───────────────────────────────────
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: dogs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              return _DogSuggestionCard(
                dog: dogs[index],
                index: index,
              );
            },
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.04);
  }
}

// ─── Dog Suggestion Card ─────────────────────────────────────────────────────

class _DogSuggestionCard extends StatelessWidget {
  final Dog dog;
  final int index;

  const _DogSuggestionCard({required this.dog, required this.index});

  bool get _isShimmering =>
      dog.rarity == Rarity.rare || dog.rarity == Rarity.legendary;

  @override
  Widget build(BuildContext context) {
    final rarityColor = dog.rarity.color;

    Widget card = Container(
      width: 80,
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          // ── Rarity color top border ────────────────────────────────
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: rarityColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── Silhouette icon ────────────────────────────────────────
          Icon(
            Icons.help_outline,
            size: 24,
            color: Colors.white.withValues(alpha: 0.25),
          ),

          const SizedBox(height: 6),

          // ── Dog name ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              dog.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),

          const Spacer(),

          // ── Rarity badge ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: rarityColor,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  dog.rarity.label,
                  style: TextStyle(
                    color: rarityColor.withValues(alpha: 0.8),
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // ── Habitat text ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
            child: Text(
              dog.habitat,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 8,
              ),
            ),
          ),
        ],
      ),
    );

    // Staggered entrance animation
    card = card
        .animate(delay: Duration(milliseconds: 150 + index * 80))
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.06);

    // Subtle shimmer on rare/legendary suggestions
    if (_isShimmering) {
      card = card
          .animate(
            onPlay: (controller) => controller.repeat(reverse: true),
          )
          .shimmer(
            delay: 600.ms,
            duration: 1800.ms,
            color: rarityColor.withValues(alpha: 0.12),
          );
    }

    return card;
  }
}
