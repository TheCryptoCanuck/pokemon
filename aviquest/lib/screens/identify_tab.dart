import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:camera/camera.dart';
import '../constants.dart';
class IdentifyTab extends StatelessWidget {
  final CameraController? cam;
  final bool camReady;
  final VoidCallback onTakePhoto;
  final VoidCallback onListenCall;

  const IdentifyTab({
    super.key,
    required this.cam,
    required this.camReady,
    required this.onTakePhoto,
    required this.onListenCall,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('AviQuest',
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber))
            .animate()
            .fadeIn()
            .slideY(begin: -0.3),
        const Text('Point at a bird and identify it!',
                style: TextStyle(color: Colors.white54))
            .animate()
            .fadeIn(delay: 100.ms),
        const SizedBox(height: 24),
        if (camReady && cam != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(
                    color: Colors.amber.withAlpha(128), width: 2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: CameraPreview(cam!),
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
                Text('Camera unavailable',
                    style: TextStyle(color: Colors.white38)),
              ]),
            ),
          ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: onTakePhoto,
              icon: const Icon(Icons.camera_alt, size: 28),
              label: const Text('Identify by Photo'),
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3),
            const SizedBox(width: 16),
            OutlinedButton.icon(
              onPressed: onListenCall,
              icon: const Icon(Icons.mic, color: Colors.amber),
              label: const Text('By Call',
                  style: TextStyle(color: Colors.amber)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.amber),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.3),
          ],
        ),
      ],
    );
  }
}
