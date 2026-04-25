import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants.dart';

/// Compact horizontal dog info widget for use in overlays and bottom sheets.
/// Displays dog name, rarity pill, mastery level, sighting count, and NEW badge.
class DogStatsMini extends StatelessWidget {
  final String dogName;
  final Rarity rarity;
  final int sightingCount;
  final bool isNew;
  final int masteryLevel; // 0-5

  const DogStatsMini({
    super.key,
    required this.dogName,
    required this.rarity,
    this.sightingCount = 0,
    this.isNew = false,
    this.masteryLevel = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNew
              ? Colors.amber.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Dog avatar placeholder ──
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: rarity.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: rarity.color.withValues(alpha: 0.3),
              ),
            ),
            child: Center(
              child: Text(
                '\u{1F436}',
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // ── Name + meta ──
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name row with NEW badge
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        dogName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isNew) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'NEW!',
                          style: TextStyle(
                            color: Color(0xFF1A0F0A),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(
                            begin: 1.0,
                            end: 1.1,
                            duration: 800.ms,
                            curve: Curves.easeInOut,
                          ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),

                // Bottom row: rarity + sightings + mastery
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Rarity pill
                    _RarityPill(rarity: rarity),
                    const SizedBox(width: 8),

                    // Sighting count
                    Icon(
                      Icons.visibility_rounded,
                      color: Colors.white.withValues(alpha: 0.4),
                      size: 13,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Spotted ${sightingCount}x',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Mastery dots
                    _MasteryDots(level: masteryLevel),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Rarity Pill ──────────────────────────────────────────────────────────────

class _RarityPill extends StatelessWidget {
  final Rarity rarity;
  const _RarityPill({required this.rarity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: rarity.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: rarity.color.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        rarity.label,
        style: TextStyle(
          color: rarity.color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ── Mastery Dots ─────────────────────────────────────────────────────────────

class _MasteryDots extends StatelessWidget {
  final int level; // 0-5
  const _MasteryDots({required this.level});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < level;
        return Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? Colors.amber : Colors.white.withValues(alpha: 0.15),
          ),
        );
      }),
    );
  }
}
