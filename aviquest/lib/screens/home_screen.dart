import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:just_audio/just_audio.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../constants.dart';
import '../models/bird.dart';
import '../services/bird_service.dart';
import '../services/player_service.dart';
import '../widgets/bird_detail_sheet.dart';
import '../widgets/bird_network_image.dart';
import 'identify_tab.dart';
import 'aviary_tab.dart';
import 'field_guide_tab.dart';
import 'map_tab.dart';
import 'profile_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int level;
  late int xp;
  late int streak;
  late Set<String> unlockedAchievements;

  late Box<String> aviaryBox;
  bool hiveReady = false;

  final _player = AudioPlayer();
  final _rng = Random();
  CameraController? _cam;
  bool _camReady = false;

  int _tab = 1;

  @override
  void initState() {
    super.initState();
    level = PlayerService.level;
    xp = PlayerService.xp;
    streak = PlayerService.streak;
    unlockedAchievements = PlayerService.unlockedAchievements;
    _initHive();
    _initCamera();
  }

  @override
  void dispose() {
    _cam?.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _initHive() async {
    aviaryBox = await Hive.openBox<String>('aviary_v2');
    if (!mounted) return;
    setState(() => hiveReady = true);
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      _cam = CameraController(cameras[0], ResolutionPreset.high);
      await _cam!.initialize();
      if (!mounted) return;
      setState(() => _camReady = true);
    } catch (_) {
      // Camera unavailable — silently degrade
    }
  }

  Future<void> _takePhoto() async {
    await Permission.camera.request();
    if (_cam == null || !_camReady) return;
    try {
      final file = await _cam!.takePicture();
      if (!mounted) return;
      await _simulateIdentify(File(file.path));
    } catch (_) {}
  }

  Future<void> _simulateIdentify(File _) async {
    final matchedBird = BirdService.weightedRandom(_rng);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🔬 Analysing...',
            style: TextStyle(color: Colors.amber)),
        content: const Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: Colors.amber),
          SizedBox(height: 16),
          Text('Processing photo...',
              style: TextStyle(color: Colors.white70)),
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: bird.rarityColor.withAlpha(51),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: bird.rarityColor),
                ),
                child: Text(
                  isUnknown ? 'NEW DISCOVERY' : bird.rarity.toUpperCase(),
                  style: TextStyle(
                      color: bird.rarityColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
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
                style: const TextStyle(
                    color: Colors.white54, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 12),
              if (isUnknown)
                Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: bird.rarityColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: bird.rarityColor.withAlpha(102)),
                  ),
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('❓', style: TextStyle(fontSize: 56)),
                      const SizedBox(height: 6),
                      Text('Not in our database yet',
                          style: TextStyle(
                              color: bird.rarityColor,
                              fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ).animate().fadeIn(delay: 200.ms)
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BirdNetworkImage(url: bird.imageUrl, height: 220),
                )
                    .animate()
                    .fadeIn(delay: 200.ms)
                    .scale(begin: const Offset(0.95, 0.95)),
              const SizedBox(height: 12),
              Text(bird.lore,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bolt, color: Colors.amber, size: 16),
                  Text(' +${bird.xp} XP',
                      style: const TextStyle(
                          color: Colors.amber, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white54),
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
    if (bird.audioUrl.isNotEmpty) {
      _player
          .setUrl(bird.audioUrl)
          .then((_) => _player.play())
          .catchError((_) {});
    }

    setState(() {
      aviaryBox.add(bird.name);
      xp += bird.xp;

      while (xp >= xpForNextLevel(level)) {
        xp -= xpForNextLevel(level);
        level++;
        _showLevelUp();
      }

      // Persist stats
      PlayerService.level = level;
      PlayerService.xp = xp;

      _checkAchievements(bird);
    });
  }

  void _showLevelUp() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.amber,
        duration: const Duration(seconds: 3),
        content: Row(children: [
          const Text('🎉 LEVEL UP! ',
              style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          Text('You are now a ${levelTitle(level)}!',
              style: const TextStyle(color: Colors.black)),
        ]),
      ),
    );
  }

  void _checkAchievements(Bird bird) {
    final collected = aviaryBox.length;
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
    if (bird.rarity == 'rare' || bird.rarity == 'legendary') {
      tryUnlock('rare_find');
    }
    if (bird.rarity == 'legendary') tryUnlock('legendary_find');
    if (level >= 5) tryUnlock('level_5');
    if (level >= 10) tryUnlock('level_10');
    if (level >= 20) tryUnlock('level_20');

    if (newOnes.isNotEmpty) {
      PlayerService.unlockedAchievements = unlockedAchievements;
    }

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
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Achievement Unlocked!',
                        style: TextStyle(
                            color: Colors.amber, fontWeight: FontWeight.bold)),
                    Text(a.$2,
                        style: const TextStyle(color: Colors.white70)),
                  ]),
            ]),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const MapTab(),
      IdentifyTab(
        cam: _cam,
        camReady: _camReady,
        onTakePhoto: _takePhoto,
        onListenCall: () => _simulateIdentify(File('')),
      ),
      if (hiveReady)
        AviaryTab(
          aviaryBox: aviaryBox,
          hiveReady: hiveReady,
          onBirdTapped: (bird) =>
              BirdDetailSheet.show(context, bird, _player),
          onGoIdentify: () => setState(() => _tab = 1),
        )
      else
        const Center(
            child: CircularProgressIndicator(color: Colors.amber)),
      FieldGuideTab(
        onBirdTapped: (bird) =>
            BirdDetailSheet.show(context, bird, _player),
      ),
      ProfileTab(
        level: level,
        xp: xp,
        streak: streak,
        collectedCount: hiveReady ? aviaryBox.length : 0,
        unlockedAchievements: unlockedAchievements,
      ),
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
          BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt), label: 'Identify'),
          BottomNavigationBarItem(
              icon: Icon(Icons.collections), label: 'Aviary'),
          BottomNavigationBarItem(
              icon: Icon(Icons.menu_book), label: 'Field Guide'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Me'),
        ],
      ),
    );
  }
}
