import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/kennel_screen.dart';
import 'screens/field_guide_screen.dart';
import 'screens/home_shell.dart';
import 'screens/identify_screen.dart';
import 'screens/login_screen.dart';
import 'screens/map_tab.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/my_dog_wizard_screen.dart';
import 'screens/my_dog_profile_screen.dart';
import 'screens/pack_screen.dart';
import 'screens/quiz_screen.dart';
import 'screens/register_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/dog_feed_screen.dart';
import 'screens/dogs_nearby_screen.dart';
import 'screens/breed_community_screen.dart';
import 'screens/lost_dog_hub_screen.dart';
import 'screens/report_lost_screen.dart';
import 'screens/scan_stray_screen.dart';
import 'screens/shelter_mode_screen.dart';
import 'screens/lost_dog_map_screen.dart';
import 'screens/share_lost_dog_screen.dart';
import 'screens/marketplace_screen.dart';
import 'screens/service_list_screen.dart';
import 'screens/provider_detail_screen.dart';
import 'models/lost_dog_report.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Listenable that notifies GoRouter when Supabase auth state changes.
class SupabaseAuthNotifier extends ChangeNotifier {
  late final StreamSubscription<AuthState> _sub;

  SupabaseAuthNotifier() {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final _authNotifier = SupabaseAuthNotifier();

final router = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/identify',
  observers: [SentryNavigatorObserver()],
  refreshListenable: _authNotifier,
  redirect: (context, state) {
    final loc = state.matchedLocation;

    // Allow auth and onboarding routes through
    const authRoutes = {'/onboarding', '/login', '/register', '/privacy'};
    if (authRoutes.contains(loc)) {
      // If already authenticated and on an auth route, redirect to app
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null && (loc == '/login' || loc == '/register')) {
        return '/identify';
      }
      return null;
    }

    // Onboarding gate
    if (!OnboardingScreen.isComplete()) return '/onboarding';

    // Auth gate — check Supabase session first, then offline mode fallback
    final session = Supabase.instance.client.auth.currentSession;
    final playerBox = Hive.box('dogquest_player_stats');
    final offlineMode = playerBox.get('offline_mode', defaultValue: false) as bool;

    if (session == null && !offlineMode) return '/login';

    return null;
  },
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => OnboardingScreen(
        onComplete: () => GoRouter.of(context).go('/login'),
      ),
    ),
    GoRoute(
      path: '/login',
      builder: (_, __) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (_, __) => const RegisterScreen(),
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
          GoRoute(path: '/kennel', builder: (_, __) => const KennelScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/guide', builder: (_, __) => const FieldGuideScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ]),
      ],
    ),
    GoRoute(
      path: '/settings',
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/privacy',
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const PrivacyPolicyScreen(),
    ),
    GoRoute(
      path: '/leaderboard',
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const LeaderboardScreen(),
    ),
    GoRoute(
      path: '/friends',
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const FriendsScreen(),
    ),
    GoRoute(
      path: '/pack',
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const PackScreen(),
    ),
    GoRoute(
      path: '/feed',
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const DogFeedScreen(),
    ),
    GoRoute(
      path: '/dogs-nearby',
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const DogsNearbyScreen(),
    ),
    GoRoute(
      path: '/lost-dog',
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const LostDogHubScreen(),
    ),
    GoRoute(
      path: '/lost-dog/report',
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const ReportLostScreen(),
    ),
    GoRoute(
      path: '/lost-dog/scan',
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const ScanStrayScreen(),
    ),
    GoRoute(
      path: '/lost-dog/map',
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const LostDogMapScreen(),
    ),
    GoRoute(
      path: '/lost-dog/share',
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, state) => ShareLostDogScreen(
        report: state.extra! as LostDogReport,
      ),
    ),
    GoRoute(
      path: '/shelter-mode',
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const ShelterModeScreen(),
    ),
    GoRoute(
      path: '/marketplace',
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const MarketplaceScreen(),
    ),
    GoRoute(
      path: '/marketplace/category/:name',
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, state) => ServiceListScreen(
        categoryName: state.pathParameters['name'] ?? '',
      ),
    ),
    GoRoute(
      path: '/marketplace/provider/:id',
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, state) => ProviderDetailScreen(
        providerId: state.pathParameters['id'] ?? '',
      ),
    ),
    GoRoute(
      path: '/breed/:name',
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, state) => BreedCommunityScreen(
        breedName: Uri.decodeComponent(state.pathParameters['name'] ?? ''),
      ),
    ),
    GoRoute(
      path: '/my-dog/wizard',
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const MyDogWizardScreen(),
    ),
    GoRoute(
      path: '/my-dog/profile/:name',
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, state) => MyDogProfileScreen(
        dogName: Uri.decodeComponent(state.pathParameters['name'] ?? ''),
      ),
    ),
    GoRoute(
      path: '/quiz',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => CustomTransitionPage(
        child: const QuizScreen(),
        transitionsBuilder: (context, animation, _, child) =>
            SlideTransition(
              position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                  .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
      ),
    ),
  ],
);
