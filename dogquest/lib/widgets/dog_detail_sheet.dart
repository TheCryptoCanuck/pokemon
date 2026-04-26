import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';

import 'package:dogquest/constants.dart';
import 'package:dogquest/models/dog.dart';
import 'package:dogquest/widgets/breed_share_sheet.dart';
import 'package:dogquest/widgets/network_dog_image.dart';

final _log = Logger('DogDetailSheet');

class DogDetailSheet extends StatefulWidget {
  final Dog dog;
  final AudioPlayer player;

  const DogDetailSheet({super.key, required this.dog, required this.player});

  static void show(
    BuildContext context,
    Dog dog,
    AudioPlayer player, {
    String source = 'unknown',
  }) {
    _log.fine('Showing detail sheet for ${dog.name} (source: $source)');
    showModalBottomSheet(
      context: context,
      backgroundColor: bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DogDetailSheet(dog: dog, player: player),
    );
  }

  @override
  State<DogDetailSheet> createState() => _DogDetailSheetState();
}

class _DogDetailSheetState extends State<DogDetailSheet> {
  Dog get dog => widget.dog;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, ctrl) => SingleChildScrollView(
        controller: ctrl,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Rarity badge and share button row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: dog.rarity.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: dog.rarity.color),
                  ),
                  child: Text(
                    dog.rarity.label,
                    style: TextStyle(
                      color: dog.rarity.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (dog.rarity != Rarity.unknown) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 32,
                    width: 32,
                    child: IconButton(
                      onPressed: () => BreedShareSheet.show(context, dog),
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.share,
                        color: Colors.white54,
                        size: 18,
                      ),
                      tooltip: 'Share',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                dog.name,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Center(
              child: Text(
                dog.scientificName,
                style: const TextStyle(
                  color: Colors.white54,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (dog.rarity == Rarity.unknown)
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: dog.rarity.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: dog.rarity.color.withValues(alpha: 0.4)),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('\u2753', style: TextStyle(fontSize: 64)),
                      const SizedBox(height: 6),
                      Text(
                        'Photo not yet in database',
                        style: TextStyle(color: dog.rarity.color),
                      ),
                    ],
                  ),
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: NetworkDogImage(url: dog.imageUrl, height: 240),
              ),
            const SizedBox(height: 16),
            _detailRow(Icons.auto_stories, 'Lore', dog.lore),
            _detailRow(Icons.landscape, 'Habitat', dog.habitat),
            _detailRow(Icons.eco, 'Conservation', dog.conservationStatus),
            _detailRow(Icons.bolt, 'XP Value', '+${dog.xp} XP'),
            const SizedBox(height: 16),
            Row(
              children: [
                if (dog.audioUrl.isNotEmpty)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        widget.player
                            .setUrl(dog.audioUrl)
                            .then((_) => widget.player.play())
                            .catchError((e) {
                          _log.fine(
                              'Audio playback failed for ${dog.name}: $e');
                        });
                      },
                      icon: const Icon(Icons.volume_up),
                      label: const Text('Play Sound'),
                    ),
                  ),
                if (dog.audioUrl.isNotEmpty) const SizedBox(width: 12),
                if (dog.rarity != Rarity.unknown)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: bgCard,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: const Row(
                              children: [
                                Text('\u{1F4A1}',
                                    style: TextStyle(fontSize: 24)),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Did You Know?',
                                    style: TextStyle(
                                      color: Colors.amber,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            content: Text(
                              _generateFunFact(dog),
                              style: const TextStyle(
                                color: Colors.white70,
                                height: 1.5,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  'Cool!',
                                  style: TextStyle(color: Colors.amber),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.lightbulb_outline,
                        color: Colors.amber,
                        size: 18,
                      ),
                      label: const Text(
                        'Fun Fact',
                        style: TextStyle(color: Colors.amber),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.amber),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _generateFunFact(Dog dog) {
    final facts = <String>[];
    if (dog.conservationStatus == 'Critically Endangered') {
      facts.add(
        'The ${dog.name} is critically endangered. This breed is extremely rare. Every sighting matters for breed preservation efforts.',
      );
    } else if (dog.conservationStatus == 'Endangered') {
      facts.add(
        'The ${dog.name} is listed as endangered. Breed preservation programs around the world are working to protect this breed.',
      );
    } else if (dog.conservationStatus == 'Vulnerable') {
      facts.add(
        'The ${dog.name} is considered vulnerable. Their numbers are declining, making each sighting increasingly valuable.',
      );
    }
    if (dog.rarity == Rarity.legendary) {
      facts.add(
        'The ${dog.name} is one of the rarest breeds you can find in DogQuest. Only 3% of encounters yield a legendary dog!',
      );
    }
    if (dog.rarity == Rarity.rare) {
      facts.add(
        'The ${dog.name} appears in only 12% of encounters. Finding one takes patience and a keen eye.',
      );
    }
    facts.add(
      'The scientific name "${dog.scientificName}" helps scientists worldwide identify this exact species regardless of language barriers.',
    );
    facts.add(
      '${dog.name} lives in ${dog.habitat.toLowerCase()}. Understanding habitats is key to successful dog spotting.',
    );
    return facts[dog.name.hashCode.abs() % facts.length];
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
