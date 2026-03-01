import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../constants.dart';
import '../data/bird_database.dart';
import '../models/bird.dart';

class FieldGuideTab extends StatefulWidget {
  final void Function(Bird bird) onBirdTap;

  const FieldGuideTab({super.key, required this.onBirdTap});

  @override
  State<FieldGuideTab> createState() => _FieldGuideTabState();
}

class _FieldGuideTabState extends State<FieldGuideTab> {
  String _guideSearch = '';
  String _guideRarityFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final filtered = birds.where((b) {
      final matchRarity = _guideRarityFilter == 'all' || b.rarity == _guideRarityFilter;
      final matchSearch = _guideSearch.isEmpty ||
          b.name.toLowerCase().contains(_guideSearch.toLowerCase()) ||
          b.scientificName.toLowerCase().contains(_guideSearch.toLowerCase());
      return matchRarity && matchSearch;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            onChanged: (v) => setState(() => _guideSearch = v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search species...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              filled: true,
              fillColor: bgCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: ['all', 'common', 'uncommon', 'rare', 'legendary'].map((r) {
              final selected = _guideRarityFilter == r;
              final color = r == 'all' ? Colors.white70 : (rarityColors[r] ?? Colors.white70);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _guideRarityFilter = r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? color.withOpacity(0.2) : bgCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? color : Colors.white12),
                    ),
                    child: Text(r[0].toUpperCase() + r.substring(1),
                      style: TextStyle(color: selected ? color : Colors.white54,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filtered.length,
            itemBuilder: (c, i) {
              final bird = filtered[i];
              return Card(
                color: bgCard,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: bird.rarityColor.withOpacity(0.4)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 60, height: 60,
                      child: CachedNetworkImage(
                        imageUrl: bird.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Shimmer.fromColors(
                          baseColor: bgCard,
                          highlightColor: const Color(0xFF2A3F2F),
                          child: Container(color: bgCard),
                        ),
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.broken_image, color: Colors.white24),
                      ),
                    ),
                  ),
                  title: Text(bird.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(bird.scientificName,
                      style: const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic, fontSize: 12)),
                    Row(children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: bird.rarityColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: bird.rarityColor.withOpacity(0.5)),
                        ),
                        child: Text(bird.rarity,
                          style: TextStyle(color: bird.rarityColor, fontSize: 10)),
                      ),
                      const SizedBox(width: 8),
                      Text('+${bird.xp} XP', style: const TextStyle(color: Colors.amber, fontSize: 11)),
                    ]),
                  ]),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                  onTap: () => widget.onBirdTap(bird),
                ),
              ).animate().fadeIn(delay: Duration(milliseconds: i * 30));
            },
          ),
        ),
      ],
    );
  }
}
