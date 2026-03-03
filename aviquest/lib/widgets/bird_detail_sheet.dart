import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';
import '../constants.dart';
import '../models/bird.dart';
import 'network_bird_image.dart';

final _log = Logger('BirdDetailSheet');

class BirdDetailSheet extends StatelessWidget {
  final Bird bird;
  final AudioPlayer player;

  const BirdDetailSheet({super.key, required this.bird, required this.player});

  static void show(BuildContext context, Bird bird, AudioPlayer player, {String source = 'unknown'}) {
    _log.fine('Showing detail sheet for ${bird.name} (source: $source)');
    showModalBottomSheet(
      context: context,
      backgroundColor: bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => BirdDetailSheet(bird: bird, player: player),
    ).whenComplete(() => player.dispose());
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, ctrl) => SingleChildScrollView(
        controller: ctrl,
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: bird.rarity.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: bird.rarity.color),
              ),
              child: Text(
                bird.rarity.label,
                style: TextStyle(color: bird.rarity.color, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(child: Text(bird.name,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.amber),
            textAlign: TextAlign.center)),
          Center(child: Text(bird.scientificName,
            style: const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic))),
          const SizedBox(height: 16),
          if (bird.rarity == Rarity.unknown)
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: bird.rarity.color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: bird.rarity.color.withOpacity(0.4)),
              ),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('❓', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 6),
                  Text('Photo not yet in database',
                      style: TextStyle(color: bird.rarity.color)),
                ]),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: NetworkBirdImage(url: bird.imageUrl, height: 240),
            ),
          const SizedBox(height: 16),
          _detailRow(Icons.auto_stories, 'Lore', bird.lore),
          _detailRow(Icons.landscape, 'Habitat', bird.habitat),
          _detailRow(Icons.eco, 'Conservation', bird.conservationStatus),
          _detailRow(Icons.bolt, 'XP Value', '+${bird.xp} XP'),
          const SizedBox(height: 16),
          Row(
            children: [
              if (bird.audioUrl.isNotEmpty)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      player.setUrl(bird.audioUrl).then((_) => player.play()).catchError((e) {
                        _log.fine('Audio playback failed for ${bird.name}: $e');
                      });
                    },
                    icon: const Icon(Icons.volume_up),
                    label: const Text('Play Call'),
                  ),
                ),
              if (bird.audioUrl.isNotEmpty) const SizedBox(width: 12),
              if (bird.rarity != Rarity.unknown)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: bgCard,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Row(children: [
                            Text('💡', style: TextStyle(fontSize: 24)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text('Did You Know?',
                                style: TextStyle(color: Colors.amber, fontSize: 18)),
                            ),
                          ]),
                          content: Text(
                            _generateFunFact(bird),
                            style: const TextStyle(color: Colors.white70, height: 1.5),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cool!', style: TextStyle(color: Colors.amber)),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 18),
                    label: const Text('Fun Fact', style: TextStyle(color: Colors.amber)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.amber),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  String _generateFunFact(Bird bird) {
    final facts = <String>[];
    if (bird.conservationStatus == 'Critically Endangered') {
      facts.add('The ${bird.name} is critically endangered. Fewer than ever remain in the wild. Every sighting matters for conservation efforts.');
    } else if (bird.conservationStatus == 'Endangered') {
      facts.add('The ${bird.name} is listed as endangered. Conservation programs around the world are working to protect this species.');
    } else if (bird.conservationStatus == 'Vulnerable') {
      facts.add('The ${bird.name} is considered vulnerable. Their population is declining, making each sighting increasingly valuable.');
    }
    if (bird.rarity == Rarity.legendary) {
      facts.add('The ${bird.name} is one of the rarest birds you can find in AviQuest. Only 3% of encounters yield a legendary bird!');
    }
    if (bird.rarity == Rarity.rare) {
      facts.add('The ${bird.name} appears in only 12% of encounters. Finding one takes patience and a keen eye.');
    }
    facts.add('The scientific name "${bird.scientificName}" helps scientists worldwide identify this exact species regardless of language barriers.');
    facts.add('${bird.name} lives in ${bird.habitat.toLowerCase()}. Understanding habitats is key to successful birdwatching.');
    return facts[bird.name.hashCode.abs() % facts.length];
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Colors.amber, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 15)),
        ])),
      ]),
    );
  }
}
