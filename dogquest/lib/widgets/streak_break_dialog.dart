import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:dogquest/constants.dart';

/// Dialog shown when a user's streak was broken or saved by a streak saver.
///
/// Auto-dismisses after 5 seconds. Dismissible by tapping the button or
/// tapping outside the dialog.
class StreakBreakDialog extends StatefulWidget {
  /// The old streak value that was lost (only meaningful when [wasSaved] is false).
  final int lostStreak;

  /// Whether a streak saver was consumed to preserve the streak.
  final bool wasSaved;

  /// The current streak value (after the save, if applicable).
  final int currentStreak;

  const StreakBreakDialog({
    super.key,
    required this.lostStreak,
    required this.wasSaved,
    required this.currentStreak,
  });

  /// Shows the streak break/save dialog with auto-dismiss after 5 seconds.
  static Future<void> show(
    BuildContext context, {
    required int lostStreak,
    required bool wasSaved,
    required int currentStreak,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) => StreakBreakDialog(
        lostStreak: lostStreak,
        wasSaved: wasSaved,
        currentStreak: currentStreak,
      ),
    );
  }

  @override
  State<StreakBreakDialog> createState() => _StreakBreakDialogState();
}

class _StreakBreakDialogState extends State<StreakBreakDialog> {
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _autoDismissTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: widget.wasSaved
                ? Colors.amber.withValues(alpha: 0.4)
                : Colors.white12,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.wasSaved
                  ? Colors.amber.withValues(alpha: 0.15)
                  : Colors.black38,
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: widget.wasSaved ? _buildSavedContent() : _buildBrokenContent(),
      ),
    ).animate().fadeIn(duration: 300.ms).scale(
          begin: const Offset(0.85, 0.85),
          end: const Offset(1.0, 1.0),
          duration: 350.ms,
          curve: Curves.easeOutBack,
        );
  }

  Widget _buildBrokenContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Broken chain icon
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withValues(alpha: 0.12),
          ),
          child: const Icon(
            Icons.link_off_rounded,
            color: Colors.redAccent,
            size: 36,
          ),
        )
            .animate()
            .shake(duration: 600.ms, delay: 200.ms, hz: 3)
            .then()
            .fadeIn(),
        const SizedBox(height: 20),
        Text(
          'Your ${widget.lostStreak}-day streak ended',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'No worries -- every champion starts fresh.\nGet back out there and build a new one!',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 14,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              "Let's Go!",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSavedContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Shield / save icon with glow
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.amber.withValues(alpha: 0.15),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.25),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.shield_rounded,
            color: Colors.amber,
            size: 36,
          ),
        )
            .animate()
            .scale(
              begin: const Offset(0.5, 0.5),
              end: const Offset(1.0, 1.0),
              duration: 400.ms,
              curve: Curves.easeOutBack,
            )
            .then()
            .shimmer(
              duration: 1200.ms,
              color: Colors.amber.withValues(alpha: 0.3),
            ),
        const SizedBox(height: 20),
        const Text(
          'Streak Saved!',
          style: TextStyle(
            color: Colors.amber,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Your ${widget.currentStreak}-day streak lives on!\nA streak saver kept you in the game.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 14,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'Awesome!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
