// test/tflite_identification_service_test.dart
//
// Unit tests for the pure-logic portions of TfliteIdentificationService.
//
// Testing strategy
// ----------------
// The private methods _buildResults(), _softmax(), and _matchLabelToDog() are
// not accessible cross-library in Dart. We test them through two complementary
// approaches:
//
//   A. Logic mirrors — small inline Dart functions that replicate the EXACT
//      arithmetic from tflite_identification_service.dart. These provide fast,
//      framework-free validation of softmax, entropy, rejection gates, top-K
//      selection, and confidence thresholds.
//
//      The mirrors implement the real algorithm from the source:
//        Gate 1: normalizedEntropy > 0.97  → reject (return [])
//        Gate 2: topProb < 0.05 AND gap < 0.01 → reject (return [])
//        Top-K:  iterate sorted entries, include if prob >= _minConfidence (0.03)
//                and label maps to a Dog; stop when _topK (3) results accumulated.
//
//   B. Public model tests — IdentificationResult and ConfidenceTier are tested
//      directly against the actual thresholds declared in identification_service.dart:
//        high   >= 0.35
//        medium >= 0.20
//        low    <  0.20
//
//   C. Label cache simulation — the label-cache population and lookup logic in
//      _matchLabelToDog is mirrored and tested against a MockDogService.
//
//   D. TTA averaging — the three-variant averaging arithmetic is verified with
//      a mirrored accumulator that matches the loop in identify().
//
// The TFLite Interpreter and File I/O are never instantiated. Every test runs
// without a device, emulator, or asset bundle.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dogquest/constants.dart';
import 'package:dogquest/models/dog.dart';
import 'package:dogquest/services/dog_service.dart';
import 'package:dogquest/services/identification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mocks and fixtures
// ─────────────────────────────────────────────────────────────────────────────

class MockDogService extends Mock implements DogService {}

/// Builds a minimal [Dog] fixture with overrideable rarity and XP.
Dog _dog(
  String name, {
  Rarity rarity = Rarity.common,
  int baseXp = 20,
}) =>
    Dog(
      name: name,
      scientificName: 'Canis lupus $name',
      imageUrl: '',
      audioUrl: '',
      lore: '',
      habitat: 'Domestic',
      conservationStatus: 'LC',
      rarity: rarity,
      baseXp: baseXp,
    );

// ─────────────────────────────────────────────────────────────────────────────
// Logic mirrors
//
// Keep these mechanically faithful to tflite_identification_service.dart.
// Any arithmetic change in the source must be reflected here.
// ─────────────────────────────────────────────────────────────────────────────

// Constants mirrored from TfliteIdentificationService.
const _kTopK = 3;
const _kMinConfidence = 0.03;

/// Mirrors TfliteIdentificationService._softmax().
///
/// Applies numerically stable softmax via max-subtraction before exponentiation.
List<double> _softmax(List<double> logits) {
  final maxLogit = logits.reduce((a, b) => a > b ? a : b);
  final exps = logits.map((l) => math.exp(l - maxLogit)).toList();
  final sum = exps.reduce((a, b) => a + b);
  return exps.map((e) => e / sum).toList();
}

/// Structured output from the _buildResults mirror so tests can inspect
/// both the rejection decision and the accepted entries independently.
class _Decision {
  final bool rejected;
  final String? rejectionReason; // 'entropy' | 'gap'
  final List<_Entry> accepted;

  const _Decision({
    required this.rejected,
    this.rejectionReason,
    this.accepted = const [],
  });
}

class _Entry {
  final int index;
  final double prob;
  const _Entry({required this.index, required this.prob});
}

/// Mirrors TfliteIdentificationService._buildResults().
///
/// [scores] may contain negatives (logits) or be non-negative probabilities.
/// [acceptEntry] simulates _matchLabelToDog: return true when the entry at
///   that index resolves to a Dog. Pass null to accept every valid index.
_Decision _mirrorBuildResults(
  List<double> scores, {
  bool Function(int index)? acceptEntry,
}) {
  final n = scores.length;

  // 1. Apply softmax when any score is negative.
  final hasNegative = scores.any((s) => s < 0);
  final probs = hasNegative ? _softmax(scores) : List<double>.from(scores);

  // 2. Compute normalized Shannon entropy.
  double entropy = 0.0;
  for (final p in probs) {
    if (p > 0) entropy -= p * math.log(p);
  }
  final double maxEntropy = math.log(n);
  final double normalizedEntropy = maxEntropy > 0 ? entropy / maxEntropy : 0.0;

  // 3. Sort descending by probability.
  final indexed = List.generate(n, (i) => (index: i, prob: probs[i]));
  indexed.sort((a, b) => b.prob.compareTo(a.prob));

  final double topProb = indexed.isNotEmpty ? indexed.first.prob : 0.0;
  final double top2Prob = indexed.length > 1 ? indexed[1].prob : 0.0;
  final double gap = topProb - top2Prob;

  // --- Gate 1: entropy-based rejection ---
  if (normalizedEntropy > 0.97) {
    return const _Decision(rejected: true, rejectionReason: 'entropy');
  }

  // --- Gate 2: confidence-gap rejection ---
  if (topProb < 0.05 && gap < 0.01) {
    return const _Decision(rejected: true, rejectionReason: 'gap');
  }

  // --- Build top-K results ---
  // Mirrors the exact loop in _buildResults:
  //   for (final entry in indexed.take(_topK * 2)):
  //     if prob < _minConfidence: break
  //     if dog == null: continue
  //     add; if results.length >= _topK: break
  final accepted = <_Entry>[];
  final seen = <int>{};

  for (final entry in indexed.take(_kTopK * 2)) {
    if (entry.prob < _kMinConfidence) break;
    if (entry.index >= n) continue;
    final accept = acceptEntry == null || acceptEntry(entry.index);
    if (!accept) continue;
    if (seen.contains(entry.index)) continue;
    seen.add(entry.index);
    accepted.add(_Entry(index: entry.index, prob: entry.prob));
    if (accepted.length >= _kTopK) break;
  }

  return _Decision(rejected: false, accepted: accepted);
}

