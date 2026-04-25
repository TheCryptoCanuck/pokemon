import 'dart:math';
import 'package:flutter/material.dart';
import '../constants.dart';

/// Post-identification celebration with a capture ring animation,
/// rarity-colored ring, optional "NEW!" badge, and confidence display.
///
/// Usage:
/// ```dart
/// DogCatchAnimation.show(
///   context,
///   dogName: 'European Robin',
///   rarity: Rarity.uncommon,
///   confidence: 0.92,
///   isNew: true,
/// );
/// ```
class DogCatchAnimation {
  static void show(
    BuildContext context, {
    required String dogName,
    required Rarity rarity,
    required double confidence,
    bool isNew = false,
  }) {
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _DogCatchOverlay(
        dogName: dogName,
        rarity: rarity,
        confidence: confidence,
        isNew: isNew,
        onDone: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

class _DogCatchOverlay extends StatefulWidget {
  final String dogName;
  final Rarity rarity;
  final double confidence;
  final bool isNew;
  final VoidCallback onDone;

  const _DogCatchOverlay({
    required this.dogName,
    required this.rarity,
    required this.confidence,
    required this.isNew,
    required this.onDone,
  });

  @override
  State<_DogCatchOverlay> createState() => _DogCatchOverlayState();
}

class _DogCatchOverlayState extends State<_DogCatchOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _ringController;
  late final AnimationController _contentController;
  late final AnimationController _dismissController;
  late final Animation<double> _ringScale;
  late final Animation<double> _ringOpacity;
  late final Animation<double> _ringStroke;
  late final Animation<double> _flashOpacity;

  @override
  void initState() {
    super.initState();

    // Ring closing animation
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _ringScale = Tween<double>(begin: 3.0, end: 1.0).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeInBack),
    );

    _ringOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.3, end: 1.0), weight: 70),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 30),
    ]).animate(_ringController);

    _ringStroke = Tween<double>(begin: 2.0, end: 4.0).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeIn),
    );

    // Flash on capture
    _flashOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 85),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.6), weight: 5),
      TweenSequenceItem(tween: Tween(begin: 0.6, end: 0.0), weight: 10),
    ]).animate(_ringController);

    // Content reveal after ring closes
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Dismiss fade-out
    _dismissController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    await _ringController.forward();
    if (!mounted) return;
    await _contentController.forward();
    if (!mounted) return;

    // Hold visible for 1.2 seconds then dismiss
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    await _dismissController.forward();
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _ringController.dispose();
    _contentController.dispose();
    _dismissController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final rarityColor = widget.rarity.color;
    final confidencePct = (widget.confidence * 100).round();

    return AnimatedBuilder(
      animation: Listenable.merge(
          [_ringController, _contentController, _dismissController]),
      builder: (context, _) {
        final dismissOpacity = 1.0 - _dismissController.value;
        final contentProgress = _contentController.value;

        return IgnorePointer(
          child: Opacity(
            opacity: dismissOpacity,
            child: Stack(
              children: [
                // Background dim
                Container(
                  width: size.width,
                  height: size.height,
                  color: Colors.black.withValues(
                      alpha: 0.5 * (1.0 - _dismissController.value)),
                ),

                // White flash on capture
                if (_flashOpacity.value > 0)
                  Container(
                    width: size.width,
                    height: size.height,
                    color: rarityColor.withValues(alpha: _flashOpacity.value),
                  ),

                // Capture ring
                Center(
                  child: Transform.scale(
                    scale: _ringScale.value,
                    child: Opacity(
                      opacity: _ringOpacity.value,
                      child: CustomPaint(
                        size: const Size(160, 160),
                        painter: _CaptureRingPainter(
                          color: rarityColor,
                          strokeWidth: _ringStroke.value,
                          progress: _ringController.value,
                        ),
                      ),
                    ),
                  ),
                ),

                // Dog emoji in center
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Dog emoji appears when ring closes
                      Transform.scale(
                        scale: _ringController.value > 0.8
                            ? 0.5 + (_ringController.value - 0.8) / 0.2 * 0.5
                            : 0.0,
                        child: const Text(
                          '\u{1F436}',
                          style: TextStyle(
                            fontSize: 56,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // "NEW!" badge
                      if (widget.isNew)
                        Opacity(
                          opacity: contentProgress,
                          child: Transform.scale(
                            scale: 0.5 + contentProgress * 0.5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    Colors.greenAccent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.greenAccent
                                        .withValues(alpha: 0.8)),
                              ),
                              child: const Text(
                                'NEW!',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.greenAccent,
                                  letterSpacing: 2,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 8),

                      // Dog name
                      Opacity(
                        opacity: contentProgress,
                        child: Transform.translate(
                          offset: Offset(0, 10 * (1.0 - contentProgress)),
                          child: Text(
                            widget.dogName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: rarityColor,
                              shadows: [
                                Shadow(
                                  color: rarityColor.withValues(alpha: 0.5),
                                  blurRadius: 12,
                                ),
                              ],
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Rarity label
                      Opacity(
                        opacity: contentProgress,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 3),
                          decoration: BoxDecoration(
                            color: rarityColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: rarityColor.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            widget.rarity.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: rarityColor,
                              letterSpacing: 1,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Confidence percentage
                      Opacity(
                        opacity: contentProgress,
                        child: Text(
                          '$confidencePct% confidence',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.6),
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Radial sparkles on capture
                if (_ringController.value > 0.9)
                  ...List.generate(8, (i) {
                    final angle = (i / 8) * pi * 2;
                    final burstProgress =
                        ((contentProgress) * 1.5).clamp(0.0, 1.0);
                    final distance = 90 + burstProgress * 40;
                    final cx = size.width / 2 + cos(angle) * distance;
                    final cy = size.height / 2 + sin(angle) * distance;

                    return Positioned(
                      left: cx - 3,
                      top: cy - 3,
                      child: Opacity(
                        opacity: (1.0 - burstProgress).clamp(0.0, 1.0) *
                            contentProgress,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: rarityColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: rarityColor.withValues(alpha: 0.6),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter that draws the closing capture ring with glow effect.
class _CaptureRingPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double progress;

  _CaptureRingPainter({
    required this.color,
    required this.strokeWidth,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.15 * progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, radius, glowPaint);

    // Main ring
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw as an arc that completes based on progress
    final sweepAngle = progress * 2 * pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      paint,
    );

    // Small dots at start and end of arc
    if (progress > 0.1) {
      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      final endAngle = -pi / 2 + sweepAngle;
      final dotX = center.dx + cos(endAngle) * radius;
      final dotY = center.dy + sin(endAngle) * radius;
      canvas.drawCircle(Offset(dotX, dotY), strokeWidth + 1, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_CaptureRingPainter old) =>
      old.progress != progress || old.strokeWidth != strokeWidth;
}
