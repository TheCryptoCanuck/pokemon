import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dogquest/services/supabase_social_service.dart';
import 'package:dogquest/services/social_post_generator.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

/// Covers the fluent query-builder chain returned by client.from().
/// Every terminal and chaining method that the services call must be stubbed.
class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder<dynamic> {}

class MockPostgrestTransformBuilder extends Mock
    implements PostgrestTransformBuilder<dynamic> {}

/// A minimal fake of SupabaseSocialService used for SocialPostGenerator tests.
class MockSupabaseSocialService extends Mock implements SupabaseSocialService {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Wires up the fluent chain:
///   client.from(table) → builder
///   builder.insert(...)         → Future (void / data)
///   builder.select(...)         → builder
///   builder.delete()            → builder
///   builder.update(...)         → builder
///   builder.eq(col, val)        → builder  (multiple calls chain to same mock)
///   builder.maybeSingle()       → Future<Map?>
///   builder.order(...)          → builder
///   builder.limit(...)          → builder
void _stubFrom(
  MockSupabaseClient client,
  MockPostgrestFilterBuilder builder,
) {
  when(() => client.from(any())).thenReturn(builder);
  when(() => builder.insert(any())).thenReturn(builder);
  when(() => builder.select(any())).thenReturn(builder);
  when(() => builder.select()).thenReturn(builder);
  when(() => builder.delete()).thenReturn(builder);
  when(() => builder.update(any())).thenReturn(builder);
  when(() => builder.eq(any(), any())).thenReturn(builder);
  when(() => builder.order(any())).thenReturn(builder);
  when(() => builder.order(any(), ascending: any(named: 'ascending')))
      .thenReturn(builder);
  when(() => builder.limit(any())).thenReturn(builder);
}

/// Builds a minimal valid SocialPost JSON map.
Map<String, dynamic> _postJson({
  String id = 'post-1',
  String userId = 'user-abc',
  String postType = 'breed_discovered',
  String breedName = 'Labrador Retriever',
}) =>
    {
      'id': id,
      'user_id': userId,
      'username': 'tester',
      'display_name': 'Tester',
      'avatar_id': null,
      'post_type': postType,
      'content': 'Discovered a $breedName!',
      'breed_name': breedName,
      'photo_url': null,
      'metadata': <String, dynamic>{},
      'like_count': 0,
      'comment_count': 0,
      'user_has_liked': false,
      'created_at': '2026-03-15T10:00:00.000Z',
    };

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // Register fallback values that mocktail needs for any() matchers.
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue('');
  });

  // ─── Group 1: SupabaseSocialService ──────────────────────────────────────

  group('SupabaseSocialService', () {
    late MockSupabaseClient mockClient;
    late MockGoTrueClient mockAuth;
    late MockUser mockUser;
    late MockPostgrestFilterBuilder mockBuilder;
    late SupabaseSocialService service;

    const currentUserId = 'user-abc';

    setUp(() {
      mockClient = MockSupabaseClient();
      mockAuth = MockGoTrueClient();
      mockUser = MockUser();
      mockBuilder = MockPostgrestFilterBuilder();

      when(() => mockClient.auth).thenReturn(mockAuth);
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.id).thenReturn(currentUserId);

      _stubFrom(mockClient, mockBuilder);

      service = SupabaseSocialService(mockClient);
    });

    // 1. getFeed returns parsed SocialPost list
    test('getFeed returns parsed SocialPost list', () async {
      final rawData = [_postJson(), _postJson(id: 'post-2', postType: 'level_up')];

      when(() => mockClient.rpc('get_feed', params: any(named: 'params')))
          .thenAnswer((_) async => rawData);

      final posts = await service.getFeed();

      expect(posts, hasLength(2));
      expect(posts.first.id, 'post-1');
      expect(posts.first.postType, 'breed_discovered');
      expect(posts.first.breedName, 'Labrador Retriever');
      expect(posts[1].id, 'post-2');
      verify(() => mockClient.rpc('get_feed', params: any(named: 'params')))
          .called(1);
    });

    // 2. createPost inserts with correct params
    test('createPost inserts with correct params', () async {
      when(() => mockBuilder.insert(any()))
          .thenAnswer((_) async => <dynamic>[]);

      await service.createPost(
        postType: 'breed_discovered',
        content: 'Discovered a Beagle!',
        breedName: 'Beagle',
      );

      final captured = verify(() => mockBuilder.insert(captureAny())).captured;
      expect(captured, hasLength(1));
      final payload = captured.first as Map<String, dynamic>;
      expect(payload['post_type'], 'breed_discovered');
      expect(payload['content'], 'Discovered a Beagle!');
      expect(payload['breed_name'], 'Beagle');
      expect(payload['user_id'], currentUserId);
    });

    // 3. toggleLike adds like when not already liked
    test('toggleLike adds like when not liked', () async {
      // maybeSingle returns null → not yet liked
      when(() => mockBuilder.maybeSingle()).thenAnswer((_) async => null);
      // insert for the like
      when(() => mockBuilder.insert(any()))
          .thenAnswer((_) async => <dynamic>[]);
      // select + eq for _updateLikeCount's count query
      when(() => mockBuilder.select(any())).thenReturn(mockBuilder);
      // update for denormalized like_count
      when(() => mockBuilder.update(any())).thenReturn(mockBuilder);
      // Make the final awaited calls resolve
      when(() => mockBuilder.eq(any(), any())).thenReturn(mockBuilder);

      // Override the terminal awaits: select().eq().eq() for count returns list
      // and update().eq() also needs to resolve.
      // Because all calls go through the same mock builder, we stub the
      // cast-to-List path via a fresh answer on the builder itself.
      // The _updateLikeCount awaits the builder after .select('id').eq(...);
      // we satisfy that by having the Future<dynamic> resolve to [].
      when(mockBuilder.call).thenAnswer((_) async => <dynamic>[]);

      final result = await service.toggleLike('post-1');

      expect(result, isTrue);
      verify(() => mockBuilder.insert(any())).called(greaterThanOrEqualTo(1));
    });

    // 4. toggleLike removes like when already liked
    test('toggleLike removes like when already liked', () async {
      final existingLike = {'id': 'like-99'};
      when(() => mockBuilder.maybeSingle())
          .thenAnswer((_) async => existingLike);
      when(() => mockBuilder.delete()).thenReturn(mockBuilder);
      when(() => mockBuilder.eq(any(), any())).thenReturn(mockBuilder);
      when(() => mockBuilder.select(any())).thenReturn(mockBuilder);
      when(() => mockBuilder.update(any())).thenReturn(mockBuilder);
      when(mockBuilder.call).thenAnswer((_) async => <dynamic>[]);

      final result = await service.toggleLike('post-1');

      expect(result, isFalse);
      verify(() => mockBuilder.delete()).called(greaterThanOrEqualTo(1));
    });

    // 5. followUser inserts follow record
    test('followUser inserts follow record', () async {
      when(() => mockBuilder.insert(any()))
          .thenAnswer((_) async => <dynamic>[]);

      await service.followUser('user-xyz');

      final captured = verify(() => mockBuilder.insert(captureAny())).captured;
      final payload = captured.first as Map<String, dynamic>;
      expect(payload['follower_id'], currentUserId);
      expect(payload['following_id'], 'user-xyz');
    });

    // 6. unfollowUser deletes follow record
    test('unfollowUser deletes follow record', () async {
      when(() => mockBuilder.delete()).thenReturn(mockBuilder);
      when(() => mockBuilder.eq(any(), any())).thenReturn(mockBuilder);
      // Terminal await on the builder after .eq()
      when(mockBuilder.call).thenAnswer((_) async => <dynamic>[]);

      await service.unfollowUser('user-xyz');

      verify(() => mockClient.from('follows')).called(greaterThanOrEqualTo(1));
      verify(() => mockBuilder.delete()).called(greaterThanOrEqualTo(1));
    });

    // 7. blockUser inserts block record and unfollows in both directions
    test('blockUser inserts block record and unfollows both directions',
        () async {
      when(() => mockBuilder.insert(any()))
          .thenAnswer((_) async => <dynamic>[]);
      when(() => mockBuilder.delete()).thenReturn(mockBuilder);
      when(() => mockBuilder.eq(any(), any())).thenReturn(mockBuilder);
      when(mockBuilder.call).thenAnswer((_) async => <dynamic>[]);

      await service.blockUser('user-xyz');

      // 1 insert for the block record
      verify(() => mockClient.from('user_blocks')).called(1);
      // 2 deletes on 'follows' (one per direction)
      final followsFromCalls =
          verify(() => mockClient.from('follows')).callCount;
      expect(followsFromCalls, 2);
      verify(() => mockBuilder.delete()).called(greaterThanOrEqualTo(2));
    });
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
    Future<void> _pump() => Future<void>.delayed(Duration.zero);

    // 8. onBreedDiscovered creates a breed_discovered post
    test('onBreedDiscovered creates breed_discovered post', () async {
      generator.onBreedDiscovered('Golden Retriever');
      await _pump();

      verify(() => mockSocial.createPost(
            postType: 'breed_discovered',
            content: any(named: 'content'),
            breedName: 'Golden Retriever',
            metadata: any(named: 'metadata'),
          )).called(1);
    });

    // 9. onBreedDiscovered with legendary rarity creates two posts
    test('onBreedDiscovered with legendary rarity creates breed_discovered and rare_find',
        () async {
      generator.onBreedDiscovered('Xoloitzcuintli', rarity: 'legendary');
      await _pump();

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

    // 10. onStreakMilestone fires at 7 but NOT at 8
    test('onStreakMilestone fires at milestone day 7 but not at day 8',
        () async {
      generator.onStreakMilestone(7);
      await _pump();

      verify(() => mockSocial.createPost(
            postType: 'streak_milestone',
            content: any(named: 'content'),
            metadata: any(named: 'metadata'),
          )).called(1);

      clearInteractions(mockSocial);

      generator.onStreakMilestone(8);
      await _pump();

      verifyNever(() => mockSocial.createPost(
            postType: any(named: 'postType'),
            content: any(named: 'content'),
            metadata: any(named: 'metadata'),
          ));
    });

    // 11. onLevelUp creates level_up post with level metadata
    test('onLevelUp creates level_up post with correct metadata', () async {
      generator.onLevelUp(10, 'Expert');
      await _pump();

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

    // 12. null service is a silent no-op
    test('null service is silent no-op — no errors thrown', () async {
      final silentGenerator = SocialPostGenerator(null);

      expect(
        () async {
          silentGenerator.onBreedDiscovered('Poodle', rarity: 'legendary');
          silentGenerator.onStreakMilestone(7);
          silentGenerator.onLevelUp(5, 'Novice');
          await _pump();
        },
        returnsNormally,
      );
    });
  });
}
