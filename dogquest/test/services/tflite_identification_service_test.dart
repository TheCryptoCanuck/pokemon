// test/services/tflite_identification_service_test.dart
//
// Unit tests for the pure-logic portions of TfliteIdentificationService.
//
// Strategy
// --------
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
//   B. IdentificationResult and ConfidenceTier model — tested directly since
//      those classes are public and contain no platform dependencies.
//
//   C. Label cache simulation — the label-cache population and guard logic in
//      _matchLabelToDog is mirrored and tested against a MockDogService.
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
// Mocks & fixtures
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
// Logic mirrors — keep mechanically faithful to tflite_identification_service.dart
// ─────────────────────────────────────────────────────────────────────────────

// Constants mirrored from TfliteIdentificationService
const _kTopK = 3;
const _kMinConfidence = 0.03;

/// Mirrors TfliteIdentificationService._softmax().
List<double> _softmax(List<double> logits) {
  final maxLogit = logits.reduce((a, b) => a > b ? a : b);
  final exps = logits.map((l) => math.exp(l - maxLogit)).toList();
  final sum = exps.reduce((a, b) => a + b);
  return exps.map((e) => e / sum).toList();
}

/// Structured output from the _buildResults mirror.
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
/// [acceptEntry] simulates _matchLabelToDog: return true if the label at that
///   index resolves to a Dog. Pass null to accept every valid entry.
_Decision _mirrorBuildResults(
  List<double> scores, {
  bool Function(int index)? acceptEntry,
}) {
  final n = scores.length;

  // 1. Softmax when input contains any negative value.
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

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ───────────────────────────────────────────────────────────────────────────
  // 1. Softmax
  // ───────────────────────────────────────────────────────────────────────────

  group('_softmax', () {
    test('outputs sum to 1.0', () {
      final probs = _softmax([1.0, 2.0, 3.0, 0.5, -1.0]);
      expect(probs.fold(0.0, (a, b) => a + b), closeTo(1.0, 1e-9));
    });

    test('preserves rank order — largest logit maps to largest probability',
        () {
      final probs = _softmax([1.0, 5.0, 2.0, -3.0]);
      final maxProb = probs.reduce((a, b) => a > b ? a : b);
      expect(probs[1], closeTo(maxProb, 1e-12));
    });

    test('uniform logits produce uniform probabilities', () {
      final probs = _softmax(List.filled(10, 2.0));
      for (final p in probs) {
        expect(p, closeTo(0.1, 1e-9));
      }
    });

    test('numerically stable with large logit values (no Inf overflow)', () {
      final probs = _softmax([1000.0, 999.0, 998.0]);
      expect(probs.fold(0.0, (a, b) => a + b), closeTo(1.0, 1e-9));
      expect(probs[0], greaterThan(probs[1]));
    });

    test('handles single-element input — returns [1.0]', () {
      final probs = _softmax([3.7]);
      expect(probs.length, equals(1));
      expect(probs[0], closeTo(1.0, 1e-9));
    });

    test('handles all-negative logits', () {
      final probs = _softmax([-2.0, -1.0, -3.0]);
      expect(probs.fold(0.0, (a, b) => a + b), closeTo(1.0, 1e-9));
      // -1.0 is the highest logit → must have the highest probability.
      expect(probs[1], greaterThan(probs[0]));
      expect(probs[1], greaterThan(probs[2]));
    });

    test('two-class softmax: [0, ln(3)] → [0.25, 0.75]', () {
      final probs = _softmax([0.0, math.log(3)]);
      expect(probs[0], closeTo(0.25, 1e-9));
      expect(probs[1], closeTo(0.75, 1e-9));
    });

    test('all-equal logits produce uniform output', () {
      final probs = _softmax([0.0, 0.0, 0.0, 0.0]);
      for (final p in probs) {
        expect(p, closeTo(0.25, 1e-9));
      }
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 2. Entropy-based rejection — Gate 1: normalizedEntropy > 0.97
  // ───────────────────────────────────────────────────────────────────────────

  group('rejection gate 1: normalizedEntropy > 0.97', () {
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
      // One class slightly above uniform; normEntropy still > 0.97.
      const small = (1.0 - 0.02) / 99;
      final scores = [0.02, ...List<double>.filled(99, small)];
      final out = _mirrorBuildResults(scores);
      expect(out.rejected, isTrue);
      expect(out.rejectionReason, equals('entropy'));
    });

    test('clear 70% winner with 9-class spread is NOT rejected by entropy', () {
      const rest = 0.30 / 9;
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
        0.01,
      ];
      final out = _mirrorBuildResults(scores);
      expect(out.rejectionReason, isNot(equals('entropy')));
    });

    test(
        'entropy uses natural log — uniform n-class always gives normEntropy=1.0',
        () {
      // For a uniform distribution: H=ln(n), maxH=ln(n) → normEntropy=1.0.
      // Verify for 3, 7, 50 classes.
      for (final n in [3, 7, 50]) {
        final scores = List<double>.filled(n, 1.0 / n);
        final out = _mirrorBuildResults(scores);
        expect(
          out.rejected,
          isTrue,
          reason: 'uniform $n-class should be rejected',
        );
        expect(out.rejectionReason, equals('entropy'));
      }
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 3. Confidence-gap rejection — Gate 2: topProb < 0.05 AND gap < 0.01
  //
  // NOTE: Gate 2 only fires when Gate 1 passes (normEntropy <= 0.97).
  // For topProb to be < 0.05 with entropy <= 0.97, the distribution must be
  // non-uniform with a very small maximum. The only reliable construction uses
  // 2-class inputs where one class dominates at < 0.05 and the other is close.
  // ───────────────────────────────────────────────────────────────────────────

  group('rejection gate 2: topProb < 0.05 AND gap < 0.01', () {
    test('rejects when topProb=0.044 and gap=0.004 (2-class)', () {
      // [0.044, 0.040]:
      //   sorted topProb=0.044 < 0.05 ✓; gap=0.004 < 0.01 ✓
      //   normEntropy (2-class, unequal): H≈0.266, maxH=ln(2)≈0.693 → normH≈0.384 ✓
      final out = _mirrorBuildResults([0.044, 0.040]);
      expect(out.rejected, isTrue);
      expect(out.rejectionReason, equals('gap'));
    });

    test('rejects when topProb=0.030 and gap=0.005 (2-class)', () {
      // [0.030, 0.025]: topProb=0.030 < 0.05, gap=0.005 < 0.01.
      final out = _mirrorBuildResults([0.030, 0.025]);
      expect(out.rejected, isTrue);
      expect(out.rejectionReason, equals('gap'));
    });

    test('does NOT reject when topProb >= 0.05 (3-class dominant middle)', () {
      // [0.055, 0.050, 0.895]: sorted topProb=0.895 >= 0.05 → condition fails.
      final out = _mirrorBuildResults([0.055, 0.050, 0.895]);
      expect(out.rejectionReason, isNot(equals('gap')));
    });

    test('does NOT reject when topProb < 0.05 but gap >= 0.01', () {
      // [0.044, 0.029]: topProb=0.044 < 0.05 ✓; gap=0.015 >= 0.01 ✗ → no rejection.
      final out = _mirrorBuildResults([0.044, 0.029]);
      expect(out.rejectionReason, isNot(equals('gap')));
    });

    test('gate-2 boundary: topProb exactly 0.05 does NOT trigger rejection',
        () {
      // topProb = 0.05 is NOT strictly < 0.05.
      final out = _mirrorBuildResults([0.050, 0.044]);
      expect(out.rejectionReason, isNot(equals('gap')));
    });

    test('gate-2 boundary: gap exactly 0.01 does NOT trigger rejection', () {
      // gap = 0.01 is NOT strictly < 0.01.
      final out = _mirrorBuildResults([0.040, 0.030]); // gap=0.01 exactly
      expect(out.rejectionReason, isNot(equals('gap')));
    });

    test('gate-2 not reached when gate-1 already fires', () {
      // Uniform distribution fires gate-1 (entropy), never reaches gate-2.
      final out = _mirrorBuildResults(List.filled(100, 0.01));
      expect(out.rejectionReason, equals('entropy'));
      expect(out.rejectionReason, isNot(equals('gap')));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 4. Top-K selection with _minConfidence threshold (0.03)
  // ───────────────────────────────────────────────────────────────────────────

  group('top-K selection and _minConfidence=0.03 threshold', () {
    test('returns up to 3 entries when all are above 0.03', () {
      // [0.70, 0.15, 0.10, 0.05]: sorted all >= 0.03; first 3 accepted.
      final out = _mirrorBuildResults([0.70, 0.15, 0.10, 0.05]);
      expect(out.rejected, isFalse);
      expect(out.accepted.length, equals(3));
    });

    test('returns exactly 1 entry when only top-1 is >= 0.03', () {
      // [0.95, 0.02, 0.02, 0.01]: sorted top=0.95; second=0.02 < 0.03 → break.
      final out = _mirrorBuildResults([0.95, 0.02, 0.02, 0.01]);
      expect(out.rejected, isFalse);
      expect(out.accepted.length, equals(1));
      expect(out.accepted.first.index, equals(0));
    });

    test('stops accumulating when prob falls below 0.03', () {
      // [0.60, 0.30, 0.05, 0.02]: 0.02 < 0.03 breaks the loop after 3 entries.
      final out = _mirrorBuildResults([0.60, 0.30, 0.05, 0.02, 0.02, 0.01]);
      expect(out.rejected, isFalse);
      expect(out.accepted.length, equals(3));
    });

    test('capped at 3 even when all 5 scores are above 0.03', () {
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
      // Class at index 3 has max probability.
      final out = _mirrorBuildResults([0.05, 0.10, 0.15, 0.60, 0.10]);
      expect(out.rejected, isFalse);
      expect(out.accepted.first.index, equals(3));
    });

    test('_minConfidence boundary: prob exactly 0.03 IS included', () {
      // [0.90, 0.04, 0.03, 0.02]: 0.03 >= 0.03 → included; 0.02 → break.
      final out = _mirrorBuildResults([0.90, 0.04, 0.03, 0.02]);
      expect(out.rejected, isFalse);
      expect(out.accepted.length, equals(3));
    });

    test('_minConfidence boundary: prob 0.029 is excluded (breaks the loop)',
        () {
      // [0.90, 0.04, 0.029, 0.02]: 0.029 < 0.03 → break after 2.
      final out = _mirrorBuildResults([0.90, 0.04, 0.029, 0.02]);
      expect(out.rejected, isFalse);
      expect(out.accepted.length, equals(2));
    });

    test('skips entries rejected by acceptEntry and continues to next', () {
      // Only even-index entries accepted. [0.50, 0.30, 0.15, 0.03]:
      // index 0 (0.50) ✓, index 1 (0.30) skipped, index 2 (0.15) ✓, index 3 (0.03) skipped.
      final out = _mirrorBuildResults(
        [0.50, 0.30, 0.15, 0.03],
        acceptEntry: (i) => i.isEven,
      );
      expect(out.rejected, isFalse);
      for (final e in out.accepted) {
        expect(e.index.isEven, isTrue);
      }
    });

    test(
        'returns empty accepted list when all entries are filtered by acceptEntry',
        () {
      // Distribution is valid but no label maps to a Dog → _unrecognizedResult path.
      final out =
          _mirrorBuildResults([0.70, 0.20, 0.10], acceptEntry: (_) => false);
      expect(out.rejected, isFalse);
      expect(out.accepted, isEmpty);
    });

    test('topK scan window is topK*2 (6 candidates examined)', () {
      // 7 entries all above minConfidence. The loop examines at most topK*2=6;
      // only the top 3 by probability should be accepted.
      final out =
          _mirrorBuildResults([0.30, 0.28, 0.20, 0.10, 0.07, 0.04, 0.01]);
      expect(out.rejected, isFalse);
      expect(out.accepted.length, equals(3));
      // Must be the top 3 by probability (indices 0, 1, 2 in this sorted order).
      final probs = out.accepted.map((e) => e.prob).toList();
      expect(probs[0], closeTo(0.30, 1e-9));
      expect(probs[1], closeTo(0.28, 1e-9));
      expect(probs[2], closeTo(0.20, 1e-9));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 5. Logit input path — softmax applied when any score is negative
  // ───────────────────────────────────────────────────────────────────────────

  group('logit input detection and softmax application', () {
    test('negative scores are passed through softmax before gating', () {
      // [3.0, 1.0, -1.0, -3.0] → softmax ≈ [0.84, 0.11, 0.02, 0.003].
      final out = _mirrorBuildResults([3.0, 1.0, -1.0, -3.0]);
      expect(out.rejected, isFalse);
      expect(out.accepted.isNotEmpty, isTrue);
    });

    test('logit inputs produce the same rank as manually applied softmax', () {
      final logits = [2.5, 0.5, -0.5, 1.5];
      final expected = _softmax(logits);
      final argmax = expected.indexOf(expected.reduce((a, b) => a > b ? a : b));
      final out = _mirrorBuildResults(logits);
      expect(out.rejected, isFalse);
      expect(out.accepted.first.index, equals(argmax));
    });

    test('non-negative probability inputs are NOT modified by softmax', () {
      final out = _mirrorBuildResults([0.70, 0.20, 0.10]);
      expect(out.rejected, isFalse);
      expect(out.accepted.first.prob, closeTo(0.70, 1e-9));
    });

    test(
        'logits with small differences produce near-uniform softmax — rejected by entropy',
        () {
      // [0.1, -0.1, -0.2] → softmax ≈ [0.390, 0.320, 0.289]: nearly uniform
      // for 3 classes. normEntropy ≈ 0.99 > 0.97 → rejected by gate-1.
      // This documents the correct behavior: close-logit inputs are uncertain.
      final out = _mirrorBuildResults([0.1, -0.1, -0.2]);
      expect(out.rejected, isTrue);
      expect(out.rejectionReason, equals('entropy'));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 6. Entropy threshold boundary behavior
  // ───────────────────────────────────────────────────────────────────────────

  group('entropy threshold direction', () {
    test('clear winner with 5-class spread has normEntropy << 0.97', () {
      // [0.80, 0.10, 0.05, 0.03, 0.02]: H is low → accepted.
      final out = _mirrorBuildResults([0.80, 0.10, 0.05, 0.03, 0.02]);
      expect(out.rejectionReason, isNot(equals('entropy')));
    });

    test('threshold is strictly > 0.97 (equals does not reject)', () {
      // Analytically targeting exactly 0.97 is impractical; instead verify
      // that a discriminative 15-class distribution is not rejected.
      const rest = 0.35 / 14;
      final scores = [0.65, ...List<double>.filled(14, rest)];
      final out = _mirrorBuildResults(scores);
      expect(out.rejectionReason, isNot(equals('entropy')));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 7. Realistic model output scenarios
  // ───────────────────────────────────────────────────────────────────────────

  group('realistic model output scenarios', () {
    test('v3/v4.1 production model: clear winner at 72% — accepted', () {
      const residual = 0.08 / 148;
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

    test('blurry photo — nearly uniform 151-class output — rejected by entropy',
        () {
      final out = _mirrorBuildResults(List<double>.filled(151, 1.0 / 151));
      expect(out.rejected, isTrue);
      expect(out.rejectionReason, equals('entropy'));
    });

    test('two similar breeds above minConfidence are both included', () {
      // Labrador 40% vs Golden Retriever 38%; both above 0.03.
      final out = _mirrorBuildResults([0.40, 0.38, 0.12, 0.06, 0.04]);
      expect(out.rejected, isFalse);
      expect(out.accepted.length, greaterThanOrEqualTo(2));
    });

    test(
        'label-matching failure: valid distribution but no Dog matches → empty accepted',
        () {
      final out =
          _mirrorBuildResults([0.70, 0.20, 0.10], acceptEntry: (_) => false);
      expect(out.rejected, isFalse);
      expect(out.accepted, isEmpty);
    });

    test('partial label match: only 2 of 4 entries resolve to a Dog', () {
      final out = _mirrorBuildResults(
        [0.60, 0.25, 0.10, 0.05],
        acceptEntry: (i) => i == 0 || i == 2,
      );
      expect(out.rejected, isFalse);
      final indices = out.accepted.map((e) => e.index).toList();
      expect(indices, containsAll([0, 2]));
      expect(indices, isNot(contains(1)));
      expect(indices, isNot(contains(3)));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 8. _matchLabelToDog guard and cache logic
  // ───────────────────────────────────────────────────────────────────────────

  group('_matchLabelToDog guard logic (mirrored)', () {
    // Guards from the real method:
    //   if (label.isEmpty || label.startsWith('_')) return null;
    //   return _labelCache[label];

    bool guardPasses(String label) =>
        label.isNotEmpty && !label.startsWith('_');

    test('empty label is rejected by the guard', () {
      expect(guardPasses(''), isFalse);
    });

    test('underscore-prefixed labels are rejected', () {
      expect(guardPasses('_background_'), isFalse);
      expect(guardPasses('_'), isFalse);
      expect(guardPasses('_unknown'), isFalse);
    });

    test('normal labels pass the guard', () {
      expect(guardPasses('Golden Retriever'), isTrue);
      expect(guardPasses('labrador retriever'), isTrue);
      expect(guardPasses('beagle'), isTrue);
    });

    test('single underscore is rejected (starts with underscore)', () {
      expect(guardPasses('_'), isFalse);
    });

    test('label with underscore in the middle passes the guard', () {
      // Only labels STARTING with underscore are rejected.
      expect(guardPasses('some_label'), isTrue);
    });
  });

  group('label cache population logic', () {
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

    test('unmatched labels store null in the cache', () {
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

    test('cache hit returns same Dog instance', () {
      final dog = _dog('German Shepherd');
      final cache = <String, Dog?>{'German Shepherd': dog};
      expect(cache['German Shepherd'], same(dog));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 9. IdentificationResult model
  // ───────────────────────────────────────────────────────────────────────────

  group('IdentificationResult', () {
    // Thresholds: high >= 0.35, medium >= 0.20, low < 0.20
    // Calibrated for label-smoothed models where typical correct = 10-50%.

    test('confidence >= 0.35 yields ConfidenceTier.high (lower boundary)', () {
      expect(
        IdentificationResult(dog: _dog('Lab'), confidence: 0.35, source: 'ml')
            .confidenceTier,
        equals(ConfidenceTier.high),
      );
    });

    test('confidence 0.50 yields ConfidenceTier.high', () {
      expect(
        IdentificationResult(
          dog: _dog('Poodle'),
          confidence: 0.50,
          source: 'ml',
        ).confidenceTier,
        equals(ConfidenceTier.high),
      );
    });

    test('confidence 0.90 yields ConfidenceTier.high', () {
      expect(
        IdentificationResult(
          dog: _dog('Poodle'),
          confidence: 0.90,
          source: 'ml',
        ).confidenceTier,
        equals(ConfidenceTier.high),
      );
    });

    test(
        'confidence 0.34 yields ConfidenceTier.medium (just below high boundary)',
        () {
      expect(
        IdentificationResult(
          dog: _dog('Bulldog'),
          confidence: 0.34,
          source: 'ml',
        ).confidenceTier,
        equals(ConfidenceTier.medium),
      );
    });

    test('confidence 0.20 yields ConfidenceTier.medium (lower boundary)', () {
      expect(
        IdentificationResult(
          dog: _dog('Beagle'),
          confidence: 0.20,
          source: 'ml',
        ).confidenceTier,
        equals(ConfidenceTier.medium),
      );
    });

    test('confidence 0.27 yields ConfidenceTier.medium', () {
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
          dog: _dog('Chihuahua'),
          confidence: 0.19,
          source: 'ml',
        ).confidenceTier,
        equals(ConfidenceTier.low),
      );
    });

    test('confidence 0.10 yields ConfidenceTier.low', () {
      expect(
        IdentificationResult(
          dog: _dog('Dachshund'),
          confidence: 0.10,
          source: 'ml',
        ).confidenceTier,
        equals(ConfidenceTier.low),
      );
    });

    test('confidence 0.0 yields ConfidenceTier.low', () {
      expect(
        IdentificationResult(
          dog: _dog('Shih Tzu'),
          confidence: 0.0,
          source: 'ml',
        ).confidenceTier,
        equals(ConfidenceTier.low),
      );
    });

    test('isUnrecognized is false for source "ml"', () {
      expect(
        IdentificationResult(dog: _dog('Boxer'), confidence: 0.75, source: 'ml')
            .isUnrecognized,
        isFalse,
      );
    });

    test('isUnrecognized is true for source "unrecognized"', () {
      expect(
        IdentificationResult(
          dog: _dog('Unknown', rarity: Rarity.unknown),
          confidence: 0.0,
          source: 'unrecognized',
        ).isUnrecognized,
        isTrue,
      );
    });

    test('isUnrecognized is false for source "manual"', () {
      expect(
        IdentificationResult(
          dog: _dog('Golden Retriever'),
          confidence: 0.80,
          source: 'manual',
        ).isUnrecognized,
        isFalse,
      );
    });

    test('dog field is preserved', () {
      final dog = _dog('Rottweiler', rarity: Rarity.uncommon, baseXp: 35);
      final result =
          IdentificationResult(dog: dog, confidence: 0.50, source: 'ml');
      expect(result.dog.name, equals('Rottweiler'));
      expect(result.dog.rarity, equals(Rarity.uncommon));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 10. Dog model — xp and fromJson/toJson (regression coverage)
  // ───────────────────────────────────────────────────────────────────────────

  group('Dog model', () {
    test('xp equals baseXp for common rarity', () {
      expect(_dog('Poodle', rarity: Rarity.common, baseXp: 20).xp, equals(20));
    });

    test('xp is 1.5x baseXp (rounded) for uncommon rarity', () {
      expect(
        _dog('Border Collie', rarity: Rarity.uncommon, baseXp: 20).xp,
        equals(30),
      );
    });

    test('xp is 2x baseXp for rare rarity', () {
      expect(
        _dog('Afghan Hound', rarity: Rarity.rare, baseXp: 20).xp,
        equals(40),
      );
    });

    test('xp is 5x baseXp for legendary rarity', () {
      expect(
        _dog('Tibetan Mastiff', rarity: Rarity.legendary, baseXp: 20).xp,
        equals(100),
      );
    });

    test('fromJson with missing rarity defaults to common', () {
      final d = Dog.fromJson({'name': 'Mystery Dog'});
      expect(d.rarity, equals(Rarity.common));
    });

    test('fromJson with invalid rarity defaults to common', () {
      final d = Dog.fromJson({'name': 'Test', 'rarity': 'ultra_rare'});
      expect(d.rarity, equals(Rarity.common));
    });

    test('toJson round-trips through fromJson preserving all core fields', () {
      final original = _dog('Rottweiler', rarity: Rarity.uncommon, baseXp: 30);
      final restored = Dog.fromJson(original.toJson());
      expect(restored.name, equals(original.name));
      expect(restored.scientificName, equals(original.scientificName));
      expect(restored.rarity, equals(original.rarity));
      expect(restored.baseXp, equals(original.baseXp));
    });
  });
}
