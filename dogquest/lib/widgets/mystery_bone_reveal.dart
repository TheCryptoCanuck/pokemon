import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/mystery_reward_service.dart';

// --- Bone Painter ---------------------------------------------------------------

class _BonePainter extends CustomPainter {
  final double crackProgress; // 0.0 = no cracks, 1.0 = fully cracked
  final Color boneColor;
  final Color glowColor;
  final double glowPhase; // 0..2*pi for shimmer animation

  _BonePainter({
    required this.crackProgress,
    required this.boneColor,
    required this.glowColor,
    required this.glowPhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Bone dimensions for mystery reward animation.
    final shaftHalfLen = size.height * 0.34; // total length ~68% of height
    final shaftHalfW = size.width * 0.09; // shaft width ~18% of width
    final knobRadius = size.width * 0.14; // knob radius
    final knobSpread = size.width * 0.17; // distance between knob centers (half)

    // Glow behind bone.
    if (crackProgress < 1.0) {
      final glowRadius = shaftHalfLen * 1.5 + sin(glowPhase) * 8;
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            glowColor.withValues(alpha: 0.3 + sin(glowPhase) * 0.1),
            glowColor.withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(center: Offset(cx, cy), radius: glowRadius),
        );
      canvas.drawCircle(Offset(cx, cy), glowRadius, glowPaint);
    }

    // Build bone path: shaft + four knobs (two on each end).
    final bonePath = _buildBonePath(
        cx, cy, shaftHalfLen, shaftHalfW, knobRadius, knobSpread);

    // Bone fill with warm brown/cream gradient.
    final boneGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        boneColor,
        Color.lerp(boneColor, const Color(0xFFD2B48C), 0.3)!,
        boneColor,
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    final bonePaint = Paint()
      ..shader = boneGradient.createShader(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: size.width,
          height: size.height,
        ),
      );
    canvas.drawPath(bonePath, bonePaint);

    // Subtle outline to define shape.
    final outlinePaint = Paint()
      ..color = const Color(0xFFA0845C).withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(bonePath, outlinePaint);

