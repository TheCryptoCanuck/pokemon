import 'package:flutter/material.dart';

class ZoomIndicator extends StatelessWidget {
  final double currentZoom;
  final double minZoom;

  const ZoomIndicator({
    required this.currentZoom,
    required this.minZoom,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (currentZoom <= minZoom + 0.05) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '${currentZoom.toStringAsFixed(1)}x',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
