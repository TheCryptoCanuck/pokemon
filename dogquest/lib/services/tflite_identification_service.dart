import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:dogquest/models/dog.dart';
import 'package:dogquest/services/dog_service.dart';
import 'package:dogquest/services/identification_service.dart';
import 'package:dogquest/services/shared_tflite_service.dart';

/// Input size constant accessible to the top-level preprocessing function.
/// v5: 260x260 for EfficientNetB2 (was 224 for B0).
const int _kInputSize = 260;

/// Estimate subject (dog) size in the image using downsampled luminance variance
/// and edge density. Returns a score in [0.0, 1.0] where:
///   - 0.0 = very small/distant subject or blank image
///   - 0.5 = neutral/unknown
///   - 1.0 = subject fills most of frame
///
/// Algorithm:
///   1. Downsample to 64x64 using average interpolation
///   2. Convert each pixel to grayscale luminance (0.299*r + 0.587*g + 0.114*b)
///   3. Compute variance of luminances across the image
///   4. Compute edge density: count interior pixels with (|dx| + |dy|) / 2 > 15.0
///   5. Return (variance / 2000.0 + edgeDensity).clamp(0.0, 1.0)
double _estimateSubjectSize(Uint8List bytes) {
  try {
    final image = img.decodeImage(bytes);
    if (image == null) return 0.5;

    final downsampled = img.copyResize(
      image,
      width: 64,
      height: 64,
      interpolation: img.Interpolation.average,
    );

    final lum = List<double>.filled(64 * 64, 0.0);
    for (int y = 0; y < 64; y++) {
      for (int x = 0; x < 64; x++) {
        final pixel = downsampled.getPixel(x, y);
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();
        lum[y * 64 + x] = 0.299 * r + 0.587 * g + 0.114 * b;
      }
    }

    double mean = 0.0;
    for (final l in lum) {
      mean += l;
    }
    mean /= lum.length;

    double variance = 0.0;
    for (final l in lum) {
      final diff = l - mean;
      variance += diff * diff;
    }
    variance /= lum.length;

    int edgeCount = 0;
    const int interiorTotal = 62 * 62;
    for (int y = 1; y < 63; y++) {
      for (int x = 1; x < 63; x++) {
        final gx = (lum[(y * 64) + (x + 1)] - lum[(y * 64) + (x - 1)]).abs();
        final gy = (lum[((y + 1) * 64) + x] - lum[((y - 1) * 64) + x]).abs();
        final avgGrad = (gx + gy) / 2.0;
        if (avgGrad > 15.0) {
          edgeCount++;
        }
      }
    }

    final edgeDensity = edgeCount / interiorTotal;
    final score = ((variance / 2000.0) + edgeDensity).clamp(0.0, 1.0);
    return score;
  } catch (_) {
    return 0.5;
  }
}

