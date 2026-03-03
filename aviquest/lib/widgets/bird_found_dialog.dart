import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final isUnknown = bird.rarity == Rarity.unknown;
    final isMock = source == 'mock';
    final confidencePct = (confidence * 100).round();

    return Dialog(
      backgroundColor: bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Rarity badge + confidence
              Row(
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _confidenceColor(confidence).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _confidenceColor(confidence).withOpacity(0.6)),
                      ),
                      child: Text(
                        '$confidencePct% match',
                        style: TextStyle(
                          color: _confidenceColor(confidence),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ).animate().fadeIn().scale(),
              const SizedBox(height: 12),

              // Bird name
              Text(
                isUnknown ? '🔭 ${bird.name}' : '✨ ${bird.name}',
                style: TextStyle(
                  color: isUnknown ? bird.rarity.color : Colors.amber,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 100.ms),
              Text(
                bird.scientificName,
                style: const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 12),

              // Bird image
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
                ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.95, 0.95)),
              const SizedBox(height: 12),

              // Lore
              Text(bird.lore, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),

              // XP
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bolt, color: Colors.amber, size: 16),
                  Text(' +${bird.xp} XP', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                ],
              ),

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
                const Text(
                  'Could also be:',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
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
                child: Text(
                  '$pct%',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
