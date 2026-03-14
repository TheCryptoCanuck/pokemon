import 'package:flutter_test/flutter_test.dart';
import 'package:dogquest/services/sighting_service.dart';

void main() {
  group('Sighting model', () {
    test('toMap produces correct keys', () {
      final s = Sighting(
        dogName: 'Pug',
        timestamp: DateTime(2026, 3, 10, 14, 30),
        confidence: 0.92,
        source: 'ml',
        latitude: 40.78,
        longitude: -73.96,
        accuracy: 10.0,
      );
      final map = s.toMap();
      expect(map['dog'], 'Pug');
      expect(map['conf'], 0.92);
      expect(map['src'], 'ml');
      expect(map['lat'], 40.78);
      expect(map['lon'], -73.96);
      expect(map['acc'], 10.0);
      expect(map['ts'], contains('2026-03-10'));
    });

    test('toMap omits null GPS fields', () {
      final s = Sighting(
        dogName: 'Beagle',
        timestamp: DateTime.now(),
      );
      final map = s.toMap();
      expect(map.containsKey('lat'), isFalse);
      expect(map.containsKey('lon'), isFalse);
      expect(map.containsKey('acc'), isFalse);
    });

    test('fromMap round-trips correctly', () {
      final original = Sighting(
        dogName: 'Corgi',
        timestamp: DateTime(2026, 1, 15, 10, 0),
        confidence: 0.85,
        source: 'ml',
        latitude: 51.5,
        longitude: -0.1,
        accuracy: 5.0,
      );
      final restored = Sighting.fromMap(original.toMap());
      expect(restored.dogName, 'Corgi');
      expect(restored.confidence, 0.85);
      expect(restored.source, 'ml');
      expect(restored.latitude, 51.5);
      expect(restored.longitude, -0.1);
      expect(restored.accuracy, 5.0);
    });

    test('fromMap handles missing fields gracefully', () {
      final s = Sighting.fromMap({});
      expect(s.dogName, '');
      expect(s.confidence, 1.0);
      expect(s.source, 'mock');
      expect(s.latitude, isNull);
    });

    test('default values are correct', () {
      final s = Sighting(dogName: 'Lab', timestamp: DateTime.now());
      expect(s.confidence, 1.0);
      expect(s.source, 'mock');
      expect(s.latitude, isNull);
      expect(s.longitude, isNull);
      expect(s.accuracy, isNull);
    });

    test('fromMap handles numeric type coercion', () {
      final s = Sighting.fromMap({
        'dog': 'Husky',
        'ts': '2026-03-10T12:00:00.000',
        'conf': 0.9, // double
        'lat': 40, // int, should coerce to double
        'lon': -73,
        'acc': 5,
      });
      expect(s.latitude, 40.0);
      expect(s.longitude, -73.0);
      expect(s.accuracy, 5.0);
    });
  });
}
