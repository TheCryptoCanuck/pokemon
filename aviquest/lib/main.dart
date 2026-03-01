import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'constants.dart';
import 'router.dart';
import 'services/aviary_service.dart';
import 'services/bird_service.dart';
import 'services/log_service.dart';
import 'services/player_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LogService.init();

  await Hive.initFlutter();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Initialise services
  final birdSvc = BirdService();
  await birdSvc.load();

  final aviaryBox = await Hive.openBox<String>('aviary_v2');
  final aviarySvc = AviaryService(aviaryBox);

  final playerBox = await Hive.openBox('player_stats');
  final playerNotifier = PlayerNotifier(playerBox);

  runApp(
    ProviderScope(
      overrides: [
        birdServiceProvider.overrideWithValue(birdSvc),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
