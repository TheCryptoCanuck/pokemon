import 'package:flutter/material.dart';
import 'package:dogquest/constants.dart';
import 'package:dogquest/models/dog.dart';

class BreedGhostCard extends StatelessWidget {
  final Dog dog;

  const BreedGhostCard({
    required this.dog,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: dog.rarity.color.withValues(alpha: 0.55),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Placeholder center icon
          const Center(
            child: Icon(
              Icons.help_outline,
              color: Colors.white54,
              size: 40,
            ),
          ),
          // Bottom gradient overlay with breed name and rarity
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dog.name,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    dog.rarity.name,
                    style: TextStyle(
                      color: dog.rarity.color.withValues(alpha: 0.75),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
