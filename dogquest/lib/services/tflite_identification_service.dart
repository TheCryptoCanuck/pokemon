import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/dog.dart';
import 'dog_service.dart';
import 'identification_service.dart';
import 'shared_tflite_service.dart';

/// Input size constant accessible to the top-level preprocessing function.
/// v5: 260x260 for EfficientNetB2 (was 224 for B0).
const int _kInputSize = 260;

/// Top-level function for [compute] — runs image preprocessing in a separate
/// isolate.  Returns flat Uint8List tensors for TTA (test-time augmentation).
///
/// v5.1 optimized TTA: 3 variants (center tight, center flipped, center zoomed-out).
/// Each tensor is a flat Uint8List of length _kInputSize * _kInputSize * 3 (RGB).
/// Using flat Uint8List instead of nested List<int> reduces:
///   - Memory: ~600KB vs ~30-40MB (50x reduction)
///   - Serialization: Uint8List transfers as raw bytes via SendPort
///   - GC pressure: 3 buffers vs 2M+ boxed objects
List<Uint8List> _preprocessImage(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) {
    throw Exception('Failed to decode image in isolate');
  }

  // EXIF orientation
  var oriented = img.bakeOrientation(image);

  // Build flat tensor from an Image region
  Uint8List buildFlatTensor(img.Image src) {
    final resized = (src.width == _kInputSize && src.height == _kInputSize)
        ? src
        : img.copyResize(
            src,
            width: _kInputSize,
            height: _kInputSize,
            interpolation: img.Interpolation.linear,
          );
    final flat = Uint8List(_kInputSize * _kInputSize * 3);
    int offset = 0;
    for (int y = 0; y < _kInputSize; y++) {
      for (int x = 0; x < _kInputSize; x++) {
        final pixel = resized.getPixel(x, y);
        flat[offset++] = pixel.r.toInt().clamp(0, 255);
        flat[offset++] = pixel.g.toInt().clamp(0, 255);
        flat[offset++] = pixel.b.toInt().clamp(0, 255);
      }
    }
    return flat;
  }

  final w = oriented.width;
  final h = oriented.height;
  final shortEdge = w < h ? w : h;

  final tensors = <Uint8List>[];

  // Variant 1: tight center crop (scale shorter edge to _kInputSize)
  final tightScale = _kInputSize / shortEdge;
  final tightW = (w * tightScale).round();
  final tightH = (h * tightScale).round();
  final tight = img.copyResize(oriented,
      width: tightW, height: tightH, interpolation: img.Interpolation.linear);
  final tightCrop = img.copyCrop(tight,
      x: (tightW - _kInputSize) ~/ 2,
      y: (tightH - _kInputSize) ~/ 2,
      width: _kInputSize,
      height: _kInputSize);
  tensors.add(buildFlatTensor(tightCrop));

  // Variant 2: horizontal flip of tight center crop
  tensors.add(buildFlatTensor(img.flipHorizontal(tightCrop)));

  // Variant 3: slightly zoomed-out center crop (1.15x gives context)
  final looseTarget = (_kInputSize * 1.15).round();
  final looseScale = looseTarget / shortEdge;
  final looseW = (w * looseScale).round();
  final looseH = (h * looseScale).round();
  final loose = img.copyResize(oriented,
      width: looseW, height: looseH, interpolation: img.Interpolation.linear);
  final looseCrop = img.copyCrop(loose,
      x: (looseW - _kInputSize) ~/ 2,
      y: (looseH - _kInputSize) ~/ 2,
      width: _kInputSize,
      height: _kInputSize);
  tensors.add(buildFlatTensor(looseCrop));

  return tensors; // 3 tensors, ~600KB total
}

final _log = Logger('TfliteIdentificationService');

/// Dog identification using an on-device TFLite classifier.
///
/// Expects:
///   - Shared TFLite model from [SharedTfliteService]
///   - `assets/dog_labels.txt`   — one label per line (scientific or common name)
///
/// Compatible with Google's AIY Vision Dog Classifier V1 and similar models
/// trained on iNaturalist/NADogs data with 224×224 input.
class TfliteIdentificationService implements IdentificationService {
  final DogService _dogService;
  final SharedTfliteService _sharedTflite;
  List<String> _labels = [];
  bool _loaded = false;

  /// Pre-computed label → Dog cache (O(1) lookup, built at model load time).
  Map<String, Dog?> _labelCache = {};

  /// Number of top predictions to return.
  static const _topK = 3;

  /// Minimum confidence to include in results (low because label smoothing
  /// flattens distributions; uniform for 151 classes = 0.66%).
  static const _minConfidence = 0.03;

