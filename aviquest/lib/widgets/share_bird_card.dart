import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/bird.dart';
import 'network_bird_image.dart';

/// A visually rich bird card designed for sharing/screenshots.
///
/// Renders the bird's photo, name, rarity, lore, and XP in a styled card
/// format. Intended to be wrapped in a RepaintBoundary for screenshot capture.
class ShareBirdCard extends StatelessWidget {
  final Bird bird;
  final int playerLevel;
  final String playerTitle;

  const ShareBirdCard({
    super.key,
    required this.bird,
    required this.playerLevel,
    required this.playerTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: bgDeep,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: bird.rarity.color.withOpacity(0.6), width: 2),
        boxShadow: [
          BoxShadow(
            color: bird.rarity.color.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bird image
          SizedBox(
            height: 200,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                NetworkBirdImage(url: bird.imageUrl, height: 200),
                // Gradient overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, bgDeep],
                      ),
                    ),
                  ),
                ),
                // Rarity badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: bird.rarity.color.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      bird.rarity.label,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Bird info
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bird.name,
                  style: TextStyle(
                    color: bird.rarity.color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  bird.scientificName,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  bird.lore,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // Stats row
                Row(
                  children: [
                    _statPill(Icons.bolt, '+${bird.xp} XP', Colors.amber),
                    const SizedBox(width: 8),
                    _statPill(Icons.eco, bird.conservationStatus, Colors.green),
                  ],
                ),
                const SizedBox(height: 12),
                // Footer with branding
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: bgCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Text('🦅', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('AviQuest',
                              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                            Text('$playerTitle  •  Lv. $playerLevel',
                              style: const TextStyle(color: Colors.white54, fontSize: 10)),
                          ],
                        ),
                      ),
                      Text(
                        'Spotted!',
                        style: TextStyle(
                          color: bird.rarity.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statPill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
