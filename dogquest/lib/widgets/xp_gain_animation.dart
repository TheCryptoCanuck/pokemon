import 'dart:math';
import 'package:flutter/material.dart';

/// Full-screen XP gain celebration overlay with particle burst,
/// counting number, optional streak multiplier, and optional level-up.
///
/// Usage:
/// ```dart
/// XpGainAnimation.show(context, xp: 150, streakMultiplier: 1.5, didLevelUp: true, newLevel: 5);
/// ```
class XpGainAnimation {
  static void show(
    BuildContext context, {
    required int xp,
    double? streakMultiplier,
    bool didLevelUp = false,
    int? newLevel,
  }) {
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _XpGainOverlay(
        xp: xp,
        streakMultiplier: streakMultiplier,
        didLevelUp: didLevelUp,
        newLevel: newLevel,
        onDone: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

class _XpGainOverlay extends StatefulWidget {
  final int xp;
  final double? streakMultiplier;
  final bool didLevelUp;
  final int? newLevel;
  final VoidCallback onDone;

  const _XpGainOverlay({
    required this.xp,
    this.streakMultiplier,
    required this.didLevelUp,
    this.newLevel,
    required this.onDone,
  });

  @override
  State<_XpGainOverlay> createState() => _XpGainOverlayState();
}

class _XpGainOverlayState extends State<_XpGainOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _countController;
  late final AnimationController _levelUpController;
  late final Animation<double> _overlayOpacity;
  late final Animation<int> _countUp;
  late final List<_Particle> _particles;
  final _random = Random();

  @override
  void initState() {
    super.initState();

    // Generate burst particles
    _particles = List.generate(24, (_) => _Particle(_random));

    // Main controller drives the full lifecycle
    final totalDuration = widget.didLevelUp ? 3500 : 2000;
    _mainController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalDuration),
    );

    _overlayOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_mainController);

    // Count-up controller
    _countController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _countUp = IntTween(begin: 0, end: widget.xp).animate(
      CurvedAnimation(parent: _countController, curve: Curves.easeOut),
    );

    // Level up golden glow controller
    _levelUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    _mainController.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    _countController.forward();

    if (widget.didLevelUp) {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) _levelUpController.forward();
    }

    _mainController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        widget.onDone();
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _countController.dispose();
    _levelUpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: Listenable.merge(
          [_mainController, _countController, _levelUpController]),
      builder: (context, _) {
        final levelUpProgress = _levelUpController.value;
        final showLevelUp = widget.didLevelUp && levelUpProgress > 0;

        return IgnorePointer(
          child: Opacity(
            opacity: _overlayOpacity.value,
            child: Stack(
              children: [
                // Background dim with optional golden glow for level-up
                Container(
                  width: size.width,
                  height: size.height,
                  color: showLevelUp
                      ? Color.lerp(
                          Colors.black.withValues(alpha: 0.6),
                          Colors.amber.withValues(alpha: 0.15),
                          levelUpProgress,
                        )
                      : Colors.black.withValues(alpha: 0.6),
                ),

                // Particle burst
                ..._particles.map((p) {
                  final progress = _mainController.value;
                  final particleOpacity = (1.0 - progress).clamp(0.0, 1.0);
                  final distance = p.speed * progress * size.width * 0.5;
                  final dx = cos(p.angle) * distance;
                  final dy = sin(p.angle) * distance;

                  return Positioned(
                    left: size.width / 2 + dx - 4,
                    top: size.height / 2 - 40 + dy - 4,
                    child: Opacity(
                      opacity: (particleOpacity * p.opacity).clamp(0.0, 1.0),
                      child: Container(
                        width: p.size,
                        height: p.size,
                        decoration: BoxDecoration(
                          color: p.color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: p.color.withValues(alpha: 0.6),
                              blurRadius: 6,
                            ),
                          ],
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
                      if (showLevelUp) ...[
                        // Level up text
                        Opacity(
                          opacity: levelUpProgress,
                          child: Transform.scale(
                            scale: 0.5 + levelUpProgress * 0.5,
                            child: Text(
                              'LEVEL UP!',
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                color: Colors.amber,
                                letterSpacing: 4,
                                shadows: [
                                  Shadow(
                                    color: Colors.amber.withValues(alpha: 0.8),
                                    blurRadius: 30,
                                  ),
                                  Shadow(
                                    color: Colors.orange.withValues(alpha: 0.6),
                                    blurRadius: 60,
                                  ),
                                ],
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                        if (widget.newLevel != null)
                          Opacity(
                            opacity: levelUpProgress,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Level ${widget.newLevel}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                      ],

                      // XP count
                      Text(
                        '+${_countUp.value} XP',
                        style: TextStyle(
                          fontSize: showLevelUp ? 32 : 48,
                          fontWeight: FontWeight.w900,
                          color: Colors.amber,
                          letterSpacing: 2,
                          shadows: [
                            Shadow(
                              color: Colors.amber.withValues(alpha: 0.6),
                              blurRadius: 20,
                            ),
                          ],
                          decoration: TextDecoration.none,
                        ),
                      ),

                      // Streak multiplier
                      if (widget.streakMultiplier != null &&
                          widget.streakMultiplier! > 1.0)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '\u{1F525}',
                                  style: TextStyle(
                                      fontSize: 20,
                                      decoration: TextDecoration.none),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${widget.streakMultiplier!.toStringAsFixed(1)}x',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
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
    );
  }
}

/// A single burst particle with random properties.
class _Particle {
  final double angle;
  final double speed;
  final double size;
  final double opacity;
  final Color color;

  _Particle(Random r)
      : angle = r.nextDouble() * 2 * pi,
        speed = 0.4 + r.nextDouble() * 0.8,
        size = 3.0 + r.nextDouble() * 6.0,
        opacity = 0.5 + r.nextDouble() * 0.5,
        color = [
          Colors.amber,
          Colors.orange,
          Colors.yellow,
          Colors.amberAccent,
          Colors.white,
        ][r.nextInt(5)];
}
