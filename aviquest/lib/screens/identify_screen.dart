import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';

import '../constants.dart';
import '../helpers/game_helpers.dart';
import '../models/bird.dart';
import '../services/analytics_service.dart';
import '../services/aviary_service.dart';
import '../services/bird_service.dart';
import '../services/identification_service.dart';
import '../services/daily_bird_service.dart';
import '../services/player_service.dart';
import '../services/sighting_service.dart';
import '../widgets/bird_found_dialog.dart';
import '../widgets/daily_bird_card.dart';
import '../widgets/seasonal_event_banner.dart';

final _log = Logger('IdentifyScreen');

class IdentifyScreen extends ConsumerStatefulWidget {
  const IdentifyScreen({super.key});

  @override
  ConsumerState<IdentifyScreen> createState() => _IdentifyScreenState();
}

class _IdentifyScreenState extends ConsumerState<IdentifyScreen> {
  final _player = AudioPlayer();
  CameraController? _cam;
  bool _camReady = false;
  String? _cameraError;

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
      if (cameras.isEmpty) {
        setState(() => _cameraError = 'No camera found on this device');
        return;
      }
      _cam = CameraController(cameras[0], ResolutionPreset.high);
      await _cam!.initialize();
      if (!mounted) return;
      setState(() => _camReady = true);
    } catch (e) {
      _log.warning('Camera init failed', e);
      if (!mounted) return;
      setState(() => _cameraError = 'Camera unavailable: ${_friendlyError(e)}');
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('permission') || msg.contains('Permission')) {
      return 'Camera permission denied';
    }
    if (msg.contains('CameraAccessDenied')) {
      return 'Camera access denied — check Settings';
    }
    return 'Could not start camera';
  }

  Future<void> _takePhoto() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission is required to identify birds')),
      );
      return;
    }
    if (_cam == null || !_camReady) return;
    try {
      final file = await _cam!.takePicture();
      if (!mounted) return;
      ref.read(analyticsProvider).track('identify_attempted', {
        'method': 'photo',
        'model_loaded': ref.read(identificationServiceProvider).isModelLoaded,
      });
      await _identify(File(file.path));
    } catch (e) {
      _log.warning('Photo capture failed', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not capture photo — please try again')),
      );
    }
  }

  Future<void> _identify(File imageFile) async {
    final idService = ref.read(identificationServiceProvider);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          idService.isModelLoaded ? '🔬 Identifying...' : '🔬 Analysing...',
          style: const TextStyle(color: Colors.amber),
        ),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: Colors.amber),
          const SizedBox(height: 16),
          Text(
            idService.isModelLoaded
                ? 'Running bird classifier...'
                : 'Processing photo...',
            style: const TextStyle(color: Colors.white70),
          ),
        ]),
      ),
    );

    final results = await idService.identify(imageFile);
    if (!mounted) return;
    Navigator.pop(context); // dismiss loading dialog

    if (results.isEmpty) {
      ref.read(analyticsProvider).track('identify_failed', {'method': 'photo'});
      _showNoResultDialog();
      return;
    }

    final top = results.first;
    ref.read(analyticsProvider).track('identify_succeeded', {
      'bird_name': top.bird.name,
      'rarity': top.bird.rarity.name,
      'confidence': top.confidence,
      'source': top.source,
      'alternative_count': results.length - 1,
    });

    // Log sighting regardless of whether added to aviary
    ref.read(sightingServiceProvider).log(Sighting(
      birdName: top.bird.name,
      timestamp: DateTime.now(),
      confidence: top.confidence,
      source: top.source,
    ));
    ref.read(playerProvider.notifier).recordSighting();

    _showFoundDialog(results);
  }

  void _showNoResultDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('No match found', style: TextStyle(color: Colors.amber)),
        content: const Text(
          'Could not identify a bird in this photo. Try getting a clearer shot with the bird centered in frame.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _showFoundDialog(List<IdentificationResult> results) {
    final topResult = results.first;
    final alternatives = results.length > 1 ? results.sublist(1) : <IdentificationResult>[];
    final aviarySvc = ref.read(aviaryServiceProvider);
    final alreadyOwned = aviarySvc.contains(topResult.bird.name);

    showDialog(
      context: context,
      builder: (ctx) => BirdFoundDialog(
        bird: topResult.bird,
        confidence: topResult.confidence,
        source: topResult.source,
        alternatives: alternatives,
        alreadyOwned: alreadyOwned,
        onAdd: () => _addBird(topResult.bird),
        onSelectAlternative: (alt) {
          ref.read(analyticsProvider).track('alternative_selected', {
            'original_bird': topResult.bird.name,
            'selected_bird': alt.bird.name,
          });
          Navigator.pop(ctx);
          _showFoundDialog([alt, ...results.where((r) => r != alt)]);
        },
      ),
    );
  }

  void _addBird(Bird bird) {
    final aviarySvc = ref.read(aviaryServiceProvider);
    if (!aviarySvc.add(bird.name)) {
      ref.read(analyticsProvider).track('bird_skipped', {
        'bird_name': bird.name,
        'rarity': bird.rarity.name,
        'already_owned': true,
      });
      return;
    }

    ref.read(analyticsProvider).track('bird_added_to_aviary', {
      'bird_name': bird.name,
      'rarity': bird.rarity.name,
      'xp_earned': bird.xp,
      'aviary_count': aviarySvc.count,
    });

    if (bird.audioUrl.isNotEmpty) {
      _player.setUrl(bird.audioUrl).then((_) => _player.play()).catchError((e) {
        _log.fine('Audio playback failed for ${bird.name}: $e');
      });
    }

    // Check daily bird bonus
    final dailySvc = ref.read(dailyBirdServiceProvider);
    if (bird.name == dailySvc.todaysBird.name) {
      final bonus = dailySvc.claimDailyBonus();
      if (bonus > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.amber.withOpacity(0.9),
            duration: const Duration(seconds: 3),
            content: Row(children: [
              const Text('⭐', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Daily Bird Bonus!', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                Text('+$bonus bonus XP', style: const TextStyle(color: Colors.black87)),
              ]),
            ]),
          ),
        );
      }
    }

    final playerNotifier = ref.read(playerProvider.notifier);
    final birdSvc = ref.read(birdServiceProvider);
    final collectedBirds = aviarySvc.all
        .map((name) => birdSvc.lookup(name))
        .whereType<Bird>()
        .toList();
    final newAchievements = playerNotifier.addXpForBird(
      bird,
      aviarySvc.count,
      collectedBirds: collectedBirds,
      allBirds: birdSvc.all,
    );

    for (final key in newAchievements) {
      final a = achievements[key]!;
      ref.read(analyticsProvider).track('achievement_unlocked', {
        'achievement_key': key,
        'achievement_name': a.$2,
      });
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

    // Encounter milestone notification
    final sightingSvc = ref.read(sightingServiceProvider);
    final milestone = sightingSvc.encounterMilestoneText(bird.name);
    if (milestone != null && mounted) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.deepPurple.withOpacity(0.9),
            duration: const Duration(seconds: 3),
            content: Row(children: [
              const Text('🔄', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(child: Text(milestone, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
            ]),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final idService = ref.watch(identificationServiceProvider);
    return SingleChildScrollView(
      child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        const Text('AviQuest', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.amber))
            .animate().fadeIn().slideY(begin: -0.3),
        const Text('Point at a bird and identify it!',
            style: TextStyle(color: Colors.white54)).animate().fadeIn(delay: 100.ms),
        if (!idService.isModelLoaded)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.4)),
              ),
              child: const Text(
                'Demo mode — add bird_model.tflite for real ID',
                style: TextStyle(color: Colors.orange, fontSize: 11),
              ),
            ),
          ).animate().fadeIn(delay: 400.ms),
        const SizedBox(height: 12),
        const SeasonalEventBanner(),
        const DailyBirdCard(),
        const SizedBox(height: 12),
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
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.camera_alt, size: 64, color: Colors.white24),
                const SizedBox(height: 8),
                Text(
                  _cameraError ?? 'Camera loading...',
                  style: const TextStyle(color: Colors.white38),
                  textAlign: TextAlign.center,
                ),
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
                ref.read(analyticsProvider).track('identify_attempted', {
                  'method': 'audio',
                  'model_loaded': false,
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Audio identification coming soon!')),
                );
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
        const SizedBox(height: 16),
      ],
      ),
    );
  }
}
