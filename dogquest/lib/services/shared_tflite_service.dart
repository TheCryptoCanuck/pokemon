import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

final _log = Logger('SharedTfliteService');

/// Singleton service that loads the TFLite model once and provides shared access.
///
/// Both [TfliteIdentificationService] and [DogEmbeddingService] use the same
/// EfficientNetB2 model at `assets/dog_model.tflite`. Loading it twice doubled
/// cold-start time by 800–1200ms. This service ensures exactly one
/// `Interpreter.fromAsset` call during app initialization.
///
/// Usage:
///   final sharedTflite = SharedTfliteService();
///   await sharedTflite.loadModel();
///   final interpreter = sharedTflite.interpreter;
class SharedTfliteService {
  Interpreter? _interpreter;
  bool _loaded = false;

  /// Whether the model has been successfully loaded.
  bool get isLoaded => _loaded;

  /// The TFLite interpreter, or null if not yet loaded.
  Interpreter? get interpreter => _interpreter;

  /// Load the TFLite model from assets. Idempotent — calling twice is safe.
  ///
  /// Returns true if successful, false if the model is missing.
  Future<bool> loadModel() async {
    // Idempotent: if already loaded, return true immediately
    if (_loaded) {
      _log.info('TFLite model already loaded');
      return true;
    }

    try {
      _interpreter = await Interpreter.fromAsset('assets/dog_model.tflite');
      _loaded = true;
      _log.info(
        'TFLite model loaded: '
        'input=${_interpreter!.getInputTensor(0).shape}, '
        'output=${_interpreter!.getOutputTensor(0).shape}',
      );
      return true;
    } catch (e) {
      _log.warning('Failed to load TFLite model: $e');
      _loaded = false;
      return false;
    }
  }

  /// Close the interpreter and release resources.
  void dispose() {
    if (_interpreter != null) {
      _interpreter!.close();
      _interpreter = null;
      _loaded = false;
      _log.info('TFLite model disposed');
    }
  }
}

/// Riverpod provider for the singleton [SharedTfliteService].
///
/// Must be overridden in main.dart at startup with the loaded instance:
///   sharedTfliteServiceProvider.overrideWithValue(sharedTflite)
final sharedTfliteServiceProvider = Provider<SharedTfliteService>((ref) {
  throw UnimplementedError(
      'sharedTfliteServiceProvider must be overridden at startup');
});
