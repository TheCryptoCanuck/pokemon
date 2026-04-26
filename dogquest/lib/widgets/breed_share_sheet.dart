import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:dogquest/constants.dart';
import 'package:dogquest/models/dog.dart';
import 'package:dogquest/services/analytics_service.dart';
import 'package:dogquest/services/kennel_service.dart';
import 'package:dogquest/services/dog_service.dart';
import 'package:dogquest/services/player_service.dart';
import 'package:dogquest/widgets/breed_share_card.dart';

/// Shows a bottom sheet with a breed card preview and one-tap share buttons.
class BreedShareSheet {
  static void show(BuildContext context, Dog dog) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BreedShareSheetContent(dog: dog),
    );
  }
}

class _BreedShareSheetContent extends ConsumerStatefulWidget {
  final Dog dog;
  const _BreedShareSheetContent({required this.dog});

  @override
  ConsumerState<_BreedShareSheetContent> createState() =>
      _BreedShareSheetContentState();
}

class _BreedShareSheetContentState
    extends ConsumerState<_BreedShareSheetContent> {
  final GlobalKey _cardKey = GlobalKey();
  bool _isSharing = false;
  bool _shared = false;

  Dog get dog => widget.dog;

  Future<File?> _captureCard() async {
    await Future.delayed(const Duration(milliseconds: 300));

    final boundary =
        _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;

    final bytes = byteData.buffer.asUint8List();
    final tempDir = await getTemporaryDirectory();
    final file =
        File('${tempDir.path}/dogquest_${dog.name.replaceAll(' ', '_')}.png');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> _shareToGeneric() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final file = await _captureCard();
      if (file == null) return;

      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'I spotted a ${dog.name} on DogQuest! ${dog.rarity == Rarity.legendary ? "LEGENDARY find!" : dog.rarity == Rarity.rare ? "Rare find!" : ""}',
      );

      _trackShare('generic');
      if (mounted) setState(() => _shared = true);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _shareToStories() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final file = await _captureCard();
      if (file == null) return;

      // Use generic share — Instagram/TikTok will appear in the system share sheet
      // and handle story formatting automatically from the image
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Spotted on DogQuest!',
      );

      _trackShare('stories');
      if (mounted) setState(() => _shared = true);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  void _trackShare(String method) {
    ref.read(analyticsProvider).track('breed_card_shared', {
      'dog_name': dog.name,
      'rarity': dog.rarity.name,
      'method': method,
    });
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final kennelSvc = ref.read(kennelServiceProvider);
    final dogSvc = ref.read(dogServiceProvider);

    return Container(
      decoration: const BoxDecoration(
        color: bgDeep,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            _shared ? 'Shared!' : 'Share your catch',
            style: TextStyle(
              color: _shared ? Colors.green : Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn(),

          const SizedBox(height: 16),

          // Card preview (scaled down for preview, full-res for capture)
          SizedBox(
            height: 340,
            child: Center(
              child: Transform.scale(
                scale: 0.53,
                child: RepaintBoundary(
                  key: _cardKey,
                  child: Material(
                    color: Colors.transparent,
                    child: BreedShareCard(
                      dog: dog,
                      playerLevel: playerState.level,
                      playerTitle: playerState.title,
                      kennelCount: kennelSvc.count,
                      totalBreeds: dogSvc.all.length,
                    ),
                  ),
                ),
              ),
            ),
          )
              .animate()
              .fadeIn(delay: 100.ms)
              .scale(begin: const Offset(0.95, 0.95)),

          const SizedBox(height: 16),

          // Share buttons row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _ShareButton(
                  icon: Icons.auto_awesome,
                  label: 'Stories',
                  color: const Color(0xFFE1306C),
                  onTap: _isSharing ? null : _shareToStories,
                ),
                const SizedBox(width: 12),
                _ShareButton(
                  icon: Icons.chat_bubble_outline,
                  label: 'Message',
                  color: const Color(0xFF25D366),
                  onTap: _isSharing ? null : _shareToGeneric,
                ),
                const SizedBox(width: 12),
                _ShareButton(
                  icon: Icons.share_outlined,
                  label: 'More',
                  color: Colors.white54,
                  onTap: _isSharing ? null : _shareToGeneric,
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms),

          if (_isSharing) ...[
            const SizedBox(height: 16),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.amber,
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Dismiss
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              _shared ? 'Done' : 'Not now',
              style: TextStyle(
                color: _shared ? Colors.green : Colors.white38,
                fontSize: 14,
              ),
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ShareButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
