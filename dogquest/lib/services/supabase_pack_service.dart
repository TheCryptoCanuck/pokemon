import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _log = Logger('SupabasePackService');

// ─── Data Classes ──────────────────────────────────────────────

/// A pack (family group) from Supabase.
class PackRemote {
  final String id;
  final String name;
  final String inviteCode;
  final String createdBy;
  final DateTime createdAt;
  final int memberCount;

  const PackRemote({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.createdBy,
    required this.createdAt,
    this.memberCount = 0,
  });

  factory PackRemote.fromJson(Map<String, dynamic> json) => PackRemote(
        id: json['id'] as String,
        name: json['name'] as String,
        inviteCode: json['invite_code'] as String,
        createdBy: json['created_by'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        memberCount: json['member_count'] as int? ?? 0,
      );
}

/// A pack member joined with user info.
class PackMemberRemote {
  final String id;
  final String userId;
  final String username;
  final String? displayName;
  final String? avatarId;
  final String role;
  final DateTime joinedAt;

  const PackMemberRemote({
    required this.id,
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarId,
    required this.role,
    required this.joinedAt,
  });

  factory PackMemberRemote.fromJson(Map<String, dynamic> json) {
    final user = json['users'] as Map<String, dynamic>?;
    return PackMemberRemote(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      username:
          user?['username'] as String? ?? json['username'] as String? ?? '',
      displayName:
          user?['display_name'] as String? ?? json['display_name'] as String?,
      avatarId: user?['avatar_id'] as String? ?? json['avatar_id'] as String?,
      role: json['role'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }
}

/// A dog in a pack joined with dog profile info.
class PackDogRemote {
  final String id;
  final String dogId;
  final String dogName;
  final String? breed;
  final String? photoUrl;

  const PackDogRemote({
    required this.id,
    required this.dogId,
    required this.dogName,
    this.breed,
    this.photoUrl,
  });

  factory PackDogRemote.fromJson(Map<String, dynamic> json) {
    final dog = json['dog_profiles'] as Map<String, dynamic>?;
    return PackDogRemote(
      id: json['id'] as String,
      dogId: json['dog_id'] as String,
      dogName: dog?['name'] as String? ?? json['dog_name'] as String? ?? '',
      breed: dog?['breed'] as String? ?? json['breed'] as String?,
      photoUrl: dog?['photo_url'] as String? ?? json['photo_url'] as String?,
    );
  }
}

// ─── Service ───────────────────────────────────────────────────

/// Supabase-backed pack service for cloud pack operations.
class SupabasePackService {
  final SupabaseClient _client;
  static const _chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  SupabasePackService(this._client);

  String? get _userId => _client.auth.currentUser?.id;

  // ─── Create ─────────────────────────────────────────────────

  /// Create a new pack with the current user as owner.
  Future<PackRemote> createPack(String name) async {
    final uid = _userId;
    if (uid == null) throw StateError('Not authenticated');

    final inviteCode = _generateInviteCode();

    final response = await _client
        .from('packs')
        .insert({
          'name': name,
          'created_by': uid,
          'invite_code': inviteCode,
        })
        .select()
        .single();

    final packId = response['id'] as String;

    // Add creator as owner
    await _client.from('pack_members').insert({
      'pack_id': packId,
      'user_id': uid,
      'role': 'owner',
    });

    _log.info('Created pack "$name" with invite code $inviteCode');

    return PackRemote(
      id: packId,
      name: name,
      inviteCode: inviteCode,
      createdBy: uid,
      createdAt: DateTime.parse(response['created_at'] as String),
      memberCount: 1,
    );
  }

  // ─── Join / Leave / Delete ──────────────────────────────────

  /// Join a pack by invite code.
  Future<PackRemote> joinPack(String inviteCode) async {
    final uid = _userId;
    if (uid == null) throw StateError('Not authenticated');

    final code = inviteCode.trim().toUpperCase();

    final packRow = await _client
        .from('packs')
        .select()
        .eq('invite_code', code)
        .maybeSingle();

    if (packRow == null) {
      throw ArgumentError('Invalid invite code');
    }

    final packId = packRow['id'] as String;

    // Check if already a member
    final existing = await _client
        .from('pack_members')
        .select('id')
        .eq('pack_id', packId)
        .eq('user_id', uid)
        .maybeSingle();

    if (existing != null) {
      throw StateError('Already a member of this pack');
    }

    await _client.from('pack_members').insert({
      'pack_id': packId,
      'user_id': uid,
      'role': 'member',
    });

    _log.info('Joined pack ${packRow['name']} via code $code');

    // Return pack with updated member count
    final members =
        await _client.from('pack_members').select('id').eq('pack_id', packId);

    return PackRemote(
      id: packId,
      name: packRow['name'] as String,
      inviteCode: packRow['invite_code'] as String,
      createdBy: packRow['created_by'] as String,
      createdAt: DateTime.parse(packRow['created_at'] as String),
      memberCount: (members as List).length,
    );
  }

  /// Leave a pack. Owners cannot leave — they must delete the pack instead.
  Future<void> leavePack(String packId) async {
    final uid = _userId;
    if (uid == null) throw StateError('Not authenticated');

    // Check role
    final membership = await _client
        .from('pack_members')
        .select('role')
        .eq('pack_id', packId)
        .eq('user_id', uid)
        .maybeSingle();

    if (membership == null) {
      throw StateError('Not a member of this pack');
    }

    if (membership['role'] == 'owner') {
      throw StateError('Pack owner cannot leave. Delete the pack instead.');
    }

    await _client
        .from('pack_members')
        .delete()
        .eq('pack_id', packId)
        .eq('user_id', uid);

    _log.info('Left pack $packId');
  }

  /// Delete a pack (cascades to members and dogs via DB constraints).
  Future<void> deletePack(String packId) async {
    final uid = _userId;
    if (uid == null) throw StateError('Not authenticated');

    // Verify ownership
    final membership = await _client
        .from('pack_members')
        .select('role')
        .eq('pack_id', packId)
        .eq('user_id', uid)
        .maybeSingle();

    if (membership == null || membership['role'] != 'owner') {
      throw StateError('Only the pack owner can delete the pack');
    }

    await _client.from('packs').delete().eq('id', packId);
    _log.info('Deleted pack $packId');
  }

  // ─── Queries ────────────────────────────────────────────────

  /// Fetch all packs the current user is a member of, with member counts.
  Future<List<PackRemote>> getMyPacks() async {
    final uid = _userId;
    if (uid == null) return [];

    try {
      // Get pack IDs the user belongs to
      final memberships = await _client
          .from('pack_members')
          .select('pack_id')
          .eq('user_id', uid);

      if ((memberships as List).isEmpty) return [];

      final packIds = memberships.map((m) => m['pack_id'] as String).toList();

      // Fetch packs
      final packs = await _client
          .from('packs')
          .select()
          .inFilter('id', packIds)
          .order('created_at', ascending: false);

      // Count members per pack
      final results = <PackRemote>[];
      for (final pack in packs as List) {
        final members = await _client
            .from('pack_members')
            .select('id')
            .eq('pack_id', pack['id'] as String);

        results.add(PackRemote(
          id: pack['id'] as String,
          name: pack['name'] as String,
          inviteCode: pack['invite_code'] as String,
          createdBy: pack['created_by'] as String,
          createdAt: DateTime.parse(pack['created_at'] as String),
          memberCount: (members as List).length,
        ));
      }

      return results;
    } catch (e) {
      _log.warning('Failed to fetch packs: $e');
      return [];
    }
  }

  /// Fetch members of a pack joined with user profile data.
  Future<List<PackMemberRemote>> getPackMembers(String packId) async {
    try {
      final response = await _client
          .from('pack_members')
          .select('*, users!inner(username, display_name, avatar_id)')
          .eq('pack_id', packId)
          .order('joined_at');

      return (response as List<dynamic>)
          .map((e) => PackMemberRemote.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log.warning('Failed to fetch pack members: $e');
      return [];
    }
  }

  /// Fetch dogs in a pack joined with dog profile data.
  Future<List<PackDogRemote>> getPackDogs(String packId) async {
    try {
      final response = await _client
          .from('pack_dogs')
          .select('*, dog_profiles!inner(name, breed, photo_url)')
          .eq('pack_id', packId);

      return (response as List<dynamic>)
          .map((e) => PackDogRemote.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log.warning('Failed to fetch pack dogs: $e');
      return [];
    }
  }

  // ─── Dog Management ─────────────────────────────────────────

  /// Add a dog to a pack.
  Future<void> addDogToPack(String packId, String dogId) async {
    final uid = _userId;
    if (uid == null) throw StateError('Not authenticated');

    await _client.from('pack_dogs').insert({
      'pack_id': packId,
      'dog_id': dogId,
    });
    _log.info('Added dog $dogId to pack $packId');
  }

  /// Remove a dog from a pack.
  Future<void> removeDogFromPack(String packId, String dogId) async {
    final uid = _userId;
    if (uid == null) throw StateError('Not authenticated');

    await _client
        .from('pack_dogs')
        .delete()
        .eq('pack_id', packId)
        .eq('dog_id', dogId);
    _log.info('Removed dog $dogId from pack $packId');
  }

  // ─── Helpers ────────────────────────────────────────────────

  /// Generate a random 6-character uppercase alphanumeric invite code.
  String _generateInviteCode() {
    final random = Random.secure();
    return List.generate(6, (_) => _chars[random.nextInt(_chars.length)])
        .join();
  }
}

// ─── Provider ──────────────────────────────────────────────────

/// Provider that returns SupabasePackService when authenticated,
/// or null when offline/unauthenticated.
final supabasePackServiceProvider = Provider<SupabasePackService?>((ref) {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) return null;
  return SupabasePackService(Supabase.instance.client);
});
