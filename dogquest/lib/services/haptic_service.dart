import 'package:flutter/services.dart';

/// Static utility for haptic feedback at key game moments.
///
/// Provides single-tap feedback (light/medium/heavy/selection) and
/// multi-step patterns for celebrations, achievements, and combos.
class HapticService {
  static void light() => HapticFeedback.lightImpact();
  static void medium() => HapticFeedback.mediumImpact();
  static void heavy() => HapticFeedback.heavyImpact();
  static void selection() => HapticFeedback.selectionClick();

  /// Celebratory haptic pattern: light-pause-medium-pause-heavy.
  static Future<void> celebration() async {
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.heavyImpact();
  }

  /// Double-tap feel for achievements.
  static Future<void> achievement() async {
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 150));
    HapticFeedback.heavyImpact();
  }

  /// Rapid succession for combo — pulses scale with [count] (capped at 5).
  static Future<void> combo(int count) async {
    for (int i = 0; i < count.clamp(1, 5); i++) {
      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 60));
    }
  }
}
