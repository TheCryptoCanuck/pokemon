import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/flash_challenge_service.dart';

/// Animated banner displaying the active flash challenge with a live countdown.
///
/// Returns [SizedBox.shrink] when no challenge is active.
/// Place at the top of the identify or home screen.
class FlashChallengeBanner extends ConsumerStatefulWidget {
  const FlashChallengeBanner({super.key});

  @override
  ConsumerState<FlashChallengeBanner> createState() =>
      _FlashChallengeBannerState();
}

class _FlashChallengeBannerState extends ConsumerState<FlashChallengeBanner> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Update every second for the countdown
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final h = d.inHours.toString();
      return '$h:$m:$s';
    }
    return '$m:$s';
  }


  @override
  Widget build(BuildContext context) {
    final state = ref.watch(flashChallengeProvider);
    final challenge = state.activeChallenge;

    // Nothing to show
    if (challenge == null) return const SizedBox.shrink();

    // Expired and already claimed -- hide
    if (challenge.isExpired && challenge.claimed) return const SizedBox.shrink();

    // Expired but not claimed -- show as missed (auto-dismiss)
    if (challenge.isExpired && !challenge.completed) {
      // Let service clean up on next app open
      return const SizedBox.shrink();
    }

    final remaining = challenge.timeRemaining;
    final isUrgent = remaining.inMinutes < 5 && !challenge.completed;
    final isCompleted = challenge.completed;
    final isClaimed = challenge.claimed;

    // Determine colors
    final List<Color> gradientColors;
    if (isClaimed) {
      gradientColors = [
        const Color(0xFF2E7D32),
        const Color(0xFF388E3C),
      ];
    } else if (isCompleted) {
      gradientColors = [
        const Color(0xFF2E7D32),
        const Color(0xFF43A047),
      ];
    } else {
      gradientColors = [
        const Color(0xFFC62828),
        const Color(0xFFE65100),
      ];
    }

    Widget banner = Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Left: icon
          Icon(
            isCompleted ? Icons.check_circle : Icons.flash_on,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 10),
          // Center: title + progress
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                if (isClaimed)
                  const Text(
                    'Reward claimed!',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  )
                else
                  Text(
                    isCompleted
                        ? 'Complete! +${challenge.xpReward} XP'
                        : '${challenge.progress}/${challenge.target} -- ${challenge.description}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Right: countdown or claim button
          if (isCompleted && !isClaimed)
            GestureDetector(
              onTap: () {
                HapticFeedback.heavyImpact();
                ref.read(flashChallengeProvider.notifier).claimReward();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.3),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Text(
                  'CLAIM',
                  style: TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 1.0, end: 1.08, duration: 700.ms)
          else if (!isClaimed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _formatDuration(remaining),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: 'monospace',
                ),
              ),
            ),
        ],
      ),
    );

    // Pulse red when urgent (< 5 min remaining)
    if (isUrgent) {
      banner = banner
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .tint(color: const Color(0xFFC62828).withValues(alpha: 0.15), duration: 600.ms);
    }

    // Entry animation
    return banner
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: -0.15, duration: 300.ms);
  }
}
