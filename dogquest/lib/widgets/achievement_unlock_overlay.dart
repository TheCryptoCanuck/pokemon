import 'dart:math';
import 'package:flutter/material.dart';
import 'package:dogquest/constants.dart';

/// Full-screen achievement unlock celebration overlay with confetti,
/// bouncing emoji, and gold header text.
///
/// Usage:
/// ```dart
/// AchievementUnlockOverlay.show(
///   context,
///   achievementKey: 'first_dog',
///   emoji: '\u{1F436}',
///   title: 'First Dog',
///   description: 'You identified your first dog!',
/// );
/// ```
class AchievementUnlockOverlay {
  static void show(
    BuildContext context, {
    required String achievementKey,
    required String emoji,
    required String title,
    required String description,
  }) {
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _AchievementOverlay(
        achievementKey: achievementKey,
        emoji: emoji,
        title: title,
        description: description,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

class _AchievementOverlay extends StatefulWidget {
  final String achievementKey;
  final String emoji;
  final String title;
  final String description;
  final VoidCallback onDismiss;

  const _AchievementOverlay({
    required this.achievementKey,
    required this.emoji,
    required this.title,
    required this.description,
    required this.onDismiss,
  });

  @override
  State<_AchievementOverlay> createState() => _AchievementOverlayState();
}

class _AchievementOverlayState extends State<_AchievementOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _confettiController;
  late final Animation<double> _bgOpacity;
  late final Animation<double> _emojiScale;
  late final List<_ConfettiParticle> _confetti;
  final _random = Random();
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();

    _confetti = List.generate(40, (_) => _ConfettiParticle(_random));

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _bgOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 75),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 15),
    ]).animate(_mainController);

    // Emoji bounces in with elastic curve
    _emojiScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.85), weight: 8),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.05), weight: 7),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 5),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 65),
    ]).animate(CurvedAnimation(parent: _mainController, curve: Curves.easeOut));

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _mainController.forward();
    _confettiController.forward();

    _mainController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _dismiss();
    });
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    widget.onDismiss();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: _dismiss,
      child: AnimatedBuilder(
        animation: Listenable.merge([_mainController, _confettiController]),
        builder: (context, _) {
          final progress = _mainController.value;
          final textOpacity = ((progress - 0.15) / 0.15).clamp(0.0, 1.0);
          final descOpacity = ((progress - 0.25) / 0.15).clamp(0.0, 1.0);

          return Opacity(
            opacity: _bgOpacity.value,
            child: Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  // Semi-transparent background
                  Container(
                    width: size.width,
                    height: size.height,
                    color: bgDeep.withValues(alpha: 0.85),
                  ),

                  // Confetti particles
                  ..._confetti.map((p) {
                    final t = _confettiController.value;
                    final fallProgress = t * p.speed;
                    final x = p.startX * size.width +
                        sin(fallProgress * pi * 2 * p.wobbleFreq) * p.wobbleAmp;
                    final y = -20 + fallProgress * size.height * 1.2;
                    final rotation = fallProgress * p.rotationSpeed * pi * 2;

                    return Positioned(
                      left: x,
                      top: y,
                      child: Opacity(
                        opacity: (1.0 - t * 0.5).clamp(0.0, 1.0),
                        child: Transform.rotate(
                          angle: rotation,
                          child: Container(
                            width: p.width,
                            height: p.height,
                            decoration: BoxDecoration(
                              color: p.color,
                              borderRadius:
                                  BorderRadius.circular(p.isCircle ? 10 : 2),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  // Center content
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Emoji with bounce scale
                        Transform.scale(
                          scale: _emojiScale.value,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.amber.withValues(alpha: 0.1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withValues(alpha: 0.3),
                                  blurRadius: 40,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                widget.emoji,
                                style: const TextStyle(
                                  fontSize: 56,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // "Achievement Unlocked!" header
                        Opacity(
                          opacity: textOpacity,
                          child: Text(
                            'Achievement Unlocked!',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.amber,
                              letterSpacing: 1.5,
                              shadows: [
                                Shadow(
                                  color: Colors.amber.withValues(alpha: 0.5),
                                  blurRadius: 20,
                                ),
                              ],
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Achievement title
                        Opacity(
                          opacity: textOpacity,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Description
                        Opacity(
                          opacity: descOpacity,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              widget.description,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.white70,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Tap to dismiss hint
                        Opacity(
                          opacity: descOpacity * 0.5,
                          child: const Text(
                            'Tap to continue',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white38,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ConfettiParticle {
  final double startX;
  final double speed;
  final double wobbleFreq;
  final double wobbleAmp;
  final double rotationSpeed;
  final double width;
  final double height;
  final bool isCircle;
  final Color color;

  _ConfettiParticle(Random r)
      : startX = r.nextDouble(),
        speed = 0.6 + r.nextDouble() * 0.6,
        wobbleFreq = 1.0 + r.nextDouble() * 3.0,
        wobbleAmp = 10.0 + r.nextDouble() * 30.0,
        rotationSpeed = 0.5 + r.nextDouble() * 2.0,
        width = 4.0 + r.nextDouble() * 8.0,
        height = r.nextBool()
            ? (4.0 + r.nextDouble() * 8.0)
            : (8.0 + r.nextDouble() * 14.0),
        isCircle = r.nextDouble() < 0.3,
        color = [
          Colors.amber,
          Colors.orange,
          Colors.yellow,
          Colors.green,
          Colors.blue,
          Colors.red,
          Colors.purple,
          Colors.pink,
        ][r.nextInt(8)];
}
