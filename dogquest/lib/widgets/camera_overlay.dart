import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:dogquest/constants.dart';

/// Game-style camera viewfinder overlay with targeting reticle,
/// corner brackets, hint text, streak info, and action buttons.
class CameraOverlay extends StatelessWidget {
  final VoidCallback onCapture;
  final VoidCallback onAudioRecord;
  final int streak;
  final int dailyChallengeTotal;
  final int dailyChallengeCompleted;

  const CameraOverlay({
    super.key,
    required this.onCapture,
    required this.onAudioRecord,
    this.streak = 0,
    this.dailyChallengeTotal = 3,
    this.dailyChallengeCompleted = 0,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        // ── Scanning line ──
        _ScanningLine(height: size.height),

        // ── Crosshair / reticle ──
        const Center(child: _Reticle(size: 200)),

        // ── Corner brackets ──
        const Center(child: _CornerBrackets(size: 240)),

        // ── Top bar: streak + daily challenge ──
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          child: _TopBar(
            streak: streak,
            challengeTotal: dailyChallengeTotal,
            challengeCompleted: dailyChallengeCompleted,
          ),
        ),

        // ── Hint text ──
        Positioned(
          bottom: 140,
          left: 32,
          right: 32,
          child: Text(
            'Point at a dog and tap the capture button',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              shadows: [
                Shadow(
                  blurRadius: 8,
                  color: Colors.black.withValues(alpha: 0.8),
                ),
              ],
            ),
          )
              .animate(
                onPlay: (c) => c.repeat(reverse: true),
              )
              .fadeIn(duration: 800.ms)
              .then(delay: 3.seconds)
              .fadeOut(duration: 800.ms)
              .then(delay: 2.seconds),
        ),

        // ── Bottom action area ──
        Positioned(
          bottom: 32,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Audio record button
              _ActionButton(
                icon: Icons.mic_rounded,
                label: 'Audio',
                onTap: onAudioRecord,
              ),
              // Spacer for central capture button (handled by CaptureButton)
              const SizedBox(width: 72),
              // Gallery placeholder
              _ActionButton(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Reticle ──────────────────────────────────────────────────────────────────

class _Reticle extends StatelessWidget {
  final double size;
  const _Reticle({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ReticlePainter()),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(begin: 1.0, end: 1.03, duration: 2.seconds);
  }
}

class _ReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.amber.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Outer circle
    canvas.drawCircle(center, size.width * 0.4, paint);

    // Inner circle
    paint.color = Colors.amber.withValues(alpha: 0.25);
    canvas.drawCircle(center, size.width * 0.15, paint);

    // Crosshair lines
    paint.color = Colors.amber.withValues(alpha: 0.4);
    paint.strokeWidth = 0.8;
    const gap = 12.0;
    final lineLen = size.width * 0.18;

    // Horizontal
    canvas.drawLine(
      Offset(center.dx - lineLen - gap, center.dy),
      Offset(center.dx - gap, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + gap, center.dy),
      Offset(center.dx + lineLen + gap, center.dy),
      paint,
    );
    // Vertical
    canvas.drawLine(
      Offset(center.dx, center.dy - lineLen - gap),
      Offset(center.dx, center.dy - gap),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy + gap),
      Offset(center.dx, center.dy + lineLen + gap),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Corner Brackets ──────────────────────────────────────────────────────────

class _CornerBrackets extends StatelessWidget {
  final double size;
  const _CornerBrackets({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CornerPainter()),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(
          begin: 1.0,
          end: 1.02,
          duration: 1800.ms,
          curve: Curves.easeInOut,
        );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.amber.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    const len = 28.0;
    const r = 6.0;

    // Top-left
    canvas.drawLine(const Offset(0, len), const Offset(0, r), paint);
    canvas.drawArc(
      const Rect.fromLTWH(0, 0, r * 2, r * 2),
      pi,
      pi / 2,
      false,
      paint,
    );
    canvas.drawLine(const Offset(r, 0), const Offset(len, 0), paint);

    // Top-right
    canvas.drawLine(Offset(size.width, len), Offset(size.width, r), paint);
    canvas.drawArc(
      Rect.fromLTWH(size.width - r * 2, 0, r * 2, r * 2),
      0,
      -pi / 2,
      false,
      paint,
    );
    canvas.drawLine(
      Offset(size.width - r, 0),
      Offset(size.width - len, 0),
      paint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(0, size.height - len),
      Offset(0, size.height - r),
      paint,
    );
    canvas.drawArc(
      Rect.fromLTWH(0, size.height - r * 2, r * 2, r * 2),
      pi,
      -pi / 2,
      false,
      paint,
    );
    canvas.drawLine(Offset(r, size.height), Offset(len, size.height), paint);

    // Bottom-right
    canvas.drawLine(
      Offset(size.width, size.height - len),
      Offset(size.width, size.height - r),
      paint,
    );
    canvas.drawArc(
      Rect.fromLTWH(size.width - r * 2, size.height - r * 2, r * 2, r * 2),
      0,
      pi / 2,
      false,
      paint,
    );
    canvas.drawLine(
      Offset(size.width - r, size.height),
      Offset(size.width - len, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Scanning Line ────────────────────────────────────────────────────────────

class _ScanningLine extends StatelessWidget {
  final double height;
  const _ScanningLine({required this.height});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.amber.withValues(alpha: 0.3),
                Colors.transparent,
              ],
            ),
          ),
        )
            .animate(
              onPlay: (c) => c.repeat(),
            )
            .moveY(
              begin: -height * 0.3,
              end: height * 0.3,
              duration: 4.seconds,
              curve: Curves.easeInOut,
            )
            .fadeIn(duration: 500.ms)
            .then(delay: 3.seconds)
            .fadeOut(duration: 500.ms),
      ),
    );
  }
}

// ── Top Bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final int streak;
  final int challengeTotal;
  final int challengeCompleted;

  const _TopBar({
    required this.streak,
    required this.challengeTotal,
    required this.challengeCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Streak badge
        if (streak > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: bgCard.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('\u{1F525}', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  '$streak-day streak',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2, end: 0),
        const Spacer(),
        // Daily challenge progress
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: bgCard.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flag_rounded, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              Text(
                '$challengeCompleted/$challengeTotal',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Small Action Button ──────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bgCard.withValues(alpha: 0.7),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: Colors.white70, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
