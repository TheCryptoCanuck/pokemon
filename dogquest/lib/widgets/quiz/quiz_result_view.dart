import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:dogquest/constants.dart';
import 'package:dogquest/services/quiz_engine.dart';

/// Results screen shown after completing a quiz round.
class QuizResultView extends StatelessWidget {
  final int score;
  final int totalQuestions;
  final int totalXp;
  final int bestStreak;
  final QuizDifficulty difficulty;
  final bool isNewBest;
  final List<QuizQuestion> questions;
  final List<int?> userAnswers;
  final AnimationController confettiController;
  final List<ConfettiParticle> confettiParticles;
  final VoidCallback onPlayAgain;
  final VoidCallback onChangeDifficulty;

  const QuizResultView({
    super.key,
    required this.score,
    required this.totalQuestions,
    required this.totalXp,
    required this.bestStreak,
    required this.difficulty,
    required this.isNewBest,
    required this.questions,
    required this.userAnswers,
    required this.confettiController,
    required this.confettiParticles,
    required this.onPlayAgain,
    required this.onChangeDifficulty,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (score / totalQuestions * 100).round();
    final gradeColor = percentage >= 80
        ? Colors.green
        : percentage >= 50
            ? Colors.amber
            : Colors.red;
    String grade;
    String emoji;
    if (percentage == 100) {
      grade = 'Perfect!';
      emoji = '\u{1F4AF}';
    } else if (percentage >= 90) {
      grade = 'Dog Expert!';
      emoji = '\u{1F3C6}';
    } else if (percentage >= 70) {
      grade = 'Great Job!';
      emoji = '\u{2B50}';
    } else if (percentage >= 50) {
      grade = 'Good Try!';
      emoji = '\u{1F4AA}';
    } else {
      grade = 'Keep Practicing!';
      emoji = '\u{1F43E}';
    }

    return Scaffold(
      backgroundColor: bgDeep,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Emoji
                    Text(emoji, style: const TextStyle(fontSize: 64))
                        .animate()
                        .scale(
                          begin: const Offset(0.3, 0.3),
                          curve: Curves.elasticOut,
                          duration: 800.ms,
                        ),

                    const SizedBox(height: 8),

                    // Score ring
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: score / totalQuestions),
                        duration: 1500.ms,
                        curve: Curves.easeOutCubic,
                        builder: (_, value, child) => CustomPaint(
                          painter: ScoreRingPainter(
                            progress: value,
                            color: gradeColor,
                          ),
                          child: child,
                        ),
                        child: Center(
                          child: TweenAnimationBuilder<int>(
                            tween: IntTween(begin: 0, end: score),
                            duration: 1200.ms,
                            builder: (_, value, __) => Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$value',
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                    color: gradeColor,
                                  ),
                                ),
                                Text(
                                  'of $totalQuestions',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 200.ms),

                    const SizedBox(height: 16),

                    Text(
                      grade,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: gradeColor,
                      ),
                    ).animate().fadeIn(delay: 400.ms),

                    if (isNewBest) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.greenAccent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              color: Colors.greenAccent,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'NEW BEST!',
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 500.ms)
                          .scale(
                            begin: const Offset(0.8, 0.8),
                            curve: Curves.elasticOut,
                          )
                          .then()
                          .shimmer(
                            duration: 1200.ms,
                            color: Colors.greenAccent.withValues(alpha: 0.3),
                          ),
                    ],

                    const SizedBox(height: 24),

                    // Stats
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: bgCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.04),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatColumn(
                            Icons.bolt,
                            '+$totalXp',
                            'XP Earned',
                            Colors.amber,
                          ),
                          Container(
                            width: 1,
                            height: 36,
                            color: Colors.white.withValues(alpha: 0.04),
                          ),
                          _buildStatColumn(
                            Icons.local_fire_department,
                            '${bestStreak}x',
                            'Best Streak',
                            Colors.orange,
                          ),
                          Container(
                            width: 1,
                            height: 36,
                            color: Colors.white.withValues(alpha: 0.04),
                          ),
                          _buildStatColumn(
                            Icons.speed,
                            difficulty.label,
                            'Difficulty',
                            difficulty.color,
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 600.ms),

                    const SizedBox(height: 24),

                    // Review
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => _showReview(context),
                        icon: const Icon(Icons.list_alt, size: 18),
                        label: const Text('Review Answers'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white54,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 700.ms),

                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: onPlayAgain,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: bgDeep,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: const Text('Play Again'),
                      ),
                    ).animate().fadeIn(delay: 750.ms),

                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: onChangeDifficulty,
                      child: Text(
                        'Change Difficulty',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Confetti overlay
          if (score >= 7)
            AnimatedBuilder(
              animation: confettiController,
              builder: (context, _) {
                if (!confettiController.isAnimating &&
                    confettiController.value == 0) {
                  return const SizedBox.shrink();
                }
                return CustomPaint(
                  size: MediaQuery.of(context).size,
                  painter: ConfettiPainter(
                    particles: confettiParticles,
                    progress: confettiController.value,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.25),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  // ─── Review Sheet ─────────────────────────────────────────────────────────

  void _showReview(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Quiz Review',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: questions.length,
                itemBuilder: (_, i) {
                  final q = questions[i];
                  final userAnswer =
                      i < userAnswers.length ? userAnswers[i] : null;
                  final wasCorrect =
                      userAnswer != null && userAnswer == q.correctIndex;
                  final timedOut = userAnswer == null;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: wasCorrect
                          ? Colors.green.withValues(alpha: 0.06)
                          : Colors.red.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: (wasCorrect ? Colors.green : Colors.red)
                            .withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          wasCorrect
                              ? Icons.check_circle_rounded
                              : timedOut
                                  ? Icons.timer_off
                                  : Icons.cancel_rounded,
                          color: wasCorrect ? Colors.green : Colors.red,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                q.options[q.correctIndex],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (!wasCorrect &&
                                  userAnswer != null &&
                                  userAnswer >= 0 &&
                                  userAnswer < q.options.length)
                                Text(
                                  'You picked: ${q.options[userAnswer]}',
                                  style: TextStyle(
                                    color: Colors.red.withValues(alpha: 0.5),
                                    fontSize: 12,
                                  ),
                                ),
                              if (timedOut)
                                Text(
                                  'Time ran out',
                                  style: TextStyle(
                                    color: Colors.red.withValues(alpha: 0.5),
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          'Q${i + 1}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.15),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAINTERS
// ═══════════════════════════════════════════════════════════════════════════════

class ScoreRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  ScoreRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const stroke = 10.0;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );

    if (progress <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: 2 * pi,
          colors: [color.withValues(alpha: 0.4), color],
          transform: const GradientRotation(-pi / 2),
        ).createShader(rect),
    );

    final angle = -pi / 2 + 2 * pi * progress;
    canvas.drawCircle(
      Offset(center.dx + radius * cos(angle), center.dy + radius * sin(angle)),
      5,
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  @override
  bool shouldRepaint(covariant ScoreRingPainter old) =>
      old.progress != progress;
}

class ConfettiParticle {
  final double x;
  final double speed;
  final double size;
  final double drift;
  final Color color;
  final double rotation;

  ConfettiParticle(Random rng)
      : x = rng.nextDouble(),
        speed = 0.5 + rng.nextDouble() * 0.8,
        size = 4 + rng.nextDouble() * 6,
        drift = (rng.nextDouble() - 0.5) * 0.3,
        rotation = rng.nextDouble() * 2 * pi,
        color = [
          Colors.amber,
          Colors.green,
          Colors.red,
          Colors.blue,
          Colors.purple,
          Colors.orange,
          Colors.pink,
          const Color(0xFFD4874E),
        ][rng.nextInt(8)];
}

class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  final double progress;

  ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = progress < 0.7 ? 1.0 : 1.0 - ((progress - 0.7) / 0.3);

    for (final p in particles) {
      final y = -20 + (size.height + 40) * progress * p.speed;
      final x =
          p.x * size.width + sin(progress * 8 + p.rotation) * 20 * p.drift;

      if (y < -20 || y > size.height + 20) continue;

      final paint = Paint()..color = p.color.withValues(alpha: 0.7 * opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * 6 * p.speed + p.rotation);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.6,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter old) => old.progress != progress;
}
