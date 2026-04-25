import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants.dart';

/// Prominently displays the most recently unlocked achievement, or the
/// next closest achievement with a progress bar if nothing was unlocked
/// recently.
class AchievementShowcase extends StatelessWidget {
  /// Achievement identifier key (e.g. 'first_dog').
  final String achievementKey;

  /// Large emoji representing the achievement.
  final String emoji;

  /// Achievement title text.
  final String title;

  /// Achievement description text.
  final String description;

  /// When the achievement was unlocked. Null means it is still locked
  /// and will be shown as "next up" with a progress indicator.
  final DateTime? unlockedDate;

  /// Progress toward unlocking (0.0 to 1.0). Only used when
  /// [unlockedDate] is null.
  final double progress;

  const AchievementShowcase({
    super.key,
    required this.achievementKey,
    required this.emoji,
    required this.title,
    required this.description,
    this.unlockedDate,
    this.progress = 0.0,
  });

  String get _timeAgoText {
    if (unlockedDate == null) return '';
    final now = DateTime.now();
    final diff = now.difference(unlockedDate!);

    if (diff.inDays == 0) return 'Unlocked today!';
    if (diff.inDays == 1) return 'Unlocked yesterday';
    if (diff.inDays < 7) return 'Unlocked ${diff.inDays} days ago';
    if (diff.inDays < 30) {
      final weeks = diff.inDays ~/ 7;
      return 'Unlocked $weeks week${weeks > 1 ? 's' : ''} ago';
    }
    final months = diff.inDays ~/ 30;
    return 'Unlocked $months month${months > 1 ? 's' : ''} ago';
  }

  bool get _isUnlocked => unlockedDate != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isUnlocked
              ? Colors.amber.withValues(alpha: 0.4)
              : Colors.white12,
        ),
        boxShadow: _isUnlocked
            ? [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.1),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header label
          Text(
            _isUnlocked ? 'LATEST ACHIEVEMENT' : 'NEXT ACHIEVEMENT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: _isUnlocked ? Colors.amber.shade300 : Colors.white38,
            ),
          ),
          const SizedBox(height: 14),

          // Emoji with glow
          _EmojiGlow(
            emoji: emoji,
            isUnlocked: _isUnlocked,
          ),
          const SizedBox(height: 14),

          // Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          // Description
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white54,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),

          // Timestamp or progress bar
          if (_isUnlocked)
            Text(
              _timeAgoText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.amber.shade300,
              ),
            )
          else ...[
            const SizedBox(height: 4),
            _ProgressBar(progress: progress),
            const SizedBox(height: 6),
            Text(
              '${(progress * 100).round()}% complete',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white38,
              ),
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.08, end: 0, duration: 500.ms, curve: Curves.easeOut);
  }
}

/// Large emoji with an optional golden glow for unlocked achievements.
class _EmojiGlow extends StatelessWidget {
  final String emoji;
  final bool isUnlocked;

  const _EmojiGlow({required this.emoji, required this.isUnlocked});

  @override
  Widget build(BuildContext context) {
    Widget emojiWidget = Text(
      emoji,
      style: const TextStyle(fontSize: 48),
    );

    if (isUnlocked) {
      emojiWidget = Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.35),
              blurRadius: 24,
              spreadRadius: 4,
            ),
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.15),
              blurRadius: 40,
              spreadRadius: 8,
            ),
          ],
        ),
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 48),
        ),
      ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.06, 1.06),
            duration: 1500.ms,
            curve: Curves.easeInOut,
          );
    } else {
      // Locked: desaturated look via reduced opacity wrapper
      emojiWidget = Opacity(
        opacity: 0.5,
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 48),
        ),
      );
    }

    return emojiWidget;
  }
}

/// Animated horizontal progress bar with green-to-amber gradient.
class _ProgressBar extends StatelessWidget {
  final double progress;

  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 8,
        width: double.infinity,
        child: Stack(
          children: [
            // Track
            Container(color: bgDeep),
            // Fill
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFD4874E),
                      Colors.amber.shade600,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ).animate().scaleX(
                  begin: 0.0,
                  end: 1.0,
                  duration: 800.ms,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.centerLeft,
                ),
          ],
        ),
      ),
    );
  }
}
