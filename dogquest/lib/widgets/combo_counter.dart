import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dogquest/services/combo_service.dart';

/// Compact animated combo counter that appears when combo >= 2.
///
/// Shows the combo count, XP multiplier, and a circular countdown timer.
/// Pulsing glow intensifies with higher combo; countdown turns red below 10s.
///
/// Usage:
/// ```dart
/// const ComboCounter()
/// ```
class ComboCounter extends ConsumerStatefulWidget {
  const ComboCounter({super.key});

  @override
  ConsumerState<ComboCounter> createState() => _ComboCounterState();
}

class _ComboCounterState extends ConsumerState<ComboCounter>
    with TickerProviderStateMixin {
  Timer? _tickTimer;
  late AnimationController _pulseController;
  late AnimationController _bounceController;
  int _previousCount = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Tick every minute for countdown updates (24h window).
    _tickTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _pulseController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final combo = ref.watch(comboProvider);

    // Trigger bounce when count increases.
    if (combo.count > _previousCount && combo.count >= 2) {
      _bounceController.forward(from: 0.0);
    }
    _previousCount = combo.count;

    // Hide when combo is inactive or below threshold.
    if (!combo.isActive || combo.count < 2) {
      return const SizedBox.shrink();
    }

    final secondsLeft = combo.secondsRemaining;
    final progress = secondsLeft / 86400.0; // 24 hours
    final isUrgent = secondsLeft <= 3600; // last hour

    // Glow intensity scales with combo count (0.0 to 1.0).
    final glowIntensity = ((combo.count - 1) / 5.0).clamp(0.0, 1.0);

    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 1.15).animate(
        CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
      ),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulseValue = _pulseController.value * glowIntensity;
          return _buildComboWidget(
            combo: combo,
            progress: progress,
            isUrgent: isUrgent,
            secondsLeft: secondsLeft,
            pulseValue: pulseValue,
            glowIntensity: glowIntensity,
          );
        },
      ),
    );
  }

  Widget _buildComboWidget({
    required ComboState combo,
    required double progress,
    required bool isUrgent,
    required int secondsLeft,
    required double pulseValue,
    required double glowIntensity,
  }) {
    final glowColor = isUrgent ? Colors.red : Colors.amber;
    final glowSpread = 4.0 + pulseValue * 12.0;
    final glowBlur = 8.0 + pulseValue * 16.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.3 + pulseValue * 0.4),
            blurRadius: glowBlur,
            spreadRadius: glowSpread,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Circular countdown ring.
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3.5,
              backgroundColor: const Color(0xFF1A2A1A),
              valueColor: AlwaysStoppedAnimation<Color>(
                isUrgent ? Colors.red : Colors.amber,
              ),
            ),
          )
              .animate(
                target: isUrgent ? 1.0 : 0.0,
              )
              .scaleXY(
                begin: 1.0,
                end: 1.05,
                duration: 500.ms,
                curve: Curves.easeInOut,
              )
              .then()
              .scaleXY(
                begin: 1.05,
                end: 1.0,
                duration: 500.ms,
                curve: Curves.easeInOut,
              ),
          // Pill content.
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.amber,
                  Colors.deepOrange,
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Combo count.
                Text(
                  '${combo.count}x',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    shadows: [
                      Shadow(
                        blurRadius: 4,
                        color: Colors.black54,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'COMBO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                // Multiplier badge.
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A0F0A).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${combo.multiplier}x XP',
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
