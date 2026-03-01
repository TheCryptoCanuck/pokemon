import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants.dart';

class MapTab extends StatelessWidget {
  const MapTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.map, size: 80, color: Colors.white24)
            .animate().fadeIn().scale(),
        const SizedBox(height: 16),
        const Text('Interactive Map', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber))
            .animate().fadeIn(delay: 100.ms),
        const SizedBox(height: 8),
        const Text('Hotspot mapping & community sightings\ncoming soon!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54))
            .animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgCard,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.people, color: Colors.amber),
            SizedBox(width: 8),
            Text('1,247 sightings logged today 🌍', style: TextStyle(color: Colors.white70)),
          ]),
        ).animate().fadeIn(delay: 300.ms),
      ]),
    );
  }
}
