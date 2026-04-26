import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dogquest/constants.dart';
import 'package:dogquest/services/social_service.dart';
import 'package:dogquest/services/supabase_friendship_service.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _sentRequests = [];
  bool _loading = true;
  bool _searching = false;
  bool _offline = false;

  // Supabase remote data
  List<FriendshipRemote> _remoteFriendships = [];
  List<FriendshipRemote> _remotePending = [];
  bool _useRemote = false;
  StreamSubscription? _pendingSub;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _pendingSub?.cancel();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() {
      _loading = true;
      _offline = false;
    });

    // Try Supabase first
    final remoteSvc = ref.read(supabaseFriendshipServiceProvider);
    if (remoteSvc != null) {
      try {
        final friendships = await remoteSvc
            .getMyFriendships()
            .timeout(const Duration(seconds: 8));
        final pending = await remoteSvc
            .getPendingRequests()
            .timeout(const Duration(seconds: 8));
        if (mounted) {
          setState(() {
            _remoteFriendships = friendships;
            _remotePending = pending;
            _useRemote = true;
            _loading = false;
          });
          // Watch for new pending requests in real-time
          _pendingSub?.cancel();
          _pendingSub = remoteSvc.watchPendingRequests().listen((requests) {
            if (mounted) {
              setState(
                () => _remotePending =
                    requests.map(FriendshipRemote.fromJson).toList(),
              );
            }
          });
          return;
        }
      } catch (_) {
        // Fall through to local
      }
    }

    // Local fallback
    final svc = ref.read(socialServiceProvider);
    try {
      final data = await svc.fetchFriends().timeout(const Duration(seconds: 8));
      if (data != null && mounted) {
        setState(() {
          _friends = List<Map<String, dynamic>>.from(data['friends'] ?? []);
          _pendingRequests =
              List<Map<String, dynamic>>.from(data['pending_requests'] ?? []);
          _sentRequests =
              List<Map<String, dynamic>>.from(data['sent_requests'] ?? []);
          _useRemote = false;
          _loading = false;
        });
      } else if (mounted) {
        setState(() {
          _offline = true;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _offline = true;
          _loading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _searching = true);
      try {
        final svc = ref.read(socialServiceProvider);
        final results = await svc
            .searchUsers(query.trim())
            .timeout(const Duration(seconds: 8));
        if (mounted) {
          setState(() {
            _searchResults = results;
            _searching = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => _searching = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Search unavailable — check your connection'),
              backgroundColor: Color(0xFF5D4037),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  Future<void> _sendRequest(int userId) async {
    // Outbound friend requests use the local SocialService.
    // Remote (Supabase) friend requests require resolving both the
    // requester's and recipient's dog ids, which this UI's search flow
    // does not yet surface. Until the search returns dog records,
    // outbound sends go through local. Inbound accept/reject still use
    // the remote path because they operate on a friendshipId already
    // returned by getPendingRequests().
    final svc = ref.read(socialServiceProvider);
    final success = await svc.sendFriendRequest(userId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Friend request sent!'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
      _searchController.clear();
      setState(() => _searchResults = []);
      _loadFriends();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send request. Maybe already friends?'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _acceptRemoteRequest(String friendshipId) async {
    final remoteSvc = ref.read(supabaseFriendshipServiceProvider);
    if (remoteSvc == null) return;
    try {
      await remoteSvc.acceptRequest(friendshipId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request accepted!'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        _loadFriends();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not accept request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectRemoteRequest(String friendshipId) async {
    final remoteSvc = ref.read(supabaseFriendshipServiceProvider);
    if (remoteSvc == null) return;
    try {
      await remoteSvc.rejectRequest(friendshipId);
      if (mounted) {
        _loadFriends();
      }
    } catch (_) {}
  }

  Future<void> _removeRemoteFriendship(String friendshipId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgCard,
        title:
            const Text('Remove Friend', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to remove this friend?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final remoteSvc = ref.read(supabaseFriendshipServiceProvider);
    if (remoteSvc == null) return;
    try {
      await remoteSvc.removeFriendship(friendshipId);
      if (mounted) _loadFriends();
    } catch (_) {}
  }

  Future<void> _acceptRequest(int friendshipId) async {
    final svc = ref.read(socialServiceProvider);
    final success = await svc.acceptFriendRequest(friendshipId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Friend request accepted!'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
      _loadFriends();
    }
  }

  Future<void> _removeFriend(int friendshipId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgCard,
        title:
            const Text('Remove Friend', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to remove this friend?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final svc = ref.read(socialServiceProvider);
    final success = await svc.removeFriend(friendshipId);
    if (success && mounted) {
      _loadFriends();
    }
  }

  int get _pendingBadgeCount =>
      _useRemote ? _remotePending.length : _pendingRequests.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AppBar(
        backgroundColor: bgNav,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Friends',
              style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_pendingBadgeCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_pendingBadgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _offline && _friends.isEmpty && _remoteFriendships.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off,
                        color: Colors.white38,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Friends feature available when connected',
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Connect to the internet to find friends',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      TextButton.icon(
                        onPressed: _loadFriends,
                        icon: const Icon(
                          Icons.refresh,
                          color: Colors.amber,
                          size: 18,
                        ),
                        label: const Text(
                          'Retry',
                          style: TextStyle(color: Colors.amber),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: Colors.amber,
                  backgroundColor: bgCard,
                  onRefresh: _loadFriends,
                  child: _useRemote ? _buildRemoteBody() : _buildLocalBody(),
                ),
    );
  }

  // ─── Remote (Supabase) body ─────────────────────────────────────

  Widget _buildRemoteBody() {
    final accepted =
        _remoteFriendships.where((f) => f.status == 'accepted').toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Search bar
        _buildSearchBar(),
        if (_searchResults.isNotEmpty || _searching) ...[
          const SizedBox(height: 12),
          _buildSearchResults(),
        ],

        // Pending requests from Supabase
        if (_remotePending.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionHeader('Pending Requests', '${_remotePending.length}'),
          const SizedBox(height: 8),
          ..._remotePending.asMap().entries.map(
                (e) => _buildRemotePendingTile(e.value)
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: 50 * e.key)),
              ),
        ],

        // Accepted friendships from Supabase
        const SizedBox(height: 20),
        _sectionHeader('Friends', '${accepted.length}'),
        const SizedBox(height: 8),
        if (accepted.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: bgCard,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              children: [
                Text(
                  'No friends yet',
                  style: TextStyle(color: Colors.white54, fontSize: 15),
                ),
                SizedBox(height: 4),
                Text(
                  'Search for users above to send friend requests!',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          )
        else
          ...accepted.asMap().entries.map(
                (e) => _buildRemoteFriendTile(e.value)
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: 50 * e.key)),
              ),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildRemotePendingTile(FriendshipRemote request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Dog photo or placeholder
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.amber.withValues(alpha: 0.15),
              image: request.requesterPhotoUrl != null
                  ? DecorationImage(
                      image: NetworkImage(request.requesterPhotoUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: request.requesterPhotoUrl == null
                ? const Center(
                    child: Icon(Icons.pets, color: Colors.amber, size: 20),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.requesterDogName,
                  style: const TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${request.requesterBreed} \u2022 ${request.requesterOwnerUsername}',
                  style: const TextStyle(color: textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 28),
            onPressed: () => _acceptRemoteRequest(request.id),
            tooltip: 'Accept',
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.red, size: 28),
            onPressed: () => _rejectRemoteRequest(request.id),
            tooltip: 'Reject',
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteFriendTile(FriendshipRemote friendship) {
    // Show the other dog's info (recipient side for sent requests, requester for received)
    final dogName = friendship.recipientDogName;
    final breed = friendship.recipientBreed;
    final owner = friendship.recipientOwnerUsername;
    final photoUrl = friendship.recipientPhotoUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.amber.withValues(alpha: 0.3),
                  accent.withValues(alpha: 0.3),
                ],
              ),
              image: photoUrl != null
                  ? DecorationImage(
                      image: NetworkImage(photoUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: photoUrl == null
                ? const Center(
                    child: Icon(Icons.pets, color: Colors.amber, size: 20),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dogName,
                  style: const TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '$breed \u2022 $owner',
                  style: const TextStyle(color: textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.person_remove,
              color: Colors.white38,
              size: 20,
            ),
            onPressed: () => _removeRemoteFriendship(friendship.id),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }

  // ─── Local fallback body ────────────────────────────────────────

  Widget _buildLocalBody() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Search bar
        _buildSearchBar(),
        if (_searchResults.isNotEmpty || _searching) ...[
          const SizedBox(height: 12),
          _buildSearchResults(),
        ],

        // Pending requests
        if (_pendingRequests.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionHeader('Pending Requests', '${_pendingRequests.length}'),
          const SizedBox(height: 8),
          ..._pendingRequests.asMap().entries.map(
                (e) => _buildPendingTile(e.value)
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: 50 * e.key)),
              ),
        ],

        // Sent requests
        if (_sentRequests.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionHeader('Sent Requests', '${_sentRequests.length}'),
          const SizedBox(height: 8),
          ..._sentRequests.asMap().entries.map(
                (e) => _buildSentTile(e.value)
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: 50 * e.key)),
              ),
        ],

        // Friends list
        const SizedBox(height: 20),
        _sectionHeader('Friends', '${_friends.length}'),
        const SizedBox(height: 8),
        if (_friends.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: bgCard,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              children: [
                Text(
                  'No friends yet',
                  style: TextStyle(color: Colors.white54, fontSize: 15),
                ),
                SizedBox(height: 4),
                Text(
                  'Search for users above to send friend requests!',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          )
        else
          ..._friends.asMap().entries.map(
                (e) => _buildFriendTile(e.value)
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: 50 * e.key)),
              ),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search users by name...',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Colors.white38),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white38),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchResults = [];
                      _searching = false;
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searching) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: Colors.amber,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    return Column(
      children: _searchResults.map((user) {
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bgCard,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.withValues(alpha: 0.15),
                ),
                child: const Center(
                  child: Icon(Icons.person, color: Colors.amber, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['username'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Lv.${user['level']} ${user['level_title']}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: () => _sendRequest(user['id'] as int),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text('Add', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPendingTile(Map<String, dynamic> request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.amber.withValues(alpha: 0.15),
            ),
            child: const Center(
              child: Icon(Icons.person_add, color: Colors.amber, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request['from_username'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Lv.${request['from_level']}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 28),
            onPressed: () => _acceptRequest(request['id'] as int),
            tooltip: 'Accept',
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.red, size: 28),
            onPressed: () => _removeFriend(request['id'] as int),
            tooltip: 'Decline',
          ),
        ],
      ),
    );
  }

  Widget _buildSentTile(Map<String, dynamic> request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            child: const Center(
              child: Icon(Icons.hourglass_top, color: Colors.white38, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request['friend_username'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Text(
                  'Pending...',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white38, size: 22),
            onPressed: () => _removeFriend(request['id'] as int),
            tooltip: 'Cancel',
          ),
        ],
      ),
    );
  }

  Widget _buildFriendTile(Map<String, dynamic> friend) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.amber.withValues(alpha: 0.3),
                  const Color(0xFFD4874E).withValues(alpha: 0.3),
                ],
              ),
            ),
            child: const Center(
              child: Icon(Icons.person, color: Colors.amber, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend['friend_username'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Lv.${friend['friend_level']}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '${friend['friend_xp']} XP',
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(
              Icons.person_remove,
              color: Colors.white38,
              size: 20,
            ),
            onPressed: () => _removeFriend(friend['id'] as int),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String count) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.amber,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            count,
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
