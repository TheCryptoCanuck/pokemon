import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';

import 'constants.dart';
import 'router.dart';
import 'security/security_manager.dart';
import 'services/analytics_service.dart';
import 'services/aviary_service.dart';
import 'services/bird_service.dart';
import 'services/bird_family_service.dart';
import 'services/daily_bird_service.dart';
import 'services/identification_service.dart';
import 'services/log_service.dart';
import 'services/player_service.dart';
import 'services/sighting_service.dart';
import 'services/tflite_identification_service.dart';

final _log = Logger('Main');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LogService.init();

  // Global error handlers — catch unhandled exceptions so they are logged
  // instead of silently crashing.
  FlutterError.onError = (details) {
    _log.severe('FlutterError: ${details.exceptionAsString()}', details.exception, details.stack);
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    _log.severe('Unhandled platform error', error, stack);
    return true; // prevent crash in release mode
  };

  try {
    await _startApp();
  } catch (e, st) {
    _log.severe('Fatal startup error', e, st);
    // Show a minimal error UI rather than a white/blank screen
    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF0A1F0F),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'AviQuest failed to start.\n\nPlease restart the app.\n\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
        ),
      ),
    ));
  }
}

Future<void> _startApp() async {
  await Hive.initFlutter();
  await SecurityManager.instance.initialize();
  await SecurityManager.instance.enforcePortraitOrientation();

  if (kDebugMode) {
    debugPrint('[Security] Debug mode active — some protections relaxed');
  }

  // Analytics — local Hive event logger
  final analytics = AnalyticsService();
  await analytics.init();

  // Initialise services
  final birdSvc = BirdService();
  await birdSvc.load();

  // Try to load TFLite model; fall back to mock if unavailable
  final tfliteSvc = TfliteIdentificationService(birdSvc);
  final modelLoaded = await tfliteSvc.loadModel();
  final IdentificationService idService = modelLoaded
      ? tfliteSvc
      : MockIdentificationService(birdSvc);

  if (modelLoaded) {
    debugPrint('[AviQuest] Bird classifier loaded — real identification active');
  } else {
    debugPrint('[AviQuest] No TFLite model found — using demo mode');
  }

  final aviaryBox = await Hive.openBox<String>('aviary_v2');
  final aviarySvc = AviaryService(aviaryBox);

  final playerBox = await Hive.openBox('player_stats');
  final playerNotifier = PlayerNotifier(playerBox);
  final dailyBirdSvc = DailyBirdService(birdSvc, playerBox);
  final birdFamilySvc = BirdFamilyService(birdSvc, aviarySvc);
  final sightingSvc = SightingService();
  await sightingSvc.init();

  // Track session start
  analytics.track('app_session_started', {
    'session_number': analytics.sessionNumber,
    'streak': playerNotifier.state.streak,
    'aviary_count': aviarySvc.count,
    'level': playerNotifier.state.level,
    'model_loaded': modelLoaded,
  });

  runApp(
    ProviderScope(
      overrides: [
        birdServiceProvider.overrideWithValue(birdSvc),
        identificationServiceProvider.overrideWithValue(idService),
        aviaryServiceProvider.overrideWithValue(aviarySvc),
        playerProvider.overrideWith((_) => playerNotifier),
        analyticsProvider.overrideWithValue(analytics),
        dailyBirdServiceProvider.overrideWithValue(dailyBirdSvc),
        birdFamilyServiceProvider.overrideWithValue(birdFamilySvc),
        sightingServiceProvider.overrideWithValue(sightingSvc),
      ],
      child: const AviQuest(),
    ),
  );
}

class AviQuest extends StatelessWidget {
  const AviQuest({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'AviQuest',
      routerConfig: router,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: bgDeep,
        primaryColor: Colors.amber,
        colorScheme: const ColorScheme.dark(
          primary: Colors.amber,
          secondary: Color(0xFF4CAF50),
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
