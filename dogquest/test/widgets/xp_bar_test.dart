// test/widgets/xp_bar_test.dart
//
// Widget tests for XpBar — the level, XP progress, and streak bonus widget
// that displays player progression with a linear progress indicator and
// optional streak multiplier.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dogquest/widgets/xp_bar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('XpBar', () {
    // Helper to wrap widget in proper rendering context
    Widget buildTestWidget(XpBar bar) => MaterialApp(
          home: Scaffold(
            body: bar,
          ),
        );

    testWidgets('renders level text', (WidgetTester tester) async {
      const bar = XpBar(level: 5, xp: 100, xpForNext: 500);
      await tester.pumpWidget(buildTestWidget(bar));

      expect(find.text('Level 5'), findsOneWidget);
    });

    testWidgets('renders XP fraction', (WidgetTester tester) async {
      const bar = XpBar(level: 3, xp: 100, xpForNext: 500);
      await tester.pumpWidget(buildTestWidget(bar));

      expect(find.text('XP: 100 / 500'), findsOneWidget);
    });

    testWidgets('shows progress bar', (WidgetTester tester) async {
      const bar = XpBar(level: 1, xp: 100, xpForNext: 500);
      await tester.pumpWidget(buildTestWidget(bar));

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('correct progress value (100/500 = 0.2)',
        (WidgetTester tester) async {
      const bar = XpBar(level: 1, xp: 100, xpForNext: 500);
      await tester.pumpWidget(buildTestWidget(bar));

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 0.2);
    });

    testWidgets('correct progress value (250/500 = 0.5)',
        (WidgetTester tester) async {
      const bar = XpBar(level: 1, xp: 250, xpForNext: 500);
      await tester.pumpWidget(buildTestWidget(bar));

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 0.5);
    });

    testWidgets('correct progress value (500/500 = 1.0)',
        (WidgetTester tester) async {
      const bar = XpBar(level: 1, xp: 500, xpForNext: 500);
      await tester.pumpWidget(buildTestWidget(bar));

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 1.0);
    });

    testWidgets('hides streak bonus by default', (WidgetTester tester) async {
      const bar = XpBar(
        level: 1,
        xp: 100,
        xpForNext: 500,
        streakMultiplier: 1.0,
      );
      await tester.pumpWidget(buildTestWidget(bar));

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data != null &&
              widget.data!.contains('streak'),
        ),
        findsNothing,
      );
    });

    testWidgets('shows streak bonus when active (2x)',
        (WidgetTester tester) async {
      const bar = XpBar(
        level: 1,
        xp: 100,
        xpForNext: 500,
        streakMultiplier: 2.0,
      );
      await tester.pumpWidget(buildTestWidget(bar));

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data != null &&
              widget.data!.contains('2.0') &&
              widget.data!.contains('streak'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows streak bonus with 3x multiplier',
        (WidgetTester tester) async {
      const bar = XpBar(
        level: 1,
        xp: 100,
        xpForNext: 500,
        streakMultiplier: 3.0,
      );
      await tester.pumpWidget(buildTestWidget(bar));

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data != null &&
              widget.data!.contains('3.0') &&
              widget.data!.contains('streak'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('clamps progress to 1.0 when xp exceeds xpForNext',
        (WidgetTester tester) async {
      const bar = XpBar(level: 1, xp: 600, xpForNext: 500);
      await tester.pumpWidget(buildTestWidget(bar));

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 1.0);
    });

    testWidgets('handles zero xpForNext without division by zero',
        (WidgetTester tester) async {
      const bar = XpBar(level: 1, xp: 0, xpForNext: 0);
      await tester.pumpWidget(buildTestWidget(bar));

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 0.0);
    });

    testWidgets('displays large level number correctly',
        (WidgetTester tester) async {
      const bar = XpBar(level: 99, xp: 1000, xpForNext: 5000);
      await tester.pumpWidget(buildTestWidget(bar));

      expect(find.text('Level 99'), findsOneWidget);
    });

    testWidgets('progress bar has correct min height',
        (WidgetTester tester) async {
      const bar = XpBar(level: 1, xp: 100, xpForNext: 500);
      await tester.pumpWidget(buildTestWidget(bar));

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.minHeight, 8);
    });

    testWidgets('container has rounded corners', (WidgetTester tester) async {
      const bar = XpBar(level: 1, xp: 100, xpForNext: 500);
      await tester.pumpWidget(buildTestWidget(bar));

      // Find the Container widget that wraps the XpBar content
      final containers = find.byType(Container);
      expect(containers, findsWidgets);

      // Verify at least one container has the bgCard background
      // and rounded border
      final containerWidgets = containers.evaluate();
      final found = containerWidgets.any((widget) {
        if (widget.widget is! Container) return false;
        final container = widget.widget as Container;
        return container.decoration is BoxDecoration;
      });
      expect(found, true);
    });

    testWidgets('level text color is amber', (WidgetTester tester) async {
      const bar = XpBar(level: 5, xp: 100, xpForNext: 500);
      await tester.pumpWidget(buildTestWidget(bar));

      final levelText = tester.widget<Text>(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == 'Level 5',
        ),
      );
      expect(levelText.style?.color, Colors.amber);
    });

    testWidgets('xp text color is white70', (WidgetTester tester) async {
      const bar = XpBar(level: 1, xp: 100, xpForNext: 500);
      await tester.pumpWidget(buildTestWidget(bar));

      final xpText = tester.widget<Text>(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == 'XP: 100 / 500',
        ),
      );
      expect(xpText.style?.color, Colors.white70);
    });

    testWidgets('streak bonus text has correct styling',
        (WidgetTester tester) async {
      const bar = XpBar(
        level: 1,
        xp: 100,
        xpForNext: 500,
        streakMultiplier: 2.5,
      );
      await tester.pumpWidget(buildTestWidget(bar));

      final streakText = tester.widget<Text>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data != null &&
              widget.data!.contains('2.5') &&
              widget.data!.contains('streak'),
        ),
      );
      expect(streakText.style?.color, Colors.amber);
      expect(streakText.style?.fontWeight, FontWeight.w600);
      expect(streakText.style?.fontSize, 11);
    });
  });
}
