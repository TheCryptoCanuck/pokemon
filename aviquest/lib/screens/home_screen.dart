import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:just_audio/just_audio.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../constants.dart';
import '../models/bird.dart';
import '../data/birds.dart';
import '../game_logic.dart';

// ─── Home Screen ──────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Player stats
  int level = 1;
  int xp = 0;
  int streak = 1;
  Set<String> unlockedAchievements = {};

  // Storage — FIX 3: Box<String> stores bird names, no adapter needed
  late Box<String> aviaryBox;
  late Box stateBox;
  bool hiveReady = false;

  // Hardware
  final _player = AudioPlayer();
  final _rng = Random();
  CameraController? _cam;
  bool _camReady = false;

  int _tab = 1;
  String _guideSearch = '';
  String _guideRarityFilter = 'all';
  final _guideSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initHive();
    _initCamera();
  }

  @override
  void dispose() {
    // FIX 6: dispose camera, player, and controllers to avoid resource leaks
    _cam?.dispose();
    _player.dispose();
    _guideSearchController.dispose();
    super.dispose();
  }

  Future<void> _initHive() async {
    aviaryBox = await Hive.openBox<String>('aviary_v2');
    stateBox = await Hive.openBox('player_state');
    _restoreState();
    // FIX 7: mounted check after await
    if (!mounted) return;
    setState(() => hiveReady = true);
  }

  void _restoreState() {
    level = stateBox.get('level', defaultValue: 1);
    xp = stateBox.get('xp', defaultValue: 0);
    streak = stateBox.get('streak', defaultValue: 1);
    final saved = stateBox.get('achievements', defaultValue: <String>[]);
    unlockedAchievements = Set<String>.from(List<String>.from(saved));
  }

  void _persistState() {
    stateBox.put('level', level);
    stateBox.put('xp', xp);
    stateBox.put('streak', streak);
    stateBox.put('achievements', unlockedAchievements.toList());
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      // FIX 5: guard against empty camera list
      if (cameras.isEmpty) return;
      _cam = CameraController(cameras[0], ResolutionPreset.high);
      await _cam!.initialize();
      // FIX 7: mounted check after await
      if (!mounted) return;
      setState(() => _camReady = true);
    } catch (_) {
      // Camera unavailable — silently degrade
    }
  }

  Future<void> _takePhoto() async {
    final status = await Permission.camera.request();
    if (status.isGranted && (_cam == null || !_camReady)) {
      await _initCamera();
    }
    if (_cam == null || !_camReady) return;
    try {
      final file = await _cam!.takePicture();
      if (!mounted) return;
      await _simulateIdentify(File(file.path)); // FIX 1: dart:io imported
    } catch (_) {}
  }

  Future<void> _simulateIdentify(File _) async {
    final matchedBird = weightedRandomBird(_rng);

    // Show analysing dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🔬 Analysing...', style: TextStyle(color: Colors.amber)),
        content: const Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: Colors.amber),
          SizedBox(height: 16),
          Text('Processing photo...', style: TextStyle(color: Colors.white70)),
        ]),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    Navigator.pop(context);
    _showFoundDialog(matchedBird);
  }

  void _showFoundDialog(Bird bird) {
    final isUnknown = bird.rarity == 'unknown';
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Rarity badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: bird.rarityColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: bird.rarityColor),
                ),
                child: Text(
                  isUnknown ? 'NEW DISCOVERY' : bird.rarity.toUpperCase(),
                  style: TextStyle(color: bird.rarityColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ).animate().fadeIn().scale(),
              const SizedBox(height: 12),
              Text(
                isUnknown ? '🔭 ${bird.name}' : '✨ ${bird.name}',
                style: TextStyle(
                  color: isUnknown ? bird.rarityColor : Colors.amber,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 100.ms),
              Text(
                bird.scientificName,
                style: const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 12),
              if (isUnknown)
                Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: bird.rarityColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: bird.rarityColor.withOpacity(0.4)),
                  ),
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('❓', style: TextStyle(fontSize: 56)),
                      const SizedBox(height: 6),
                      Text('Not in our database yet',
                          style: TextStyle(color: bird.rarityColor, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ).animate().fadeIn(delay: 200.ms)
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _buildNetworkImage(bird.imageUrl, 220),
                ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.95, 0.95)),
              const SizedBox(height: 12),
              Text(bird.lore, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bolt, color: Colors.amber, size: 16),
                  Text(' +${bird.xp} XP', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white54),
                      child: const Text('Skip'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _addBird(bird);
                      },
                      child: const Text('Add to Aviary'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addBird(Bird bird) {
    if (!hiveReady) return;
    // FIX 2 & 3: audioUrl now exists; Box<String> stores name
    if (bird.audioUrl.isNotEmpty) {
      _player.setUrl(bird.audioUrl).then((_) => _player.play()).catchError((_) {});
    }

    bool didLevelUp = false;
    setState(() {
      // FIX 3: store bird name string, not Bird object
      aviaryBox.add(bird.name);
      xp += bird.xp;

      // Level up loop
      while (xp >= xpForNextLevel(level)) {
        xp -= xpForNextLevel(level);
        level++;
        didLevelUp = true;
      }
    });

    _persistState();
    if (didLevelUp) _showLevelUp();
    _checkAchievements(bird);
  }

  void _showLevelUp() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.amber,
        duration: const Duration(seconds: 3),
        content: Row(children: [
          const Text('🎉 LEVEL UP! ', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
          Text('You are now a ${levelTitle(level)}!', style: const TextStyle(color: Colors.black)),
        ]),
      ),
    );
  }

  void _checkAchievements(Bird bird) {
    final collected = aviaryBox.values.toSet().length;
    final newOnes = <String>[];

    void tryUnlock(String key) {
      if (!unlockedAchievements.contains(key)) {
        unlockedAchievements.add(key);
        newOnes.add(key);
      }
    }

    if (collected >= 1) tryUnlock('first_bird');
    if (collected >= 5) tryUnlock('five_species');
    if (collected >= 10) tryUnlock('ten_species');
    if (collected >= 20) tryUnlock('twenty_species');
    if (bird.rarity == 'rare' || bird.rarity == 'legendary') tryUnlock('rare_find');
    if (bird.rarity == 'legendary') tryUnlock('legendary_find');
    if (level >= 5) tryUnlock('level_5');
    if (level >= 10) tryUnlock('level_10');
    if (level >= 20) tryUnlock('level_20');

    if (newOnes.isNotEmpty) _persistState();

    for (final key in newOnes) {
      final a = achievements[key]!;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1A2F1F),
            duration: const Duration(seconds: 4),
            content: Row(children: [
              Text(a.$1, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Achievement Unlocked!', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                Text(a.$2, style: const TextStyle(color: Colors.white70)),
              ]),
            ]),
          ),
        );
      });
    }
  }

  void _showBirdDetail(Bird bird) {
    showModalBottomSheet(
      context: context,
      backgroundColor: bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
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
                  color: bird.rarityColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: bird.rarityColor),
                ),
                child: Text(
                  bird.rarity == 'unknown' ? 'NEW DISCOVERY' : bird.rarity.toUpperCase(),
                  style: TextStyle(color: bird.rarityColor, fontWeight: FontWeight.bold),
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
            if (bird.rarity == 'unknown')
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: bird.rarityColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: bird.rarityColor.withOpacity(0.4)),
                ),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('❓', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 6),
                    Text('Photo not yet in database',
                        style: TextStyle(color: bird.rarityColor)),
                  ]),
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildNetworkImage(bird.imageUrl, 240),
              ),
            const SizedBox(height: 16),
            _detailRow(Icons.auto_stories, 'Lore', bird.lore),
            _detailRow(Icons.landscape, 'Habitat', bird.habitat),
            _detailRow(Icons.eco, 'Conservation', bird.conservationStatus),
            _detailRow(Icons.bolt, 'XP Value', '+${bird.xp} XP'),
            if (bird.audioUrl.isNotEmpty) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  _player.setUrl(bird.audioUrl).then((_) => _player.play()).catchError((_) {});
                },
                icon: const Icon(Icons.volume_up),
                label: const Text('Play Bird Call'),
              ),
            ],
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
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

  Widget _buildNetworkImage(String url, double height) {
    return CachedNetworkImage(
      imageUrl: url,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: (_, __) => Shimmer.fromColors(
        baseColor: bgCard,
        highlightColor: const Color(0xFF2A3F2F),
        child: Container(height: height, color: bgCard),
      ),
      errorWidget: (_, __, ___) => Container(
        height: height,
        color: bgCard,
        child: const Center(child: Icon(Icons.broken_image, color: Colors.white24, size: 48)),
      ),
    );
  }

  // ─── Tabs ─────────────────────────────────────────────────────────────────

  Widget _buildIdentifyTab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('AviQuest', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.amber))
            .animate().fadeIn().slideY(begin: -0.3),
        const Text('Point at a bird and identify it!',
            style: TextStyle(color: Colors.white54)).animate().fadeIn(delay: 100.ms),
        const SizedBox(height: 24),
        if (_camReady && _cam != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.amber.withOpacity(0.5), width: 2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: CameraPreview(_cam!),
            ),
          ).animate().fadeIn(delay: 200.ms).scale()
        else
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: bgCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white12),
            ),
            child: const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.camera_alt, size: 64, color: Colors.white24),
                SizedBox(height: 8),
                Text('Camera unavailable', style: TextStyle(color: Colors.white38)),
              ]),
            ),
          ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _takePhoto,
              icon: const Icon(Icons.camera_alt, size: 28),
              label: const Text('Identify by Photo'),
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3),
            const SizedBox(width: 16),
            OutlinedButton.icon(
              onPressed: () {
                // Simulate audio identification (same random logic)
                _simulateIdentify(File(''));
              },
              icon: const Icon(Icons.mic, color: Colors.amber),
              label: const Text('By Call', style: TextStyle(color: Colors.amber)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.amber),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.3),
          ],
        ),
      ],
    );
  }

  Widget _buildAviaryTab() {
    if (!hiveReady) {
      return const Center(child: CircularProgressIndicator(color: Colors.amber));
    }

    // FIX 4: ValueListenableBuilder<Box<String>> — correct type
    return ValueListenableBuilder<Box<String>>(
      valueListenable: aviaryBox.listenable(),
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
                onPressed: () => setState(() => _tab = 1),
                child: const Text('Go Identify'),
              ),
            ]),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, childAspectRatio: 0.82, mainAxisSpacing: 12, crossAxisSpacing: 12,
          ),
          itemCount: box.length,
          itemBuilder: (c, i) {
            final birdName = box.getAt(i);
            if (birdName == null) return const SizedBox.shrink(); // FIX 5: null guard
            final bird = birds.firstWhere(
              (b) => b.name == birdName,
              orElse: () => unknownBird(birdName),
            );
            return GestureDetector(
              onTap: () => _showBirdDetail(bird),
              child: Card(
                color: bgCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: bird.rarityColor.withOpacity(0.6), width: 1.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (bird.imageUrl.isNotEmpty)
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
                      )
                    else
                      Container(
                        color: bgCard,
                        child: const Center(child: Text('❓', style: TextStyle(fontSize: 48))),
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
                          Text(bird.rarity,
                            style: TextStyle(color: bird.rarityColor, fontSize: 11)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
            );
          },
        );
      },
    );
  }

  Widget _buildFieldGuideTab() {
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
            controller: _guideSearchController,
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
                  onTap: () => _showBirdDetail(bird),
                ),
              ).animate().fadeIn(delay: Duration(milliseconds: i * 30));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMapTab() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.map, size: 80, color: Colors.white24)
            .animate().fadeIn().scale(),
        const SizedBox(height: 16),
        const Text('Interactive Map', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber))
            .animate().fadeIn(delay: 100.ms),
        const SizedBox(height: 8),
        const Text('Hotspot mapping & community sightings\ncoming soon!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54))
            .animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgCard,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.people, color: Colors.amber),
            SizedBox(width: 8),
            Text('1,247 sightings logged today 🌍', style: TextStyle(color: Colors.white70)),
          ]),
        ).animate().fadeIn(delay: 300.ms),
      ]),
    );
  }

  Widget _buildProfileTab() {
    final nextLevelXp = xpForNextLevel(level);
    final progress = xp / nextLevelXp;
    final collectedCount = hiveReady ? aviaryBox.length : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Avatar ring
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Colors.amber, Color(0xFF4CAF50)]),
              boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.4), blurRadius: 20, spreadRadius: 4)],
            ),
            child: const Center(child: Text('🦅', style: TextStyle(fontSize: 48))),
          ).animate().fadeIn().scale(),
          const SizedBox(height: 16),
          Text(levelTitle(level),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.amber))
              .animate().fadeIn(delay: 100.ms),
          Text('Level $level', style: const TextStyle(fontSize: 16, color: Colors.white54)),
          const SizedBox(height: 20),
          // XP Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('XP Progress', style: TextStyle(color: Colors.white70)),
                Text('$xp / $nextLevelXp', style: const TextStyle(color: Colors.amber)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 12,
                  backgroundColor: bgCard,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 150.ms),
          const SizedBox(height: 20),
          // Stats row
          Row(
            children: [
              _statCard('🔥', '$streak', 'Day Streak'),
              const SizedBox(width: 12),
              _statCard('🐦', '$collectedCount', 'Species'),
              const SizedBox(width: 12),
              _statCard('🏆', '${unlockedAchievements.length}', 'Badges'),
            ],
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 24),
          // Achievements
          Align(
            alignment: Alignment.centerLeft,
            child: const Text('Achievements', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: achievements.entries.map((e) {
              final unlocked = unlockedAchievements.contains(e.key);
              return Tooltip(
                message: unlocked ? e.value.$3 : '???',
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    color: unlocked ? Colors.amber.withOpacity(0.15) : bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: unlocked ? Colors.amber : Colors.white12),
                  ),
                  child: Center(
                    child: Text(
                      unlocked ? e.value.$1 : '🔒',
                      style: TextStyle(fontSize: 28, color: unlocked ? null : Colors.white24),
                    ),
                  ),
                ),
              );
            }).toList(),
          ).animate().fadeIn(delay: 250.ms),
          const SizedBox(height: 24),
          // Eco impact
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Text('🌍', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Eco Impact', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                Text('Your sightings help scientists track bird populations worldwide.',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              ])),
            ]),
          ).animate().fadeIn(delay: 300.ms),
        ],
      ),
    );
  }

  Widget _statCard(String emoji, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: bgCard, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amber)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ]),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _buildMapTab(),
      _buildIdentifyTab(),
      _buildAviaryTab(),
      _buildFieldGuideTab(),
      _buildProfileTab(),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _tab, children: tabs),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) {
          HapticFeedback.selectionClick();
          setState(() => _tab = i);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Identify'),
          BottomNavigationBarItem(icon: Icon(Icons.collections), label: 'Aviary'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Field Guide'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Me'),
        ],
      ),
    );
  }
}
