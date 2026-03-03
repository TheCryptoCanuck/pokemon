import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:aviquest/services/analytics_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('analytics_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AnalyticsService', () {
    test('initialises with session number 1 on first run', () async {
      final svc = AnalyticsService();
      await svc.init();
      expect(svc.sessionNumber, 1);
    });

    test('increments session number on subsequent inits', () async {
      final svc1 = AnalyticsService();
      await svc1.init();
      expect(svc1.sessionNumber, 1);
      // Close and re-open to simulate app restart
      await Hive.close();
      Hive.init(tempDir.path);
      final svc2 = AnalyticsService();
      await svc2.init();
      expect(svc2.sessionNumber, 2);
    });

    test('track stores events', () async {
      final svc = AnalyticsService();
      await svc.init();
      svc.track('test_event', {'key': 'value'});
      expect(svc.eventCount, 1);
      final event = svc.events.first;
      expect(event['event'], 'test_event');
      expect(event['session'], 1);
      expect(event['props'], {'key': 'value'});
    });

    test('track stores events without properties', () async {
      final svc = AnalyticsService();
      await svc.init();
      svc.track('simple_event');
      expect(svc.eventCount, 1);
      expect(svc.events.first['event'], 'simple_event');
    });

    test('multiple events accumulate', () async {
      final svc = AnalyticsService();
      await svc.init();
      for (var i = 0; i < 10; i++) {
        svc.track('event_$i');
      }
      expect(svc.eventCount, 10);
    });
  });
}
