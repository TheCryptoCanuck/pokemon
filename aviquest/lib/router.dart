import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/aviary_screen.dart';
import 'screens/field_guide_screen.dart';
import 'screens/home_shell.dart';
import 'screens/identify_screen.dart';
import 'screens/map_tab.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/identify',
  redirect: (context, state) {
    if (state.matchedLocation == '/onboarding') return null;
    if (!OnboardingScreen.isComplete()) return '/onboarding';
    return null;
  },
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => OnboardingScreen(
        onComplete: () => GoRouter.of(context).go('/identify'),
      ),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          HomeShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/map', builder: (_, __) => const MapTab()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/identify', builder: (_, __) => const IdentifyScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/aviary', builder: (_, __) => const AviaryScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/guide', builder: (_, __) => const FieldGuideScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ]),
      ],
    ),
  ],
);
