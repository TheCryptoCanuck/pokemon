import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dogquest/constants.dart';
import 'package:dogquest/widgets/network_dog_image.dart';

/// **Mock screen for Play Store screenshot #1 (camera + live breed prediction).**
///
/// The shipping app's camera viewfinder shows a game-style reticle but does
/// NOT render live breed predictions on the preview — predictions only appear
/// after photo capture, in `DogFoundDialog`. This widget composites a
/// realistic camera-with-prediction overlay using a Wikimedia dog photo as
/// the background, so we can screenshot the experience we eventually want
/// to ship.
///
/// Reachable from `Settings -> Developer -> Mock screen 1` in debug builds.
/// Capture via `adb shell screencap` (see `scripts/capture_screenshots.ps1`).
class MockScreen1 extends StatelessWidget {
  const MockScreen1({super.key});

  // Same Wikimedia thumb that ships for the Golden Retriever entry in
  // assets/dogs.json — guarantees the photo is on-brand and known-good.
  static const _photoUrl =
      'https://commons.wikimedia.org/w/thumb.php?f=Golden_Retriever_Carlos_%2810581910556%29.jpg&w=1080';

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Background dog photo (full-bleed) ──
            NetworkDogImage(
              url: _photoUrl,
              height: size.height,
              fit: BoxFit.cover,
            ),

            // ── Dark gradient (top + bottom) for HUD legibility ──
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xCC000000),
                    Color(0x00000000),
                    Color(0x00000000),
                    Color(0xE6000000),
                  ],
                  stops: [0.0, 0.25, 0.55, 1.0],
                ),
              ),
              child: SizedBox.expand(),
            ),

            // ── Top HUD: streak + XP ──
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    _HudChip(
                      icon: Icons.local_fire_department_rounded,
                      label: '12-day streak',
                      color: accent,
                    ),
                    _HudChip(
                      icon: Icons.bolt_rounded,
                      label: '+25 XP',
                      color: accent,
                    ),
                  ],
                ),
              ),
            ),

            // ── Viewfinder corner brackets ──
            const Center(
              child: SizedBox(
                width: 280,
                height: 280,
                child: _CornerBrackets(),
              ),
            ),

            // ── Bottom prediction card ──
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: SafeArea(
                top: false,
                child: _PredictionCard(
                  breedName: 'Golden Retriever',
                  confidenceLabel: 'High match',
                  meta: 'Sporting Group  ·  Scotland  ·  Friendly',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _HudChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerBrackets extends StatelessWidget {
  const _CornerBrackets();

  @override
  Widget build(BuildContext context) {
    const stroke = 3.5;
    const length = 36.0;
    final color = Colors.white.withValues(alpha: 0.9);

    Widget corner({
      bool top = false,
      bool bottom = false,
      bool left = false,
      bool right = false,
    }) {
      return Positioned(
        top: top ? 0 : null,
        bottom: bottom ? 0 : null,
        left: left ? 0 : null,
        right: right ? 0 : null,
        child: SizedBox(
          width: length,
          height: length,
          child: CustomPaint(
            painter: _CornerPainter(
              color: color,
              stroke: stroke,
              top: top,
              bottom: bottom,
              left: left,
              right: right,
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        corner(top: true, left: true),
        corner(top: true, right: true),
        corner(bottom: true, left: true),
        corner(bottom: true, right: true),
      ],
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double stroke;
  final bool top, bottom, left, right;

  _CornerPainter({
    required this.color,
    required this.stroke,
    required this.top,
    required this.bottom,
    required this.left,
    required this.right,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    // Horizontal segment
    final hY = top ? stroke / 2 : h - stroke / 2;
    final hStart = left ? 0.0 : w * 0.4;
    final hEnd = left ? w * 0.6 : w;
    canvas.drawLine(Offset(hStart, hY), Offset(hEnd, hY), paint);

    // Vertical segment
    final vX = left ? stroke / 2 : w - stroke / 2;
    final vStart = top ? 0.0 : h * 0.4;
    final vEnd = top ? h * 0.6 : h;
    canvas.drawLine(Offset(vX, vStart), Offset(vX, vEnd), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PredictionCard extends StatelessWidget {
  final String breedName;
  final String confidenceLabel;
  final String meta;

  const _PredictionCard({
    required this.breedName,
    required this.confidenceLabel,
    required this.meta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: bgCard.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.18),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top row: TOP MATCH pill + High match pill
          Row(
            children: [
              _smallPill('TOP MATCH', Colors.amber),
              const SizedBox(width: 6),
              _smallPill(
                  confidenceLabel.toUpperCase(), Colors.greenAccent.shade400),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            breedName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            meta,
            style: const TextStyle(
              color: textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.star_rounded, size: 20),
              label: const Text('Add to Kennel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: bgDeep,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
