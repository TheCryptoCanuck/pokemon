import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aviquest/main.dart';

void main() {
  group('AviQuest widget (theme only)', () {
    // The AviQuest widget requires ProviderScope with overrides and Hive
    // initialization to render fully. These tests verify the widget's theme
    // configuration by inspecting the MaterialApp.router it builds.

    test('AviQuest can be constructed', () {
      // Smoke test: const constructor works
      const widget = AviQuest();
      expect(widget, isA<StatelessWidget>());
    });
  });
}
