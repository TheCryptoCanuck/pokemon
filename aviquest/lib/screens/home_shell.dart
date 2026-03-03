import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class HomeShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const HomeShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: navigationShell),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (i) {
          HapticFeedback.selectionClick();
          navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Identify'),
          BottomNavigationBarItem(icon: Icon(Icons.collections), label: 'Aviary'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Field Guide'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Me'),
        ],
      ),
    );
  }
}
