import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dogquest/screens/kennel_screen.dart';
import 'package:dogquest/screens/home_shell.dart';
import 'package:dogquest/screens/identify_screen.dart';
import 'package:dogquest/screens/login_screen.dart';
import 'package:dogquest/screens/map_tab.dart';
import 'package:dogquest/screens/onboarding_screen.dart';
import 'package:dogquest/screens/profile_screen.dart';
import 'package:dogquest/screens/my_dog_wizard_screen.dart';
import 'package:dogquest/screens/my_dog_profile_screen.dart';
import 'package:dogquest/screens/pack_screen.dart';
import 'package:dogquest/screens/quiz_screen.dart';
import 'package:dogquest/screens/register_screen.dart';
import 'package:dogquest/screens/privacy_policy_screen.dart';
import 'package:dogquest/screens/friends_screen.dart';
import 'package:dogquest/screens/leaderboard_screen.dart';
import 'package:dogquest/screens/settings_screen.dart';
import 'package:dogquest/screens/dog_feed_screen.dart';
import 'package:dogquest/screens/dogs_nearby_screen.dart';
import 'package:dogquest/screens/breed_community_screen.dart';
import 'package:dogquest/screens/lost_dog_hub_screen.dart';
import 'package:dogquest/screens/social_hub_screen.dart';
import 'package:dogquest/screens/report_lost_screen.dart';
import 'package:dogquest/screens/scan_stray_screen.dart';
import 'package:dogquest/screens/lost_dog_map_screen.dart';
// NOTE: imports for shelter_mode_screen, share_lost_dog_screen, marketplace_screen,
// service_list_screen, provider_detail_screen, reunion_celebration_screen, and
// models/lost_dog_report removed pending those features being completed and
// committed. Routes for those features are stripped below — restore the imports
// AND the routes together when shipping. Tracked: T5-feature-restore.

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
    final offlineMode =
        playerBox.get('offline_mode', defaultValue: false) as bool;

    if (session == null && !offlineMode) return '/login';

    // sec-C1: invalidate stale offline_mode flag when an authenticated
    // session exists. Without this, offline mode can persist across login
    // boundaries (deep links, password resets, second-account logins on a
    // shared device, etc.) and cause sightings created offline to attribute
    // to whichever user is currently authenticated. The login/register
    // screens already clear it on their happy paths; this is the safety net
    // for every other code path that produces a session.
    if (session != null && offlineMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await playerBox.put('offline_mode', false);
      });
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => OnboardingScreen(
        onComplete: () => GoRouter.of(context).go('/login'),
        onStartGuest: () => GoRouter.of(context).go('/identify'),
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
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/map', builder: (_, __) => const MapTab()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/identify',
              builder: (_, __) => const IdentifyScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/kennel', builder: (_, __) => const KennelScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/lost-dog',
              builder: (_, __) => const LostDogHubScreen(),
              routes: [
                GoRoute(
                  path: 'report',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, __) => const ReportLostScreen(),
                ),
                GoRoute(
                  path: 'scan',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, __) => const ScanStrayScreen(),
                ),
                GoRoute(
                  path: 'map',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, __) => const LostDogMapScreen(),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
                path: '/profile', builder: (_, __) => const ProfileScreen(),),
          ],
        ),
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
      path: '/social',
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, __) => const SocialHubScreen(),
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
    // /lost-dog/share, /shelter-mode, /marketplace, /marketplace/category/:name,
    // and /marketplace/provider/:id routes removed pending those screens being
    // committed. Restore alongside the imports above. (T5-feature-restore)
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
        transitionsBuilder: (context, animation, _, child) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
    ),
    // /reunion-celebration route removed pending reunion_celebration_screen
    // being committed. (T5-feature-restore)
  ],
);
