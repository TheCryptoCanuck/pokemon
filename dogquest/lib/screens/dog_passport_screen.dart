import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dogquest/constants.dart';
import 'package:dogquest/models/dog.dart';
import 'package:dogquest/services/dog_service.dart';
import 'package:dogquest/services/my_dog_service.dart';
import 'package:dogquest/services/player_service.dart';
import 'package:dogquest/widgets/dog_passport_card.dart';

/// Full-screen view of the dog passport card, with share/save functionality.
class DogPassportScreen extends ConsumerStatefulWidget {
  final String dogName;

  const DogPassportScreen({super.key, required this.dogName});

  @override
  ConsumerState<DogPassportScreen> createState() => _DogPassportScreenState();
}

class _DogPassportScreenState extends ConsumerState<DogPassportScreen> {
  final _repaintKey = GlobalKey();
  bool _sharing = false;

  @override
  Widget build(BuildContext context) {
    final dog = ref.read(myDogServiceProvider).getDog(widget.dogName);
    if (dog == null) {
      return Scaffold(
        backgroundColor: bgDeep,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(
          child: Text('Dog not found', style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    final playerState = ref.watch(playerProvider);
    final Dog? breedData = dog.breed != null
        ? ref.read(dogServiceProvider).lookupByCommonName(dog.breed!)
        : null;

    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Dog Passport',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _sharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.amber,
                    ),
                  )
                : const Icon(Icons.share, color: Colors.amber),
            onPressed: _sharing ? null : () => _sharePassport(context),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              // The passport card (wrapped for screenshot capture)
              RepaintBoundary(
                key: _repaintKey,
                child: DogPassportCard(
                  profile: dog,
                  breedData: breedData,
                  playerLevel: playerState.level,
                  playerTitle: _playerTitle(playerState.level),
                ),
              ).animate().fadeIn(duration: 500.ms).scale(
                    begin: const Offset(0.95, 0.95),
                    curve: Curves.easeOutBack,
                  ),

              const SizedBox(height: 32),

              // Share button
              SizedBox(
                width: 280,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _sharing ? null : () => _sharePassport(context),
                  icon: const Icon(Icons.share, size: 20),
                  label: const Text(
                    'Share Passport',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4874E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: const Color(0xFFD4874E).withValues(alpha: 0.4),
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),

              const SizedBox(height: 12),

              Text(
                'Scan the QR code to verify your pup!',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 12,
                ),
              ).animate().fadeIn(delay: 500.ms),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sharePassport(BuildContext context) async {
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/dogquest_passport_${widget.dogName.replaceAll(' ', '_')}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());

      if (!mounted) return;

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Check out my dog\'s Hound Passport!',
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Could not share: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  String _playerTitle(int level) {
    if (level >= 50) return 'Dog Whisperer';
    if (level >= 40) return 'Pack Leader';
    if (level >= 30) return 'Best in Show';
    if (level >= 20) return 'Dog Walker';
    if (level >= 10) return 'Puppy Trainer';
    return 'Pup Explorer';
  }
}
