import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _log = Logger('SupabaseSocialService');

/// A social feed post from Supabase.
class SocialPost {
  final String id;
  final String userId;
  final String username;
  final String? displayName;
  final String? avatarId;
  final String postType;
  final String? content;
  final String? breedName;
  final String? photoUrl;
  final Map<String, dynamic> metadata;
  final int likeCount;
  final int commentCount;
  final bool userHasLiked;
  final DateTime createdAt;

  const SocialPost({
    required this.id,
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarId,
    required this.postType,
    this.content,
    this.breedName,
    this.photoUrl,
    this.metadata = const {},
    this.likeCount = 0,
    this.commentCount = 0,
    this.userHasLiked = false,
    required this.createdAt,
  });

  factory SocialPost.fromJson(Map<String, dynamic> json) => SocialPost(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        username: json['username'] as String? ?? '',
        displayName: json['display_name'] as String?,
        avatarId: json['avatar_id'] as String?,
        postType: json['post_type'] as String,
        content: json['content'] as String?,
        breedName: json['breed_name'] as String?,
        photoUrl: json['photo_url'] as String?,
        metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
        likeCount: json['like_count'] as int? ?? 0,
        commentCount: json['comment_count'] as int? ?? 0,
        userHasLiked: json['user_has_liked'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

/// A comment on a social post.
class PostComment {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final DateTime createdAt;
  // Joined fields
  final String? username;
  final String? displayName;

  const PostComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.username,
    this.displayName,
  });

  factory PostComment.fromJson(Map<String, dynamic> json) => PostComment(
        id: json['id'] as String,
        postId: json['post_id'] as String,
        userId: json['user_id'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        username: json['username'] as String?,
        displayName: json['display_name'] as String?,
      );
}

/// Supabase-backed social service replacing local mock data.
class SupabaseSocialService {
  final SupabaseClient _client;

  SupabaseSocialService(this._client);

  String? get _userId => _client.auth.currentUser?.id;

  // ─── Feed ──────────────────────────────────────────────────

  /// Get paginated social feed using the get_feed RPC.
  Future<List<SocialPost>> getFeed({int limit = 20, DateTime? cursor}) async {
    final uid = _userId;
    if (uid == null) return [];

    try {
      final response = await _client.rpc('get_feed', params: {
        'p_user_id': uid,
        'p_limit': limit,
        if (cursor != null) 'p_cursor': cursor.toUtc().toIso8601String(),
      });
      final list = response as List<dynamic>;
      return list.map((e) => SocialPost.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      _log.warning('Failed to fetch feed: $e');
      return [];
    }
  }

  // ─── Posts ─────────────────────────────────────────────────

  /// Create a new social post.
  Future<void> createPost({
    required String postType,
    String? content,
    String? breedName,
    String? photoUrl,
    Map<String, dynamic>? metadata,
  }) async {
    final uid = _userId;
    if (uid == null) return;

    await _client.from('social_posts').insert({
      'user_id': uid,
      'post_type': postType,
      if (content != null) 'content': content,
      if (breedName != null) 'breed_name': breedName,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (metadata != null) 'metadata': metadata,
    });
    _log.info('Created social post: $postType');
  }

  /// Delete own post.
  Future<void> deletePost(String postId) async {
    await _client.from('social_posts').delete().eq('id', postId);
  }

  // ─── Likes ─────────────────────────────────────────────────

  /// Toggle like on a post. Returns true if now liked.
  Future<bool> toggleLike(String postId) async {
    final uid = _userId;
    if (uid == null) return false;

    // Check if already liked
    final existing = await _client
        .from('post_likes')
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', uid)
        .maybeSingle();

    if (existing != null) {
      // Unlike
      await _client.from('post_likes').delete().eq('id', existing['id']);
      await _updateLikeCount(postId);
      return false;
    } else {
      // Like
      await _client.from('post_likes').insert({
        'post_id': postId,
        'user_id': uid,
      });
      await _updateLikeCount(postId);
      return true;
    }
  }

  /// Recount likes and update the denormalized like_count.
  Future<void> _updateLikeCount(String postId) async {
    final likes = await _client
        .from('post_likes')
        .select('id')
        .eq('post_id', postId);
    await _client
        .from('social_posts')
        .update({'like_count': (likes as List).length})
        .eq('id', postId);
  }

  // ─── Comments ──────────────────────────────────────────────

  /// Add a comment to a post.
  Future<void> addComment(String postId, String content) async {
    final uid = _userId;
    if (uid == null) return;

    await _client.from('post_comments').insert({
      'post_id': postId,
      'user_id': uid,
      'content': content,
    });
    // Recount comments and update denormalized count
    final comments = await _client
        .from('post_comments')
        .select('id')
        .eq('post_id', postId);
    await _client
        .from('social_posts')
        .update({'comment_count': (comments as List).length})
        .eq('id', postId);
  }

  /// Get comments for a post.
  Future<List<PostComment>> getComments(String postId) async {
    try {
      final response = await _client
          .from('post_comments')
          .select('*, users!inner(username, display_name)')
          .eq('post_id', postId)
          .order('created_at');

      return (response as List<dynamic>).map((e) {
        final json = e as Map<String, dynamic>;
        final user = json['users'] as Map<String, dynamic>?;
        return PostComment(
          id: json['id'] as String,
          postId: json['post_id'] as String,
          userId: json['user_id'] as String,
          content: json['content'] as String,
          createdAt: DateTime.parse(json['created_at'] as String),
          username: user?['username'] as String?,
          displayName: user?['display_name'] as String?,
        );
      }).toList();
    } catch (e) {
      _log.warning('Failed to fetch comments: $e');
      return [];
    }
  }

  // ─── Follow ────────────────────────────────────────────────

  /// Follow a user.
  Future<void> followUser(String targetUserId) async {
    final uid = _userId;
    if (uid == null || uid == targetUserId) return;

    await _client.from('follows').insert({
      'follower_id': uid,
      'following_id': targetUserId,
    });
    _log.info('Followed user: $targetUserId');
  }

  /// Unfollow a user.
  Future<void> unfollowUser(String targetUserId) async {
    final uid = _userId;
    if (uid == null) return;

    await _client
        .from('follows')
        .delete()
        .eq('follower_id', uid)
        .eq('following_id', targetUserId);
    _log.info('Unfollowed user: $targetUserId');
  }

  /// Check if current user follows a target user.
  Future<bool> isFollowing(String targetUserId) async {
    final uid = _userId;
    if (uid == null) return false;

    final result = await _client
        .from('follows')
        .select('id')
        .eq('follower_id', uid)
        .eq('following_id', targetUserId)
        .maybeSingle();
    return result != null;
  }

  /// Get follower count for a user.
  Future<int> getFollowerCount(String userId) async {
    final result = await _client
        .from('follows')
        .select('id')
        .eq('following_id', userId);
    return (result as List).length;
  }

  /// Get following count for a user.
  Future<int> getFollowingCount(String userId) async {
    final result = await _client
        .from('follows')
        .select('id')
        .eq('follower_id', userId);
    return (result as List).length;
  }

  // ─── Block ─────────────────────────────────────────────────

  /// Block a user.
  Future<void> blockUser(String targetUserId) async {
    final uid = _userId;
    if (uid == null) return;

    await _client.from('user_blocks').insert({
      'blocker_id': uid,
      'blocked_id': targetUserId,
    });
    // Also unfollow in both directions
    await _client
        .from('follows')
        .delete()
        .eq('follower_id', uid)
        .eq('following_id', targetUserId);
    await _client
        .from('follows')
        .delete()
        .eq('follower_id', targetUserId)
        .eq('following_id', uid);
    _log.info('Blocked user: $targetUserId');
  }

  /// Unblock a user.
  Future<void> unblockUser(String targetUserId) async {
    final uid = _userId;
    if (uid == null) return;

    await _client
        .from('user_blocks')
        .delete()
        .eq('blocker_id', uid)
        .eq('blocked_id', targetUserId);
  }

  // ─── Report ────────────────────────────────────────────────

  /// Report content.
  Future<void> reportContent({
    required String contentType,
    required String contentId,
    required String reason,
    String? description,
  }) async {
    final uid = _userId;
    if (uid == null) return;

    await _client.from('content_reports').insert({
      'reporter_id': uid,
      'content_type': contentType,
      'content_id': contentId,
      'reason': reason,
      if (description != null) 'description': description,
    });
    _log.info('Reported $contentType: $contentId');
  }

  // ─── Leaderboard ───────────────────────────────────────────

  /// Get the XP leaderboard.
  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 50}) async {
    try {
      final response = await _client.rpc('get_leaderboard', params: {
        'p_limit': limit,
      });
      return (response as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (e) {
      _log.warning('Failed to fetch leaderboard: $e');
      return [];
    }
  }

  // ─── Real-time ─────────────────────────────────────────────

  /// Subscribe to new social posts (for live feed updates).
  Stream<List<Map<String, dynamic>>> watchFeed() {
    return _client
        .from('social_posts')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(20);
  }

}

/// Provider that returns SupabaseSocialService when authenticated,
/// or null when offline/unauthenticated.
final supabaseSocialServiceProvider = Provider<SupabaseSocialService?>((ref) {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) return null;
  return SupabaseSocialService(Supabase.instance.client);
});
