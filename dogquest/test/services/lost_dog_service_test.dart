import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dogquest/models/lost_dog_report.dart';
import 'package:dogquest/services/dog_embedding_service.dart';

void main() {
  group('LostDogReport', () {
    test('toJson/fromJson round-trip preserves all fields', () {
      final report = LostDogReport(
        id: 'test-001',
        dogName: 'Buddy',
        breed: 'Golden Retriever',
        photoPath: '/photos/buddy.jpg',
        embedding: [0.1, 0.5, 0.3, 0.05, 0.05],
        lastSeenLat: 40.7736,
        lastSeenLon: -73.9712,
        lastSeenLocation: 'Central Park',
        lostDate: DateTime(2026, 3, 10),
        createdAt: DateTime(2026, 3, 10),
        status: LostDogStatus.active,
        ownerContact: 'Sarah — 555-0147',
        notes: 'Red collar',
      );

      final json = report.toJson();
      final restored = LostDogReport.fromJson(json);

      expect(restored.id, 'test-001');
      expect(restored.dogName, 'Buddy');
      expect(restored.breed, 'Golden Retriever');
      expect(restored.photoPath, '/photos/buddy.jpg');
      expect(restored.embedding, [0.1, 0.5, 0.3, 0.05, 0.05]);
      expect(restored.lastSeenLat, 40.7736);
      expect(restored.lastSeenLon, -73.9712);
      expect(restored.lastSeenLocation, 'Central Park');
      expect(restored.status, LostDogStatus.active);
      expect(restored.ownerContact, 'Sarah — 555-0147');
      expect(restored.notes, 'Red collar');
    });

    test('fromJson handles missing optional fields', () {
      final report = LostDogReport.fromJson({
        'id': 'test-002',
        'dogName': 'Luna',
      });

      expect(report.id, 'test-002');
      expect(report.dogName, 'Luna');
      expect(report.breed, isNull);
      expect(report.photoPath, isNull);
      expect(report.embedding, isEmpty);
      expect(report.lastSeenLat, isNull);
      expect(report.ownerContact, isNull);
      expect(report.notes, isNull);
      expect(report.status, LostDogStatus.active);
    });

    test('fromJson handles unknown status gracefully', () {
      final report = LostDogReport.fromJson({
        'id': 'test-003',
        'dogName': 'Max',
        'status': 'unknown_status',
      });
      expect(report.status, LostDogStatus.active);
    });

    test('copyWith preserves unchanged fields', () {
      final original = LostDogReport(
        id: 'test-004',
        dogName: 'Coco',
        breed: 'Labrador',
        lostDate: DateTime(2026, 3, 1),
        createdAt: DateTime(2026, 3, 1),
        ownerContact: 'Mike',
      );

      final updated = original.copyWith(status: LostDogStatus.found);
      expect(updated.id, 'test-004');
      expect(updated.dogName, 'Coco');
      expect(updated.breed, 'Labrador');
      expect(updated.status, LostDogStatus.found);
      expect(updated.ownerContact, 'Mike');
    });
  });

  group('LostDogMatch', () {
    test('confidence is high when similarity >= 0.85', () {
      const match = LostDogMatch(
        reportId: 'r1',
        dogName: 'Buddy',
        similarity: 0.92,
      );
      expect(match.confidence, MatchConfidence.high);
      expect(match.similarityPercent, 92);
    });

    test('confidence is medium when similarity >= 0.70', () {
      const match = LostDogMatch(
        reportId: 'r2',
        dogName: 'Luna',
        similarity: 0.75,
      );
      expect(match.confidence, MatchConfidence.medium);
    });

    test('confidence is low when similarity < 0.70', () {
      const match = LostDogMatch(
        reportId: 'r3',
        dogName: 'Max',
        similarity: 0.55,
      );
      expect(match.confidence, MatchConfidence.low);
    });
  });

  group('LostDogStatus', () {
    test('labels are human-readable', () {
      expect(LostDogStatus.active.label, 'Missing');
      expect(LostDogStatus.found.label, 'Reunited');
      expect(LostDogStatus.cancelled.label, 'Cancelled');
    });
  });

  group('MatchConfidence', () {
    test('labels are descriptive', () {
      expect(MatchConfidence.high.label, 'Likely Match');
      expect(MatchConfidence.medium.label, 'Possible Match');
      expect(MatchConfidence.low.label, 'Weak Match');
    });
  });

  group('DogEmbeddingService (static methods)', () {
    test('cosineSimilarity of identical vectors is 1.0', () {
      final vec = [0.5, 0.3, 0.1, 0.05, 0.05];
      final sim = DogEmbeddingService.cosineSimilarity(vec, vec);
      expect(sim, closeTo(1.0, 0.001));
    });

    test('cosineSimilarity of orthogonal vectors is 0.0', () {
      final a = [1.0, 0.0, 0.0];
      final b = [0.0, 1.0, 0.0];
      final sim = DogEmbeddingService.cosineSimilarity(a, b);
      expect(sim, closeTo(0.0, 0.001));
    });

    test('cosineSimilarity of similar vectors is high', () {
      final a = [0.7, 0.2, 0.05, 0.03, 0.02];
      final b = [0.65, 0.22, 0.06, 0.04, 0.03];
      final sim = DogEmbeddingService.cosineSimilarity(a, b);
      expect(sim, greaterThan(0.99));
    });

    test('cosineSimilarity of different breed distributions is lower', () {
      // Simulate two different breed distributions
      final goldenRetriever = List<double>.filled(150, 0.005);
      goldenRetriever[1] = 0.7;
      goldenRetriever[2] = 0.1;

      final germanShepherd = List<double>.filled(150, 0.005);
      germanShepherd[2] = 0.7;
      germanShepherd[3] = 0.1;

      final sim =
          DogEmbeddingService.cosineSimilarity(goldenRetriever, germanShepherd);
      expect(sim, lessThan(0.5));
    });

    test('cosineSimilarity handles empty vectors', () {
      expect(DogEmbeddingService.cosineSimilarity([], []), 0.0);
    });

    test('cosineSimilarity handles mismatched lengths', () {
      expect(DogEmbeddingService.cosineSimilarity([1.0], [1.0, 2.0]), 0.0);
    });

    test('cosineSimilarity handles zero vectors', () {
      final zero = [0.0, 0.0, 0.0];
      expect(DogEmbeddingService.cosineSimilarity(zero, zero), 0.0);
    });

    test('averageEmbeddings of single embedding returns copy', () {
      final emb = [0.5, 0.3, 0.2];
      final avg = DogEmbeddingService.averageEmbeddings([emb]);
      expect(avg, [0.5, 0.3, 0.2]);
      // Should be a copy, not the same reference
      avg[0] = 0.0;
      expect(emb[0], 0.5);
    });

    test('averageEmbeddings computes element-wise mean', () {
      final a = [1.0, 0.0, 0.0];
      final b = [0.0, 1.0, 0.0];
      final avg = DogEmbeddingService.averageEmbeddings([a, b]);
      expect(avg[0], closeTo(0.5, 0.001));
      expect(avg[1], closeTo(0.5, 0.001));
      expect(avg[2], closeTo(0.0, 0.001));
    });

    test('averageEmbeddings of empty list returns empty', () {
      expect(DogEmbeddingService.averageEmbeddings([]), isEmpty);
    });

    test('same-breed synthetic embeddings produce high cosine similarity', () {
      // Simulate the demo seeding pattern
      final rng = Random(42);
      List<double> syntheticEmb(int spike) {
        final emb = List<double>.filled(150, 0.005);
        emb[spike] = 0.65 + rng.nextDouble() * 0.15;
        for (int i = 1; i <= 3; i++) {
          if (spike + i < 150) emb[spike + i] = 0.02 + rng.nextDouble() * 0.05;
          if (spike - i >= 0) emb[spike - i] = 0.02 + rng.nextDouble() * 0.05;
        }
        return emb;
      }

      // Two embeddings with the same spike index (same breed)
      final a = syntheticEmb(1);
      final b = syntheticEmb(1);
      final sim = DogEmbeddingService.cosineSimilarity(a, b);
      expect(sim, greaterThan(0.85),
          reason: 'Same-breed embeddings should match');

      // Two embeddings with different spike indices (different breeds)
      final c = syntheticEmb(10);
      final crossSim = DogEmbeddingService.cosineSimilarity(a, c);
      expect(crossSim, lessThan(0.5),
          reason: 'Different-breed embeddings should not match');
    });
  });

  group('StrayScanResult', () {
    test('default matches is empty list', () {
      final result = StrayScanResult(
        scanId: 'scan-001',
        scannedAt: DateTime.now(),
      );
      expect(result.matches, isEmpty);
      expect(result.photoPath, isNull);
    });
  });
}
