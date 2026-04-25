import 'package:flutter/material.dart';

/// Animated streak display with fire effect that intensifies with streak length.
///
/// Compact enough to fit in a Row. Fire intensity scales from subtle at 1
/// to blazing at 7+. Shows XP multiplier when above 1x.
///
/// Usage:
/// ```dart
/// Row(children: [
///   StreakFireWidget(streak: 5, xpMultiplier: 1.5),
///   // other widgets
/// ])
/// ```
class StreakFireWidget extends StatefulWidget {
  final int streak;
  final double xpMultiplier;

  const StreakFireWidget({
    super.key,
    required this.streak,
    this.xpMultiplier = 1.0,
  });

  @override
  State<StreakFireWidget> createState() => _StreakFireWidgetState();
}

class _StreakFireWidgetState extends State<StreakFireWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Normalized intensity from 0.0 (streak=0) to 1.0 (streak>=7).
  double get _intensity => (widget.streak / 7.0).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.streak <= 0) return const SizedBox.shrink();

    final intensity = _intensity;
    final glowRadius = 8.0 + intensity * 24.0;
    final glowOpacity = 0.15 + intensity * 0.35;

    // Fire color gradient: dim orange -> bright amber/white-hot
    final fireColor = Color.lerp(
      Colors.deepOrange,
      Colors.amber,
      intensity,
    )!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = 0.85 + _controller.value * 0.15 * intensity;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: fireColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: fireColor.withValues(alpha: 0.3 + intensity * 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: fireColor.withValues(
                    alpha: glowOpacity * _controller.value),
                blurRadius: glowRadius,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated fire stack
              SizedBox(
                width: 24,
                height: 28,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer fire glow (larger, dimmer)
                    if (intensity > 0.3)
                      Positioned(
                        bottom: 0,
                        child: Transform.scale(
                          scale: pulse * (0.7 + intensity * 0.4),
                          child: Text(
                            '\u{1F525}',
                            style: TextStyle(
                              fontSize: 14 + intensity * 6,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                    // Main fire emoji
                    Positioned(
                      bottom: 0,
                      child: Transform.scale(
                        scale: pulse,
                        child: Text(
                          '\u{1F525}',
                          style: TextStyle(
                            fontSize: 18 + intensity * 4,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),

              // Streak number
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.streak}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: fireColor,
                      height: 1.0,
                      shadows: intensity > 0.5
                          ? [
                              Shadow(
                                color: fireColor.withValues(alpha: 0.6),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  // XP multiplier
                  if (widget.xpMultiplier > 1.0)
                    Text(
                      '${widget.xpMultiplier.toStringAsFixed(1)}x',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: fireColor.withValues(alpha: 0.8),
                        height: 1.1,
                        decoration: TextDecoration.none,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
