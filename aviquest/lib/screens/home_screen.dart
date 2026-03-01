import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';

import '../constants.dart';
import '../helpers/game_helpers.dart';
import '../models/bird.dart';
import '../widgets/bird_detail_sheet.dart';
import '../widgets/bird_found_dialog.dart';
import 'aviary_tab.dart';
import 'field_guide_tab.dart';
import 'identify_tab.dart';
import 'map_tab.dart';
import 'profile_tab.dart';

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

  // Storage
  late Box<String> aviaryBox;
  bool hiveReady = false;

  // Hardware
  final _player = AudioPlayer();
  final _rng = Random();
  CameraController? _cam;
  bool _camReady = false;

  int _tab = 1;

  @override
  void initState() {
    super.initState();
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
    final matchedBird = weightedRandomBird(_rng);

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
    showDialog(
      context: context,
      builder: (ctx) => BirdFoundDialog(
        bird: bird,
        onAdd: () => _addBird(bird),
      ),
    );
  }

  void _addBird(Bird bird) {
    if (bird.audioUrl.isNotEmpty) {
      _player.setUrl(bird.audioUrl).then((_) => _player.play()).catchError((_) {});
    }

    setState(() {
      aviaryBox.add(bird.name);
      xp += bird.xp;

      while (xp >= xpForNextLevel(level)) {
        xp -= xpForNextLevel(level);
        level++;
        _showLevelUp();
      }

      _checkAchievements(bird);
    });
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
    if (bird.rarity == 'rare' || bird.rarity == 'legendary') tryUnlock('rare_find');
    if (bird.rarity == 'legendary') tryUnlock('legendary_find');
    if (level >= 5) tryUnlock('level_5');
    if (level >= 10) tryUnlock('level_10');
    if (level >= 20) tryUnlock('level_20');

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
                const Text('Achievement Unlocked!', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                Text(a.$2, style: const TextStyle(color: Colors.white70)),
              ]),
            ]),
          ),
        );
      });
    }
  }

  void _showBirdDetail(Bird bird) {
    BirdDetailSheet.show(context, bird, _player);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const MapTab(),
      IdentifyTab(
        cam: _cam,
        camReady: _camReady,
        onTakePhoto: _takePhoto,
        onIdentifyByCall: () => _simulateIdentify(File('')),
      ),
      AviaryTab(
        aviaryBox: hiveReady ? aviaryBox : Hive.box<String>('aviary_v2'),
        hiveReady: hiveReady,
        onGoIdentify: () => setState(() => _tab = 1),
        onBirdTap: _showBirdDetail,
      ),
      FieldGuideTab(onBirdTap: _showBirdDetail),
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
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Identify'),
          BottomNavigationBarItem(icon: Icon(Icons.collections), label: 'Aviary'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Field Guide'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Me'),
        ],
      ),
    );
  }
}
