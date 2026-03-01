import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';

import '../constants.dart';
import '../helpers/game_helpers.dart';
import '../models/bird.dart';
import '../services/aviary_service.dart';
import '../services/bird_service.dart';
import '../services/player_service.dart';
import '../widgets/bird_detail_sheet.dart';
import '../widgets/bird_found_dialog.dart';
import 'aviary_tab.dart';
import 'field_guide_tab.dart';
import 'identify_tab.dart';
import 'map_tab.dart';
import 'profile_tab.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _player = AudioPlayer();
  final _rng = Random();
  CameraController? _cam;
  bool _camReady = false;
  int _tab = 1;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _cam?.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      _cam = CameraController(cameras[0], ResolutionPreset.high);
      await _cam!.initialize();
      if (!mounted) return;
      setState(() => _camReady = true);
    } catch (_) {}
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
    final birdSvc = ref.read(birdServiceProvider);
    final matchedBird = birdSvc.weightedRandomBird(_rng);

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
    final aviarySvc = ref.read(aviaryServiceProvider);
    final alreadyOwned = aviarySvc.contains(bird.name);
    showDialog(
      context: context,
      builder: (ctx) => BirdFoundDialog(
        bird: bird,
        alreadyOwned: alreadyOwned,
        onAdd: () => _addBird(bird),
      ),
    );
  }

  void _addBird(Bird bird) {
    final aviarySvc = ref.read(aviaryServiceProvider);
    if (!aviarySvc.add(bird.name)) return; // duplicate

    if (bird.audioUrl.isNotEmpty) {
      _player.setUrl(bird.audioUrl).then((_) => _player.play()).catchError((_) {});
    }

    final playerNotifier = ref.read(playerProvider.notifier);
    final newAchievements = playerNotifier.addXpForBird(bird, aviarySvc.count);
    final playerState = ref.read(playerProvider);

    // Show level-up if level changed
    if (playerState.level > 1) {
      // We check fresh state after XP award
    }

    for (final key in newAchievements) {
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
    final playerState = ref.watch(playerProvider);
    final aviarySvc = ref.read(aviaryServiceProvider);

    final tabs = [
      const MapTab(),
      IdentifyTab(
        cam: _cam,
        camReady: _camReady,
        onTakePhoto: _takePhoto,
        onIdentifyByCall: () => _simulateIdentify(File('')),
      ),
      AviaryTab(
        aviaryBox: aviarySvc.box,
        onGoIdentify: () => setState(() => _tab = 1),
        onBirdTap: _showBirdDetail,
      ),
      FieldGuideTab(onBirdTap: _showBirdDetail),
      ProfileTab(
        playerState: playerState,
        collectedCount: aviarySvc.count,
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
