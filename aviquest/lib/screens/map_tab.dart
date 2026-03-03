import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../constants.dart';
import '../services/bird_service.dart';
import '../services/sighting_service.dart';
import '../widgets/bird_detail_sheet.dart';
import '../widgets/network_bird_image.dart';

class MapTab extends ConsumerWidget {
  const MapTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sightingSvc = ref.read(sightingServiceProvider);
    final birdSvc = ref.read(birdServiceProvider);
    final sightings = sightingSvc.all;
    final grouped = sightingSvc.groupedByDate();

    if (sightings.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.history, size: 80, color: Colors.white24)
                .animate().fadeIn().scale(),
            const SizedBox(height: 16),
            const Text('Sighting Log',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber))
                .animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 8),
            const Text(
              'Your sighting history will appear here.\nIdentify birds to start logging!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ).animate().fadeIn(delay: 200.ms),
          ]),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        // Stats header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sighting Log',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amber))
                    .animate().fadeIn(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _statBubble('Total', '${sightingSvc.totalSightings}', Icons.remove_red_eye),
                    const SizedBox(width: 8),
                    _statBubble('Species', '${sightingSvc.uniqueSpecies}', Icons.category),
                    const SizedBox(width: 8),
                    if (sightingSvc.bestDay != null)
                      _statBubble('Best Day', '${sightingSvc.bestDay!.$2}', Icons.star),
                  ],
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        // Grouped sightings by date
        ...grouped.entries.expand((entry) {
          final dateKey = entry.key;
          final daySightings = entry.value;
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_formatDate(dateKey),
                          style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Text('${daySightings.length} sighting${daySightings.length == 1 ? '' : 's'}',
                        style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final sighting = daySightings[i];
                  final bird = birdSvc.lookup(sighting.birdName);
                  final count = sightingSvc.sightingCount(sighting.birdName);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (bird != null) {
                          BirdDetailSheet.show(context, bird, AudioPlayer(), source: 'sighting_log');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: bgCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: bird?.rarity.color.withOpacity(0.3) ?? Colors.white12,
                          ),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 44, height: 44,
                                child: bird != null && bird.imageUrl.isNotEmpty
                                    ? NetworkBirdImage(url: bird.imageUrl, height: 44, width: 44)
                                    : Container(
                                        color: Colors.white.withOpacity(0.05),
                                        child: const Icon(Icons.help_outline, color: Colors.white24),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(sighting.birdName,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Row(children: [
                                    Text(_formatTime(sighting.timestamp),
                                        style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                    if (bird != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: bird.rarity.color.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(bird.rarity.name,
                                            style: TextStyle(color: bird.rarity.color, fontSize: 9)),
                                      ),
                                    ],
                                  ]),
                                ],
                              ),
                            ),
                            if (count > 1)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('×$count',
                                    style: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            const SizedBox(width: 6),
                            Text('${(sighting.confidence * 100).round()}%',
                                style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: daySightings.length,
              ),
            ),
          ];
        }),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _statBubble(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: [
          Icon(icon, color: Colors.amber, size: 20),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ]),
      ),
    );
  }

  String _formatDate(String dateKey) {
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayKey = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    if (dateKey == todayKey) return 'Today';
    if (dateKey == yesterdayKey) return 'Yesterday';
    final parts = dateKey.split('-');
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[int.parse(parts[1])]} ${int.parse(parts[2])}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:${dt.minute.toString().padLeft(2, '0')} $amPm';
  }
}
