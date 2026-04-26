import 'package:flutter/material.dart';

import 'package:dogquest/constants.dart';

class CameraPlaceholder extends StatelessWidget {
  final String? cameraError;
  final VoidCallback? onRetry;

  const CameraPlaceholder({
    required this.cameraError,
    this.onRetry,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: cameraError != null ? onRetry : null,
      child: Container(
        decoration: const BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                cameraError != null
                    ? Icons.videocam_off_rounded
                    : Icons.camera_alt,
                size: 64,
                color: Colors.white24,
              ),
              const SizedBox(height: 12),
              Text(
                cameraError != null
                    ? 'Camera not available'
                    : 'Camera loading...',
                style: const TextStyle(color: Colors.white54, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              if (cameraError != null) ...[
                const SizedBox(height: 8),
                const Text(
                  'Tap to retry',
                  style: TextStyle(color: Colors.amber, fontSize: 14),
                ),
              ] else ...[
                const SizedBox(height: 12),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white24,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
