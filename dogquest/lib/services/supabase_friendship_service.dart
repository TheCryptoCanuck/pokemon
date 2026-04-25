import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _log = Logger('SupabaseFriendshipService');

/// A friendship record from Supabase with joined dog and owner info.
class FriendshipRemote {
  final String id;
  final String requesterDogId;
  final String requesterDogName;
  final String requesterBreed;
  final String? requesterPhotoUrl;
  final String requesterOwnerUsername;
  final String recipientDogId;
  final String recipientDogName;
  final String recipientBreed;
  final String? recipientPhotoUrl;
  final String recipientOwnerUsername;
  final String status;
  final DateTime createdAt;
  final DateTime? acceptedAt;

  const FriendshipRemote({
    required this.id,
    required this.requesterDogId,
    required this.requesterDogName,
    required this.requesterBreed,
    this.requesterPhotoUrl,
    required this.requesterOwnerUsername,
    required this.recipientDogId,
    required this.recipientDogName,
    required this.recipientBreed,
    this.recipientPhotoUrl,
    required this.recipientOwnerUsername,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
  });

  factory FriendshipRemote.fromJson(Map<String, dynamic> json) {
    final requesterDog = json['requester_dog'] as Map<String, dynamic>?;
    final recipientDog = json['recipient_dog'] as Map<String, dynamic>?;
    final requesterOwner = json['requester_owner'] as Map<String, dynamic>?;
    final recipientOwner = json['recipient_owner'] as Map<String, dynamic>?;

    return FriendshipRemote(
      id: json['id'] as String,
      requesterDogId: json['requester_dog_id'] as String,
      requesterDogName: requesterDog?['name'] as String? ?? '',
      requesterBreed: requesterDog?['breed'] as String? ?? '',
      requesterPhotoUrl: requesterDog?['photo_url'] as String?,
      requesterOwnerUsername: requesterOwner?['username'] as String? ?? '',
      recipientDogId: json['recipient_dog_id'] as String,
      recipientDogName: recipientDog?['name'] as String? ?? '',
      recipientBreed: recipientDog?['breed'] as String? ?? '',
      recipientPhotoUrl: recipientDog?['photo_url'] as String?,
      recipientOwnerUsername: recipientOwner?['username'] as String? ?? '',
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
    );
  }
}

/// Supabase-backed friendship service for dog-to-dog friendships.
class SupabaseFriendshipService {
  final SupabaseClient _client;

  SupabaseFriendshipService(this._client);

  String? get _userId => _client.auth.currentUser?.id;

  // ─── Select clause for joined queries ───────────────────────

  static const _selectWithJoins = '''
    *,
    requester_dog:dog_profiles!requester_dog_id(name, breed, photo_url),
    recipient_dog:dog_profiles!recipient_dog_id(name, breed, photo_url),
    requester_owner:users!requester_dog_owner_id(username),
    recipient_owner:users!recipient_dog_owner_id(username)
  ''';

  // ─── Send / Accept / Reject / Remove ────────────────────────

  /// Send a friendship request from one dog to another.
  /// Looks up owner IDs from dog_profiles before inserting.
  Future<void> sendRequest(String requesterDogId, String recipientDogId) async {
    final uid = _userId;
    if (uid == null) return;

    try {
      // Look up both dog owners
      final requesterDog = await _client
          .from('dog_profiles')
          .select('owner_id')
          .eq('id', requesterDogId)
          .single();

      final recipientDog = await _client
          .from('dog_profiles')
          .select('owner_id')
          .eq('id', recipientDogId)
          .single();

      await _client.from('friendships').insert({
        'requester_dog_id': requesterDogId,
        'requester_dog_owner_id': requesterDog['owner_id'] as String,
        'recipient_dog_id': recipientDogId,
        'recipient_dog_owner_id': recipientDog['owner_id'] as String,
        'status': 'pending',
      });
      _log.info('Friendship request sent: $requesterDogId -> $recipientDogId');
    } catch (e) {
      _log.warning('Failed to send friendship request: $e');
      rethrow;
    }
  }

