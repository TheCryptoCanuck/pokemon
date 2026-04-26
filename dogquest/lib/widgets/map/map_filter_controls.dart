import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dogquest/constants.dart';

/// Horizontal scrollable breed filter chips for the Live Map.
class MapFilterControls extends StatelessWidget {
  final String? selectedBreed;
  final List<String> breeds;
  final Map<String, int> breedCounts;
  final int totalCount;
  final ValueChanged<String?> onBreedSelected;

  const MapFilterControls({
    super.key,
    required this.selectedBreed,
    required this.breeds,
    required this.breedCounts,
    required this.totalCount,
    required this.onBreedSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _filterChip('All', null, totalCount),
          ...breeds.map(
            (b) => _filterChip(
              b,
              b,
              breedCounts[b] ?? 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? breed, int count) {
    final selected = selectedBreed == breed;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onBreedSelected(breed);
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
