import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants.dart';
import '../models/bird.dart';
import '../services/identification_service.dart';
import 'network_bird_image.dart';

class BirdFoundDialog extends StatelessWidget {
  final Bird bird;
  final double confidence;
  final String source;
  final List<IdentificationResult> alternatives;
  final bool alreadyOwned;
  final VoidCallback onAdd;
  final ValueChanged<IdentificationResult>? onSelectAlternative;

  const BirdFoundDialog({
    super.key,
    required this.bird,
    this.confidence = 1.0,
    this.source = 'mock',
    this.alternatives = const [],
    this.alreadyOwned = false,
    required this.onAdd,
    this.onSelectAlternative,
  });

  bool get _isSpecial => bird.rarity == Rarity.rare || bird.rarity == Rarity.legendary;

  @override
  Widget build(BuildContext context) {
    final isUnknown = bird.rarity == Rarity.unknown;
    final isMock = source == 'mock';
    final confidencePct = (confidence * 100).round();

    // Haptic for rare/legendary finds
    if (_isSpecial) {
      HapticFeedback.heavyImpact();
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(24),
          border: _isSpecial
              ? Border.all(color: bird.rarity.color.withOpacity(0.8), width: 2)
              : null,
          boxShadow: _isSpecial
              ? [BoxShadow(color: bird.rarity.color.withOpacity(0.3), blurRadius: 30, spreadRadius: 5)]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Special header for rare/legendary, standard for others
                if (bird.rarity == Rarity.legendary)
                  _legendaryHeader(isMock, confidencePct)
                else if (bird.rarity == Rarity.rare)
                  _rareHeader(isMock, confidencePct)
                else
                  _standardHeader(isMock, confidencePct),
                const SizedBox(height: 12),

                // Bird name with shimmer for special finds
                Text(
                  isUnknown ? '🔭 ${bird.name}' : bird.name,
                  style: TextStyle(
                    color: _isSpecial ? bird.rarity.color : (isUnknown ? bird.rarity.color : Colors.amber),
                    fontSize: _isSpecial ? 26 : 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 100.ms)
                  .then()
                  .shimmer(duration: _isSpecial ? 1500.ms : 0.ms, color: bird.rarity.color.withOpacity(0.3)),
                Text(
                  bird.scientificName,
                  style: const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 12),

                // Bird image with dramatic scaling for special finds
                if (isUnknown)
                  Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: bird.rarity.color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: bird.rarity.color.withOpacity(0.4)),
                    ),
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('❓', style: TextStyle(fontSize: 56)),
                        const SizedBox(height: 6),
                        Text('Not in our database yet',
                            style: TextStyle(color: bird.rarity.color, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ).animate().fadeIn(delay: 200.ms)
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: NetworkBirdImage(url: bird.imageUrl, height: 220),
                  )
                      .animate()
                      .fadeIn(delay: 200.ms)
                      .scale(
                        begin: _isSpecial ? const Offset(0.8, 0.8) : const Offset(0.95, 0.95),
                        duration: _isSpecial ? 600.ms : 300.ms,
                        curve: _isSpecial ? Curves.elasticOut : Curves.easeOut,
                      ),
                const SizedBox(height: 12),

                // Lore
                Text(bird.lore, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),

                // XP display — bigger for special birds
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: _isSpecial ? 16 : 8,
                    vertical: _isSpecial ? 8 : 4,
                  ),
                  decoration: _isSpecial
                      ? BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withOpacity(0.3)),
                        )
                      : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bolt, color: Colors.amber, size: _isSpecial ? 22 : 16),
                      Text(
                        ' +${bird.xp} XP',
                        style: TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: _isSpecial ? 18 : 14,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms),

                // Low confidence hint
                if (!isMock && confidence < 0.5) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Low confidence — check alternatives below',
                    style: TextStyle(color: Colors.orange, fontSize: 11),
                  ),
                ],

                if (alreadyOwned) ...[
                  const SizedBox(height: 8),
                  const Text('Already in your aviary', style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],

                // Alternatives section
                if (alternatives.isNotEmpty && onSelectAlternative != null) ...[
                  const SizedBox(height: 14),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 6),
                  const Text('Could also be:', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  const SizedBox(height: 6),
                  ...alternatives.map((alt) => _AlternativeChip(
                    result: alt,
                    onTap: () => onSelectAlternative!(alt),
                  )),
                ],

                const SizedBox(height: 16),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white54),
                        child: Text(alreadyOwned ? 'OK' : 'Skip'),
                      ),
                    ),
                    if (!alreadyOwned) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            Navigator.pop(context);
                            onAdd();
                          },
                          child: const Text('Add to Aviary'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _legendaryHeader(bool isMock, int confidencePct) {
    return Column(
      children: [
        const Text('✨🏆✨', style: TextStyle(fontSize: 32))
            .animate(onPlay: (c) => c.repeat())
            .shimmer(duration: 2000.ms, color: Colors.amber.withOpacity(0.8)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.amber.withOpacity(0.3),
                  Colors.orange.withOpacity(0.2),
                  Colors.amber.withOpacity(0.3),
                ]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber),
              ),
              child: const Text(
                'LEGENDARY!',
                style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.5),
              ),
            ).animate().fadeIn().scale()
                .then()
                .shimmer(delay: 500.ms, duration: 1500.ms, color: Colors.amber.withOpacity(0.4)),
            if (!isMock) ...[
              const SizedBox(width: 8),
              _confidenceBadge(confidencePct),
            ],
          ],
        ),
      ],
    );
  }

  Widget _rareHeader(bool isMock, int confidencePct) {
    return Column(
      children: [
        const Text('💎', style: TextStyle(fontSize: 36))
            .animate().fadeIn().scale(begin: const Offset(0.5, 0.5), curve: Curves.elasticOut),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF2196F3)),
              ),
              child: const Text(
                'RARE FIND!',
                style: TextStyle(color: Color(0xFF2196F3), fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2),
              ),
            ).animate().fadeIn().scale(),
            if (!isMock) ...[
              const SizedBox(width: 8),
              _confidenceBadge(confidencePct),
            ],
          ],
        ),
      ],
    );
  }

  Widget _standardHeader(bool isMock, int confidencePct) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: bird.rarity.color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: bird.rarity.color),
          ),
          child: Text(
            bird.rarity.label,
            style: TextStyle(color: bird.rarity.color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        if (!isMock) ...[
          const SizedBox(width: 8),
          _confidenceBadge(confidencePct),
        ],
      ],
    ).animate().fadeIn().scale();
  }

  Widget _confidenceBadge(int pct) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _confidenceColor(confidence).withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _confidenceColor(confidence).withOpacity(0.6)),
      ),
      child: Text(
        '$pct% match',
        style: TextStyle(color: _confidenceColor(confidence), fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Color _confidenceColor(double conf) {
    if (conf >= 0.8) return Colors.green;
    if (conf >= 0.5) return Colors.amber;
    return Colors.orange;
  }
}

class _AlternativeChip extends StatelessWidget {
  final IdentificationResult result;
  final VoidCallback onTap;

  const _AlternativeChip({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct = (result.confidence * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              if (result.bird.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: NetworkBirdImage(url: result.bird.imageUrl, height: 36, width: 36),
                )
              else
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: result.bird.rarity.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(child: Text('🐦', style: TextStyle(fontSize: 18))),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.bird.name,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      result.bird.scientificName,
                      style: const TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$pct%', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
