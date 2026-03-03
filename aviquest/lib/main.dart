import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'constants.dart';
import 'database/database.dart';
import 'router.dart';
import 'security/security_manager.dart';
import 'services/aviary_service.dart';
import 'services/bird_service.dart';
import 'services/identification_service.dart';
import 'services/log_service.dart';
import 'services/player_service.dart';
import 'services/tflite_identification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LogService.init();

  await Hive.initFlutter();
  await DatabaseService.instance.initialize();
  await SecurityManager.instance.initialize();
  await SecurityManager.instance.enforcePortraitOrientation();

  if (kDebugMode) {
    debugPrint('[Security] Debug mode active — some protections relaxed');
  }

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

  runApp(
    ProviderScope(
      overrides: [
        birdServiceProvider.overrideWithValue(birdSvc),
        identificationServiceProvider.overrideWithValue(idService),
        aviaryServiceProvider.overrideWithValue(aviarySvc),
        playerProvider.overrideWith((_) => playerNotifier),
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
