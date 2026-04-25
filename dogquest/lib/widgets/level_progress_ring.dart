import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants.dart';

/// Circular XP progress indicator with level number, player title,
/// animated gradient ring, sparkle particles, and streak multiplier badge.
class LevelProgressRing extends StatefulWidget {
  final int level;
  final int xp;
  final int xpForNext;
  final double streakMultiplier;

  const LevelProgressRing({
    super.key,
    required this.level,
    required this.xp,
    required this.xpForNext,
    this.streakMultiplier = 1.0,
  });

  @override
  State<LevelProgressRing> createState() => _LevelProgressRingState();
}

class _LevelProgressRingState extends State<LevelProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnim;
  late Animation<double> _sparkleRotation;

  double get _progress => widget.xpForNext > 0
      ? (widget.xp / widget.xpForNext).clamp(0.0, 1.0)
      : 0.0;

  String get _title {
    final l = widget.level;
    if (l < 3) return 'Puppy';
    if (l < 6) return 'Good Boy';
    if (l < 10) return 'Pack Member';
    if (l < 15) return 'Breed Spotter';
    if (l < 20) return 'Dog Whisperer';
    if (l < 30) return 'Expert Handler';
    if (l < 40) return 'Show Judge';
    return 'Best in Show';
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _progressAnim = Tween<double>(begin: 0.0, end: _progress).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _sparkleRotation = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant LevelProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.xp != widget.xp || oldWidget.xpForNext != widget.xpForNext) {
      _progressAnim = Tween<double>(
        begin: _progressAnim.value,
        end: _progress,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatNumber(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
    }
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 180,
          height: 180,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: _RingPainter(
                  progress: _progressAnim.value,
                  sparkleAngle: _sparkleRotation.value,
                ),
                child: child,
              );
            },
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${widget.level}',
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    _title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade300,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ).animate().scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1.0, 1.0),
              duration: 600.ms,
              curve: Curves.elasticOut,
            ),
        const SizedBox(height: 12),
        Text(
          '${_formatNumber(widget.xp)} / ${_formatNumber(widget.xpForNext)} XP',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
            letterSpacing: 0.3,
          ),
        ),
        if (widget.streakMultiplier > 1.0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.shade800.withValues(alpha: 0.8),
                  Colors.red.shade700.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Text(
              '\u{1F525} ${widget.streakMultiplier.toStringAsFixed(1)}x',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                begin: const Offset(1.0, 1.0),
                end: const Offset(1.08, 1.08),
                duration: 800.ms,
              ),
        ],
      ],
    );
  }
}

/// Paints the gradient arc ring with sparkle particles at the leading edge.
class _RingPainter extends CustomPainter {
  final double progress;
  final double sparkleAngle;

  _RingPainter({required this.progress, required this.sparkleAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 10.0;

    // Background track
    final trackPaint = Paint()
      ..color = bgCard
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    // Gradient arc
    final sweepAngle = 2 * pi * progress;
    const startAngle = -pi / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final gradientPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * pi,
        colors: [
          const Color(0xFF2E7D32), // dark green
          const Color(0xFFD4874E), // green
          const Color(0xFF8BC34A), // light green
          Colors.amber.shade600,
          Colors.amber,
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
        transform: const GradientRotation(-pi / 2),
      ).createShader(rect);

    canvas.drawArc(rect, startAngle, sweepAngle, false, gradientPaint);

    // Sparkle particles at progress edge
    final edgeAngle = startAngle + sweepAngle;
    final edgeX = center.dx + radius * cos(edgeAngle);
    final edgeY = center.dy + radius * sin(edgeAngle);

    // Glow at the leading edge
    final glowPaint = Paint()
      ..color = Colors.amber.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(edgeX, edgeY), 6, glowPaint);

    // Small sparkle dots orbiting the edge
    final rng = Random(42);
    for (int i = 0; i < 5; i++) {
      final sparkleRadius = 8.0 + rng.nextDouble() * 6;
      final angle = sparkleAngle + (i * 2 * pi / 5);
      final sx = edgeX + sparkleRadius * cos(angle);
      final sy = edgeY + sparkleRadius * sin(angle);
      final opacity = (0.4 + rng.nextDouble() * 0.6).clamp(0.0, 1.0);
      final dotSize = 1.0 + rng.nextDouble() * 1.5;

      final dotPaint = Paint()..color = Colors.amber.withValues(alpha: opacity);
      canvas.drawCircle(Offset(sx, sy), dotSize, dotPaint);
    }

    // Bright dot at exact edge
    final edgeDotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(edgeX, edgeY), 3.5, edgeDotPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.sparkleAngle != sparkleAngle;
}

/// Wrapper to use [AnimatedBuilder] (which is just [AnimatedWidget]) but with
/// a builder callback for convenience inside the tree. Flutter provides
/// [AnimatedBuilder] which is exactly this.
