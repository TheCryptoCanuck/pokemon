import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/bird.dart';
import 'bird_service.dart';
import 'identification_service.dart';

final _log = Logger('TfliteIdentificationService');

/// Bird identification using an on-device TFLite classifier.
///
/// Expects:
///   - `assets/bird_model.tflite` — EfficientNet/MobileNet bird classifier
///   - `assets/bird_labels.txt`   — one label per line (scientific or common name)
///
/// Compatible with Google's AIY Vision Bird Classifier V1 and similar models
/// trained on iNaturalist/NABirds data with 224×224 input.
class TfliteIdentificationService implements IdentificationService {
  final BirdService _birdService;
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _loaded = false;

  /// Model input dimensions (standard for EfficientNet-Lite / MobileNet).
  static const _inputSize = 224;

  /// Number of top predictions to return.
  static const _topK = 3;

  /// Minimum confidence to include in results.
  static const _minConfidence = 0.02;

  TfliteIdentificationService(this._birdService);

  @override
  bool get isModelLoaded => _loaded;

  /// Load the TFLite model and labels from assets.
  /// Returns true if successful, false if model files are missing.
  Future<bool> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('bird_model.tflite');
      _labels = await _loadLabels();
      _loaded = true;
      _log.info(
        'TFLite model loaded: '
        'input=${_interpreter!.getInputTensor(0).shape}, '
        'output=${_interpreter!.getOutputTensor(0).shape}, '
        '${_labels.length} labels',
      );
      return true;
    } catch (e) {
      _log.warning('TFLite model not available: $e');
      _loaded = false;
      return false;
    }
  }

  Future<List<String>> _loadLabels() async {
    final raw = await rootBundle.loadString('assets/bird_labels.txt');
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  @override
  Future<List<IdentificationResult>> identify(File imageFile) async {
    if (!_loaded || _interpreter == null) {
      _log.warning('Model not loaded, cannot identify');
      return [];
    }

    try {
      // 1. Read and decode the image
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) {
        _log.warning('Failed to decode image: ${imageFile.path}');
        return [];
      }

      // 2. Preprocess: resize and build input tensor
      final input = _preprocessImage(image);

      // 3. Run inference
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final numClasses = outputShape.last;
      final output = List.filled(numClasses, 0.0).reshape([1, numClasses]);
      _interpreter!.run(input, output);

      // 4. Extract and rank predictions
      final scores = (output[0] as List).cast<double>();
      return _buildResults(scores);
    } catch (e, st) {
      _log.severe('Identification failed', e, st);
      return [];
    }
  }

  @override
  Future<List<IdentificationResult>> identifyByAudio(File audioFile) async {
    // Audio identification requires a separate model — not yet supported.
    _log.info('Audio identification not yet supported with TFLite');
    return [];
  }

  /// Resize image to [_inputSize]x[_inputSize] and normalize pixel values
  /// to [0.0, 1.0] as a Float32 tensor shaped [1, height, width, 3].
  List<List<List<List<double>>>> _preprocessImage(img.Image image) {
    final resized = img.copyResize(
      image,
      width: _inputSize,
      height: _inputSize,
      interpolation: img.Interpolation.linear,
    );

    return [
      List.generate(_inputSize, (y) {
        return List.generate(_inputSize, (x) {
          final pixel = resized.getPixel(x, y);
          return [
            pixel.r / 255.0,
            pixel.g / 255.0,
            pixel.b / 255.0,
          ];
        });
      }),
    ];
  }

  /// Apply softmax to raw logits to get probabilities.
  List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce((a, b) => a > b ? a : b);
    final exps = logits.map((l) => math.exp(l - maxLogit)).toList();
    final sum = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sum).toList();
  }

  /// Build ranked [IdentificationResult] list from raw model output scores.
  List<IdentificationResult> _buildResults(List<double> scores) {
    // Check if scores look like logits (can be negative) or probabilities
    final hasNegative = scores.any((s) => s < 0);
    final probs = hasNegative ? _softmax(scores) : scores;

    // Create indexed entries and sort by probability descending
    final indexed = List.generate(probs.length, (i) => (index: i, prob: probs[i]));
    indexed.sort((a, b) => b.prob.compareTo(a.prob));

    final results = <IdentificationResult>[];
    final seen = <String>{};

    for (final entry in indexed.take(_topK * 2)) {
      if (entry.prob < _minConfidence) break;
      if (entry.index >= _labels.length) continue;

      final label = _labels[entry.index];
      final bird = _matchLabelToBird(label);
      if (bird == null) continue;
      if (seen.contains(bird.name)) continue;
      seen.add(bird.name);

      results.add(IdentificationResult(
        bird: bird,
        confidence: entry.prob,
        source: 'ml',
      ));

      if (results.length >= _topK) break;
    }

    return results;
  }

  /// Match a model label to a Bird in our database.
  ///
  /// Supports label formats:
  ///   - "Poecile atricapillus" (scientific name only)
  ///   - "Poecile atricapillus (Black-capped Chickadee)" (sci + common)
  ///   - "Black-capped Chickadee" (common name only)
  Bird? _matchLabelToBird(String label) {
    // Try parsing "ScientificName (CommonName)" format
    final parenMatch = RegExp(r'^(.+?)\s*\((.+?)\)$').firstMatch(label);
    if (parenMatch != null) {
      final sciName = parenMatch.group(1)!.trim();
      final commonName = parenMatch.group(2)!.trim();
      return _birdService.lookupByScientificName(sciName) ??
          _birdService.lookup(commonName) ??
          _birdService.unknownBird(commonName);
    }

    // Try as scientific name
    final byScientific = _birdService.lookupByScientificName(label);
    if (byScientific != null) return byScientific;

    // Try as common name
    final byCommon = _birdService.lookup(label);
    if (byCommon != null) return byCommon;

    // No match — create unknown bird entry
    return _birdService.unknownBird(label);
  }
}
