import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dogquest/constants.dart';
import 'package:dogquest/router.dart';
import 'package:dogquest/screens/splash_screen.dart';
import 'package:dogquest/security/security_manager.dart';
import 'package:dogquest/services/analytics_service.dart';
import 'package:dogquest/services/kennel_service.dart';
import 'package:dogquest/services/dog_service.dart';
import 'package:dogquest/services/dog_group_service.dart';
import 'package:dogquest/services/daily_dog_service.dart';
import 'package:dogquest/services/api_client.dart';
import 'package:dogquest/services/backend_sync_service.dart';
import 'package:dogquest/services/identification_service.dart';
import 'package:dogquest/services/log_service.dart';
import 'package:dogquest/services/player_service.dart';
import 'package:dogquest/services/sighting_service.dart';
import 'package:dogquest/services/notification_service.dart';
import 'package:dogquest/services/location_service.dart';
import 'package:dogquest/services/activity_tracker_service.dart';
import 'package:dogquest/services/dog_mastery_service.dart';
import 'package:dogquest/services/daily_challenge_service.dart';
import 'package:dogquest/services/combo_service.dart';
import 'package:dogquest/services/flash_challenge_service.dart';
import 'package:dogquest/services/my_dog_service.dart';
import 'package:dogquest/services/dog_friendship_service.dart';
import 'package:dogquest/services/pack_service.dart';
import 'package:dogquest/services/breed_collection_service.dart';
import 'package:dogquest/services/dog_social_service.dart';
import 'package:dogquest/services/mystery_reward_service.dart';
import 'package:dogquest/services/smart_notification_service.dart';
import 'package:dogquest/services/shared_tflite_service.dart';
import 'package:dogquest/services/tflite_identification_service.dart';
import 'package:dogquest/services/dog_embedding_service.dart';
// NOTE: lost_dog_alert_service and lost_dog_sync_service imports removed —
// those files exist on disk but were never committed. Their construction +
// provider registrations below are also stripped. Restore alongside the
// service files when committed. (T5-feature-restore)
import 'package:dogquest/services/lost_dog_service.dart';
import 'package:dogquest/services/auth_migration_service.dart';
import 'package:dogquest/services/supabase_auth_service.dart';
import 'package:dogquest/services/supabase_user_service.dart';
import 'package:dogquest/widgets/streak_break_dialog.dart';

final _log = Logger('Main');

/// Retrieves or generates a 32-byte AES encryption key for Hive boxes.
/// The key is stored in platform-secure storage (Keychain / Keystore).
Future<List<int>> _getOrCreateHiveEncryptionKey() async {
  const storage = FlutterSecureStorage();
  const keyName = 'dogquest_hive_encryption_key';

  final existingKey = await storage.read(key: keyName);
  if (existingKey != null) {
    return base64Url.decode(existingKey);
  }

  // Generate a cryptographically random 32-byte key
  final secureRandom = Random.secure();
  final key = List<int>.generate(32, (_) => secureRandom.nextInt(256));
  await storage.write(key: keyName, value: base64Url.encode(key));
  return key;
}

/// Opens the sightings Hive box with AES encryption.
/// If the box was previously unencrypted, deletes it and creates a fresh
/// encrypted one (acceptable data loss for beta).
Future<void> _openEncryptedSightingsBox(List<int> encryptionKey) async {
  const boxName = 'dogquest_sightings_v1';
  try {
    await Hive.openBox<Map>(
      boxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
    _log.info('Opened encrypted sightings box');
  } catch (e) {
    _log.warning(
      'Failed to open sightings box (likely unencrypted migration): $e',
    );
    // Delete the old unencrypted box and create a fresh encrypted one
    await Hive.deleteBoxFromDisk(boxName);
    await Hive.openBox<Map>(
      boxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
    _log.info('Migrated sightings box to encrypted storage (old data cleared)');
  }
}

/// Sentry DSN passed at build time via --dart-define=SENTRY_DSN=...
/// When empty, the app runs without Sentry (identical to previous behavior).
const _sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
const _environment = String.fromEnvironment('ENV', defaultValue: 'development');

/// Supabase configuration — passed at build time via --dart-define
const _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://hdcpymjnrbelaawhncep.supabase.co',
);
const _supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_lrICH1RprCBAxgQAs8tg4g_eKAXDme4',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LogService.init();

  if (_sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = _sentryDsn;
        options.tracesSampleRate = 0.2;
        options.environment = _environment;
      },
      appRunner: () => _guardedStartup(),
    );
  } else {
    // No Sentry DSN — use local error handlers as fallback
    _installLocalErrorHandlers();
    await _guardedStartup();
  }
}

