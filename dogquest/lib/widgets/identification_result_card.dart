import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants.dart';
import '../services/identification_service.dart';

/// Beautiful identification result card with circular confidence gauge,
/// rarity badge, and animated entrance.
class IdentificationResultCard extends StatelessWidget {
  final String dogName;
  final String scientificName;
  final Rarity rarity;
  final double confidence; // 0.0 - 1.0
  final int rank; // 1 = top match, 2+ = alternative

  const IdentificationResultCard({
    super.key,
    required this.dogName,
    required this.scientificName,
    required this.rarity,
    required this.confidence,
    this.rank = 1,
  });

  /// Qualitative match label calibrated for label-smoothed models
  /// where correct predictions typically produce 10-50% raw confidence.
  String get _matchLabel {
    if (confidence >= 0.50) return 'Excellent Match!';
    if (confidence >= 0.35) return 'High Match';
    if (confidence >= 0.20) return 'Good Match';
    if (confidence >= 0.15) return 'Possible Match';
    return 'Best guess \u2014 try another angle';
  }

  Color get _matchColor {
    if (confidence >= 0.35) return Colors.greenAccent;
    if (confidence >= 0.20) return Colors.amber;
    if (confidence >= 0.15) return Colors.orange;
    return Colors.redAccent.shade100;
  }

  IconData get _matchIcon {
    if (confidence >= 0.35) return Icons.verified_rounded;
    if (confidence >= 0.20) return Icons.check_circle_outline_rounded;
    if (confidence >= 0.15) return Icons.help_outline_rounded;
    return Icons.warning_amber_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isTopMatch = rank == 1;
    // Show qualitative label in gauge instead of raw percentage
    final normalizedValue = ConfidenceTier.normalizedDisplay(confidence);
    final gaugeLabel = confidence >= 0.35
        ? 'HIGH'
        : (confidence >= 0.20 ? 'GOOD' : '?');

    return Container(
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: isTopMatch ? 8 : 4,
        top: isTopMatch ? 8 : 4,
      ),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTopMatch
              ? Colors.amber.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
          width: isTopMatch ? 1.5 : 1.0,
        ),
        boxShadow: isTopMatch
            ? [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.15),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // ── Confidence gauge (normalized for visual clarity) ──
            _ConfidenceGauge(
              confidence: normalizedValue,
              percentText: gaugeLabel,
              color: _matchColor,
              size: isTopMatch ? 72 : 56,
            ),
            const SizedBox(width: 16),

            // ── Text content ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Rank label
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isTopMatch
                              ? Colors.amber.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isTopMatch ? 'TOP MATCH' : 'ALTERNATIVE #$rank',
                          style: TextStyle(
                            color: isTopMatch ? Colors.amber : Colors.white54,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Rarity pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: rarity.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: rarity.color.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          rarity.label,
                          style: TextStyle(
                            color: rarity.color,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Dog name
                  Text(
                    dogName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isTopMatch ? 20 : 16,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Scientific name
                  const SizedBox(height: 2),
                  Text(
                    scientificName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: isTopMatch ? 13 : 11,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Match quality label
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(_matchIcon, color: _matchColor, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        _matchLabel,
                        style: TextStyle(
                          color: _matchColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .slideY(begin: 0.3, end: 0, duration: 450.ms, curve: Curves.easeOutCubic)
        .fadeIn(duration: 400.ms, delay: Duration(milliseconds: (rank - 1) * 120));
  }
}

// ── Circular Confidence Gauge ────────────────────────────────────────────────

class _ConfidenceGauge extends StatelessWidget {
  final double confidence;
  final String percentText;
  final Color color;
  final double size;

  const _ConfidenceGauge({
    required this.confidence,
    required this.percentText,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: confidence),
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return CustomPaint(
            painter: _GaugePainter(
              progress: value,
              color: color,
            ),
            child: Center(
              child: Text(
                percentText,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;

  _GaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Background track
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    const startAngle = -pi / 2;
    final sweepAngle = 2 * pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );

    // Glow dot at end
    if (progress > 0.01) {
      final dotAngle = startAngle + sweepAngle;
      final dotX = center.dx + radius * cos(dotAngle);
      final dotY = center.dy + radius * sin(dotAngle);
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(dotX, dotY), 4, glowPaint);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
