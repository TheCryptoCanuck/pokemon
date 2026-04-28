import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shimmer/shimmer.dart';
import 'package:dogquest/constants.dart';
import 'package:dogquest/models/dog.dart';
import 'package:dogquest/services/kennel_service.dart';
import 'package:dogquest/services/dog_group_service.dart';
import 'package:dogquest/services/dog_service.dart';
import 'package:dogquest/services/breed_collection_service.dart';
import 'package:dogquest/widgets/breed_share_sheet.dart';
import 'package:dogquest/widgets/dog_detail_sheet.dart';

enum KennelSortMode { recent, name, rarity }

enum KennelViewMode { grid, families, collections }

class KennelScreen extends ConsumerStatefulWidget {
  const KennelScreen({super.key});

  @override
  ConsumerState<KennelScreen> createState() => _KennelScreenState();
}

class _KennelScreenState extends ConsumerState<KennelScreen> {
  Rarity? _filterRarity;
  KennelSortMode _sortMode = KennelSortMode.recent;
  KennelViewMode _viewMode = KennelViewMode.grid;
  bool _hasAnimated = false;
  final _player = AudioPlayer();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _player.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kennelSvc = ref.read(kennelServiceProvider);
    final dogSvc = ref.read(dogServiceProvider);
    final familySvc = ref.read(dogGroupServiceProvider);