  /// Enable Test-Time Augmentation (original + horizontal flip, averaged).
  static const bool _enableTTA = true;

  TfliteIdentificationService(this._dogService, this._sharedTflite);

  @override
  bool get isModelLoaded => _loaded;

  /// Load the TFLite model and labels from assets.
  /// Returns true if successful, false if model files are missing.
  ///
  /// This method ensures the shared TFLite service is loaded, then loads
  /// labels and builds the label cache.
  Future<bool> loadModel() async {
    try {
      // Ensure the shared interpreter is loaded (idempotent)
      final modelLoaded = await _sharedTflite.loadModel();
      if (!modelLoaded) {
        _loaded = false;
        return false;
      }

      _labels = await _loadLabels();
      // Pre-resolve all labels to Dog objects once at load time
      _labelCache = {
        for (final label in _labels)
          label: _dogService.lookupByCommonName(label),
      };
      _loaded = true;
      final interpreter = _sharedTflite.interpreter;
      if (interpreter != null) {
        _log.info(
          'TfliteIdentificationService ready: '
          '${_labels.length} labels, '
          '${_labelCache.values.where((d) => d != null).length} matched',
        );
      }
      return true;
    } catch (e) {
      _log.warning('TFLite model not available: $e');
      _loaded = false;
      return false;
    }
  }

