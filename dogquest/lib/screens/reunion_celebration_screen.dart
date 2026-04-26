import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dogquest/constants.dart';

const _log = developer.log;

/// Full-screen celebration shown when a lost dog is marked as found/reunited.
class ReunionCelebrationScreen extends StatefulWidget {
  final String dogName;
  final String reportId;

  const ReunionCelebrationScreen({
    required this.dogName,
    required this.reportId,
    super.key,
  });

  @override
  State<ReunionCelebrationScreen> createState() =>
      _ReunionCelebrationScreenState();
}

class _ReunionCelebrationScreenState extends State<ReunionCelebrationScreen>
    with TickerProviderStateMixin {
  late AnimationController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _confettiController.forward();

    // Fire-and-forget: notify users who filed sightings.
    // notify-sighters Edge Function may not be deployed yet — silent failure ok.
    unawaited(
      Supabase.instance.client.functions.invoke(
        'notify-sighters',
        body: {'report_id': widget.reportId},
      ).catchError((Object e) {
        _log(
          'notify-sighters not available: $e',
          name: 'ReunionCelebrationScreen',
        );
      }),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDeep,
      body: Stack(
        children: [
          _ConfettiBackground(animation: _confettiController),
          _CelebrationContent(
            dogName: widget.dogName,
            reportId: widget.reportId,
          ),
        ],
      ),
    );
  }
}

/// Confetti background with animated burst effect.
class _ConfettiBackground extends StatelessWidget {
  final AnimationController animation;

  const _ConfettiBackground({
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _ConfettiPainter(animation.value),
          size: Size.infinite,
        );
      },
    );
  }
}

/// Main celebration content with text and buttons.
class _CelebrationContent extends StatelessWidget {
  final String dogName;
  final String reportId;

  const _CelebrationContent({
    required this.dogName,
    required this.reportId,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Paw icon with animation
              const _SimplePawIcon(),
              const SizedBox(height: 32),
              // Headline
              Text(
                "They're Home! 🎉",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              )
                  .animate()
                  .slideY(
                    begin: 0,
                    end: 0,
                    duration: 800.ms,
                    curve: Curves.easeOutCubic,
                  )
                  .fadeIn(duration: 600.ms),
              const SizedBox(height: 16),
              // Subtext with dog name
              Text(
                '$dogName has been reunited with their family.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.5,
                ),
              )
                  .animate()
                  .slideY(
                    begin: 10,
                    end: 0,
                    duration: 800.ms,
                    curve: Curves.easeOutCubic,
                    delay: 100.ms,
                  )
                  .fadeIn(duration: 600.ms, delay: 100.ms),
              const SizedBox(height: 48),
              // Action buttons
              _ActionButtons(
                dogName: dogName,
                reportId: reportId,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated paw icon with scale and fade effects.
class _SimplePawIcon extends StatelessWidget {
  const _SimplePawIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.pets,
      size: 80,
      color: Colors.amber,
    )
        .animate()
        .scale(
          begin: 0.5,
          end: 1.0,
          duration: 600.ms,
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: 400.ms);
  }
}

/// Action buttons row (Share + Done).
class _ActionButtons extends StatelessWidget {
  final String dogName;
  final String reportId;

  const _ActionButtons({
    required this.dogName,
    required this.reportId,
  });

  Future<void> _shareNews(BuildContext context) async {
    final message =
        '🎉 Great news! $dogName has been reunited with their family! #DogQuest #ReunionStory';
    try {
      final scaff = ScaffoldMessenger.of(context);
      await Clipboard.setData(ClipboardData(text: message));
      if (context.mounted) {
        scaff.showSnackBar(
          const SnackBar(
            backgroundColor: bgCard,
            content: Text(
              'Message copied to clipboard!',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      _log('Failed to share: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Share button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => _shareNews(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.share),
            label: const Text(
              'Share the Good News',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        )
            .animate()
            .slideY(
              begin: 20,
              end: 0,
              duration: 600.ms,
              curve: Curves.easeOutCubic,
              delay: 200.ms,
            )
            .fadeIn(duration: 500.ms, delay: 200.ms),
        const SizedBox(height: 12),
        // Done button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: () => context.go('/'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(
                color: Colors.white24,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Done',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        )
            .animate()
            .slideY(
              begin: 20,
              end: 0,
              duration: 600.ms,
              curve: Curves.easeOutCubic,
              delay: 300.ms,
            )
            .fadeIn(duration: 500.ms, delay: 300.ms),
      ],
    );
  }
}

/// Custom painter for confetti burst effect.
class _ConfettiPainter extends CustomPainter {
  final double progress;

  static const _particleCount = 30;

  _ConfettiPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final colors = [
      Colors.amber,
      Colors.amber.shade200,
      Colors.yellow.shade400,
      Colors.amber.shade700,
      Colors.orange,
    ];

    for (int i = 0; i < _particleCount; i++) {
      final angle = (i / _particleCount) * math.pi * 2;
      final speed = 100 + (i % 3) * 50.0;
      final distance = speed * progress;

      final dx = math.cos(angle) * distance;
      final dy = math.sin(angle) * distance;
      final particlePos = center + Offset(dx, dy);

      // Fade out towards end
      final opacity = (1.0 - progress).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: opacity * 0.8);

      canvas.drawCircle(particlePos, 4.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