/// Installs FlutterError and PlatformDispatcher handlers for local logging
/// when Sentry is not active (SentryFlutter sets its own when active).
void _installLocalErrorHandlers() {
  FlutterError.onError = (details) {
    _log.severe(
      'FlutterError: ${details.exceptionAsString()}',
      details.exception,
      details.stack,
    );
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    _log.severe('Unhandled platform error', error, stack);
    return true; // prevent crash in release mode
  };
}

Future<void> _guardedStartup() async {
  // Override the default red error widget with a themed fallback
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: bgDeep,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.amber, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                kDebugMode
                    ? details.exceptionAsString()
                    : 'An unexpected error occurred',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  };

  // Single runApp call -- the AppBootstrap widget manages the splash-to-app
  // transition internally, keeping the splash mounted so animations play.
  runApp(const AppBootstrap());
}

/// Root widget that shows the splash screen while services initialize,
/// then crossfades to the real app. Uses a single runApp() call so
/// the splash widget tree stays mounted and animations play properly.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  final _statusController = StreamController<String>.broadcast();
  final _progressController = StreamController<double>.broadcast();

  List<Override>? _overrides;
  String? _fatalError;
  bool _showApp = false;
  double _appOpacity = 0.0;

  // Streak event info captured during initialization
  int _brokenStreakValue = 0;
  bool _streakSaverUsed = false;
  int _currentStreak = 0;

  // Auth migration state
  bool _needsMigration = false;

  @override
  void initState() {
    super.initState();
    // Delay initialization until after the first frame renders,
    // so splash animations can start playing immediately.
    // Delay init by 1.5s so splash animations play unblocked.
    // Heavy sync work (JSON parse, model load) jams the event loop,
    // so we let the animations finish first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 200), _initialize);
    });
  }

  Future<void> _initialize() async {
    try {
      final startTime = DateTime.now();
      final initResult =
          await _initializeServices(_statusController, _progressController);
      final overrides = initResult.overrides;

      // Ensure splash shows for at least 2.5 seconds so animations play
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      final remaining = 2500 - elapsed;
      _statusController.add('Ready!');
      _progressController.add(1.0);
      await Future.delayed(
        Duration(milliseconds: remaining > 0 ? remaining : 300),
      );

      // Check for legacy auth migration need
      bool needsMigration = false;
      final migrationSvc = AuthMigrationService(
        SupabaseAuthService(Supabase.instance.client),
        SupabaseUserService(Supabase.instance.client),
      );
      if (!migrationSvc.wasPrompted && await migrationSvc.hasLegacyAuth()) {
        needsMigration = Supabase.instance.client.auth.currentSession == null;
      }

      if (mounted) {
        setState(() {
          _overrides = overrides;
          _brokenStreakValue = initResult.brokenStreakValue;
          _streakSaverUsed = initResult.streakSaverUsed;
          _currentStreak = initResult.currentStreak;
          _needsMigration = needsMigration;
          _showApp = true;
        });
        // Trigger crossfade after the app widget tree has built
        await Future.delayed(const Duration(milliseconds: 50));
        if (mounted) {
          setState(() => _appOpacity = 1.0);
        }
        // Show migration dialog first, then streak dialog
        if (_needsMigration) {
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) {
            await _showMigrationDialog(migrationSvc);
          }
        }
        // Show streak break/save dialog after app is visible
        if (_brokenStreakValue > 1 || _streakSaverUsed) {
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) {
            _showStreakDialog();
          }
        }
      }
    } catch (e, st) {
      _log.severe('Fatal startup error', e, st);
      // Best-effort report to Crashlytics. Firebase may not have init'd yet
      // if the failure happened early, so swallow Crashlytics errors.
      try {
        await FirebaseCrashlytics.instance
            .recordError(e, st, fatal: true, reason: 'Fatal startup error');
      } catch (_) {}
      if (_sentryDsn.isNotEmpty) {
        await Sentry.captureException(e, stackTrace: st);
      }
      _statusController.add('Error: $e');
      if (mounted) {
        setState(() => _fatalError = e.toString());
      }
    }
  }

  Future<void> _showMigrationDialog(AuthMigrationService migrationSvc) async {
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null) return;

    final email = migrationSvc.legacyEmail ?? '';
    final username = migrationSvc.legacyUsername ?? '';

    await showDialog<bool>(
      context: navContext,
      barrierDismissible: false,
      builder: (ctx) {
        final emailCtrl = TextEditingController(text: email);
        final usernameCtrl = TextEditingController(text: username);
        final passwordCtrl = TextEditingController();
        final formKey = GlobalKey<FormState>();
        bool loading = false;
        String? error;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: bgCard,
              title: const Text(
                'Upgrade Your Account',
                style:
                    TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create a cloud account to enable social features and backup your collection.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            error!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      TextFormField(
                        controller: usernameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          labelStyle: TextStyle(color: Colors.white54),
                        ),
                        validator: (v) => (v == null || v.trim().length < 3)
                            ? 'At least 3 characters'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          labelStyle: TextStyle(color: Colors.white54),
                        ),
                        validator: (v) => (v == null || !v.contains('@'))
                            ? 'Enter a valid email'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordCtrl,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Choose a Password',
                          labelStyle: TextStyle(color: Colors.white54),
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'At least 6 characters'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: loading
                      ? null
                      : () async {
                          await migrationSvc.markPrompted();
                          if (ctx.mounted) Navigator.of(ctx).pop(false);
                        },
                  child: const Text(
                    'Not Now',
                    style: TextStyle(color: Colors.white38),
                  ),
                ),
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() {
                            loading = true;
                            error = null;
                          });
                          try {
                            final success =
                                await migrationSvc.migrateToSupabase(
                              email: emailCtrl.text.trim(),
                              password: passwordCtrl.text,
                              username: usernameCtrl.text.trim(),
                            );
                            await migrationSvc.markPrompted();
                            if (ctx.mounted) Navigator.of(ctx).pop(success);
                          } on SupabaseAuthException catch (e) {
                            setDialogState(() {
                              error = e.message;
                              loading = false;
                            });
                          } catch (e) {
                            setDialogState(() {
                              error = 'Upgrade failed. Try again later.';
                              loading = false;
                            });
                          }
                        },
                  child: loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Upgrade'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showStreakDialog() {
    // Find the navigator context from the mounted app widget tree.
    // rootNavigatorKey is defined in router.dart
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null) return;

    StreakBreakDialog.show(
      navContext,
      lostStreak: _brokenStreakValue,
      wasSaved: _streakSaverUsed,
      currentStreak: _currentStreak,
    );
  }

  @override
  void dispose() {
    _statusController.close();
    _progressController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fatal error state
    if (_fatalError != null) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: bgDeep,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'DogQuest failed to start.\n\nPlease restart the app.\n\n$_fatalError',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
          ),
        ),
      );
    }

    // Stack splash and app for smooth crossfade transition
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          // Splash stays mounted until app fades in fully
          MaterialApp(
            home: SplashScreen(
              statusStream: _statusController.stream,
              progressStream: _progressController.stream,
            ),
            theme: ThemeData.dark(),
            debugShowCheckedModeBanner: false,
          ),
          // App fades in over the splash
          if (_showApp && _overrides != null)
            AnimatedOpacity(
              opacity: _appOpacity,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              child: ProviderScope(
                overrides: _overrides!,
                child: const DogQuest(),
              ),
            ),
        ],
      ),
    );
  }
}

