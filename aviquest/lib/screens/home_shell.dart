import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/analytics_service.dart';

const _tabLabels = ['Log', 'Identify', 'Aviary', 'Field Guide', 'Me'];

class HomeShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const HomeShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(child: navigationShell),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (i) {
          HapticFeedback.selectionClick();
          final fromTab = _tabLabels[navigationShell.currentIndex];
          final toTab = _tabLabels[i];
          if (fromTab != toTab) {
            ref.read(analyticsProvider).track('tab_navigated', {
              'from_tab': fromTab,
              'to_tab': toTab,
            });
          }
          navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Log'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Identify'),
          BottomNavigationBarItem(icon: Icon(Icons.collections), label: 'Aviary'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Field Guide'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Me'),
        ],
      ),
    );
  }
}
