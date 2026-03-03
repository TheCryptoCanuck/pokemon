import 'dart:io'; // FIX 1: dart:io for File
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'constants.dart';
import 'screens/home_screen.dart';
import 'services/bird_service.dart';
import 'services/player_service.dart';
import 'package:aviquest/security/security_manager.dart';
import 'package:aviquest/security/secure_storage_helper.dart';
import 'package:aviquest/security/input_validator.dart';
import 'package:aviquest/security/app_lifecycle_observer.dart';
import 'database/database.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await PlayerService.init();
  await BirdService.load();
  await DatabaseService.instance.initialize();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Initialize security subsystems
  await SecurityManager.instance.initialize();
  await SecurityManager.instance.enforcePortraitOrientation();

  if (kDebugMode) {
    debugPrint('[Security] Debug mode active — some protections relaxed');
  }

  runApp(const AviQuest());
}

class AviQuest extends StatelessWidget {
  const AviQuest({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AviQuest',
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
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
