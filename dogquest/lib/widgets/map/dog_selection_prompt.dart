import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../constants.dart';

class DogSelectionPrompt extends StatelessWidget {
  const DogSelectionPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.touch_app, color: Colors.white38, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tap a dog in the neighborhood to meet them!',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}