    // Shimmer highlight on the shaft.
    final shimmerX = cx + cos(glowPhase) * shaftHalfW * 0.4;
    final shimmerY = cy + sin(glowPhase * 0.7) * shaftHalfLen * 0.2;
    final shimmerPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.40),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
            center: Offset(shimmerX, shimmerY), radius: shaftHalfW * 1.8),
      );
    canvas.drawCircle(
        Offset(shimmerX, shimmerY), shaftHalfW * 1.8, shimmerPaint);

    // Fracture lines along the bone shaft.
    if (crackProgress > 0.0) {
      _drawFractures(canvas, cx, cy, shaftHalfLen, shaftHalfW, crackProgress);
    }
  }

  /// Builds a classic dog-bone silhouette path (vertical orientation).
  Path _buildBonePath(double cx, double cy, double shaftHalfLen,
      double shaftHalfW, double knobR, double knobSpread) {
    final path = Path();

    // Top-left knob center.
    final tlx = cx - knobSpread;
    final tly = cy - shaftHalfLen;
    // Top-right knob center.
    final trx = cx + knobSpread;
    final try_ = cy - shaftHalfLen;
    // Bottom-left knob center.
    final blx = cx - knobSpread;
    final bly = cy + shaftHalfLen;
    // Bottom-right knob center.
    final brx = cx + knobSpread;
    final bry = cy + shaftHalfLen;

    // Draw using arcs for knobs connected by straight/curved shaft edges.
    // Start at top-left knob, go clockwise.

    // Top-left knob arc (sweeping from left side to inner).
    path.addOval(Rect.fromCircle(center: Offset(tlx, tly), radius: knobR));
    path.addOval(Rect.fromCircle(center: Offset(trx, try_), radius: knobR));
    path.addOval(Rect.fromCircle(center: Offset(blx, bly), radius: knobR));
    path.addOval(Rect.fromCircle(center: Offset(brx, bry), radius: knobR));

    // Shaft rectangle.
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: shaftHalfW * 2,
        height: shaftHalfLen * 2 + knobR * 0.5,
      ),
      Radius.circular(shaftHalfW * 0.3),
    ));

    // Top connector (fills gap between knobs at top).
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTRB(
          tlx, tly - knobR * 0.3, trx, tly + knobR * 0.3),
      Radius.circular(knobR * 0.2),
    ));

    // Bottom connector (fills gap between knobs at bottom).
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTRB(
          blx, bly - knobR * 0.3, brx, bly + knobR * 0.3),
      Radius.circular(knobR * 0.2),
    ));

    // Use PathFillType.evenOdd inverted — we want union, so keep default nonZero.
    path.fillType = PathFillType.nonZero;
    return path;
  }

  void _drawFractures(Canvas canvas, double cx, double cy,
      double shaftHalfLen, double shaftHalfW, double t) {
    final fracturePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final darkFracturePaint = Paint()
      ..color = const Color(0xFF5C3D1A).withValues(alpha: 0.8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Primary horizontal fracture across the shaft center.
    final mainLen = shaftHalfW * 1.2 * t;
    canvas.drawLine(
      Offset(cx - mainLen, cy),
      Offset(cx + mainLen, cy),
      darkFracturePaint,
    );
    canvas.drawLine(
      Offset(cx - mainLen, cy),
      Offset(cx + mainLen, cy),
      fracturePaint,
    );

    // Diagonal fractures branching up and down the shaft.
    if (t > 0.3) {
      final branchLen = shaftHalfLen * 0.4 * ((t - 0.3) / 0.7);
      // Upper-right diagonal.
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + shaftHalfW * 0.5, cy - branchLen),
        darkFracturePaint,
      );
      // Lower-left diagonal.
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx - shaftHalfW * 0.4, cy + branchLen * 0.8),
        darkFracturePaint,
      );
    }

    if (t > 0.6) {
      final branchLen = shaftHalfLen * 0.35 * ((t - 0.6) / 0.4);
      // Upper-left splintering.
      canvas.drawLine(
        Offset(cx, cy - shaftHalfLen * 0.15),
        Offset(cx - shaftHalfW * 0.6, cy - shaftHalfLen * 0.15 - branchLen),
        darkFracturePaint,
      );
      // Lower-right splintering.
      canvas.drawLine(
        Offset(cx, cy + shaftHalfLen * 0.1),
        Offset(cx + shaftHalfW * 0.7, cy + shaftHalfLen * 0.1 + branchLen),
        darkFracturePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_BonePainter old) =>
      crackProgress != old.crackProgress || glowPhase != old.glowPhase;
}

// --- Bone Fragment Particle ----------------------------------------------------

class _BoneFragment {
  Offset position;
  Offset velocity;
  double rotation;
  double rotationSpeed;
  double size;
  Color color;
  double opacity;

  _BoneFragment({
    required this.position,
    required this.velocity,
    required this.rotation,
    required this.rotationSpeed,
    required this.size,
    required this.color,
    this.opacity = 1.0, // ignore: unused_element_parameter
  });
}

class _FragmentPainter extends CustomPainter {
  final List<_BoneFragment> fragments;
  final double progress; // 0..1 for particle lifetime

