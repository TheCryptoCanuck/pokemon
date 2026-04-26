import 'package:flutter/material.dart';
import 'package:dogquest/constants.dart';
import 'package:dogquest/services/sighting_service.dart';

/// Info card shown at the bottom of the Live Map when a sighting marker is tapped.
class MapBottomSheet extends StatelessWidget {
  final Sighting sighting;
  final dynamic dog; // Dog?
  final VoidCallback onClose;

  const MapBottomSheet({
    super.key,
    required this.sighting,
    required this.dog,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final rarityColor = dog?.rarity?.color ?? Colors.amber;
    final rarityLabel = dog?.rarity?.label ?? '';
    final confidence = (sighting.confidence * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: rarityColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: rarityColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.pets, color: rarityColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        sighting.dogName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (rarityLabel.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: rarityColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          rarityLabel,
                          style: TextStyle(
                            color: rarityColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 12,
                      color: Colors.white38,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _timeAgo(sighting.timestamp),
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.verified, size: 12, color: Colors.white38),
                    const SizedBox(width: 4),
                    Text(
                      '$confidence%',
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onClose,
            child: const Icon(Icons.close, color: Colors.white38, size: 20),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }
}
