import 'dart:io';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import '../models/bird.dart';
import 'bird_service.dart';

final _log = Logger('IdentificationService');

/// Result of a bird identification attempt.
class IdentificationResult {
  final Bird bird;
  final double confidence;
  final String source; // 'ml', 'mock', 'audio'

  const IdentificationResult({
    required this.bird,
    required this.confidence,
    required this.source,
  });
}

/// Abstraction for bird identification.
/// In production, swap [MockIdentificationService] for a TFLite-backed impl.
abstract class IdentificationService {
  Future<Bird> identify(File imageFile);
  Future<Bird> identifyByAudio(File audioFile);
}

/// Mock implementation using weighted random bird selection.
/// Replace with TFLite or cloud ML inference when model is ready.
class MockIdentificationService implements IdentificationService {
  final BirdService _birdService;
  final Random _rng;

  MockIdentificationService(this._birdService, [Random? rng])
      : _rng = rng ?? Random();

  @override
  Future<Bird> identify(File imageFile) async {
    _log.info('Mock identify: ${imageFile.path}');
    // Simulate processing delay
    await Future.delayed(const Duration(milliseconds: 1800));
    return _birdService.weightedRandomBird(_rng);
  }

  @override
  Future<Bird> identifyByAudio(File audioFile) async {
    _log.info('Mock audio identify: ${audioFile.path}');
    await Future.delayed(const Duration(milliseconds: 1800));
    return _birdService.weightedRandomBird(_rng);
  }
}

final identificationServiceProvider = Provider<IdentificationService>((ref) {
  final birdSvc = ref.read(birdServiceProvider);
  return MockIdentificationService(birdSvc);
});
