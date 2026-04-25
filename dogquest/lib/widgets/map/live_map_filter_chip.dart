import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants.dart';

class LiveMapFilterChip extends StatelessWidget {
  final String label;
  final String? breed;
  final int count;
  final bool selected;
  final ValueChanged<String?> onTap;

  const LiveMapFilterChip({
    required this.label,
    required this.breed,
    required this.count,
    required this.selected,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap(breed);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? Colors.amber.withValues(alpha: 0.2) : bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? Colors.amber : Colors.white12,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.amber : Colors.white54,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  color: selected
                      ? Colors.amber.withValues(alpha: 0.7)
                      : Colors.white30,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
