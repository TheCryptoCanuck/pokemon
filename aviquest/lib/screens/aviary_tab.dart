import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../constants.dart';
import '../models/bird.dart';
import '../services/bird_service.dart';

class AviaryTab extends StatelessWidget {
  final Box<String> aviaryBox;
  final bool hiveReady;
  final void Function(Bird bird) onBirdTapped;
  final VoidCallback onGoIdentify;

  const AviaryTab({
    super.key,
    required this.aviaryBox,
    required this.hiveReady,
    required this.onBirdTapped,
    required this.onGoIdentify,
  });

  @override
  Widget build(BuildContext context) {
    if (!hiveReady) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.amber));
    }

    return ValueListenableBuilder<Box<String>>(
      valueListenable: aviaryBox.listenable(),
      builder: (context, box, _) {
        if (box.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.auto_awesome, size: 64, color: Colors.white24),
              const SizedBox(height: 16),
              const Text('Your aviary is empty!',
                  style: TextStyle(fontSize: 20, color: Colors.white54)),
              const SizedBox(height: 8),
              const Text('Identify birds to add them here.',
                  style: TextStyle(color: Colors.white38)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onGoIdentify,
                child: const Text('Go Identify'),
              ),
            ]),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.82,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: box.length,
          itemBuilder: (c, i) {
            final birdName = box.getAt(i);
            if (birdName == null) return const SizedBox.shrink();
            final bird = BirdService.findByName(birdName);
            return GestureDetector(
              onTap: () => onBirdTapped(bird),
              child: Card(
                color: bgCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color: bird.rarityColor.withAlpha(153), width: 1.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: bird.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Shimmer.fromColors(
                        baseColor: bgCard,
                        highlightColor: const Color(0xFF2A3F2F),
                        child: Container(color: bgCard),
                      ),
                      errorWidget: (_, __, ___) => const Icon(
                          Icons.broken_image,
                          color: Colors.white24),
                    ),
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
                              Colors.black.withAlpha(204)
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(bird.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text(bird.rarity,
                                  style: TextStyle(
                                      color: bird.rarityColor, fontSize: 11)),
                            ]),
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn()
                  .scale(begin: const Offset(0.9, 0.9)),
            );
          },
        );
      },
    );
  }
}
