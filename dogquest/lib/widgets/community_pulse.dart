import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import '../services/dog_service.dart';

/// Simulated community activity card creating social proof.
///
/// All numbers are deterministic for the same date/hour so they feel
/// real but require no backend.
class CommunityPulse extends ConsumerWidget {
  const CommunityPulse({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final daySeed =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final hourSeed =
        DateTime(now.year, now.month, now.day, now.hour).millisecondsSinceEpoch;

    final dayRng = Random(daySeed);
    final hourRng = Random(hourSeed);

    final dogsToday = 1200 + dayRng.nextInt(2301); // 1200..3500
    final activeDogers = 80 + hourRng.nextInt(171); // 80..250

    // Pick trending dog deterministically from the full list
    final dogSvc = ref.watch(dogServiceProvider);
    final allDogs = dogSvc.all;
    final trendingDog = allDogs.isNotEmpty
        ? allDogs[hourRng.nextInt(allDogs.length)].name
        : 'Northern Cardinal';

    final joinCount = 8400 + daySeed % 3200; // stable per day

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(
            color: Color(0xFFD4874E),
            width: 3,
          ),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Header ----
          Row(
            children: [
              // Animated pulse dot
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFD4874E),
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(begin: 1.0, end: 1.4, duration: 900.ms)
                  .then()
                  .fadeOut(duration: 400.ms)
                  .then()
                  .fadeIn(duration: 400.ms),
              const SizedBox(width: 8),
              const Text(
                'Community Activity',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4874E).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Color(0xFFD4874E),
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ---- Stats rows ----
          _StatRow(
            icon: Icons.search,
            text: '$dogsToday dogs identified today',
          ),
          const SizedBox(height: 8),
          _StatRow(
            icon: Icons.local_fire_department,
            text: '$activeDogers active identifiers right now',
          ),
          const SizedBox(height: 8),
          _StatRow(
            icon: Icons.star_outline,
            text: 'Trending: $trendingDog',
          ),
          const SizedBox(height: 10),
          // ---- Footer ----
          Text(
            'Join $joinCount dog lovers on their quest!',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.04);
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _StatRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