/// Result of service initialization, including provider overrides and
/// streak event information to display after the app becomes interactive.
class _InitResult {
  final List<Override> overrides;
  final int brokenStreakValue;
  final bool streakSaverUsed;
  final int currentStreak;

  const _InitResult({
    required this.overrides,
    this.brokenStreakValue = 0,
    this.streakSaverUsed = false,
    this.currentStreak = 0,
  });
}

Future<_InitResult> _initializeServices(
  StreamController<String> status,
  StreamController<double> progress,
) async {
  void update(String msg, double p) {
    status.add(msg);
    progress.add(p);
  }

  update('Setting up...', 0.05);
  await Future.delayed(Duration.zero); // yield to let animations tick

  // Initialize Supabase before Hive — auth state may be needed early
  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseAnonKey,
  );
  _log.info(
    'Supabase initialized (${_supabaseUrl.split('.').first.split('//').last})',
  );

  await Hive.initFlutter();
  await Future.delayed(Duration.zero);
  await SecurityManager.instance.initialize();
  await SecurityManager.instance.enforcePortraitOrientation();

  if (kDebugMode) {
    debugPrint('[Security] Debug mode active — some protections relaxed');
  }

  // Firebase
  update('Connecting services...', 0.10);
  await Future.delayed(Duration.zero); // yield for animations
  FirebaseAnalytics? firebaseAnalytics;
  try {
    await Firebase.initializeApp();
    firebaseAnalytics = FirebaseAnalytics.instance;
    _log.info('Firebase initialized');

    // Crashlytics: take over the Flutter and platform error handlers so
    // unhandled errors get reported to the Firebase console. Disabled in
    // debug to avoid polluting reports during development.
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode);
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true; // prevent crash in release mode
    };
    _log.info('Crashlytics handlers installed');
  } catch (e) {
    _log.info('Firebase not available: $e');
  }

  final analytics = AnalyticsService();
  await analytics.init(firebaseAnalytics: firebaseAnalytics);

  // Dog database
  update('Loading dog database...', 0.20);
  await Future.delayed(Duration.zero); // yield for animations
  final dogSvc = DogService();
  await dogSvc.load();
  await Future.delayed(Duration.zero); // yield after heavy JSON parse

  // ML model (the heavy one) — loaded once by SharedTfliteService
  update('Loading AI model...', 0.35);
  await Future.delayed(Duration.zero); // yield before heaviest step
  final sharedTflite = SharedTfliteService();
  final sharedModelLoaded = await sharedTflite.loadModel();
  await Future.delayed(Duration.zero); // yield after model load
  if (!sharedModelLoaded) {
    throw Exception(
      'Dog classifier model failed to load.\n'
      'Ensure dog_model.tflite is present in assets.\n'
      'DogQuest requires real ML inference — no mock mode.',
    );
  }
  debugPrint(
    '[DogQuest] TFLite model loaded once — real identification active',
  );

  // Both TfliteIdentificationService and DogEmbeddingService use the shared model
  final tfliteSvc = TfliteIdentificationService(dogSvc, sharedTflite);
  final modelLoaded = await tfliteSvc.loadModel();
  await Future.delayed(Duration.zero); // yield after label cache build
  if (!modelLoaded) {
    throw Exception('Failed to build TFLite identification service.');
  }

  update('Preparing your collection...', 0.60);
  await Future.delayed(Duration.zero); // yield for animations
  final locationSvc = LocationService();
  ApiClient.assertBaseUrl();
  final apiClient = ApiClient();

  // Parallelize independent Hive box opens
  final hiveEncryptionKey = await _getOrCreateHiveEncryptionKey();
  final boxResults = await Future.wait([
    Hive.openBox<String>('dogquest_kennel'), // [0]
    Hive.openBox('dogquest_player_stats'), // [1]
    Hive.openBox<Map>('dogquest_pending_syncs'), // [2]
    Hive.openBox('dogquest_collections'), // [3]
    Hive.openBox('dogquest_social'), // [4]
  ]);
  final kennelBox = boxResults[0] as Box<String>;
  final playerBox = boxResults[1];
  final pendingSyncBox = boxResults[2] as Box<Map>;
  final socialBox = boxResults[4];

  final kennelSvc = KennelService(kennelBox);
  final playerNotifier = PlayerNotifier(playerBox);
  final dailyDogSvc = DailyDogService(dogSvc, playerBox);
  kennelSvc.setDogService(dogSvc);
  final dogGroupSvc = DogGroupService(dogSvc, kennelSvc);
  final breedCollectionSvc = BreedCollectionService(playerBox, kennelSvc);

  // Open the sightings box with AES encryption before SightingService
  // accesses it. Hive returns the already-opened box on subsequent
  // openBox calls, so SightingService.init() will reuse this handle.
  await _openEncryptedSightingsBox(hiveEncryptionKey);

  final sightingSvc = SightingService();
  await sightingSvc.init();

  update('Loading challenges...', 0.75);
  await Future.delayed(Duration.zero); // yield for animations

  // Parallelize independent service inits
  final dailyChallengeNotifier = DailyChallengeNotifier();
  final dogMasteryNotifier = DogMasteryNotifier();
  final activityTracker = ActivityTrackerService();
  final mysteryRewardNotifier = MysteryRewardNotifier();
  await Future.wait([
    dailyChallengeNotifier.init(),
    dogMasteryNotifier.init(),
    activityTracker.init(),
    mysteryRewardNotifier.init(),
    Hive.openBox('dogquest_flash_challenges'),
  ]);
  final flashChallengeBox = Hive.box('dogquest_flash_challenges');
  final flashChallengeNotifier = FlashChallengeNotifier(flashChallengeBox);
  flashChallengeNotifier.checkAndOffer();
  final comboNotifier = ComboNotifier(playerBox);
  final myDogSvc = MyDogService(playerBox);
  final packSvc = PackService(playerBox);
  final friendshipSvc = DogFriendshipService(playerBox, dogSvc);
  final dogSocialSvc = DogSocialService(socialBox);

  // Lost Dog Recognition Network (uses the same shared TFLite model)
  final embeddingSvc = DogEmbeddingService(sharedTflite);
  await embeddingSvc.loadModel();
  final lostDogSvc = LostDogService(playerBox, embeddingSvc, locationSvc);
  // alertedBox kept open for downstream consumers; LostDogAlertService stripped
  // pending its file being committed. (T5-feature-restore)
  await Hive.openBox<int>('dogquest_alerted_reports');

  // supabaseLostDogSvc + LostDogSyncService construction stripped together —
  // the only consumer of supabaseLostDogSvc was LostDogSyncService.
  // (T5-feature-restore)

  update('Syncing data...', 0.88);
  await Future.delayed(Duration.zero); // yield for animations
  final backendSync = BackendSyncService(
    pendingSyncBox: pendingSyncBox,
  );

  await NotificationService.init();
  await NotificationService.scheduleFromPreferences();

  final uncollectedDogs =
      dogSvc.all.where((b) => !kennelSvc.contains(b.name)).toList();
  final challengeState = dailyChallengeNotifier.currentState;
  SmartNotificationService.scheduleAll(
    streak: playerNotifier.currentState.streak,
    challengesCompleted:
        challengeState.challenges.where((c) => c.completed).length,
    totalChallenges: challengeState.challenges.length,
    uncollectedDogNames: uncollectedDogs.map((b) => b.name).toList(),
    uncollectedHabitat:
        uncollectedDogs.isNotEmpty ? uncollectedDogs.first.habitat : null,
  ).catchError((e) {
    debugPrint('[DogQuest] Smart notification scheduling failed: $e');
  });

  if (await apiClient.isAuthenticated) {
    backendSync.flushPendingSyncs().catchError((e) {
      debugPrint('[DogQuest] Pending sync flush failed: $e');
    });
  }

  update('Almost ready...', 0.95);
  analytics.track('app_session_started', {
    'session_number': analytics.sessionNumber,
    'streak': playerNotifier.currentState.streak,
    'kennel_count': kennelSvc.count,
    'level': playerNotifier.currentState.level,
  });

  return _InitResult(
    overrides: [
      sharedTfliteServiceProvider.overrideWithValue(sharedTflite),
      dogServiceProvider.overrideWithValue(dogSvc),
      identificationServiceProvider.overrideWithValue(tfliteSvc),
      kennelServiceProvider.overrideWithValue(kennelSvc),
      playerProvider.overrideWith((_) => playerNotifier),
      analyticsProvider.overrideWithValue(analytics),
      dailyDogServiceProvider.overrideWithValue(dailyDogSvc),
      dogGroupServiceProvider.overrideWithValue(dogGroupSvc),
      breedCollectionServiceProvider.overrideWithValue(breedCollectionSvc),
      sightingServiceProvider.overrideWithValue(sightingSvc),
      apiClientProvider.overrideWithValue(apiClient),
      backendSyncProvider.overrideWithValue(backendSync),
      locationServiceProvider.overrideWithValue(locationSvc),
      dailyChallengeProvider.overrideWith((_) => dailyChallengeNotifier),
      dogMasteryProvider.overrideWith((_) => dogMasteryNotifier),
      activityTrackerProvider.overrideWithValue(activityTracker),
      mysteryRewardProvider.overrideWith((_) => mysteryRewardNotifier),
      flashChallengeProvider.overrideWith((_) => flashChallengeNotifier),
      comboProvider.overrideWith((_) => comboNotifier),
      myDogServiceProvider.overrideWithValue(myDogSvc),
      packServiceProvider.overrideWithValue(packSvc),
      dogFriendshipServiceProvider.overrideWithValue(friendshipSvc),
      dogSocialServiceProvider.overrideWithValue(dogSocialSvc),
      dogEmbeddingServiceProvider.overrideWithValue(embeddingSvc),
      lostDogServiceProvider.overrideWithValue(lostDogSvc),
      // lostDogAlertServiceProvider + lostDogSyncServiceProvider overrides
      // stripped pending the corresponding service files being committed.
      // (T5-feature-restore)
    ],
    brokenStreakValue: playerNotifier.brokenStreakValue,
    streakSaverUsed: playerNotifier.streakSaverUsed,
    currentStreak: playerNotifier.currentState.streak,
  );
}

class DogQuest extends StatelessWidget {
  const DogQuest({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DogQuest',
      routerConfig: router,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: bgDeep,
        primaryColor: Colors.amber,
        colorScheme: const ColorScheme.dark(
          primary: Colors.amber,
          secondary: Color(0xFFD4874E),
          surface: bgCard,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: bgNav,
          selectedItemColor: Colors.amber,
          unselectedItemColor: Colors.white54,
          type: BottomNavigationBarType.fixed,
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
