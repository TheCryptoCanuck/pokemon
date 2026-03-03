import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../constants.dart';
import '../services/daily_bird_service.dart';
import 'bird_detail_sheet.dart';
import 'network_bird_image.dart';

class DailyBirdCard extends ConsumerWidget {
  const DailyBirdCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailySvc = ref.read(dailyBirdServiceProvider);
    final bird = dailySvc.todaysBird;
    final claimed = dailySvc.isBonusClaimed;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        BirdDetailSheet.show(context, bird, AudioPlayer());
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              Colors.amber.withOpacity(0.15),
              bird.rarity.color.withOpacity(0.08),
            ],
          ),
          border: Border.all(color: Colors.amber.withOpacity(0.4)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wb_sunny, color: Colors.amber, size: 14),
                        SizedBox(width: 4),
                        Text('Bird of the Day',
                          style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (claimed)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 12),
                          SizedBox(width: 4),
                          Text('Claimed', style: TextStyle(color: Colors.green, fontSize: 11)),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${DailyBirdService.bonusMultiplier}x XP',
                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                ],
              ),
            ),
            // Bird info row
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: NetworkBirdImage(url: bird.imageUrl, height: 64, width: 64),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(bird.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(bird.scientificName,
                          style: const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(dailySvc.dailyChallenge,
                          style: const TextStyle(color: Colors.amber, fontSize: 11)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white24),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.05),
    );
  }
}
