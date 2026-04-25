import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dog.dart';

/// Confidence tier for identification results.
///
/// Thresholds are calibrated for label-smoothed models where correct
/// predictions typically produce 10-50% raw confidence. The tiers map
/// raw model output to user-facing quality labels.
enum ConfidenceTier {
  high, // >= 35% raw — model is quite sure
  medium, // >= 20% raw — decent match, worth showing
  low; // < 20% raw  — uncertain, hedge the language

  /// User-facing label for this confidence tier.
  String get label {
    switch (this) {
      case ConfidenceTier.high:
        return 'High Match';
      case ConfidenceTier.medium:
        return 'Good Match';
      case ConfidenceTier.low:
        return 'Possible Match';
    }
  }

  /// Color associated with this tier.
  Color get color {
    switch (this) {
      case ConfidenceTier.high:
        return const Color(0xFF4CAF50); // green
      case ConfidenceTier.medium:
        return const Color(0xFFFFB300); // amber
      case ConfidenceTier.low:
        return const Color(0xFFFF7043); // deep orange
    }
  }

  /// Icon for the tier badge.
  IconData get icon {
    switch (this) {
      case ConfidenceTier.high:
        return Icons.verified_rounded;
      case ConfidenceTier.medium:
        return Icons.check_circle_outline_rounded;
      case ConfidenceTier.low:
        return Icons.help_outline_rounded;
    }
  }

  /// Normalized display value (0.0-1.0) that maps the raw confidence
  /// to a visually meaningful gauge. This prevents showing a tiny
  /// sliver for a perfectly correct 40% prediction.
  ///
  /// Mapping: 0% raw -> 0.0 display, 15% -> 0.3, 35% -> 0.7, 50%+ -> 1.0
  static double normalizedDisplay(double rawConfidence) {
    if (rawConfidence >= 0.50) return 1.0;
    if (rawConfidence >= 0.35) return 0.7 + (rawConfidence - 0.35) / 0.15 * 0.3;
    if (rawConfidence >= 0.15) return 0.3 + (rawConfidence - 0.15) / 0.20 * 0.4;
    return rawConfidence / 0.15 * 0.3;
  }
}

/// Result of a dog identification attempt.
class IdentificationResult {
  final Dog dog;
  final double confidence;
  final String source; // 'ml', 'manual', 'unrecognized'

  const IdentificationResult({
    required this.dog,
    required this.confidence,
    required this.source,
  });

  /// Whether this is a sentinel result indicating the model could not
  /// identify the breed (prompts the UI to offer manual search).
  bool get isUnrecognized => source == 'unrecognized';

  /// Categorize confidence into high/medium/low tiers.
  /// Calibrated for label-smoothed models (typical correct = 10-50%).
  ConfidenceTier get confidenceTier {
    if (confidence >= 0.35) return ConfidenceTier.high;
    if (confidence >= 0.20) return ConfidenceTier.medium;
    return ConfidenceTier.low;
  }

  /// Whether [other] is close enough in confidence to be considered a
  /// plausible alternative (gap < 0.10). Returns false when [other] is null.
  bool isCloseToAlternative(IdentificationResult? other) {
    if (other == null) return false;
    return (confidence - other.confidence).abs() < 0.10;
  }
}

/// Abstraction for dog identification.
abstract class IdentificationService {
  /// Identify a dog from a photo. Returns top predictions ranked by confidence.
  Future<List<IdentificationResult>> identify(File imageFile);

  /// Whether the service is using a real ML model vs mock.
  bool get isModelLoaded;
}

final identificationServiceProvider = Provider<IdentificationService>((ref) {
  throw UnimplementedError(
      'identificationServiceProvider must be overridden at startup');
});
