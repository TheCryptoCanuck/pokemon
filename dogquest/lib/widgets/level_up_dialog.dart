import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants.dart';
import '../services/player_service.dart';

/// Full-screen level-up celebration dialog.
class LevelUpDialog extends StatelessWidget {
  final int newLevel;
  final String newTitle;

  const LevelUpDialog({
    super.key,
    required this.newLevel,
    required this.newTitle,
  });

  /// Show the level-up dialog if a level change occurred.
  static void showIfLeveledUp(
      BuildContext context, int oldLevel, PlayerState newState) {
    if (newState.level > oldLevel) {
      HapticFeedback.heavyImpact();
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => LevelUpDialog(
          newLevel: newState.level,
          newTitle: newState.title,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(28),
          border:
              Border.all(color: Colors.amber.withValues(alpha: 0.6), width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.amber.withValues(alpha: 0.3),
                blurRadius: 40,
                spreadRadius: 8),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated star burst
            const Text('⭐', style: TextStyle(fontSize: 72))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.2, 1.2),
                    duration: 800.ms)
                .then()
                .shimmer(
                    duration: 1200.ms,
                    color: Colors.amber.withValues(alpha: 0.6)),
            const SizedBox(height: 16),

            // LEVEL UP text
            const Text(
              'LEVEL UP!',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
                letterSpacing: 3,
              ),
            ).animate().fadeIn().scale(
                begin: const Offset(0.5, 0.5),
                curve: Curves.elasticOut,
                duration: 600.ms),
            const SizedBox(height: 12),

            // Level number
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.amber.withValues(alpha: 0.2),
                  Colors.orange.withValues(alpha: 0.15),
                ]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
              ),
              child: Text(
                'Level $newLevel',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3),
            const SizedBox(height: 16),

            // New title
            Text(
              newTitle,
              style: const TextStyle(
                fontSize: 20,
                color: Colors.amber,
                fontWeight: FontWeight.w600,
              ),
            ).animate().fadeIn(delay: 500.ms),
            const SizedBox(height: 8),

            // Motivational text
            Text(
              _motivationalText(newLevel),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ).animate().fadeIn(delay: 600.ms),
            const SizedBox(height: 28),

            // Continue button
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Continue Doging!'),
            ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2),
          ],
        ),
      ),
    );
  }

  static String _motivationalText(int level) {
    if (level >= 30) return 'You are a true master of dog breeds!';
    if (level >= 20) return 'Your knowledge of dogs is truly impressive!';
    if (level >= 15) return 'Every dog wags its tail for your dedication!';
    if (level >= 10) return 'Your kennel grows ever more magnificent!';
    if (level >= 5) return 'You\'re becoming a skilled dog identifier!';
    return 'Every journey starts with a single paw print!';
  }
}
