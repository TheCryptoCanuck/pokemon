import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dogquest/constants.dart';
import 'package:dogquest/models/lost_dog_report.dart';
import 'package:dogquest/widgets/lost_dog_poster_card.dart';

/// Full-screen view of a lost dog poster, with share and save functionality.
class ShareLostDogScreen extends StatefulWidget {
  final LostDogReport report;

  const ShareLostDogScreen({super.key, required this.report});

  @override
  State<ShareLostDogScreen> createState() => _ShareLostDogScreenState();
}

class _ShareLostDogScreenState extends State<ShareLostDogScreen> {
  final _repaintKey = GlobalKey();
  bool _sharing = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Lost Dog Poster',
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
                      color: Color(0xFFD84315),
                    ),
                  )
                : const Icon(Icons.share, color: Color(0xFFD84315)),
            onPressed: _sharing ? null : () => _sharePoster(context),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              // The poster card (wrapped for screenshot capture)
              RepaintBoundary(
                key: _repaintKey,
                child: LostDogPosterCard(report: widget.report),
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
                  onPressed: _sharing ? null : () => _sharePoster(context),
                  icon: const Icon(Icons.share, size: 20),
                  label: const Text(
                    'Share Poster',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD84315),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: const Color(0xFFD84315).withValues(alpha: 0.4),
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),

              const SizedBox(height: 12),

              // Save to Gallery button
              SizedBox(
                width: 280,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : () => _saveToGallery(context),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFD84315),
                          ),
                        )
                      : const Icon(Icons.save_alt, size: 20),
                  label: Text(
                    _saving ? 'Saving...' : 'Save to Gallery',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD84315),
                    side:
                        const BorderSide(color: Color(0xFFD84315), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),

              const SizedBox(height: 16),

              Text(
                'Share this poster to help find ${widget.report.dogName}!',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 500.ms),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _sharing ? null : () => _sharePoster(context),
        backgroundColor: const Color(0xFFD84315),
        icon: _sharing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.share, color: Colors.white),
        label: Text(
          _sharing ? 'Sharing...' : 'Share Alert',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// Capture the poster card as a PNG image.
  Future<File?> _captureImage() async {
    final boundary = _repaintKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;

    final tempDir = await getTemporaryDirectory();
    final safeName =
        widget.report.dogName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final file = File('${tempDir.path}/dogquest_lost_$safeName.png');
    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file;
  }

  /// Share the poster image via share_plus.
  Future<void> _sharePoster(BuildContext context) async {
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final file = await _captureImage();
      if (file == null) return;
      if (!mounted) return;

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'MISSING DOG: ${widget.report.dogName}'
            '${widget.report.breed != null ? ' (${widget.report.breed})' : ''}'
            ' - Last seen: ${widget.report.lastSeenLocation ?? 'Unknown'}'
            '. If you see this dog, please open Hound and scan!',
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

  /// Save the poster image to a persistent location.
  Future<void> _saveToGallery(BuildContext context) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final file = await _captureImage();
      if (file == null) return;

      // Save to app documents directory (gallery access would need
      // image_gallery_saver or similar plugin; this saves to accessible storage).
      final docsDir = await getApplicationDocumentsDirectory();
      final safeName =
          widget.report.dogName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final savedFile = await file.copy(
        '${docsDir.path}/dogquest_lost_${safeName}_$timestamp.png',
      );

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Poster saved to ${savedFile.path}'),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Could not save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