  /// Accept a pending friendship request.
  Future<void> acceptRequest(String friendshipId) async {
    try {
      await _client.from('friendships').update({
        'status': 'accepted',
        'accepted_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', friendshipId);
      _log.info('Friendship accepted: $friendshipId');
    } catch (e) {
      _log.warning('Failed to accept friendship: $e');
      rethrow;
    }
  }

  /// Reject a pending friendship request.
  Future<void> rejectRequest(String friendshipId) async {
    try {
      await _client
          .from('friendships')
          .update({'status': 'rejected'}).eq('id', friendshipId);
      _log.info('Friendship rejected: $friendshipId');
    } catch (e) {
      _log.warning('Failed to reject friendship: $e');
      rethrow;
    }
  }

  /// Remove (delete) an existing friendship.
  Future<void> removeFriendship(String friendshipId) async {
    try {
      await _client.from('friendships').delete().eq('id', friendshipId);
      _log.info('Friendship removed: $friendshipId');
    } catch (e) {
      _log.warning('Failed to remove friendship: $e');
      rethrow;
    }
  }

  // ─── Queries ────────────────────────────────────────────────

  /// Get all accepted friendships where the current user is either
  /// the requester or recipient dog owner. Returns joined dog + owner info.
  Future<List<FriendshipRemote>> getMyFriendships() async {
    final uid = _userId;
    if (uid == null) return [];

    try {
      final response = await _client
          .from('friendships')
          .select(_selectWithJoins)
          .eq('status', 'accepted')
          .or('requester_dog_owner_id.eq.$uid,recipient_dog_owner_id.eq.$uid')
          .order('accepted_at', ascending: false);

      final list = response as List<dynamic>;
      return list
          .map((e) => FriendshipRemote.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log.warning('Failed to fetch friendships: $e');
      return [];
    }
  }

  /// Get pending friendship requests where the current user is the
  /// recipient dog owner (i.e., requests others have sent to me).
  Future<List<FriendshipRemote>> getPendingRequests() async {
    final uid = _userId;
    if (uid == null) return [];

    try {
      final response = await _client
          .from('friendships')
          .select(_selectWithJoins)
          .eq('status', 'pending')
          .eq('recipient_dog_owner_id', uid)
          .order('created_at', ascending: false);

      final list = response as List<dynamic>;
      return list
          .map((e) => FriendshipRemote.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log.warning('Failed to fetch pending requests: $e');
      return [];
    }
  }

  /// Get pending friendship requests the current user has sent.
  Future<List<FriendshipRemote>> getSentRequests() async {
    final uid = _userId;
    if (uid == null) return [];

    try {
      final response = await _client
          .from('friendships')
          .select(_selectWithJoins)
          .eq('status', 'pending')
          .eq('requester_dog_owner_id', uid)
          .order('created_at', ascending: false);

      final list = response as List<dynamic>;
      return list
          .map((e) => FriendshipRemote.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log.warning('Failed to fetch sent requests: $e');
      return [];
    }
  }

  // ─── Real-time ──────────────────────────────────────────────

  /// Watch for pending friendship requests addressed to the current user
  /// in real-time. Emits whenever the friendships table changes.
  Stream<List<Map<String, dynamic>>> watchPendingRequests() {
    final uid = _userId;
    if (uid == null) return const Stream.empty();

    return _client
        .from('friendships')
        .stream(primaryKey: ['id'])
        .eq('recipient_dog_owner_id', uid)
        .order('created_at', ascending: false)
        .map((rows) => rows.where((r) => r['status'] == 'pending').toList());
  }
}

/// Provider that returns [SupabaseFriendshipService] when authenticated,
/// or null when offline/unauthenticated.
final supabaseFriendshipServiceProvider =
    Provider<SupabaseFriendshipService?>((ref) {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) return null;
  return SupabaseFriendshipService(Supabase.instance.client);
});