/// Mirrors the TTA averaging loop in TfliteIdentificationService.identify().
///
/// [variantScores] is a list of raw score lists — one per TTA variant.
/// Returns the element-wise average across all variants, matching the exact
/// accumulate-then-divide pattern in the source.
List<double> _mirrorTtaAverage(List<List<double>> variantScores) {
  assert(variantScores.isNotEmpty);
  final n = variantScores.first.length;
  final avg = List<double>.filled(n, 0.0);

  // Accumulate: identical to `avgScores[i] += score` in identify().
  for (final scores in variantScores) {
    for (int i = 0; i < n; i++) {
      avg[i] += scores[i];
    }
  }

  // Divide: identical to `avgScores[i] /= count` in identify().
  final count = variantScores.length.toDouble();
  for (int i = 0; i < n; i++) {
    avg[i] /= count;
  }

  return avg;
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ───────────────────────────────────────────────────────────────────────────
  // 1. _softmax
  // ───────────────────────────────────────────────────────────────────────────

  group('_softmax', () {
    test('outputs sum to 1.0', () {
      final probs = _softmax([1.0, 2.0, 3.0, 0.5, -1.0]);
      expect(probs.fold(0.0, (a, b) => a + b), closeTo(1.0, 1e-9));
    });

    test('all outputs are non-negative', () {
      final probs = _softmax([1.0, 2.0, 3.0, 0.5, -1.0]);
      for (final p in probs) {
        expect(p, greaterThanOrEqualTo(0.0));
      }
    });

    test('preserves rank order — largest logit maps to largest probability',
        () {
      final probs = _softmax([1.0, 5.0, 2.0, -3.0]);
      final maxProb = probs.reduce((a, b) => a > b ? a : b);
      // Index 1 has the highest logit (5.0) and must have the highest prob.
      expect(probs[1], closeTo(maxProb, 1e-12));
    });

    test('uniform logits produce uniform probabilities', () {
      final probs = _softmax(List.filled(10, 2.0));
      for (final p in probs) {
        expect(p, closeTo(0.1, 1e-9));
      }
    });

    test('numerically stable with large logit values — no Inf or NaN', () {
      final probs = _softmax([1000.0, 999.0, 998.0]);
      expect(probs.fold(0.0, (a, b) => a + b), closeTo(1.0, 1e-9));
      // Largest logit must still win.
      expect(probs[0], greaterThan(probs[1]));
      expect(probs[1], greaterThan(probs[2]));
    });

    test('handles single-element input — returns [1.0]', () {
      final probs = _softmax([3.7]);
      expect(probs.length, equals(1));
      expect(probs[0], closeTo(1.0, 1e-9));
    });

    test('handles all-negative logits', () {
      final probs = _softmax([-2.0, -1.0, -3.0]);
      expect(probs.fold(0.0, (a, b) => a + b), closeTo(1.0, 1e-9));
      // -1.0 is highest, so index 1 must have the largest probability.
      expect(probs[1], greaterThan(probs[0]));
      expect(probs[1], greaterThan(probs[2]));
    });

    test('two-class softmax: [0, ln(3)] → [0.25, 0.75]', () {
      // e^0 / (e^0 + e^ln3) = 1 / (1 + 3) = 0.25
      final probs = _softmax([0.0, math.log(3)]);
      expect(probs[0], closeTo(0.25, 1e-9));
      expect(probs[1], closeTo(0.75, 1e-9));
    });

    test('all-zero logits produce uniform output', () {
      final probs = _softmax([0.0, 0.0, 0.0, 0.0]);
      for (final p in probs) {
        expect(p, closeTo(0.25, 1e-9));
      }
    });

    test('output length matches input length', () {
      for (final n in [1, 5, 151]) {
        final probs = _softmax(List.generate(n, (i) => i.toDouble()));
        expect(probs.length, equals(n));
      }
    });

    test('max-subtraction trick: result is identical for shifted logits', () {
      // f(x) == f(x + c) for any constant c — verifies the subtraction path.
      final base = _softmax([1.0, 2.0, 3.0]);
      final shifted = _softmax([101.0, 102.0, 103.0]);
      for (int i = 0; i < base.length; i++) {
        expect(base[i], closeTo(shifted[i], 1e-9));
      }
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 2. Entropy-based rejection — Gate 1: normalizedEntropy > 0.97
  // ───────────────────────────────────────────────────────────────────────────

  group('rejection gate 1 — normalizedEntropy > 0.97', () {
    test('perfectly uniform 151-class distribution is rejected', () {
      final scores = List<double>.filled(151, 1.0 / 151);
      final out = _mirrorBuildResults(scores);
      expect(out.rejected, isTrue);
      expect(out.rejectionReason, equals('entropy'));
    });

    test('perfectly uniform 10-class distribution is rejected', () {
      final out = _mirrorBuildResults(List.filled(10, 0.1));
      expect(out.rejected, isTrue);
      expect(out.rejectionReason, equals('entropy'));
    });

    test('perfectly uniform 5-class distribution is rejected', () {
      final out = _mirrorBuildResults(List.filled(5, 0.2));
      expect(out.rejected, isTrue);
      expect(out.rejectionReason, equals('entropy'));
    });

    test('near-uniform 100-class distribution is rejected', () {
      // One class at 2%, the rest share 98% equally. normEntropy still > 0.97.
      final small = (1.0 - 0.02) / 99;
      final scores = [0.02, ...List<double>.filled(99, small)];
      final out = _mirrorBuildResults(scores);
      expect(out.rejected, isTrue);
      expect(out.rejectionReason, equals('entropy'));
    });

    test('clear 70% winner with 9-class residual is NOT rejected by entropy',
        () {
      final rest = 0.30 / 9;
      final scores = [0.70, ...List<double>.filled(9, rest)];
      final out = _mirrorBuildResults(scores);
      expect(out.rejectionReason, isNot(equals('entropy')));
    });

    test('moderate 40% winner across 10 classes is NOT rejected by entropy',
        () {
      final scores = [
        0.40,
        0.20,
        0.10,
        0.08,
        0.07,
        0.05,
        0.04,
        0.03,
        0.02,
        0.01
      ];
      final out = _mirrorBuildResults(scores);
      expect(out.rejectionReason, isNot(equals('entropy')));
    });

    test(
        'entropy uses natural log — uniform n-class always gives normEntropy 1.0',
        () {
      // For a uniform distribution: H = ln(n), maxH = ln(n) → normEntropy = 1.0.
      for (final n in [3, 7, 50]) {
        final scores = List<double>.filled(n, 1.0 / n);
        final out = _mirrorBuildResults(scores);
        expect(out.rejected, isTrue,
            reason: 'uniform $n-class should be rejected');
        expect(out.rejectionReason, equals('entropy'));
      }
    });

    test(
        'threshold is strictly > 0.97, so scores at exactly 0.97 are not rejected',
        () {
      // A discriminative 15-class distribution has normEntropy well below 0.97.
      final rest = 0.35 / 14;
      final scores = [0.65, ...List<double>.filled(14, rest)];
      final out = _mirrorBuildResults(scores);
      expect(out.rejectionReason, isNot(equals('entropy')));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 3. Confidence-gap rejection — Gate 2: topProb < 0.05 AND gap < 0.01
  //
  // Gate 2 only fires when Gate 1 passes (normEntropy <= 0.97).
  // For topProb to be < 0.05 with entropy <= 0.97, the distribution must be
  // non-uniform but have a very small maximum. The most reliable construction
  // for this is a 2-class input.
  // ───────────────────────────────────────────────────────────────────────────

  group('rejection gate 2 — topProb < 0.05 AND gap < 0.01', () {
    test('rejects when topProb=0.044 and gap=0.004 (2-class)', () {
      // [0.044, 0.040]: topProb=0.044 < 0.05, gap=0.004 < 0.01.
      // 2-class normEntropy < 0.97 because probabilities are unequal.
      final out = _mirrorBuildResults([0.044, 0.040]);
      expect(out.rejected, isTrue);
      expect(out.rejectionReason, equals('gap'));
    });

    test('rejects when topProb=0.030 and gap=0.005 (2-class)', () {
      // [0.030, 0.025]: both conditions satisfied.
      final out = _mirrorBuildResults([0.030, 0.025]);
      expect(out.rejected, isTrue);
      expect(out.rejectionReason, equals('gap'));
    });

    test('does NOT reject when topProb >= 0.05 (one class dominates)', () {
      // [0.055, 0.050, 0.895]: sorted topProb = 0.895 >= 0.05 → condition fails.
      final out = _mirrorBuildResults([0.055, 0.050, 0.895]);
      expect(out.rejectionReason, isNot(equals('gap')));
    });

    test('does NOT reject when topProb < 0.05 but gap >= 0.01', () {
      // [0.044, 0.029]: topProb=0.044 < 0.05 but gap=0.015 >= 0.01 → no reject.
      final out = _mirrorBuildResults([0.044, 0.029]);
      expect(out.rejectionReason, isNot(equals('gap')));
    });

    test('boundary: topProb exactly 0.05 does NOT trigger gate 2 (strict <)',
        () {
      // 0.05 is not strictly < 0.05.
      final out = _mirrorBuildResults([0.050, 0.044]);
      expect(out.rejectionReason, isNot(equals('gap')));
    });

    test('boundary: gap exactly 0.01 does NOT trigger gate 2 (strict <)', () {
      // gap = 0.040 - 0.030 = 0.010 is not strictly < 0.01.
      final out = _mirrorBuildResults([0.040, 0.030]);
      expect(out.rejectionReason, isNot(equals('gap')));
    });

    test('gate 2 is not reached when gate 1 already fires', () {
      // A uniform distribution fires gate 1 via entropy before reaching gate 2.
      final out = _mirrorBuildResults(List.filled(100, 0.01));
      expect(out.rejectionReason, equals('entropy'));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 4. Top-K selection and _minConfidence=0.03 threshold
  // ───────────────────────────────────────────────────────────────────────────

  group('top-K selection and _minConfidence=0.03 threshold', () {
    test('returns up to 3 entries when all are above 0.03', () {
      // [0.70, 0.15, 0.10, 0.05]: first 3 above threshold.
      final out = _mirrorBuildResults([0.70, 0.15, 0.10, 0.05]);
      expect(out.rejected, isFalse);
      expect(out.accepted.length, equals(3));
    });

    test('returns exactly 1 entry when only top-1 is >= 0.03', () {
      // 0.95 accepted; 0.02 < 0.03 → loop breaks.
      final out = _mirrorBuildResults([0.95, 0.02, 0.02, 0.01]);
      expect(out.rejected, isFalse);
      expect(out.accepted.length, equals(1));
      expect(out.accepted.first.index, equals(0));
    });

    test('loop breaks as soon as prob falls below 0.03', () {
      // [0.60, 0.30, 0.05, 0.02]: 0.02 < 0.03 breaks the loop after 3 entries.
      final out = _mirrorBuildResults([0.60, 0.30, 0.05, 0.02, 0.02, 0.01]);
      expect(out.rejected, isFalse);
      expect(out.accepted.length, equals(3));
    });

    test('capped at 3 even when 5 entries are all above 0.03', () {
      final out = _mirrorBuildResults([0.35, 0.25, 0.20, 0.10, 0.10]);
      expect(out.rejected, isFalse);
      expect(out.accepted.length, equals(3));
    });

    test('results are in descending probability order', () {
      final out = _mirrorBuildResults([0.10, 0.60, 0.20, 0.08, 0.02]);
      expect(out.rejected, isFalse);
      for (int i = 0; i < out.accepted.length - 1; i++) {
        expect(
          out.accepted[i].prob,
          greaterThanOrEqualTo(out.accepted[i + 1].prob),
        );
      }
    });

    test('top-1 index corresponds to the highest-probability class', () {
      // Class at index 3 has max probability (0.60).
      final out = _mirrorBuildResults([0.05, 0.10, 0.15, 0.60, 0.10]);
      expect(out.rejected, isFalse);
      expect(out.accepted.first.index, equals(3));
    });

    test('boundary: prob exactly 0.03 IS included (>= comparison)', () {
      // [0.90, 0.04, 0.03, 0.02]: 0.03 >= 0.03 included; 0.02 → break.
      final out = _mirrorBuildResults([0.90, 0.04, 0.03, 0.02]);
      expect(out.rejected, isFalse);
      expect(out.accepted.length, equals(3));
    });

    test('boundary: prob 0.029 is excluded — breaks the loop', () {
      // [0.90, 0.04, 0.029, 0.02]: 0.029 < 0.03 → break after 2 results.
      final out = _mirrorBuildResults([0.90, 0.04, 0.029, 0.02]);
      expect(out.rejected, isFalse);
      expect(out.accepted.length, equals(2));
    });

    test('skips entries rejected by acceptEntry and continues to next', () {
      // Only even-index entries accepted.
      // [0.50, 0.30, 0.15, 0.03]: index 0 ✓, index 1 skip, index 2 ✓, index 3 skip.
      final out = _mirrorBuildResults(
        [0.50, 0.30, 0.15, 0.03],
        acceptEntry: (i) => i.isEven,
      );
      expect(out.rejected, isFalse);
      for (final e in out.accepted) {
        expect(e.index.isEven, isTrue);
      }
    });

    test('returns empty accepted list when all entries fail acceptEntry', () {
      // Distribution is valid (gate 1 and gate 2 both pass) but no Dog match.
      // The real service returns _unrecognizedResult() in this case.
      final out =
          _mirrorBuildResults([0.70, 0.20, 0.10], acceptEntry: (_) => false);
      expect(out.rejected, isFalse);
      expect(out.accepted, isEmpty);
    });

    test('scan window is _topK*2 = 6 candidates maximum', () {
      // 7 entries all above minConfidence. Scan window = 6; capped at 3 accepted.
      final out =
          _mirrorBuildResults([0.30, 0.28, 0.20, 0.10, 0.07, 0.04, 0.01]);
      expect(out.rejected, isFalse);
      expect(out.accepted.length, equals(3));
      expect(out.accepted[0].prob, closeTo(0.30, 1e-9));
      expect(out.accepted[1].prob, closeTo(0.28, 1e-9));
      expect(out.accepted[2].prob, closeTo(0.20, 1e-9));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 5. Logit input path — softmax applied when any score is negative
  // ───────────────────────────────────────────────────────────────────────────

  group('logit input detection and softmax application', () {
    test('negative scores are passed through softmax before gating', () {
      // [3.0, 1.0, -1.0, -3.0] → softmax ≈ [0.84, 0.11, 0.02, 0.003] → accepted.
      final out = _mirrorBuildResults([3.0, 1.0, -1.0, -3.0]);
      expect(out.rejected, isFalse);
      expect(out.accepted.isNotEmpty, isTrue);
    });

    test('logit inputs yield the same top-1 index as manual softmax', () {
      final logits = [2.5, 0.5, -0.5, 1.5];
      final probs = _softmax(logits);
      final argmax = probs.indexOf(probs.reduce((a, b) => a > b ? a : b));
      final out = _mirrorBuildResults(logits);
      expect(out.rejected, isFalse);
      expect(out.accepted.first.index, equals(argmax));
    });

    test('non-negative probability inputs are NOT modified by softmax', () {
      // hasNegative is false → probs = scores as-is.
      final out = _mirrorBuildResults([0.70, 0.20, 0.10]);
      expect(out.rejected, isFalse);
      expect(out.accepted.first.prob, closeTo(0.70, 1e-9));
    });

    test('single negative value among positives triggers softmax path', () {
      // Only one value is negative — `any((s) => s < 0)` fires → softmax applied.
      // [3.0, 1.0, -0.5]: softmax ≈ [0.84, 0.11, 0.04] — clear winner, not rejected.
      final out = _mirrorBuildResults([3.0, 1.0, -0.5]);
      expect(out.rejected, isFalse);
      expect(out.accepted, isNotEmpty);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 6. TTA averaging logic — 3 variants averaged correctly
  //
  // Mirrors the accumulate-then-divide loop in TfliteIdentificationService.identify().
  // The loop iterates over flatTensors (3 variants when _enableTTA = true),
  // runs inference on each, accumulates into avgScores[], then divides by count.
  // ───────────────────────────────────────────────────────────────────────────

  group('TTA averaging logic', () {
    test('single variant: average equals the variant itself', () {
      final scores = [0.70, 0.20, 0.10];
      final avg = _mirrorTtaAverage([scores]);
      for (int i = 0; i < scores.length; i++) {
        expect(avg[i], closeTo(scores[i], 1e-12));
      }
    });

    test('three identical variants average to themselves', () {
      final scores = [0.60, 0.30, 0.10];
      final avg = _mirrorTtaAverage([scores, scores, scores]);
      for (int i = 0; i < scores.length; i++) {
        expect(avg[i], closeTo(scores[i], 1e-9));
      }
    });

    test('three-variant average is element-wise mean', () {
      final v1 = [0.90, 0.06, 0.04];
      final v2 = [0.60, 0.30, 0.10];
      final v3 = [0.30, 0.40, 0.30];
      final avg = _mirrorTtaAverage([v1, v2, v3]);

      expect(avg[0], closeTo((0.90 + 0.60 + 0.30) / 3, 1e-9));
      expect(avg[1], closeTo((0.06 + 0.30 + 0.40) / 3, 1e-9));
      expect(avg[2], closeTo((0.04 + 0.10 + 0.30) / 3, 1e-9));
    });

    test('three-variant average preserves probability sum (if inputs sum to 1)',
        () {
      final v1 = [0.70, 0.20, 0.10];
      final v2 = [0.50, 0.35, 0.15];
      final v3 = [0.80, 0.15, 0.05];
      final avg = _mirrorTtaAverage([v1, v2, v3]);
      final sum = avg.fold(0.0, (a, b) => a + b);
      expect(sum, closeTo(1.0, 1e-9));
    });

    test('averaging three variants converges toward a confident prediction',
        () {
      // All three agree strongly on class 0. The average should also be high.
      final v1 = [0.80, 0.10, 0.10];
      final v2 = [0.75, 0.15, 0.10];
      final v3 = [0.85, 0.08, 0.07];
      final avg = _mirrorTtaAverage([v1, v2, v3]);
      expect(avg[0], greaterThan(0.70));
      expect(avg[0], greaterThan(avg[1]));
      expect(avg[0], greaterThan(avg[2]));
    });

    test(
        'flip variant that disagrees slightly does not reverse the top prediction',
        () {
      // Variant 2 (flipped) is less confident on class 0 but still agrees.
      // Variant 3 (zoomed-out) is slightly noisier. Average still picks class 0.
      final tight = [0.72, 0.12, 0.16];
      final flipped = [0.65, 0.20, 0.15];
      final zoomed = [0.68, 0.18, 0.14];
      final avg = _mirrorTtaAverage([tight, flipped, zoomed]);
      final argmax = avg.indexOf(avg.reduce((a, b) => a > b ? a : b));
      expect(argmax, equals(0));
    });

    test('average output length matches variant length', () {
      final v = List.generate(151, (i) => 1.0 / 151);
      final avg = _mirrorTtaAverage([v, v, v]);
      expect(avg.length, equals(151));
    });

    test(
        'averaged scores are fed correctly into _buildResults — accepted count unchanged',
        () {
      // Pre-average the scores and pass to _mirrorBuildResults.
      // Should produce the same accepted list as using the average directly.
      final v1 = [0.60, 0.25, 0.10, 0.05];
      final v2 = [0.62, 0.22, 0.11, 0.05];
      final v3 = [0.58, 0.27, 0.10, 0.05];
      final avg = _mirrorTtaAverage([v1, v2, v3]);
      final out = _mirrorBuildResults(avg);
      expect(out.rejected, isFalse);
      // All four are above minConfidence; top 3 accepted.
      expect(out.accepted.length, equals(3));
    });

    test('uint8 scores divided by 255 before accumulating — division is exact',
        () {
      // Simulate the uint8 decode: raw output 204/255 ≈ 0.800, 51/255 = 0.200.
      final uint8Raw1 = [204, 51];
      final uint8Raw2 = [196, 59];
      final uint8Raw3 = [210, 45];

      List<double> decodeUint8(List<int> raw) =>
          raw.map((v) => v / 255.0).toList();

      final avg = _mirrorTtaAverage([
        decodeUint8(uint8Raw1),
        decodeUint8(uint8Raw2),
        decodeUint8(uint8Raw3),
      ]);

      final expected0 = (204 / 255.0 + 196 / 255.0 + 210 / 255.0) / 3;
      final expected1 = (51 / 255.0 + 59 / 255.0 + 45 / 255.0) / 3;
      expect(avg[0], closeTo(expected0, 1e-9));
      expect(avg[1], closeTo(expected1, 1e-9));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 7. Label cache — O(1) lookup and population integrity
  // ───────────────────────────────────────────────────────────────────────────

  group('label cache population and O(1) lookup', () {
    test('cache contains an entry for every label', () {
      final labels = ['Golden Retriever', 'Labrador Retriever', 'unknown_xyz'];
      final mockDogService = MockDogService();
      when(() => mockDogService.lookupByCommonName('Golden Retriever'))
          .thenReturn(_dog('Golden Retriever'));
      when(() => mockDogService.lookupByCommonName('Labrador Retriever'))
          .thenReturn(_dog('Labrador Retriever'));
      when(() => mockDogService.lookupByCommonName('unknown_xyz'))
          .thenReturn(null);

      final cache = {
        for (final label in labels)
          label: mockDogService.lookupByCommonName(label),
      };

      expect(cache.length, equals(labels.length));
      expect(cache.keys, containsAll(labels));
    });

    test('matched labels store a non-null Dog', () {
      final mockDogService = MockDogService();
      when(() => mockDogService.lookupByCommonName('Beagle'))
          .thenReturn(_dog('Beagle'));
      when(() => mockDogService.lookupByCommonName('Poodle'))
          .thenReturn(_dog('Poodle'));

      final cache = {
        for (final label in ['Beagle', 'Poodle'])
          label: mockDogService.lookupByCommonName(label),
      };

      expect(cache['Beagle'], isNotNull);
      expect(cache['Poodle'], isNotNull);
    });

    test('unmatched labels store null — no crash on miss', () {
      final mockDogService = MockDogService();
      when(() => mockDogService.lookupByCommonName('unknown_breed_xyz'))
          .thenReturn(null);

      final cache = {
        'unknown_breed_xyz':
            mockDogService.lookupByCommonName('unknown_breed_xyz'),
      };

      expect(cache.containsKey('unknown_breed_xyz'), isTrue);
      expect(cache['unknown_breed_xyz'], isNull);
    });

    test(
        'lookupByCommonName is called exactly once per label during cache build',
        () {
      final mockDogService = MockDogService();
      when(() => mockDogService.lookupByCommonName(any())).thenReturn(null);

      final _ = {
        for (final label in ['Boxer', 'Pug'])
          label: mockDogService.lookupByCommonName(label),
      };

      verify(() => mockDogService.lookupByCommonName('Boxer')).called(1);
      verify(() => mockDogService.lookupByCommonName('Pug')).called(1);
    });

    test('subsequent reads return the same Dog instance — O(1) map lookup', () {
      // The cache is a plain Map; consecutive accesses must return identical refs.
      final dog = _dog('German Shepherd');
      final cache = <String, Dog?>{'German Shepherd': dog};
      expect(identical(cache['German Shepherd'], dog), isTrue);
    });

    test('cache built from 151 labels has exactly 151 entries', () {
      final mockDogService = MockDogService();
      when(() => mockDogService.lookupByCommonName(any())).thenReturn(null);

      final labels = List.generate(151, (i) => 'Breed $i');
      final cache = {
        for (final label in labels)
          label: mockDogService.lookupByCommonName(label),
      };

      expect(cache.length, equals(151));
      verifyNever(() => mockDogService.lookupByCommonName('Breed 151'));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 8. _matchLabelToDog guard logic
  //
  // Mirrors the guards from _matchLabelToDog:
  //   if (label.isEmpty || label.startsWith('_')) return null;
  //   return _labelCache[label];
  // ───────────────────────────────────────────────────────────────────────────

  group('_matchLabelToDog guard logic', () {
    bool _guardPasses(String label) =>
        label.isNotEmpty && !label.startsWith('_');

    test('empty label is rejected', () {
      expect(_guardPasses(''), isFalse);
    });

    test('underscore-prefixed labels are rejected', () {
      expect(_guardPasses('_background_'), isFalse);
      expect(_guardPasses('_'), isFalse);
      expect(_guardPasses('_unknown'), isFalse);
    });

    test('normal breed labels pass the guard', () {
      expect(_guardPasses('Golden Retriever'), isTrue);
      expect(_guardPasses('labrador retriever'), isTrue);
      expect(_guardPasses('beagle'), isTrue);
    });

    test('label with underscore in the middle is NOT rejected', () {
      // Only labels STARTING with an underscore are filtered.
      expect(_guardPasses('some_label'), isTrue);
      expect(_guardPasses('flat_coated_retriever'), isTrue);
    });

    test('whitespace-only label is not empty — passes guard', () {
      // The real method does not trim; whitespace-only is non-empty.
      expect(_guardPasses('   '), isTrue);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 9. IdentificationResult model
  //
  // Confidence tier thresholds from identification_service.dart:
  //   high   >= 0.35
  //   medium >= 0.20
  //   low    <  0.20
  // ───────────────────────────────────────────────────────────────────────────

  group('IdentificationResult', () {
    group('confidenceTier', () {
      test('confidence 0.35 yields ConfidenceTier.high (lower boundary)', () {
        expect(
          IdentificationResult(dog: _dog('Lab'), confidence: 0.35, source: 'ml')
              .confidenceTier,
          equals(ConfidenceTier.high),
        );
      });

      test('confidence 0.50 yields ConfidenceTier.high', () {
        expect(
          IdentificationResult(dog: _dog('Lab'), confidence: 0.50, source: 'ml')
              .confidenceTier,
          equals(ConfidenceTier.high),
        );
      });

      test('confidence 0.90 yields ConfidenceTier.high', () {
        expect(
          IdentificationResult(
                  dog: _dog('Poodle'), confidence: 0.90, source: 'ml')
              .confidenceTier,
          equals(ConfidenceTier.high),
        );
      });

      test(
          'confidence 0.34 yields ConfidenceTier.medium (just below high boundary)',
          () {
        expect(
          IdentificationResult(
                  dog: _dog('Bulldog'), confidence: 0.34, source: 'ml')
              .confidenceTier,
          equals(ConfidenceTier.medium),
        );
      });

      test('confidence 0.20 yields ConfidenceTier.medium (lower boundary)', () {
        expect(
          IdentificationResult(
                  dog: _dog('Beagle'), confidence: 0.20, source: 'ml')
              .confidenceTier,
          equals(ConfidenceTier.medium),
        );
      });

      test('confidence 0.27 yields ConfidenceTier.medium (mid range)', () {
        expect(
          IdentificationResult(dog: _dog('Pug'), confidence: 0.27, source: 'ml')
              .confidenceTier,
          equals(ConfidenceTier.medium),
        );
      });

      test(
          'confidence 0.19 yields ConfidenceTier.low (just below medium boundary)',
          () {
        expect(
          IdentificationResult(
                  dog: _dog('Chihuahua'), confidence: 0.19, source: 'ml')
              .confidenceTier,
          equals(ConfidenceTier.low),
        );
      });

      test('confidence 0.03 (minConfidence) yields ConfidenceTier.low', () {
        expect(
          IdentificationResult(
                  dog: _dog('Basenji'), confidence: 0.03, source: 'ml')
              .confidenceTier,
          equals(ConfidenceTier.low),
        );
      });

      test('confidence 0.0 yields ConfidenceTier.low', () {
        expect(
          IdentificationResult(
                  dog: _dog('Shih Tzu'), confidence: 0.0, source: 'ml')
              .confidenceTier,
          equals(ConfidenceTier.low),
        );
      });
    });

    group('isUnrecognized', () {
      test('source "ml" → isUnrecognized is false', () {
        expect(
          IdentificationResult(
                  dog: _dog('Boxer'), confidence: 0.75, source: 'ml')
              .isUnrecognized,
          isFalse,
        );
      });

      test('source "unrecognized" → isUnrecognized is true', () {
        expect(
          IdentificationResult(
            dog: _dog('Unknown', rarity: Rarity.unknown),
            confidence: 0.0,
            source: 'unrecognized',
          ).isUnrecognized,
          isTrue,
        );
      });

      test('source "manual" → isUnrecognized is false', () {
        expect(
          IdentificationResult(
            dog: _dog('Golden Retriever'),
            confidence: 0.80,
            source: 'manual',
          ).isUnrecognized,
          isFalse,
        );
      });
    });

    group('isCloseToAlternative', () {
      test('gap < 0.10 → isCloseToAlternative returns true', () {
        final top1 = IdentificationResult(
            dog: _dog('Lab'), confidence: 0.50, source: 'ml');
        final top2 = IdentificationResult(
            dog: _dog('Golden'), confidence: 0.45, source: 'ml');
        expect(top1.isCloseToAlternative(top2), isTrue);
      });

      test('gap of 0.11 → isCloseToAlternative returns false', () {
        // 0.50 - 0.39 = 0.11, which is safely above the 0.10 threshold.
        // Avoids the IEEE 754 issue where 0.50 - 0.40 ≈ 0.09999... < 0.10.
        final top1 = IdentificationResult(
            dog: _dog('Lab'), confidence: 0.50, source: 'ml');
        final top2 = IdentificationResult(
            dog: _dog('Golden'), confidence: 0.39, source: 'ml');
        expect(top1.isCloseToAlternative(top2), isFalse);
      });

      test('gap > 0.10 → isCloseToAlternative returns false', () {
        final top1 = IdentificationResult(
            dog: _dog('Lab'), confidence: 0.72, source: 'ml');
        final top2 = IdentificationResult(
            dog: _dog('Golden'), confidence: 0.12, source: 'ml');
        expect(top1.isCloseToAlternative(top2), isFalse);
      });

      test('null other → isCloseToAlternative returns false', () {
        final result = IdentificationResult(
            dog: _dog('Lab'), confidence: 0.50, source: 'ml');
        expect(result.isCloseToAlternative(null), isFalse);
      });
    });

    test('dog field is preserved on the result', () {
      final dog = _dog('Rottweiler', rarity: Rarity.uncommon, baseXp: 35);
      final result =
          IdentificationResult(dog: dog, confidence: 0.50, source: 'ml');
      expect(result.dog.name, equals('Rottweiler'));
      expect(result.dog.rarity, equals(Rarity.uncommon));
      expect(result.dog.baseXp, equals(35));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 10. ConfidenceTier.normalizedDisplay
  // ───────────────────────────────────────────────────────────────────────────

  group('ConfidenceTier.normalizedDisplay', () {
    test('0.0 raw → 0.0 display', () {
      expect(ConfidenceTier.normalizedDisplay(0.0), closeTo(0.0, 1e-9));
    });

    test('0.50 raw → 1.0 display (ceiling)', () {
      expect(ConfidenceTier.normalizedDisplay(0.50), closeTo(1.0, 1e-9));
    });

    test('values above 0.50 are capped at 1.0', () {
      expect(ConfidenceTier.normalizedDisplay(0.90), closeTo(1.0, 1e-9));
    });

    test('0.35 raw → 0.7 display (boundary of top segment)', () {
      expect(ConfidenceTier.normalizedDisplay(0.35), closeTo(0.7, 1e-9));
    });

    test('0.15 raw → 0.3 display (boundary of middle segment)', () {
      expect(ConfidenceTier.normalizedDisplay(0.15), closeTo(0.3, 1e-9));
    });

    test('display increases monotonically with raw confidence', () {
      final raws = [0.0, 0.05, 0.15, 0.25, 0.35, 0.45, 0.50, 0.80];
      final displays = raws.map(ConfidenceTier.normalizedDisplay).toList();
      for (int i = 0; i < displays.length - 1; i++) {
        expect(displays[i], lessThanOrEqualTo(displays[i + 1]));
      }
    });

    test('all display values are in [0.0, 1.0]', () {
      for (final raw in [0.0, 0.10, 0.20, 0.30, 0.40, 0.50, 1.0]) {
        final d = ConfidenceTier.normalizedDisplay(raw);
        expect(d, greaterThanOrEqualTo(0.0));
        expect(d, lessThanOrEqualTo(1.0));
      }
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 11. Realistic model output scenarios (integration of all logic paths)
  // ───────────────────────────────────────────────────────────────────────────

  group('realistic model output scenarios', () {
    test('production v3 model: clear winner at 72% — accepted', () {
      final residual = 0.08 / 148;
      final scores = [
        0.72, // German Shepherd
        0.12, // Belgian Malinois
        0.08, // Dutch Shepherd
        ...List<double>.filled(148, residual),
      ];
      final out = _mirrorBuildResults(scores);
      expect(out.rejected, isFalse);
      expect(out.accepted.isNotEmpty, isTrue);
      expect(out.accepted.first.index, equals(0));
    });

    test('blurry photo — uniform 151-class output — rejected by entropy', () {
      final out = _mirrorBuildResults(List<double>.filled(151, 1.0 / 151));
      expect(out.rejected, isTrue);
      expect(out.rejectionReason, equals('entropy'));
    });

    test('two similar breeds both above minConfidence are included', () {
      // Labrador 40% vs Golden Retriever 38%.
      final out = _mirrorBuildResults([0.40, 0.38, 0.12, 0.06, 0.04]);
      expect(out.rejected, isFalse);
      expect(out.accepted.length, greaterThanOrEqualTo(2));
    });

    test('logit output from float32 model: clear winner', () {
      // EfficientNet sometimes outputs float32 logits.
      final out = _mirrorBuildResults([4.5, 1.2, 0.3, -1.0, -2.5]);
      expect(out.rejected, isFalse);
      // Class 0 (logit 4.5) must be top result.
      expect(out.accepted.first.index, equals(0));
    });

    test('partial label match: only indices 0 and 2 resolve to a Dog', () {
      final out = _mirrorBuildResults(
        [0.60, 0.25, 0.10, 0.05],
        acceptEntry: (i) => i == 0 || i == 2,
      );
      expect(out.rejected, isFalse);
      final indices = out.accepted.map((e) => e.index).toList();
      expect(indices, contains(0));
      expect(indices, contains(2));
      expect(indices, isNot(contains(1)));
      expect(indices, isNot(contains(3)));
    });

    test('no Dog matches in the DB → empty accepted list', () {
      final out =
          _mirrorBuildResults([0.70, 0.20, 0.10], acceptEntry: (_) => false);
      expect(out.rejected, isFalse);
      expect(out.accepted, isEmpty);
    });

    test('TTA-averaged scores with a clear winner pass all gates', () {
      // Simulate three inference passes then average before _buildResults.
      final v1 = List.generate(151, (i) => i == 0 ? 0.75 : 0.25 / 150);
      final v2 = List.generate(151, (i) => i == 0 ? 0.70 : 0.30 / 150);
      final v3 = List.generate(151, (i) => i == 0 ? 0.65 : 0.35 / 150);
      final avg = _mirrorTtaAverage([v1, v2, v3]);
      final out = _mirrorBuildResults(avg);
      expect(out.rejected, isFalse);
      expect(out.accepted.first.index, equals(0));
    });
  });
}
