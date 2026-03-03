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
abstract class IdentificationService {
  /// Identify a bird from a photo. Returns top predictions ranked by confidence.
  Future<List<IdentificationResult>> identify(File imageFile);

  /// Identify a bird from an audio recording.
  Future<List<IdentificationResult>> identifyByAudio(File audioFile);

  /// Whether the service is using a real ML model vs mock.
  bool get isModelLoaded;
}

/// Mock implementation using weighted random bird selection.
/// Used as fallback when TFLite model is not available.
class MockIdentificationService implements IdentificationService {
  final BirdService _birdService;
  final Random _rng;

  MockIdentificationService(this._birdService, [Random? rng])
      : _rng = rng ?? Random();

  @override
  bool get isModelLoaded => false;

  @override
  Future<List<IdentificationResult>> identify(File imageFile) async {
    _log.info('Mock identify: ${imageFile.path}');
    await Future.delayed(const Duration(milliseconds: 1800));

    // Generate 3 random predictions with decreasing fake confidence
    final results = <IdentificationResult>[];
    final seen = <String>{};
    final confidences = [0.72, 0.18, 0.07];

    for (var i = 0; i < 3; i++) {
      Bird bird;
      do {
        bird = _birdService.weightedRandomBird(_rng);
      } while (seen.contains(bird.name));
      seen.add(bird.name);
      results.add(IdentificationResult(
        bird: bird,
        confidence: confidences[i] + (_rng.nextDouble() * 0.1 - 0.05),
        source: 'mock',
      ));
    }
    return results;
  }

  @override
  Future<List<IdentificationResult>> identifyByAudio(File audioFile) async {
    _log.info('Mock audio identify: ${audioFile.path}');
    return identify(audioFile);
  }
}

final identificationServiceProvider = Provider<IdentificationService>((ref) {
  throw UnimplementedError('identificationServiceProvider must be overridden at startup');
});
