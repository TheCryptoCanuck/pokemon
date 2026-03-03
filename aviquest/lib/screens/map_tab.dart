import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import '../services/aviary_service.dart';

class MapTab extends ConsumerWidget {
  const MapTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aviarySvc = ref.read(aviaryServiceProvider);
    final count = aviarySvc.count;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.map_outlined, size: 80, color: Colors.amber)
              .animate().fadeIn().scale(),
          const SizedBox(height: 16),
          const Text('Sighting Log',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber))
              .animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 8),
          const Text(
            'Your personal sighting map is coming soon.\nIdentify birds to build your sighting history.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgCard,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.collections_bookmark, color: Colors.amber),
              const SizedBox(width: 8),
              Text(
                count == 0
                    ? 'No sightings yet — go identify a bird!'
                    : '$count species in your aviary',
                style: const TextStyle(color: Colors.white70),
              ),
            ]),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: const Column(children: [
              Icon(Icons.location_on, color: Colors.amber, size: 32),
              SizedBox(height: 8),
              Text(
                'GPS sighting tracking will record where you identify each bird and plot your discoveries on a map.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ]),
          ).animate().fadeIn(delay: 400.ms),
        ]),
      ),
    );
  }
}
