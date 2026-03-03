import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shimmer/shimmer.dart';
import '../constants.dart';
import '../models/bird.dart';
import '../services/bird_service.dart';
import '../widgets/bird_detail_sheet.dart';

class FieldGuideScreen extends ConsumerStatefulWidget {
  const FieldGuideScreen({super.key});

  @override
  ConsumerState<FieldGuideScreen> createState() => _FieldGuideScreenState();
}

class _FieldGuideScreenState extends ConsumerState<FieldGuideScreen> {
  String _guideSearch = '';
  Rarity? _guideRarityFilter;

  @override
  Widget build(BuildContext context) {
    final birdSvc = ref.read(birdServiceProvider);
    final filtered = birdSvc.filter(rarity: _guideRarityFilter, search: _guideSearch);

    return Column(
      children: [
        // Quiz mode launcher
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              context.push('/quiz');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.amber.withOpacity(0.15),
                  Colors.green.withOpacity(0.08),
                ]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withOpacity(0.4)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.quiz, color: Colors.amber, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Bird Quiz', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                    Text('Test your bird knowledge — earn bonus XP!',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ]),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.amber, size: 16),
              ]),
            ),
          ).animate().fadeIn(),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
            children: [
              _filterChip(null, 'All', Colors.white70),
              ...Rarity.values
                  .where((r) => r != Rarity.unknown)
                  .map((r) => _filterChip(r, r.name[0].toUpperCase() + r.name.substring(1), r.color)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.search_off, size: 48, color: Colors.white24),
                    const SizedBox(height: 12),
                    Text(
                      _guideSearch.isNotEmpty
                          ? 'No birds matching "$_guideSearch"'
                          : 'No ${_guideRarityFilter?.name ?? ''} birds found',
                      style: const TextStyle(color: Colors.white38),
                      textAlign: TextAlign.center,
                    ),
                  ]),
                )
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filtered.length,
            itemBuilder: (c, i) {
              final bird = filtered[i];
              return Card(
                color: bgCard,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: bird.rarity.color.withOpacity(0.4)),
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
                          color: bird.rarity.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: bird.rarity.color.withOpacity(0.5)),
                        ),
                        child: Text(bird.rarity.name,
                          style: TextStyle(color: bird.rarity.color, fontSize: 10)),
                      ),
                      const SizedBox(width: 8),
                      Text('+${bird.xp} XP', style: const TextStyle(color: Colors.amber, fontSize: 11)),
                    ]),
                  ]),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                  onTap: () => BirdDetailSheet.show(context, bird, AudioPlayer(), source: 'guide'),
                ),
              ).animate().fadeIn(delay: Duration(milliseconds: i * 30));
            },
          ),
        ),
      ],
    );
  }

  Widget _filterChip(Rarity? rarity, String label, Color color) {
    final selected = _guideRarityFilter == rarity;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _guideRarityFilter = rarity),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.2) : bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? color : Colors.white12),
          ),
          child: Text(label,
            style: TextStyle(color: selected ? color : Colors.white54,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
        ),
      ),
    );
  }
}
