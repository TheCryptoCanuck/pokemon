import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shimmer/shimmer.dart';
import 'package:dogquest/constants.dart';
import 'package:dogquest/services/dog_service.dart';
import 'package:dogquest/services/kennel_service.dart';
import 'package:dogquest/widgets/dog_detail_sheet.dart';
import 'package:dogquest/widgets/exam_group_cta.dart';

class FieldGuideScreen extends ConsumerStatefulWidget {
  const FieldGuideScreen({super.key});

  @override
  ConsumerState<FieldGuideScreen> createState() => _FieldGuideScreenState();
}

class _FieldGuideScreenState extends ConsumerState<FieldGuideScreen> {
  String _guideSearch = '';
  Rarity? _guideRarityFilter;
  bool? _collectedFilter; // null=all, true=collected, false=not collected
  final _searchController = TextEditingController();
  final _player = AudioPlayer();

  @override
  void dispose() {
    _searchController.dispose();
    _player.dispose();
    super.dispose();
  }

  String _formatBreedInfo(String habitat) {
    // habitat format: "Sporting Group | Origin: Canada"
    final parts = habitat.split(' | ');
    final group = parts.isNotEmpty ? parts[0].replaceAll(' Group', '') : '';
    String origin = '';
    if (parts.length > 1 && parts[1].startsWith('Origin: ')) {
      origin = parts[1].substring('Origin: '.length);
    }
    if (group.isEmpty) return habitat; // fallback to raw string
    if (origin.isEmpty) return '$group Group';
    return '$group Group · $origin';
  }

  @override
  Widget build(BuildContext context) {
    final dogSvc = ref.read(dogServiceProvider);
    final kennelSvc = ref.read(kennelServiceProvider);
    var filtered =
        dogSvc.filter(rarity: _guideRarityFilter, search: _guideSearch);
    if (_collectedFilter == true) {
      filtered = filtered.where((d) => kennelSvc.contains(d.name)).toList();
    } else if (_collectedFilter == false) {
      filtered = filtered.where((d) => !kennelSvc.contains(d.name)).toList();
    }

    return Column(
      children: [
        // Quiz mode launcher
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Semantics(
            button: true,
            label: 'Dog Quiz — Test your dog knowledge',
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                context.push('/quiz');
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.withValues(alpha: 0.15),
                      Colors.green.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child:
                          const Icon(Icons.quiz, color: Colors.amber, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dog Quiz',
                            style: TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Test your dog knowledge — earn bonus XP!',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.amber,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(),
        ),
        const SizedBox(height: 4),
        const ExamGroupRow(),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _guideSearch = v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search species...',
              hintStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              suffixIcon: _guideSearch.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 20,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _guideSearch = '');
                      },
                    )
                  : null,
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
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0.0, 0.85, 1.0],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _filterChip(null, 'All', Colors.white70),
                ...Rarity.values.where((r) => r != Rarity.unknown).map(
                      (r) => _filterChip(
                        r,
                        r.name[0].toUpperCase() + r.name.substring(1),
                        r.color,
                      ),
                    ),
                const SizedBox(width: 8),
                _collectedChip(true, 'Collected', Colors.green),
                _collectedChip(
                  false,
                  'Not Found',
                  Colors.white54,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.search_off,
                        size: 48,
                        color: Colors.white70,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _guideSearch.isNotEmpty
                            ? 'No breeds matching "$_guideSearch"'
                            : 'No ${_guideRarityFilter?.name ?? ''} breeds found',
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (c, i) {
                    final dog = filtered[i];
                    final owned = kennelSvc.contains(dog.name);
                    return Card(
                      color: bgCard,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: dog.rarity.color.withValues(alpha: 0.4),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 60,
                            height: 60,
                            child: CachedNetworkImage(
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
                          ),
                        ),
                        title: Text(
                          dog.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatBreedInfo(dog.habitat),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: dog.rarity.color
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: dog.rarity.color
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Text(
                                    dog.rarity.name,
                                    style: TextStyle(
                                      color: dog.rarity.color,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '+${dog.xp} XP',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: owned
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 20,
                              )
                            : const Icon(
                                Icons.chevron_right,
                                color: Colors.white70,
                              ),
                        onTap: () => DogDetailSheet.show(
                          context,
                          dog,
                          _player,
                          source: 'guide',
                        ),
                      ),
                    ).animate().fadeIn(
                          delay: Duration(milliseconds: (i * 30).clamp(0, 300)),
                        );
                  },
                ),
        ),
      ],
    );
  }

  Widget _collectedChip(bool collected, String label, Color color) {
    final selected = _collectedFilter == collected;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () =>
            setState(() => _collectedFilter = selected ? null : collected),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.2) : bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? color : Colors.white12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : Colors.white54,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
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
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.2) : bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? color : Colors.white12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : Colors.white54,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
