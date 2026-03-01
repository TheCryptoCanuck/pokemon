import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants.dart';
import '../models/bird.dart';
import 'network_bird_image.dart';

class BirdFoundDialog extends StatelessWidget {
  final Bird bird;
  final VoidCallback onAdd;

  const BirdFoundDialog({super.key, required this.bird, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final isUnknown = bird.rarity == 'unknown';
    return Dialog(
      backgroundColor: bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Rarity badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: bird.rarityColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: bird.rarityColor),
              ),
              child: Text(
                isUnknown ? 'NEW DISCOVERY' : bird.rarity.toUpperCase(),
                style: TextStyle(color: bird.rarityColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ).animate().fadeIn().scale(),
            const SizedBox(height: 12),
            Text(
              isUnknown ? '🔭 ${bird.name}' : '✨ ${bird.name}',
              style: TextStyle(
                color: isUnknown ? bird.rarityColor : Colors.amber,
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
            if (isUnknown)
              Container(
                height: 140,
                decoration: BoxDecoration(
                  color: bird.rarityColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: bird.rarityColor.withOpacity(0.4)),
                ),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('❓', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 6),
                    Text('Not in our database yet',
                        style: TextStyle(color: bird.rarityColor, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ).animate().fadeIn(delay: 200.ms)
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: NetworkBirdImage(url: bird.imageUrl, height: 220),
              ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.95, 0.95)),
            const SizedBox(height: 12),
            Text(bird.lore, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bolt, color: Colors.amber, size: 16),
                Text(' +${bird.xp} XP', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white54),
                    child: const Text('Skip'),
                  ),
                ),
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
            ),
          ],
        ),
      ),
    );
  }
}
