import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';

import '../constants.dart';
import '../helpers/game_helpers.dart';
import '../models/bird.dart';
import '../services/aviary_service.dart';
import '../services/bird_service.dart';
import '../services/identification_service.dart';
import '../services/player_service.dart';
import '../widgets/bird_found_dialog.dart';

class IdentifyScreen extends ConsumerStatefulWidget {
  const IdentifyScreen({super.key});

  @override
  ConsumerState<IdentifyScreen> createState() => _IdentifyScreenState();
}

class _IdentifyScreenState extends ConsumerState<IdentifyScreen> {
  final _player = AudioPlayer();
  CameraController? _cam;
  bool _camReady = false;

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
      await _identify(File(file.path));
    } catch (_) {}
  }

  Future<void> _identify(File imageFile) async {
    final idService = ref.read(identificationServiceProvider);

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

    final matchedBird = await idService.identify(imageFile);
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
    if (!aviarySvc.add(bird.name)) return;

    if (bird.audioUrl.isNotEmpty) {
      _player.setUrl(bird.audioUrl).then((_) => _player.play()).catchError((_) {});
    }

    final playerNotifier = ref.read(playerProvider.notifier);
    final newAchievements = playerNotifier.addXpForBird(bird, aviarySvc.count);

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

  @override
  Widget build(BuildContext context) {
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
              onPressed: () => _identify(File('')),
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
}
