import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants.dart';

class MapTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final int tabIndex;
  final int selectedTab;
  final ValueChanged<int> onTap;

  const MapTabButton({
    required this.label,
    required this.icon,
    required this.tabIndex,
    required this.selectedTab,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final selected = selectedTab == tabIndex;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap(tabIndex);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? Colors.amber.withValues(alpha: 0.15) : bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? Colors.amber : Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? Colors.amber : Colors.white54,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.amber : Colors.white54,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
