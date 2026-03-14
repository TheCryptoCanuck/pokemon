import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants.dart';

/// Data for a single rarity segment in the collection wheel.
class RaritySegment {
  final Rarity rarity;
  final int collected;
  final int total;

  const RaritySegment({
    required this.rarity,
    required this.collected,
    required this.total,
  });

  double get fraction => total > 0 ? collected / total : 0.0;
}

/// Animated donut chart showing collection progress broken down by rarity tier.
class RarityCollectionWheel extends StatefulWidget {
  final List<RaritySegment> segments;

  const RarityCollectionWheel({
    super.key,
    required this.segments,
  });

  @override
  State<RarityCollectionWheel> createState() => _RarityCollectionWheelState();
}

class _RarityCollectionWheelState extends State<RarityCollectionWheel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fillAnimation;

  int get _totalCollected =>
      widget.segments.fold<int>(0, (sum, s) => sum + s.collected);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fillAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 160,
          height: 160,
          child: AnimatedBuilder(
            animation: _fillAnimation,
            builder: (context, child) {
              return CustomPaint(
                painter: _DonutPainter(
                  segments: widget.segments,
                  fillProgress: _fillAnimation.value,
                ),
                child: child,
              );
            },
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_totalCollected',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  const Text(
                    'species',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
            .animate()
            .scale(
              begin: const Offset(0.85, 0.85),
              end: const Offset(1.0, 1.0),
              duration: 600.ms,
              curve: Curves.easeOutBack,
            )
            .fadeIn(duration: 400.ms),
        const SizedBox(height: 16),
        // Legend
        ...widget.segments.map((seg) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: seg.rarity.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: Text(
                    seg.rarity.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: seg.rarity.color,
                    ),
                  ),
                ),
                Text(
                  '${seg.collected} / ${seg.total}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<RaritySegment> segments;
  final double fillProgress;

  _DonutPainter({required this.segments, required this.fillProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 18.0;
    const gapAngle = 0.06; // radians gap between segments

    // Background track
    final trackPaint = Paint()
      ..color = bgCard
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // Calculate total collected for proportional sizing.
    final totalCollected = segments.fold<int>(0, (s, seg) => s + seg.collected);
    if (totalCollected == 0) return;

    final totalGap = gapAngle * segments.where((s) => s.collected > 0).length;
    final availableAngle = (2 * pi - totalGap) * fillProgress;
    final rect = Rect.fromCircle(center: center, radius: radius);

    double currentAngle = -pi / 2;

    for (final seg in segments) {
      if (seg.collected <= 0) continue;

      final fraction = seg.collected / totalCollected;
      final sweepAngle = availableAngle * fraction;

      final paint = Paint()
        ..color = seg.rarity.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, currentAngle, sweepAngle, false, paint);

      currentAngle += sweepAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.fillProgress != fillProgress ||
      oldDelegate.segments != segments;
}
