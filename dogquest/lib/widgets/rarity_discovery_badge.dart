import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:dogquest/constants.dart';

/// A compact badge showing how exclusive a dog discovery is,
/// creating FOMO through simulated rarity percentages.
///
/// Displayed in the dog-found dialog after identification.
class RarityDiscoveryBadge extends StatelessWidget {
  final Rarity rarity;
  final String dogName;
  final int totalPlayers;

  const RarityDiscoveryBadge({
    super.key,
    required this.rarity,
    required this.dogName,
    this.totalPlayers = 1000,
  });

  /// Deterministic percentages per rarity tier.
  static const _percentages = <Rarity, int>{
    Rarity.common: 78,
    Rarity.uncommon: 34,
    Rarity.rare: 12,
    Rarity.legendary: 3,
    Rarity.unknown: 1,
  };

  String get _text {
    final pct = _percentages[rarity] ?? 50;
    switch (rarity) {
      case Rarity.common:
        return 'Found by $pct% of players';
      case Rarity.uncommon:
        return 'Found by $pct% of players';
      case Rarity.rare:
        return 'Only $pct% of players have found this!';
      case Rarity.legendary:
        return 'Less than $pct% of players have found this!';
      case Rarity.unknown:
        return 'No other player has recorded this!';
    }
  }

  Color get _textColor {
    switch (rarity) {
      case Rarity.common:
        return const Color(0xFFD4874E); // green
      case Rarity.uncommon:
        return const Color(0xFF42A5F5); // blue
      case Rarity.rare:
        return const Color(0xFFAB47BC); // purple
      case Rarity.legendary:
        return const Color(0xFFFFD54F); // gold
      case Rarity.unknown:
        return const Color(0xFFCE93D8); // light purple
    }
  }

  bool get _useShimmer => rarity == Rarity.rare || rarity == Rarity.legendary;

  bool get _useGlow => rarity == Rarity.legendary;

  @override
  Widget build(BuildContext context) {
    final color = _textColor;

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.people_outline, color: color, size: 16),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            _text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    // Wrap in shimmer for rare+ tiers
    if (_useShimmer) {
      content = Shimmer.fromColors(
        baseColor: color,
        highlightColor: Colors.white,
        period: const Duration(milliseconds: 2000),
        child: content,
      );
    }

    // Add glow container for legendary
    if (_useGlow) {
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.25),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: content,
      );
    } else {
      content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: content,
      );
    }

    return content.animate().fadeIn(delay: 300.ms, duration: 400.ms);
  }
}
