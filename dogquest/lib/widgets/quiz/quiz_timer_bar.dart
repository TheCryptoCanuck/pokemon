import 'package:flutter/material.dart';

/// Animated timer bar shown during expert-mode quiz questions.
class QuizTimerBar extends StatelessWidget {
  final AnimationController timerController;
  final int timerSeconds;
  final bool answered;

  const QuizTimerBar({
    super.key,
    required this.timerController,
    required this.timerSeconds,
    required this.answered,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: AnimatedBuilder(
        animation: timerController,
        builder: (_, __) {
          final remaining = (1 - timerController.value) * timerSeconds;
          final isLow = remaining < 5;
          return ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: 1 - timerController.value,
              minHeight: isLow ? 6 : 3,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              valueColor: AlwaysStoppedAnimation(
                isLow ? Colors.red : Colors.purple.shade300,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Full-screen vignette overlay that pulses red when timer is running low.
class TimerUrgencyVignette extends StatelessWidget {
  final AnimationController timerController;
  final int timerSeconds;
  final bool answered;

  const TimerUrgencyVignette({
    super.key,
    required this.timerController,
    required this.timerSeconds,
    required this.answered,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: timerController,
      builder: (_, __) {
        final remaining = (1 - timerController.value) * timerSeconds;
        if (remaining >= 5 || answered) return const SizedBox.shrink();
        final intensity = ((5 - remaining) / 5).clamp(0.0, 1.0);
        return IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.2,
                colors: [
                  Colors.transparent,
                  Colors.red.withValues(alpha: 0.1 * intensity),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
