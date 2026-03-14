import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants.dart';
import '../services/dog_service.dart';
import '../services/sighting_service.dart';
import '../services/kennel_service.dart';

/// Community page for a specific breed — stats, sightings, breed info.
class BreedCommunityScreen extends ConsumerWidget {
  final String breedName;
  const BreedCommunityScreen({super.key, required this.breedName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dogSvc = ref.watch(dogServiceProvider);
    final sightingSvc = ref.watch(sightingServiceProvider);
    final kennelSvc = ref.watch(kennelServiceProvider);

    final dog = dogSvc.lookupByCommonName(breedName);
    if (dog == null) {
      return Scaffold(
        backgroundColor: bgDeep,
        appBar: AppBar(title: Text(breedName), backgroundColor: bgCard),
        body: Center(
            child: Text('Breed not found',
                style: TextStyle(color: textSecondary))),
      );
    }

    final sightings = sightingSvc.forDog(breedName);
    final isOwned = kennelSvc.contains(breedName);
    final totalSightings = sightings.length;
    final firstSeen = sightings.isNotEmpty ? sightings.last.timestamp : null;
    final lastSeen = sightings.isNotEmpty ? sightings.first.timestamp : null;

    return Scaffold(
      backgroundColor: bgDeep,
      body: CustomScrollView(
        slivers: [
          // Hero header with breed image
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: bgCard,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(dog.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (dog.imageUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: dog.imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: bgCard),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          bgDeep.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status badges
                  Wrap(
                    spacing: 8,
                    children: [
                      _Badge(
                        label: dog.rarity.label,
                        color: dog.rarity.color,
                      ),
                      if (isOwned)
                        _Badge(label: 'IN KENNEL', color: Colors.green),
                      _Badge(
                          label: dog.sizeCategory.toUpperCase(),
                          color: Colors.blueGrey),
                    ],
                  ).animate().fadeIn(),

                  const SizedBox(height: 20),

                  // Community Stats
                  _SectionHeader(title: 'Community Stats'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _StatTile(
                          value: '$totalSightings',
                          label: 'Sightings',
                          icon: Icons.visibility),
                      const SizedBox(width: 10),
                      _StatTile(
                          value: '${dog.xp}',
                          label: 'XP Value',
                          icon: Icons.star),
                      const SizedBox(width: 10),
                      _StatTile(
                        value: dog.lifespan.isNotEmpty ? dog.lifespan : '?',
                        label: 'Lifespan',
                        icon: Icons.favorite,
                      ),
                    ],
                  ).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: 20),

                  // Breed Info
                  _SectionHeader(title: 'About'),
                  const SizedBox(height: 10),
                  Text(
                    dog.lore,
                    style: const TextStyle(
                        color: textPrimary, fontSize: 14, height: 1.5),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 16),

                  // Traits
                  if (dog.temperamentTraits.isNotEmpty) ...[
                    _SectionHeader(title: 'Temperament'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: dog.temperamentTraits
                          .map((t) => Chip(
                                label: Text(t,
                                    style: const TextStyle(
                                        color: textPrimary, fontSize: 12)),
                                backgroundColor: bgCard,
                                side: BorderSide(
                                    color: accent.withValues(alpha: 0.3)),
                              ))
                          .toList(),
                    ).animate().fadeIn(delay: 300.ms),
                    const SizedBox(height: 16),
                  ],

                  // Care Info
                  _SectionHeader(title: 'Care Guide'),
                  const SizedBox(height: 10),
                  _CareRow(
                      icon: Icons.fitness_center,
                      label: 'Exercise',
                      value: dog.exerciseNeeds),
                  _CareRow(
                      icon: Icons.cut,
                      label: 'Grooming',
                      value: dog.groomingNeeds),
                  _CareRow(
                      icon: Icons.scale,
                      label: 'Weight',
                      value:
                          dog.weight.isNotEmpty ? dog.weight : 'Unknown'),
                  if (dog.dietNotes.isNotEmpty)
                    _CareRow(
                        icon: Icons.restaurant,
                        label: 'Diet',
                        value: dog.dietNotes),

                  const SizedBox(height: 20),

                  // Recent Sightings Timeline
                  if (sightings.isNotEmpty) ...[
                    _SectionHeader(title: 'Sighting History'),
                    const SizedBox(height: 10),
                    if (firstSeen != null)
                      Text(
                        'First seen: ${_formatDate(firstSeen)}',
                        style: TextStyle(color: textSecondary, fontSize: 13),
                      ),
                    if (lastSeen != null)
                      Text(
                        'Last seen: ${_formatDate(lastSeen)}',
                        style: TextStyle(color: textSecondary, fontSize: 13),
                      ),
                    const SizedBox(height: 10),
                    ...sightings
                        .take(10)
                        .map((s) => _SightingTile(sighting: s)),
                  ],

                  // Health predispositions
                  if (dog.healthPredispositions.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _SectionHeader(title: 'Health Notes'),
                    const SizedBox(height: 10),
                    ...dog.healthPredispositions.map((h) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline,
                                  size: 16, color: Colors.amber),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(h,
                                    style: const TextStyle(
                                        color: textPrimary, fontSize: 13)),
                              ),
                            ],
                          ),
                        )),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.month}/${d.day}/${d.year}';
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
          color: accent, fontWeight: FontWeight.bold, fontSize: 16),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const _StatTile(
      {required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: accent, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            Text(label,
                style: TextStyle(color: textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _CareRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _CareRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textSecondary),
          const SizedBox(width: 8),
          Text('$label: ',
              style: TextStyle(color: textSecondary, fontSize: 13)),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: textPrimary, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _SightingTile extends StatelessWidget {
  final Sighting sighting;
  const _SightingTile({required this.sighting});

  @override
  Widget build(BuildContext context) {
    final hasGps = sighting.latitude != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${sighting.timestamp.month}/${sighting.timestamp.day} at ${sighting.timestamp.hour}:${sighting.timestamp.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(color: textPrimary, fontSize: 13),
            ),
          ),
          Text(
            '${(sighting.confidence * 100).toStringAsFixed(0)}%',
            style: TextStyle(color: textSecondary, fontSize: 12),
          ),
          if (hasGps) ...[
            const SizedBox(width: 6),
            Icon(Icons.location_on,
                size: 14,
                color: Colors.green.withValues(alpha: 0.6)),
          ],
        ],
      ),
    );
  }
}