  _FragmentPainter({required this.fragments, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final f in fragments) {
      final paint = Paint()
        ..color = f.color.withValues(alpha: f.opacity * (1.0 - progress));
      canvas.save();
      final dx = f.position.dx + f.velocity.dx * progress * 120;
      final dy = f.position.dy +
          f.velocity.dy * progress * 120 +
          progress * progress * 200; // gravity
      canvas.translate(dx, dy);
      canvas.rotate(f.rotation + f.rotationSpeed * progress * 6);

      // Draw irregular bone-chip shapes (jagged rectangles).
      final chipPath = Path()
        ..moveTo(-f.size * 0.5, -f.size * 0.2)
        ..lineTo(-f.size * 0.3, -f.size * 0.35)
        ..lineTo(f.size * 0.2, -f.size * 0.3)
        ..lineTo(f.size * 0.5, -f.size * 0.1)
        ..lineTo(f.size * 0.4, f.size * 0.25)
        ..lineTo(-f.size * 0.1, f.size * 0.35)
        ..lineTo(-f.size * 0.45, f.size * 0.15)
        ..close();
      canvas.drawPath(chipPath, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FragmentPainter old) => progress != old.progress;
}

// --- Reveal Overlay ------------------------------------------------------------

class MysteryBoneReveal extends StatefulWidget {
  final MysteryReward reward;
  final VoidCallback onDismiss;

  const MysteryBoneReveal({
    super.key,
    required this.reward,
    required this.onDismiss,
  });

  /// Show the mystery bone reveal as an overlay.
  static void show(BuildContext context, {required MysteryReward reward}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => MysteryBoneReveal(
        reward: reward,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }

  @override
  State<MysteryBoneReveal> createState() => _MysteryBoneRevealState();
}

class _MysteryBoneRevealState extends State<MysteryBoneReveal>
    with TickerProviderStateMixin {
  late final AnimationController _master;
  late final AnimationController _shimmer;
  late final List<_BoneFragment> _fragments;

  // Phase animations derived from master controller.
  late final Animation<double> _boneScale;
  late final Animation<double> _wobble;
  late final Animation<double> _crackProgress;
  late final Animation<double> _flashOpacity;
  late final Animation<double> _particleProgress;
  late final Animation<double> _rewardScale;
  late final Animation<double> _rewardOpacity;
  late final Animation<double> _dimOpacity;
  late final Animation<double> _dismissOpacity;

  @override
  void initState() {
    super.initState();

    _master = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _initFragments();
    _initAnimations();

    _master.forward();
    _master.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDismiss();
      }
    });
  }

  void _initFragments() {
    final rng = Random();
    _fragments = List.generate(20, (_) {
      final angle = rng.nextDouble() * 2 * pi;
      final speed = 1.0 + rng.nextDouble() * 3.0;
      return _BoneFragment(
        position: Offset.zero, // will be offset to center in build
        velocity: Offset(cos(angle) * speed, sin(angle) * speed - 2),
        rotation: rng.nextDouble() * 2 * pi,
        rotationSpeed: (rng.nextDouble() - 0.5) * 4,
        size: 6 + rng.nextDouble() * 10,
        color: Color.lerp(
          const Color(0xFFF5E6C8), // light cream
          const Color(0xFFBFA47A), // warm brown
          rng.nextDouble(),
        )!,
      );
    });
  }

