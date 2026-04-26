import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:dogquest/constants.dart';

/// A compact pill-shaped badge that displays a rarity name with a
/// moving shimmer/shine effect. Color matches the Rarity enum.
/// Legendary rarity gets extra sparkle particles.
///
/// Usage:
/// ```dart
/// RarityShimmerBadge(rarity: Rarity.legendary)
/// RarityShimmerBadge(rarity: Rarity.rare, fontSize: 11)
/// ```
class RarityShimmerBadge extends StatefulWidget {
  final Rarity rarity;
  final double fontSize;

  const RarityShimmerBadge({
    super.key,
    required this.rarity,
    this.fontSize = 12,
  });

  @override
  State<RarityShimmerBadge> createState() => _RarityShimmerBadgeState();
}

class _RarityShimmerBadgeState extends State<RarityShimmerBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sparkleController;
  final _random = Random();
  late final List<_SparklePoint> _sparkles;

  bool get _isLegendary => widget.rarity == Rarity.legendary;

  @override
  void initState() {
    super.initState();
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    if (_isLegendary) {
      _sparkles = List.generate(6, (_) => _SparklePoint(_random));
      _sparkleController.repeat();
    } else {
      _sparkles = [];
    }
  }

  @override
  void dispose() {
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.rarity.color;
    final label = widget.rarity.label;

    Widget badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.fontSize * 0.9,
        vertical: widget.fontSize * 0.3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
        boxShadow: _isLegendary
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: widget.fontSize,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.8,
          decoration: TextDecoration.none,
        ),
      ),
    );

    // Apply shimmer animation -- speed and intensity vary by rarity
    final shimmerDuration = switch (widget.rarity) {
      Rarity.legendary => 1500.ms,
      Rarity.rare => 2000.ms,
      Rarity.uncommon => 2500.ms,
      _ => 3000.ms,
    };

    badge = badge.animate(onPlay: (c) => c.repeat()).shimmer(
          duration: shimmerDuration,
          color: color.withValues(
            alpha: widget.rarity == Rarity.legendary ? 0.5 : 0.3,
          ),
          delay: 500.ms,
        );

    // Legendary gets sparkle particles around the badge
    if (_isLegendary) {
      return AnimatedBuilder(
        animation: _sparkleController,
        builder: (context, child) {
          return CustomPaint(
            foregroundPainter: _SparklePainter(
              sparkles: _sparkles,
              progress: _sparkleController.value,
              color: color,
            ),
            child: Padding(
              // Extra padding for sparkles to render outside the badge
              padding: const EdgeInsets.all(6),
              child: child,
            ),
          );
        },
        child: badge,
      );
    }

    return badge;
  }
}

class _SparklePoint {
  final double x; // 0.0 - 1.0 relative position
  final double y;
  final double phase; // Phase offset so sparkles blink at different times
  final double size;

  _SparklePoint(Random r)
      : x = r.nextDouble(),
        y = r.nextDouble(),
        phase = r.nextDouble(),
        size = 2.0 + r.nextDouble() * 3.0;
}

class _SparklePainter extends CustomPainter {
  final List<_SparklePoint> sparkles;
  final double progress;
  final Color color;

  _SparklePainter({
    required this.sparkles,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in sparkles) {
      // Each sparkle blinks with its own phase
      final t = ((progress + s.phase) % 1.0);
      final opacity = sin(t * pi).clamp(0.0, 1.0);
      if (opacity < 0.1) continue;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity * 0.8)
        ..style = PaintingStyle.fill;

      final cx = s.x * size.width;
      final cy = s.y * size.height;
      final r = s.size * (0.5 + opacity * 0.5);

      // Draw a 4-point star shape
      final path = Path();
      path.moveTo(cx, cy - r);
      path.lineTo(cx + r * 0.3, cy);
      path.lineTo(cx, cy + r);
      path.lineTo(cx - r * 0.3, cy);
      path.close();
      path.moveTo(cx - r, cy);
      path.lineTo(cx, cy + r * 0.3);
      path.lineTo(cx + r, cy);
      path.lineTo(cx, cy - r * 0.3);
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.progress != progress;
}
