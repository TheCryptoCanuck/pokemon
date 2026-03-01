import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aviquest/main.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('aviquest_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AviQuest app widget', () {
    testWidgets('creates a MaterialApp with correct title', (tester) async {
      await tester.pumpWidget(const AviQuest());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.title, 'AviQuest');
    });

    testWidgets('uses dark theme', (tester) async {
      await tester.pumpWidget(const AviQuest());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme?.brightness, Brightness.dark);
    });

    testWidgets('has amber primary color', (tester) async {
      await tester.pumpWidget(const AviQuest());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme?.primaryColor, Colors.amber);
    });

    testWidgets('debug banner is disabled', (tester) async {
      await tester.pumpWidget(const AviQuest());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.debugShowCheckedModeBanner, false);
    });

    testWidgets('has correct color scheme', (tester) async {
      await tester.pumpWidget(const AviQuest());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final colorScheme = materialApp.theme?.colorScheme;
      expect(colorScheme?.primary, Colors.amber);
      expect(colorScheme?.secondary, const Color(0xFF4CAF50));
    });

    testWidgets('has HomeScreen as home widget', (tester) async {
      await tester.pumpWidget(const AviQuest());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('has bottom navigation bar with 5 tabs', (tester) async {
      await tester.pumpWidget(const AviQuest());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.byType(BottomNavigationBar), findsOneWidget);

      final navBar = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(navBar.items.length, 5);
    });

    testWidgets('bottom nav bar has correct labels', (tester) async {
      await tester.pumpWidget(const AviQuest());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Map'), findsOneWidget);
      expect(find.text('Identify'), findsOneWidget);
      expect(find.text('Aviary'), findsOneWidget);
      expect(find.text('Field Guide'), findsOneWidget);
      expect(find.text('Me'), findsOneWidget);
    });
  });
}