  void _initAnimations() {
    // Phase 1: Bone appears (0-400ms) => 0.0-0.16
    _boneScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.0, 0.16, curve: Curves.elasticOut),
      ),
    );

    // Phase 2: Wobble (400-900ms) => 0.16-0.36
    _wobble = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.16, 0.36, curve: Curves.linear),
      ),
    );

    // Phase 3: Crack (360-440ms mapped) -- fractures appear during wobble end
    _crackProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.28, 0.44, curve: Curves.easeIn),
      ),
    );

    // Flash (900-1100ms) => 0.36-0.44
    _flashOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.9),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.9, end: 0.0),
        weight: 70,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.36, 0.48, curve: Curves.easeOut),
      ),
    );

    // Particles (900-1600ms) => 0.36-0.64
    _particleProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.36, 0.64, curve: Curves.easeOut),
      ),
    );

    // Phase 4: Reward reveal (1100-2000ms) => 0.44-0.80
    _rewardScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.44, 0.68, curve: Curves.elasticOut),
      ),
    );
    _rewardOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.44, 0.56, curve: Curves.easeIn),
      ),
    );

    // Dim background (0-400ms)
    _dimOpacity = Tween<double>(begin: 0.0, end: 0.75).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.0, 0.16, curve: Curves.easeOut),
      ),
    );

    // Phase 5: Dismiss fade (2000-2500ms) => 0.80-1.0
    _dismissOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.80, 1.0, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void dispose() {
    _master.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  IconData _rewardIcon() {
    switch (widget.reward.type) {
      case MysteryRewardType.bonusXp:
        return Icons.monetization_on_rounded;
      case MysteryRewardType.streakSaver:
        return Icons.shield_rounded;
      case MysteryRewardType.xpMultiplier:
        return Icons.bolt_rounded;
      case MysteryRewardType.rarityBoost:
        return Icons.auto_awesome_rounded;
      case MysteryRewardType.titleUnlock:
        return Icons.workspace_premium_rounded;
    }
  }

  Color _rewardColor() {
    switch (widget.reward.type) {
      case MysteryRewardType.bonusXp:
        return const Color(0xFFFFD700);
      case MysteryRewardType.streakSaver:
        return const Color(0xFF4FC3F7);
      case MysteryRewardType.xpMultiplier:
        return const Color(0xFFFF8F00);
      case MysteryRewardType.rarityBoost:
        return const Color(0xFFE040FB);
      case MysteryRewardType.titleUnlock:
        return const Color(0xFFFFD700);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: Listenable.merge([_master, _shimmer]),
      builder: (context, _) {
        // Wobble rotation: oscillating +-5 degrees, increasing frequency.
        final wobbleAngle = _wobble.value > 0 && _crackProgress.value < 1.0
            ? sin(_wobble.value * 8 * pi) *
                (5 * pi / 180) *
                (0.5 + _wobble.value * 0.5)
            : 0.0;

        final showBone = _crackProgress.value < 1.0;
        final showReward = _rewardOpacity.value > 0.0;

        return GestureDetector(
          onTap: () {
            if (_master.value > 0.6) {
              _master.forward(from: 0.80); // skip to dismiss
            }
          },
          child: Opacity(
            opacity: _dismissOpacity.value,
            child: Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  // Dim background.
                  Positioned.fill(
                    child: ColoredBox(
                      color:
                          Colors.black.withValues(alpha: _dimOpacity.value),
                    ),
                  ),

                  // Flash effect.
                  if (_flashOpacity.value > 0.01)
                    Positioned.fill(
                      child: ColoredBox(
                        color: const Color(0xFFFFD700)
                            .withValues(alpha: _flashOpacity.value),
                      ),
                    ),

                  // Bone fragment particles.
                  if (_particleProgress.value > 0.0 &&
                      _particleProgress.value < 1.0)
                    Center(
                      child: CustomPaint(
                        size: Size(size.width, size.height),
                        painter: _FragmentPainter(
                          fragments: _fragments.map((f) {
                            return _BoneFragment(
                              position: Offset(
                                size.width / 2 + f.position.dx,
                                size.height / 2 + f.position.dy,
                              ),
                              velocity: f.velocity,
                              rotation: f.rotation,
                              rotationSpeed: f.rotationSpeed,
                              size: f.size,
                              color: f.color,
                            );
                          }).toList(),
                          progress: _particleProgress.value,
                        ),
                      ),
                    ),

                  // Bone.
                  if (showBone)
                    Center(
                      child: Transform.rotate(
                        angle: wobbleAngle,
                        child: Transform.scale(
                          scale: _boneScale.value,
                          child: SizedBox(
                            width: 160,
                            height: 200,
                            child: CustomPaint(
                              painter: _BonePainter(
                                crackProgress: _crackProgress.value,
                                boneColor: const Color(0xFFF5E6C8),
                                glowColor: const Color(0xFFDEB887),
                                glowPhase: _shimmer.value * 2 * pi,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Reward reveal.
                  if (showReward)
                    Center(
                      child: Opacity(
                        opacity: _rewardOpacity.value,
                        child: Transform.scale(
                          scale: _rewardScale.value,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Icon with glow.
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _rewardColor()
                                          .withValues(alpha: 0.6),
                                      blurRadius: 30,
                                      spreadRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _rewardIcon(),
                                  size: 64,
                                  color: _rewardColor(),
                                ),
                              )
                                  .animate(
                                    onPlay: (c) => c.repeat(reverse: true),
                                  )
                                  .scaleXY(
                                    begin: 1.0,
                                    end: 1.08,
                                    duration: 800.ms,
                                    curve: Curves.easeInOut,
                                  ),
                              const SizedBox(height: 24),
                              // Reward text.
                              Text(
                                'MYSTERY REWARD!',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Colors.white.withValues(alpha: 0.7),
                                  letterSpacing: 3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.reward.displayText,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: _rewardColor(),
                                  shadows: [
                                    Shadow(
                                      color: _rewardColor()
                                          .withValues(alpha: 0.5),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