  Future<List<String>> _loadLabels() async {
    final raw = await rootBundle.loadString('assets/dog_labels.txt');
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  @override
  Future<List<IdentificationResult>> identify(File imageFile) async {
    final interpreter = _sharedTflite.interpreter;
    if (!_loaded || interpreter == null) {
      _log.warning('Model not loaded, cannot identify');
      return [];
    }

    try {
      // 1. Read image bytes and preprocess off the main isolate
      final bytes = await imageFile.readAsBytes();
      final tensors = await compute(_preprocessImage, bytes);

      // v5.1: tensors are flat Uint8List, 3 variants (tight, flipped, zoomed-out)
      final flatTensors = _enableTTA ? tensors : [tensors[0]];

      // 2. Run inference on the main isolate (fast native call)
      final outputTensor = interpreter.getOutputTensor(0);
      final outputShape = outputTensor.shape;
      final numClasses = outputShape.last;
      final isUint8 = outputTensor.type == TensorType.uint8;
      // Accumulator for averaged scores
      final avgScores = List<double>.filled(numClasses, 0.0);

      for (final flatInput in flatTensors) {
        // Pass flat Uint8List directly — tflite_flutter has fast paths for
        // Uint8List in both getInputShapeIfDifferent (skips shape check) and
        // convertObjectToBytes (returns as-is). Avoids creating 270K+ nested
        // List objects from reshape().

        late final List output;
        if (isUint8) {
          output = List.filled(numClasses, 0).reshape([1, numClasses]);
        } else {
          output = List.filled(numClasses, 0.0).reshape([1, numClasses]);
        }
        interpreter.run(flatInput, output);

        final rawScores = output[0] as List;
        for (int i = 0; i < numClasses; i++) {
          double score = (rawScores[i] as num).toDouble();
          if (isUint8) score /= 255.0;
          avgScores[i] += score;
        }
      }

      // Average across all variants
      final count = flatTensors.length.toDouble();
      for (int i = 0; i < numClasses; i++) {
        avgScores[i] /= count;
      }

      _log.info('TTA: ran ${flatTensors.length} variant(s)');
      return _buildResults(avgScores);
    } catch (e, st) {
      _log.severe('Identification failed', e, st);
      return [];
    }
  }

  /// Apply softmax to raw logits to get probabilities.
  List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce((a, b) => a > b ? a : b);
    final exps = logits.map((l) => math.exp(l - maxLogit)).toList();
    final sum = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sum).toList();
  }

  /// Build ranked [IdentificationResult] list from raw model output scores.
  ///
  /// Uses the same simple, proven algorithm as AviQuest:
  ///   - Entropy-based rejection for non-dog / ambiguous photos
  ///   - Simple confidence thresholds
  ///   - Raw probability as confidence (no normalization)
  List<IdentificationResult> _buildResults(List<double> scores) {
    // Check if scores look like logits (can be negative) or probabilities
    final hasNegative = scores.any((s) => s < 0);
    final probs = hasNegative ? _softmax(scores) : scores;

    // --- Entropy-based rejection for non-dog / ambiguous photos ---
    double entropy = 0.0;
    for (final p in probs) {
      if (p > 0) entropy -= p * math.log(p);
    }
    final double maxEntropy = math.log(probs.length);
    final double normalizedEntropy =
        maxEntropy > 0 ? entropy / maxEntropy : 0.0;

    // Create indexed entries and sort by probability descending
    final indexed =
        List.generate(probs.length, (i) => (index: i, prob: probs[i]));
    indexed.sort((a, b) => b.prob.compareTo(a.prob));

    final double topProb = indexed.isNotEmpty ? indexed.first.prob : 0.0;
    final double top2Prob = indexed.length > 1 ? indexed[1].prob : 0.0;
    final double confidenceGap = topProb - top2Prob;

    // --- Debug logging ---
    _log.info('Entropy: ${normalizedEntropy.toStringAsFixed(3)}, '
        'top-1: ${(topProb * 100).toStringAsFixed(1)}%, '
        'top-2: ${(top2Prob * 100).toStringAsFixed(1)}%, '
        'gap: ${(confidenceGap * 100).toStringAsFixed(1)}%');
    _log.fine('DOGQUEST_ID: entropy=${normalizedEntropy.toStringAsFixed(3)}, '
        'top1=${(topProb * 100).toStringAsFixed(1)}%, '
        'top2=${(top2Prob * 100).toStringAsFixed(1)}%, '
        'gap=${(confidenceGap * 100).toStringAsFixed(1)}%');

    for (int i = 0; i < math.min(5, indexed.length); i++) {
      final e = indexed[i];
      final label = e.index < _labels.length ? _labels[e.index] : '?';
      final dog = _matchLabelToDog(label);
      final dogName = dog?.name ?? '(no match)';
      _log.info('  [${i + 1}] ${(e.prob * 100).toStringAsFixed(2)}% — '
          'label="$label" -> "$dogName"');
      _log.fine(
          'DOGQUEST_ID: [${i + 1}] ${(e.prob * 100).toStringAsFixed(2)}% — '
          'label="$label" -> "$dogName"');
    }

    // --- Rejection logic ---
    // This is a dog-only classifier (151 breeds). Every output IS a dog breed.
    // Only reject truly uniform distributions where the model has zero signal.
    // Uniform for 151 classes = ~0.66% each, entropy = 1.0.
    if (normalizedEntropy > 0.97) {
      _log.info(
          'Rejected: entropy ${normalizedEntropy.toStringAsFixed(3)} > 0.97 — nearly uniform');
      return [];
    }

    // Confidence-gap rejection: if top-1 is very close to top-2, the model
    // can't distinguish — likely a non-dog or ambiguous photo.
    // Only apply when top-1 confidence is also very low.
    if (topProb < 0.05 && confidenceGap < 0.01) {
      _log.info(
          'Rejected: low confidence ${(topProb * 100).toStringAsFixed(1)}% '
          'with tiny gap ${(confidenceGap * 100).toStringAsFixed(2)}%');
      return [];
    }

    // --- Build results with simple min confidence ---
    final results = <IdentificationResult>[];
    final seen = <String>{};

    for (final entry in indexed.take(_topK * 2)) {
      if (entry.prob < _minConfidence) break;
      if (entry.index >= _labels.length) continue;

      final label = _labels[entry.index];
      final dog = _matchLabelToDog(label);
      if (dog == null) continue;
      if (seen.contains(dog.name)) continue;
      seen.add(dog.name);

      results.add(IdentificationResult(
        dog: dog,
        confidence: entry.prob,
        source: 'ml',
      ));

      if (results.length >= _topK) break;
    }

    if (results.isNotEmpty) {
      _log.info('Returning ${results.length} result(s): '
          '${results.map((r) => '${r.dog.name} ${(r.confidence * 100).toStringAsFixed(1)}%').join(', ')}');
      _log.info(
          'DOGQUEST_ID: RESULT -> ${results.map((r) => '${r.dog.name} ${(r.confidence * 100).toStringAsFixed(1)}%').join(', ')}');
    } else {
      _log.info('No label matches — returning unrecognized sentinel');
      return _unrecognizedResult();
    }

    return results;
  }

  /// Return a sentinel result list that tells the UI the model detected a dog
  /// but could not match it to any known breed in our database.
  List<IdentificationResult> _unrecognizedResult() {
    final placeholder = _dogService.unknownDog('Unknown Breed');
    return [
      IdentificationResult(
        dog: placeholder,
        confidence: 0.0,
        source: 'unrecognized',
      ),
    ];
  }

  /// Match a model label to a Dog in our database.
  /// Uses pre-computed cache (O(1)) built at model load time.
  Dog? _matchLabelToDog(String label) {
    if (label.isEmpty || label.startsWith('_')) return null;
    return _labelCache[label];
  }
}
