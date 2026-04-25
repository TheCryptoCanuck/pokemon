import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

final _log = Logger('DogEmbeddingService');

/// Input size for EfficientNetB2 (must match tflite_identification_service.dart).
const int _kInputSize = 260;

/// Top-level function for compute isolate — preprocesses a single image.
Uint8List _preprocessForEmbedding(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) throw Exception('Failed to decode image');

  var oriented = img.bakeOrientation(image);
  final w = oriented.width;
  final h = oriented.height;
  final shortEdge = w < h ? w : h;

  // Center crop to square, resize to model input size
  final scale = _kInputSize / shortEdge;
  final scaledW = (w * scale).round();
  final scaledH = (h * scale).round();
  final resized = img.copyResize(oriented,
      width: scaledW, height: scaledH, interpolation: img.Interpolation.linear);
  final cropped = img.copyCrop(resized,
      x: (scaledW - _kInputSize) ~/ 2,
      y: (scaledH - _kInputSize) ~/ 2,
      width: _kInputSize,
      height: _kInputSize);

  final flat = Uint8List(_kInputSize * _kInputSize * 3);
  int offset = 0;
  for (int y = 0; y < _kInputSize; y++) {
    for (int x = 0; x < _kInputSize; x++) {
      final pixel = cropped.getPixel(x, y);
      flat[offset++] = pixel.r.toInt().clamp(0, 255);
      flat[offset++] = pixel.g.toInt().clamp(0, 255);
      flat[offset++] = pixel.b.toInt().clamp(0, 255);
    }
  }
  return flat;
}

/// Extracts visual embeddings from dog photos for the Lost Dog Recognition Network.
///
/// Uses the same EfficientNetB2 model as breed identification. The 150-dim
/// softmax output serves as a "breed fingerprint" — dogs of the same individual
/// produce very similar probability distributions, enabling matching.
class DogEmbeddingService {
  Interpreter? _interpreter;
  bool _loaded = false;

  bool get isLoaded => _loaded;

  /// Load the TFLite model (same model as breed identification).
  Future<bool> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/dog_model.tflite');
      _loaded = true;
      _log.info('Embedding model loaded');
      return true;
    } catch (e) {
      _log.warning('Failed to load embedding model: $e');
      return false;
    }
  }

  /// Extract a 150-dim embedding (softmax output) from a dog photo.
  ///
  /// Returns normalized probability distribution across all breeds.
  /// Two photos of the same dog will produce similar distributions.
  Future<List<double>> extractEmbedding(File imageFile) async {
    if (!_loaded || _interpreter == null) {
      _log.warning('Model not loaded');
      return [];
    }

    try {
      final bytes = await imageFile.readAsBytes();
      final tensor = await compute(_preprocessForEmbedding, bytes);

      final outputTensor = _interpreter!.getOutputTensor(0);
      final numClasses = outputTensor.shape.last;
      final isUint8 = outputTensor.type == TensorType.uint8;

      late final List output;
      if (isUint8) {
        output = List.filled(numClasses, 0).reshape([1, numClasses]);
      } else {
        output = List.filled(numClasses, 0.0).reshape([1, numClasses]);
      }

      _interpreter!.run(tensor, output);

      final rawScores = output[0] as List;
      final embedding = List<double>.filled(numClasses, 0.0);
      for (int i = 0; i < numClasses; i++) {
        double score = (rawScores[i] as num).toDouble();
        if (isUint8) score /= 255.0;
        embedding[i] = score;
      }

      _log.info('Extracted ${embedding.length}-dim embedding');
      return embedding;
    } catch (e, st) {
      _log.severe('Embedding extraction failed', e, st);
      return [];
    }
  }

  /// Cosine similarity between two embeddings. Returns 0.0–1.0.
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    final denominator = math.sqrt(normA) * math.sqrt(normB);
    if (denominator == 0) return 0.0;

    // Clamp to [0, 1] — softmax outputs are non-negative so similarity
    // should always be positive, but floating point can drift.
    return (dotProduct / denominator).clamp(0.0, 1.0);
  }

  /// Average multiple embeddings (from multiple photos of the same dog).
  static List<double> averageEmbeddings(List<List<double>> embeddings) {
    if (embeddings.isEmpty) return [];
    if (embeddings.length == 1) return List.from(embeddings.first);

    final dim = embeddings.first.length;
    final avg = List<double>.filled(dim, 0.0);
    for (final emb in embeddings) {
      for (int i = 0; i < dim; i++) {
        avg[i] += emb[i];
      }
    }
    final n = embeddings.length.toDouble();
    for (int i = 0; i < dim; i++) {
      avg[i] /= n;
    }
    return avg;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _loaded = false;
  }
}

final dogEmbeddingServiceProvider = Provider<DogEmbeddingService>((ref) {
  throw UnimplementedError(
      'dogEmbeddingServiceProvider must be overridden after init');
});
