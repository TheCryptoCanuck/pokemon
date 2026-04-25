import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class NeighborhoodEmptyState extends StatelessWidget {
  const NeighborhoodEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('\u{1F3D8}', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              'Your Neighborhood',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your dog in the Profile tab to explore the neighborhood and make friends!',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ).animate().fadeIn(),
      ),
    );
  }
}
