import 'package:flutter/material.dart';

import 'package:dogquest/widgets/capture_button.dart';
import 'package:dogquest/widgets/identify/gallery_button.dart';

class CameraControls extends StatelessWidget {
  final VoidCallback onTakePhoto;
  final VoidCallback onPickFromGallery;
  final bool isProcessing;

  const CameraControls({
    required this.onTakePhoto,
    required this.onPickFromGallery,
    required this.isProcessing,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Gallery picker button (left) with label
          GalleryButton(onTap: onPickFromGallery),
          const SizedBox(width: 28),
          // Main capture button (center)
          CaptureButton(
            onTap: onTakePhoto,
            isProcessing: isProcessing,
            mode: CaptureMode.photo,
          ),
        ],
      ),
    );
  }
}
