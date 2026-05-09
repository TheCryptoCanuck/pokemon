// test/widgets/breed_ghost_card_test.dart
//
// Widget tests for BreedGhostCard — the ghost-collection pattern card
// that displays undiscovered breeds with a placeholder icon, dimmed
// rarity indicator, and breed name.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dogquest/widgets/breed_ghost_card.dart';
import 'package:dogquest/models/dog.dart';
import 'package:dogquest/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Test Fixture
// ─────────────────────────────────────────────────────────────────────────────

Dog _testDog({
  String name = 'Golden Retriever',
  Rarity rarity = Rarity.common,
}) =>
    Dog(
      name: name,
      scientificName: 'Canis lupus familiaris',
      imageUrl: 'https://example.com/dog.jpg',
      audioUrl: '',
      lore: 'Test lore',
      habitat: 'Test habitat',
      conservationStatus: 'Common',
      rarity: rarity,
      baseXp: 20,
    );

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('BreedGhostCard', () {
    // Helper to wrap card in proper rendering context
    Widget buildTestCard(Dog dog) => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 250,
              child: BreedGhostCard(dog: dog),
            ),
          ),
        );

    testWidgets('renders breed name', (WidgetTester tester) async {
      final dog = _testDog(name: 'Golden Retriever');
      await tester.pumpWidget(buildTestCard(dog));

      expect(find.text('Golden Retriever'), findsOneWidget);
    });

    testWidgets('renders rarity label', (WidgetTester tester) async {
      final dog = _testDog(rarity: Rarity.uncommon);
      await tester.pumpWidget(buildTestCard(dog));

      expect(find.text('uncommon'), findsOneWidget);
    });

    testWidgets('renders rarity label for rare', (WidgetTester tester) async {
      final dog = _testDog(rarity: Rarity.rare);
      await tester.pumpWidget(buildTestCard(dog));

      expect(find.text('rare'), findsOneWidget);
    });

    testWidgets('renders rarity label for legendary',
        (WidgetTester tester) async {
      final dog = _testDog(rarity: Rarity.legendary);
      await tester.pumpWidget(buildTestCard(dog));

      expect(find.text('legendary'), findsOneWidget);
    });

    testWidgets('shows placeholder icon', (WidgetTester tester) async {
      final dog = _testDog();
      await tester.pumpWidget(buildTestCard(dog));

      expect(find.byIcon(Icons.help_outline), findsOneWidget);
    });

    testWidgets('uses dimmed border with alpha 0.55',
        (WidgetTester tester) async {
      final dog = _testDog(rarity: Rarity.rare);
      await tester.pumpWidget(buildTestCard(dog));

      // Verify Card exists
      expect(find.byType(Card), findsOneWidget);

      // Get the Card widget and verify its shape has the correct border
      final cardFinder = find.byType(Card);
      final card = tester.widget<Card>(cardFinder);

      expect(card.shape, isA<RoundedRectangleBorder>());
      final shape = card.shape as RoundedRectangleBorder;

      // Verify border color has alpha 0.55 (approximately 0.55 * 255 ~= 140)
      expect((shape.side.color.a * 255.0).round(), 140);
      expect(shape.side.width, 1.5);
    });

    testWidgets('handles long breed name with ellipsis',
        (WidgetTester tester) async {
      final dog = _testDog(
        name: 'Very Long Hypothetical Dog Breed Name That '
            'Should Definitely Overflow',
      );
      await tester.pumpWidget(buildTestCard(dog));

      // Find the breed name Text widget
      final textFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data ?? '').startsWith('Very Long Hypothetical'),
      );

      expect(textFinder, findsOneWidget);
      final text = tester.widget<Text>(textFinder);
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('card is not tappable', (WidgetTester tester) async {
      final dog = _testDog();
      await tester.pumpWidget(buildTestCard(dog));

      // Verify no GestureDetector or InkWell wraps the Card
      expect(find.byType(GestureDetector), findsNothing);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('card background uses bgCard color',
        (WidgetTester tester) async {
      final dog = _testDog();
      await tester.pumpWidget(buildTestCard(dog));

      final card = tester.widget<Card>(find.byType(Card));
      expect(card.color, bgCard);
    });

    testWidgets('all rarity types render correctly',
        (WidgetTester tester) async {
      for (final rarity in Rarity.values) {
        final dog = _testDog(rarity: rarity);
        await tester.pumpWidget(buildTestCard(dog));

        // Should render the breed name
        expect(find.text('Golden Retriever'), findsOneWidget);

        // Should render the rarity name (skip 'unknown' special case)
        if (rarity != Rarity.unknown) {
          expect(find.text(rarity.name), findsOneWidget);
        }

        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });
}