/// Top-level function for [compute] — runs image preprocessing in a separate
/// isolate. Returns flat Uint8List tensors for TTA (test-time augmentation).
///
/// v5.1 TTA: 5 variants (center tight, horizontal flip, 1.15x, 1.5x, 1.8x zoomed-out).
List<Uint8List> _preprocessImage(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) {
    throw Exception('Failed to decode image in isolate');
  }

  var oriented = img.bakeOrientation(image);

  Uint8List buildFlatTensor(img.Image src) {
    final resized = (src.width == _kInputSize && src.height == _kInputSize)
        ? src
        : img.copyResize(
            src,
            width: _kInputSize,
            height: _kInputSize,
            interpolation: img.Interpolation.cubic,
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

  // Variant 1: tight center crop
  final tightScale = _kInputSize / shortEdge;
  final tightW = (w * tightScale).round();
  final tightH = (h * tightScale).round();
  final tight = img.copyResize(
    oriented,
    width: tightW,
    height: tightH,
    interpolation: img.Interpolation.cubic,
  );
  final tightCrop = img.copyCrop(
    tight,
    x: (tightW - _kInputSize) ~/ 2,
    y: (tightH - _kInputSize) ~/ 2,
    width: _kInputSize,
    height: _kInputSize,
  );
  tensors.add(buildFlatTensor(tightCrop));

  // Variant 2: horizontal flip of tight center crop
  tensors.add(buildFlatTensor(img.flipHorizontal(tightCrop)));

  // Variant 3: 1.15x zoomed-out center crop
  final looseTarget = (_kInputSize * 1.15).round();
  final looseScale = looseTarget / shortEdge;
  final looseW = (w * looseScale).round();
  final looseH = (h * looseScale).round();
  final loose = img.copyResize(
    oriented,
    width: looseW,
    height: looseH,
    interpolation: img.Interpolation.cubic,
  );
  final looseCrop = img.copyCrop(
    loose,
    x: (looseW - _kInputSize) ~/ 2,
    y: (looseH - _kInputSize) ~/ 2,
    width: _kInputSize,
    height: _kInputSize,
  );
  tensors.add(buildFlatTensor(looseCrop));

  // Variant 4: 1.5x zoomed-out center crop
  final looseTarget15 = (_kInputSize * 1.5).round();
  final looseScale15 = looseTarget15 / shortEdge;
  final looseW15 = (w * looseScale15).round();
  final looseH15 = (h * looseScale15).round();
  final loose15 = img.copyResize(
    oriented,
    width: looseW15,
    height: looseH15,
    interpolation: img.Interpolation.cubic,
  );
  final looseCrop15 = img.copyCrop(
    loose15,
    x: (looseW15 - _kInputSize) ~/ 2,
    y: (looseH15 - _kInputSize) ~/ 2,
    width: _kInputSize,
    height: _kInputSize,
  );
  tensors.add(buildFlatTensor(looseCrop15));

  // Variant 5: 1.8x zoomed-out center crop
  final looseTarget18 = (_kInputSize * 1.8).round();
  final looseScale18 = looseTarget18 / shortEdge;
  final looseW18 = (w * looseScale18).round();
  final looseH18 = (h * looseScale18).round();
  final loose18 = img.copyResize(
    oriented,
    width: looseW18,
    height: looseH18,
    interpolation: img.Interpolation.cubic,
  );
  final looseCrop18 = img.copyCrop(
    loose18,
    x: (looseW18 - _kInputSize) ~/ 2,
    y: (looseH18 - _kInputSize) ~/ 2,
    width: _kInputSize,
    height: _kInputSize,
  );
  tensors.add(buildFlatTensor(looseCrop18));

  return tensors;
}

final _log = Logger('TfliteIdentificationService');

/// Dog identification using an on-device TFLite classifier.
class TfliteIdentificationService implements IdentificationService {
  final DogService _dogService;
  final SharedTfliteService _sharedTflite;
  List<String> _labels = [];
  bool _loaded = false;

  Map<String, Dog?> _labelCache = {};

  static const _topK = 3;
  static const _minConfidence = 0.03;
  static const bool _enableTTA = true;

  TfliteIdentificationService(this._dogService, this._sharedTflite);

  @override
  bool get isModelLoaded => _loaded;

  Future<bool> loadModel() async {
    try {
      final modelLoaded = await _sharedTflite.loadModel();
      if (!modelLoaded) {
        _loaded = false;
        return false;
      }

      _labels = await _loadLabels();
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
      final bytes = await imageFile.readAsBytes();
      final subjectSizeScore = _estimateSubjectSize(bytes);
      _log.info(
          'SUBJ_SIZE_ESTIMATE: score=${subjectSizeScore.toStringAsFixed(2)}, '
          'hint=${subjectSizeScore < 0.35 ? "SMALL_SUBJECT" : "OK"}');

      final tensors = await compute(_preprocessImage, bytes);
      final flatTensors = _enableTTA ? tensors : [tensors[0]];

      final outputTensor = interpreter.getOutputTensor(0);
      final outputShape = outputTensor.shape;
      final numClasses = outputShape.last;
      final isUint8 = outputTensor.type == TensorType.uint8;
      final avgScores = List<double>.filled(numClasses, 0.0);

      for (final flatInput in flatTensors) {
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

      final count = flatTensors.length.toDouble();
      for (int i = 0; i < numClasses; i++) {
        avgScores[i] /= count;
      }

      _log.info('TTA: ran ${flatTensors.length} variant(s), '
          'subject_size=${subjectSizeScore.toStringAsFixed(2)}');
      return _buildResults(avgScores, subjectSizeScore: subjectSizeScore);
    } catch (e, st) {
      _log.severe('Identification failed', e, st);
      return [];
    }
  }

  List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce((a, b) => a > b ? a : b);
    final exps = logits.map((l) => math.exp(l - maxLogit)).toList();
    final sum = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sum).toList();
  }

  /// Build ranked [IdentificationResult] list from raw model output scores.
  ///
  /// Features:
  ///   - Entropy-based rejection for nearly-uniform distributions
  ///   - Entropy-aware top-K truncation (top-1/2/3 based on uncertainty)
  ///   - Gap-rejection skipped for small/distant subjects
  ///   - LOW_SIGNAL_RESULT logging for field diagnosis
  List<IdentificationResult> _buildResults(
    List<double> scores, {
    double subjectSizeScore = 0.5,
  }) {
    final hasNegative = scores.any((s) => s < 0);
    final probs = hasNegative ? _softmax(scores) : scores;

    double entropy = 0.0;
    for (final p in probs) {
      if (p > 0) entropy -= p * math.log(p);
    }
    final double maxEntropy = math.log(probs.length);
    final double normalizedEntropy =
        maxEntropy > 0 ? entropy / maxEntropy : 0.0;

    final indexed =
        List.generate(probs.length, (i) => (index: i, prob: probs[i]));
    indexed.sort((a, b) => b.prob.compareTo(a.prob));

    final double topProb = indexed.isNotEmpty ? indexed.first.prob : 0.0;
    final double top2Prob = indexed.length > 1 ? indexed[1].prob : 0.0;
    final double confidenceGap = topProb - top2Prob;

    _log.info('Entropy: ${normalizedEntropy.toStringAsFixed(3)}, '
        'top-1: ${(topProb * 100).toStringAsFixed(1)}%, '
        'top-2: ${(top2Prob * 100).toStringAsFixed(1)}%, '
        'gap: ${(confidenceGap * 100).toStringAsFixed(1)}%');
    _log.fine('HOUND_ID: entropy=${normalizedEntropy.toStringAsFixed(3)}, '
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
      _log.fine('HOUND_ID: [${i + 1}] ${(e.prob * 100).toStringAsFixed(2)}% — '
          'label="$label" -> "$dogName"');
    }

    // Reject nearly-uniform distributions (no signal)
    if (normalizedEntropy > 0.97) {
      _log.info(
        'Rejected: entropy ${normalizedEntropy.toStringAsFixed(3)} > 0.97 — nearly uniform',
      );
      return [];
    }

    // Entropy-aware top-K: reduce noise for uncertain predictions
    final int dynamicTopK;
    if (normalizedEntropy > 0.90) {
      dynamicTopK = 1;
    } else if (normalizedEntropy > 0.80) {
      dynamicTopK = 2;
    } else {
      dynamicTopK = _topK;
    }

    // Gap-rejection: skip for small/distant subjects
    if (topProb < 0.05 && confidenceGap < 0.01 && subjectSizeScore >= 0.35) {
      _log.info(
          'Rejected: low confidence ${(topProb * 100).toStringAsFixed(1)}% '
          'with tiny gap ${(confidenceGap * 100).toStringAsFixed(2)}% '
          '(subject_size=${subjectSizeScore.toStringAsFixed(2)})');
      return [];
    }

    final results = <IdentificationResult>[];
    final seen = <String>{};

    for (final entry in indexed.take(dynamicTopK * 2)) {
      if (entry.prob < _minConfidence) break;
      if (entry.index >= _labels.length) continue;

      final label = _labels[entry.index];
      final dog = _matchLabelToDog(label);
      if (dog == null) continue;
      if (seen.contains(dog.name)) continue;
      seen.add(dog.name);

      results.add(
        IdentificationResult(
          dog: dog,
          confidence: entry.prob,
          source: 'ml',
        ),
      );

      if (results.length >= dynamicTopK) break;
    }

    if (results.isNotEmpty) {
      _log.info('Returning ${results.length} result(s): '
          '${results.map((r) => '${r.dog.name} ${(r.confidence * 100).toStringAsFixed(1)}%').join(', ')}');
      _log.info(
        'HOUND_ID: RESULT -> ${results.map((r) => '${r.dog.name} ${(r.confidence * 100).toStringAsFixed(1)}%').join(', ')}',
      );

      if (results.first.confidence < 0.15) {
        _log.info(
            'LOW_SIGNAL_RESULT: entropy=${normalizedEntropy.toStringAsFixed(3)}, '
            'top1=${(results.first.confidence * 100).toStringAsFixed(1)}%, '
            'subjectSize=${subjectSizeScore.toStringAsFixed(2)}, '
            'action=${normalizedEntropy > 0.85 ? "GUIDE_USER_CLOSER" : "UNCERTAIN_MATCH"}');
      }
    } else {
      _log.info('No label matches — returning unrecognized sentinel');
      return _unrecognizedResult();
    }

    return results;
  }

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

  Dog? _matchLabelToDog(String label) {
    if (label.isEmpty || label.startsWith('_')) return null;
    return _labelCache[label];
  }
}