    return ValueListenableBuilder<Box<String>>(
      valueListenable: kennelSvc.box.listenable(),
      builder: (context, box, _) {
        if (!_hasAnimated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _hasAnimated = true;
          });
        }
        if (box.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pets, size: 72, color: Colors.white30),
                const SizedBox(height: 20),
                const Text(
                  'Your collection starts here',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Identify your first dog to begin!',
                  style: TextStyle(color: Colors.white54, fontSize: 15),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.go('/identify'),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Start Identifying'),
                ),
              ],
            ).animate().fadeIn().slideY(begin: 0.1),
          );
        }

        // Build dog list from kennel
        List<Dog> dogs = box.values
            .map((name) => dogSvc.lookup(name) ?? dogSvc.unknownDog(name))
            .toList();

        // Filter by rarity
        if (_filterRarity != null) {
          dogs = dogs.where((b) => b.rarity == _filterRarity).toList();
        }

        // Filter by search query
        if (_searchQuery.isNotEmpty) {
          final q = _searchQuery.toLowerCase();
          dogs = dogs.where((d) => d.name.toLowerCase().contains(q)).toList();
        }

        // Sort
        switch (_sortMode) {
          case KennelSortMode.recent:
            break; // Keep Hive insertion order (reversed below)
          case KennelSortMode.name:
            dogs.sort((a, b) => a.name.compareTo(b.name));
          case KennelSortMode.rarity:
            const rarityOrder = {
              Rarity.legendary: 0,
              Rarity.rare: 1,
              Rarity.uncommon: 2,
              Rarity.common: 3,
              Rarity.unknown: 4,
            };
            dogs.sort(
              (a, b) => (rarityOrder[a.rarity] ?? 5)
                  .compareTo(rarityOrder[b.rarity] ?? 5),
            );
        }

        if (_sortMode == KennelSortMode.recent) {
          dogs = dogs.reversed.toList();
        }

        // Rarity counts for header
        final allDogs = kennelSvc.collectedDogs;
        final rarityCounts = <Rarity, int>{};
        for (final b in allDogs) {
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
                    // Collection progress bar — keyed to deployed breed count
                    Row(
                      children: [
                        Text(
                          '${box.length}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                        Text(
                          ' / $kDeployedBreedCount breeds',
                          style: const TextStyle(
                            color: textMuted,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(box.length / kDeployedBreedCount * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '$kTargetBreedCount coming',
                              style: const TextStyle(
                                color: textHint,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ).animate().fadeIn(),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: box.length / kDeployedBreedCount,
                        minHeight: 8,
                        backgroundColor: bgCard,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.amber),
                      ),
                    ).animate().fadeIn(delay: 50.ms),
                    const SizedBox(height: 10),
                    // Rarity breakdown chips
                    Row(
                      children: [
                        for (final r in [
                          Rarity.common,
                          Rarity.uncommon,
                          Rarity.rare,
                          Rarity.legendary,
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: r.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${rarityCounts[r] ?? 0} ${r.name}',
                                style: TextStyle(
                                  color: r.color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ).animate().fadeIn(delay: 100.ms),
                    const SizedBox(height: 10),
                    // Search field
                    TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search breeds…',
                        hintStyle: const TextStyle(
                          color: Colors.white38,
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white38,
                          size: 20,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white38,
                                  size: 18,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Controls row
                    Row(
                      children: [
                        // View mode toggle
                        _viewToggle(),
                        const SizedBox(width: 8),
                        // Rarity filter chips (only visible in grid mode)
                        if (_viewMode == KennelViewMode.grid)
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _filterChip(null, 'All', Colors.white70),
                                  ...Rarity.values
                                      .where((r) => r != Rarity.unknown)
                                      .map(
                                        (r) => _filterChip(
                                          r,
                                          r.name[0].toUpperCase() +
                                              r.name.substring(1),
                                          r.color,
                                        ),
                                      ),
                                ],
                              ),
                            ),
                          )
                        else
                          const Spacer(),
                        if (_viewMode == KennelViewMode.grid) ...[
                          const SizedBox(width: 4),
                          // Sort dropdown
                          PopupMenuButton<KennelSortMode>(
                            onSelected: (mode) =>
                                setState(() => _sortMode = mode),
                            icon: const Icon(
                              Icons.sort,
                              color: Colors.white54,
                              size: 20,
                            ),
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: KennelSortMode.recent,
                                child: Text('Recent'),
                              ),
                              const PopupMenuItem(
                                value: KennelSortMode.name,
                                child: Text('Name'),
                              ),
                              const PopupMenuItem(
                                value: KennelSortMode.rarity,
                                child: Text('Rarity'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // View content
            if (_viewMode == KennelViewMode.families)
              SliverToBoxAdapter(
                child: _buildFamiliesSection(familySvc),
              )
            else if (_viewMode == KennelViewMode.collections)
              SliverToBoxAdapter(
                child: _buildCollectionsSection(),
              )
            else ...[
              // Dog grid
              if (dogs.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Text(
                      _searchQuery.isNotEmpty
                          ? 'No breeds match "$_searchQuery"'
                          : 'No ${_filterRarity?.name ?? ''} dogs in your kennel yet',
                      style: const TextStyle(color: Colors.white38),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (c, i) {
                        final dog = dogs[i];
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            DogDetailSheet.show(
                              context,
                              dog,
                              _player,
                              source: 'kennel',
                            );
                          },
                          child: Card(
                            color: bgCard,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: dog.rarity.color.withValues(alpha: 0.6),
                                width: 1.5,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: dog.imageUrl,
                                  httpHeaders: const {
                                    'User-Agent':
                                        'Hound/1.0 (dog identification app)',
                                  },
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Shimmer.fromColors(
                                    baseColor: bgCard,
                                    highlightColor: const Color(0xFF3A2F2A),
                                    child: Container(color: bgCard),
                                  ),
                                  errorWidget: (_, __, ___) => const Icon(
                                    Icons.broken_image,
                                    color: Colors.white24,
                                  ),
                                ),
                                // Share button (top-right)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      BreedShareSheet.show(context, dog);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.share,
                                        color: Colors.white70,
                                        size: 14,
                                      ),
                                    ),
                                  ),
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
                                          Colors.black.withValues(alpha: 0.8),
                                        ],
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dog.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          dog.rarity.name,
                                          style: TextStyle(
                                            color: dog.rarity.color,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                              .animate(autoPlay: !_hasAnimated)
                              .fadeIn(
                                delay: Duration(
                                  milliseconds: (i * 40).clamp(0, 500),
                                ),
                              )
                              .scale(begin: const Offset(0.9, 0.9)),
                        );
                      },
                      childCount: dogs.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.82,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  /// Three-way view toggle: Grid / Families / Collections
  Widget _viewToggle() {
    return Container(
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _viewToggleItem(KennelViewMode.grid, Icons.grid_view, 'Grid'),
          _viewToggleItem(
            KennelViewMode.families,
            Icons.account_tree_outlined,
            'Families',
          ),
          _viewToggleItem(
            KennelViewMode.collections,
            Icons.collections_bookmark_outlined,
            'Sets',
          ),
        ],
      ),
    );
  }

  Widget _viewToggleItem(KennelViewMode mode, IconData icon, String label) {
    final selected = _viewMode == mode;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _viewMode = mode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Colors.amber.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: selected ? Colors.amber : Colors.white54, size: 14),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.amber : Colors.white54,
                fontSize: 11,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionsSection() {
    final collectionSvc = ref.read(breedCollectionServiceProvider);
    final dogSvc = ref.read(dogServiceProvider);
    final kennelSvc = ref.read(kennelServiceProvider);
    final collections = collectionSvc.getCollections();
    final completedCount = collections.where((c) => c.isComplete).length;
    final collectedSet = kennelSvc.all.toSet();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Breed Collections',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
              const Spacer(),
              Text(
                '$completedCount/${collections.length} complete',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...collections.asMap().entries.map((e) {
            final cp = e.value;
            final collection = cp.collection;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: cp.isComplete
                        ? collection.color.withValues(alpha: 0.6)
                        : Colors.white12,
                    width: cp.isComplete ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      children: [
                        Text(
                          collection.emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      collection.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (cp.isComplete) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: collection.color
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'COMPLETE',
                                        style: TextStyle(
                                          color: collection.color,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                collection.description,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${cp.collected}/${cp.total}',
                              style: TextStyle(
                                color: cp.isComplete
                                    ? collection.color
                                    : Colors.white54,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${collection.xpReward} XP',
                              style: TextStyle(
                                color: cp.isComplete
                                    ? collection.color.withValues(alpha: 0.7)
                                    : Colors.white24,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: cp.progress,
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          cp.isComplete
                              ? collection.color
                              : collection.color.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Breed chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: collection.breeds.map((breedName) {
                        final isCollected = collectedSet.contains(breedName);
                        final dog = dogSvc.lookup(breedName);
                        return GestureDetector(
                          onTap: dog != null
                              ? () {
                                  HapticFeedback.lightImpact();
                                  DogDetailSheet.show(
                                    context,
                                    dog,
                                    _player,
                                    source: 'collection',
                                  );
                                }
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isCollected
                                  ? collection.color.withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isCollected
                                    ? collection.color.withValues(alpha: 0.4)
                                    : Colors.white10,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isCollected)
                                  Icon(
                                    Icons.check_circle,
                                    size: 12,
                                    color:
                                        collection.color.withValues(alpha: 0.8),
                                  )
                                else
                                  const Icon(
                                    Icons.radio_button_unchecked,
                                    size: 12,
                                    color: Colors.white24,
                                  ),
                                const SizedBox(width: 4),
                                Text(
                                  breedName,
                                  style: TextStyle(
                                    color: isCollected
                                        ? Colors.white
                                        : Colors.white38,
                                    fontSize: 11,
                                    fontWeight: isCollected
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(
                  delay: Duration(milliseconds: (e.key * 60).clamp(0, 600)),
                );
          }),
        ],
      ),
    );
  }

  Widget _buildFamiliesSection(DogGroupService familySvc) {
    final progress = familySvc.allProgress;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Dog Families',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
              const Spacer(),
              Text(
                '${progress.where((p) => p.isComplete).length}/${progress.length} complete',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
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
                    color: fp.isComplete
                        ? fp.family.color.withValues(alpha: 0.6)
                        : Colors.white12,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          fp.family.emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    fp.family.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (fp.mastery != FamilyMastery.none) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      fp.mastery.emoji,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                fp.family.description,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${fp.collected}/${fp.total}',
                          style: TextStyle(
                            color: fp.isComplete
                                ? fp.family.color
                                : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fp.progress,
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          fp.isComplete
                              ? fp.family.color
                              : fp.family.color.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    if (fp.mastery != FamilyMastery.none) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${fp.mastery.label} Mastery — ${(fp.xpBonus * 100 - 100).toStringAsFixed(0)}% XP bonus',
                        style: TextStyle(color: fp.mastery.color, fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ),
            ).animate().fadeIn(
                  delay: Duration(milliseconds: (e.key * 60).clamp(0, 600)),
                );
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
            color: selected ? color.withValues(alpha: 0.2) : bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? color : Colors.white12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : Colors.white54,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}
