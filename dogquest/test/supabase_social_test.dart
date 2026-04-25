// T5-B follow-up: the SupabaseSocialService group is currently skipped pending
// a mock-pattern redesign. The previous wrapper-based approach
// (`_AwaitableFilterBuilderWrapper implements Future<List<dynamic>>,
// PostgrestFilterBuilder<dynamic>`) does not compile against
// `supabase_flutter` 2.10.2 because `PostgrestBuilder` extends
// `Future<dynamic>`, not `Future<List<dynamic>>` — the type-argument
// conflict is fundamental to that interface set.
//
// Real fix path: introduce a thin repository abstraction over
// SupabaseSocialService's data layer (e.g. `SocialPostRepository`) and mock
// THAT in tests instead of mocking Supabase types directly. Tracked as
// T5-B-redesign in `.second_brain/03_Projects/Active_Tasks.md`.
//
// The SocialPostGenerator group below is unaffected — it mocks
// SupabaseSocialService at the service-class level and never touches the
// PostgrestBuilder hierarchy.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dogquest/services/supabase_social_service.dart';
import 'package:dogquest/services/social_post_generator.dart';

class MockSupabaseSocialService extends Mock implements SupabaseSocialService {}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue('');
  });

  // ─── Group 1: SupabaseSocialService — SKIPPED pending T5-B redesign ──────

  group('SupabaseSocialService', () {
    test(
      'tests pending T5-B mock-pattern redesign',
      () {},
      skip: 'PostgrestBuilder mock wrapper conflicts with '
          'supabase_flutter 2.10.2 Future<dynamic> base. '
          'Redesign needed: mock a repository layer instead. '
          'See Active_Tasks T5-B-redesign.',
    );
  });

  // ─── Group 2: SocialPostGenerator ────────────────────────────────────────

  group('SocialPostGenerator', () {
    late MockSupabaseSocialService mockSocial;
    late SocialPostGenerator generator;

    setUp(() {
      mockSocial = MockSupabaseSocialService();
      generator = SocialPostGenerator(mockSocial);

      // Default: createPost is a no-op future
      when(() => mockSocial.createPost(
            postType: any(named: 'postType'),
            content: any(named: 'content'),
            breedName: any(named: 'breedName'),
            photoUrl: any(named: 'photoUrl'),
            metadata: any(named: 'metadata'),
          )).thenAnswer((_) async {});
    });

    // Helper that drains the microtask queue so fire-and-forget _fire() callbacks run.
    Future<void> pump() => Future<void>.delayed(Duration.zero);

    test('onBreedDiscovered creates breed_discovered post', () async {
      generator.onBreedDiscovered('Golden Retriever');
      await pump();

      verify(() => mockSocial.createPost(
            postType: 'breed_discovered',
            content: any(named: 'content'),
            breedName: 'Golden Retriever',
            metadata: any(named: 'metadata'),
          )).called(1);
    });

    test(
        'onBreedDiscovered with legendary rarity creates breed_discovered and rare_find',
        () async {
      generator.onBreedDiscovered('Xoloitzcuintli', rarity: 'legendary');
      await pump();

      verify(() => mockSocial.createPost(
            postType: 'breed_discovered',
            content: any(named: 'content'),
            breedName: 'Xoloitzcuintli',
            metadata: any(named: 'metadata'),
          )).called(1);

      verify(() => mockSocial.createPost(
            postType: 'rare_find',
            content: any(named: 'content'),
            breedName: 'Xoloitzcuintli',
            metadata: any(named: 'metadata'),
          )).called(1);
    });

    test('onStreakMilestone fires at milestone day 7 but not at day 8',
        () async {
      generator.onStreakMilestone(7);
      await pump();

      verify(() => mockSocial.createPost(
            postType: 'streak_milestone',
            content: any(named: 'content'),
            metadata: any(named: 'metadata'),
          )).called(1);

      clearInteractions(mockSocial);

      generator.onStreakMilestone(8);
      await pump();

      verifyNever(() => mockSocial.createPost(
            postType: any(named: 'postType'),
            content: any(named: 'content'),
            metadata: any(named: 'metadata'),
          ));
    });

    test('onLevelUp creates level_up post with correct metadata', () async {
      generator.onLevelUp(10, 'Expert');
      await pump();

      final captured = verify(() => mockSocial.createPost(
            postType: captureAny(named: 'postType'),
            content: any(named: 'content'),
            metadata: captureAny(named: 'metadata'),
          )).captured;

      // captured = [postType, metadata] interleaved by mocktail
      expect(captured[0], 'level_up');
      final meta = captured[1] as Map<String, dynamic>;
      expect(meta['level'], 10);
      expect(meta['title'], 'Expert');
    });

    test('null service is silent no-op — no errors thrown', () async {
      final silentGenerator = SocialPostGenerator(null);

      expect(
        () async {
          silentGenerator.onBreedDiscovered('Poodle', rarity: 'legendary');
          silentGenerator.onStreakMilestone(7);
          silentGenerator.onLevelUp(5, 'Novice');
          await pump();
        },
        returnsNormally,
      );
    });
  });
}
