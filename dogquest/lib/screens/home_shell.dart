import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dogquest/constants.dart';
import 'package:dogquest/services/analytics_service.dart';
import 'package:dogquest/widgets/connection_status_banner.dart';

const _tabLabels = ['Sightings', 'Identify', 'Kennel', 'Field Guide', 'Me'];

class HomeShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const HomeShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ConnectionStatusBanner(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                  key: ValueKey(navigationShell.currentIndex),
                  child: navigationShell,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: bgNav,
        selectedItemColor: Colors.amber,
        unselectedItemColor: Colors.white.withValues(alpha: 0.5),
        type: BottomNavigationBarType.fixed,
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
          navigationShell.goBranch(
            i,
            initialLocation: i == navigationShell.currentIndex,
          );
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.location_on_outlined),
            label: 'Sightings',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt, size: 28),
            ),
            activeIcon: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.camera_alt, size: 28, color: Colors.black87),
            ),
            label: 'Identify',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.collections),
            label: 'Kennel',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: 'Field Guide',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Me'),
        ],
      ),
    );
  }
}
