import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shimmer/shimmer.dart';
import '../constants.dart';
import '../models/bird.dart';
import '../services/aviary_service.dart';
import '../services/bird_family_service.dart';
import '../services/bird_service.dart';
import '../widgets/bird_detail_sheet.dart';

enum AviarySortMode { recent, name, rarity }

class AviaryScreen extends ConsumerStatefulWidget {
  const AviaryScreen({super.key});

  @override
  ConsumerState<AviaryScreen> createState() => _AviaryScreenState();
}

class _AviaryScreenState extends ConsumerState<AviaryScreen> {
  Rarity? _filterRarity;
  AviarySortMode _sortMode = AviarySortMode.recent;
  bool _showFamilies = false;

  @override
  Widget build(BuildContext context) {
    final aviarySvc = ref.read(aviaryServiceProvider);
    final birdSvc = ref.read(birdServiceProvider);
    final familySvc = ref.read(birdFamilyServiceProvider);

    return ValueListenableBuilder<Box<String>>(
      valueListenable: aviarySvc.box.listenable(),
      builder: (context, box, _) {
        if (box.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.auto_awesome, size: 64, color: Colors.white24),
              const SizedBox(height: 16),
              const Text('Your aviary is empty!', style: TextStyle(fontSize: 20, color: Colors.white54)),
              const SizedBox(height: 8),
              const Text('Identify birds to add them here.',
                  style: TextStyle(color: Colors.white38)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/identify'),
                child: const Text('Go Identify'),
              ),
            ]),
          );
        }

        // Build bird list from aviary
        List<Bird> birds = box.values
            .map((name) => birdSvc.lookup(name) ?? birdSvc.unknownBird(name))
            .toList();

        // Filter by rarity
        if (_filterRarity != null) {
          birds = birds.where((b) => b.rarity == _filterRarity).toList();
        }

        // Sort
        switch (_sortMode) {
          case AviarySortMode.recent:
            break; // Keep Hive insertion order (reversed below)
          case AviarySortMode.name:
            birds.sort((a, b) => a.name.compareTo(b.name));
          case AviarySortMode.rarity:
            const rarityOrder = {
              Rarity.legendary: 0, Rarity.rare: 1, Rarity.uncommon: 2, Rarity.common: 3, Rarity.unknown: 4,
            };
            birds.sort((a, b) => (rarityOrder[a.rarity] ?? 5).compareTo(rarityOrder[b.rarity] ?? 5));
        }

        if (_sortMode == AviarySortMode.recent) {
          birds = birds.reversed.toList();
        }

        // Rarity counts for header
        final allBirds = box.values
            .map((name) => birdSvc.lookup(name))
            .whereType<Bird>()
            .toList();
        final rarityCounts = <Rarity, int>{};
        for (final b in allBirds) {
          rarityCounts[b.rarity] = (rarityCounts[b.rarity] ?? 0) + 1;
        }

        return CustomScrollView(
          slivers: [
            // Stats header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  children: [
                    // Collection progress bar
                    Row(
                      children: [
                        Text('${box.length}',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amber)),
                        Text(' / ${birdSvc.all.length} species',
                            style: const TextStyle(color: Colors.white54, fontSize: 14)),
                        const Spacer(),
                        Text('${(box.length / birdSvc.all.length * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                      ],
                    ).animate().fadeIn(),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: box.length / birdSvc.all.length,
                        minHeight: 8,
                        backgroundColor: bgCard,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                      ),
                    ).animate().fadeIn(delay: 50.ms),
                    const SizedBox(height: 10),
                    // Rarity breakdown chips
                    Row(
                      children: [
                        for (final r in [Rarity.common, Rarity.uncommon, Rarity.rare, Rarity.legendary])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: r.color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('${rarityCounts[r] ?? 0} ${r.name}',
                                  style: TextStyle(color: r.color, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ),
                      ],
                    ).animate().fadeIn(delay: 100.ms),
                    const SizedBox(height: 10),
                    // Controls row
                    Row(
                      children: [
                        // Family toggle
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _showFamilies = !_showFamilies);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _showFamilies ? Colors.amber.withOpacity(0.15) : bgCard,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _showFamilies ? Colors.amber : Colors.white12),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(_showFamilies ? Icons.grid_view : Icons.account_tree_outlined,
                                  color: _showFamilies ? Colors.amber : Colors.white54, size: 16),
                              const SizedBox(width: 4),
                              Text(_showFamilies ? 'Grid' : 'Families',
                                  style: TextStyle(color: _showFamilies ? Colors.amber : Colors.white54, fontSize: 12)),
                            ]),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Rarity filter chips
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _filterChip(null, 'All', Colors.white70),
                                ...Rarity.values
                                    .where((r) => r != Rarity.unknown)
                                    .map((r) => _filterChip(r, r.name[0].toUpperCase() + r.name.substring(1), r.color)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Sort dropdown
                        PopupMenuButton<AviarySortMode>(
                          onSelected: (mode) => setState(() => _sortMode = mode),
                          icon: const Icon(Icons.sort, color: Colors.white54, size: 20),
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: AviarySortMode.recent, child: Text('Recent')),
                            const PopupMenuItem(value: AviarySortMode.name, child: Text('Name')),
                            const PopupMenuItem(value: AviarySortMode.rarity, child: Text('Rarity')),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Families view
            if (_showFamilies)
              SliverToBoxAdapter(
                child: _buildFamiliesSection(familySvc),
              )
            else ...[
              // Bird grid
              if (birds.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Text('No ${_filterRarity?.name ?? ''} birds in your aviary yet',
                        style: const TextStyle(color: Colors.white38)),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (c, i) {
                        final bird = birds[i];
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            BirdDetailSheet.show(context, bird, AudioPlayer(), source: 'aviary');
                          },
                          child: Card(
                            color: bgCard,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: bird.rarity.color.withOpacity(0.6), width: 1.5),
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
                                  errorWidget: (_, __, ___) =>
                                      const Icon(Icons.broken_image, color: Colors.white24),
                                ),
                                Positioned(
                                  bottom: 0, left: 0, right: 0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(bird.name,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text(bird.rarity.name,
                                        style: TextStyle(color: bird.rarity.color, fontSize: 11)),
                                    ]),
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: Duration(milliseconds: (i * 40).clamp(0, 500))).scale(begin: const Offset(0.9, 0.9)),
                        );
                      },
                      childCount: birds.length,
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, childAspectRatio: 0.82, mainAxisSpacing: 12, crossAxisSpacing: 12,
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildFamiliesSection(BirdFamilyService familySvc) {
    final progress = familySvc.allProgress;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Bird Families',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
              const Spacer(),
              Text('${progress.where((p) => p.isComplete).length}/${progress.length} complete',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          ...progress.asMap().entries.map((e) {
            final fp = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: fp.isComplete ? fp.family.color.withOpacity(0.6) : Colors.white12,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(fp.family.emoji, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Text(fp.family.name,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                              if (fp.mastery != FamilyMastery.none) ...[
                                const SizedBox(width: 6),
                                Text(fp.mastery.emoji, style: const TextStyle(fontSize: 14)),
                              ],
                            ]),
                            Text(fp.family.description,
                                style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          ]),
                        ),
                        Text('${fp.collected}/${fp.total}',
                            style: TextStyle(
                              color: fp.isComplete ? fp.family.color : Colors.white54,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fp.progress,
                        minHeight: 6,
                        backgroundColor: Colors.white.withOpacity(0.05),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          fp.isComplete ? fp.family.color : fp.family.color.withOpacity(0.6),
                        ),
                      ),
                    ),
                    if (fp.mastery != FamilyMastery.none) ...[
                      const SizedBox(height: 4),
                      Text('${fp.mastery.label} Mastery — ${(fp.xpBonus * 100 - 100).toStringAsFixed(0)}% XP bonus',
                          style: TextStyle(color: fp.mastery.color, fontSize: 10)),
                    ],
                  ],
                ),
              ),
            ).animate().fadeIn(delay: Duration(milliseconds: (e.key * 60).clamp(0, 600)));
          }),
        ],
      ),
    );
  }

  Widget _filterChip(Rarity? rarity, String label, Color color) {
    final selected = _filterRarity == rarity;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _filterRarity = rarity),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.2) : bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? color : Colors.white12),
          ),
          child: Text(label,
            style: TextStyle(color: selected ? color : Colors.white54,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 11)),
        ),
      ),
    );
  }
}
