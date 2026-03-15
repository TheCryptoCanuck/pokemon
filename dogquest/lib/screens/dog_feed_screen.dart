import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import '../services/dog_social_service.dart';
import '../services/supabase_social_service.dart';

class DogFeedScreen extends ConsumerStatefulWidget {
  const DogFeedScreen({super.key});

  @override
  ConsumerState<DogFeedScreen> createState() => _DogFeedScreenState();
}

class _DogFeedScreenState extends ConsumerState<DogFeedScreen> {
  bool _followedOnly = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  List<SocialPost> _remotePosts = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadFeed();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadFeed() async {
    final social = ref.read(supabaseSocialServiceProvider);
    if (social == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    final posts = await social.getFeed(limit: 20);
    if (mounted) setState(() { _remotePosts = posts; _isLoading = false; });
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _remotePosts.isEmpty) return;
    final social = ref.read(supabaseSocialServiceProvider);
    if (social == null) return;

    setState(() => _isLoadingMore = true);
    final cursor = _remotePosts.last.createdAt;
    final more = await social.getFeed(limit: 20, cursor: cursor);
    if (mounted) {
      setState(() {
        _remotePosts.addAll(more);
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final social = ref.watch(supabaseSocialServiceProvider);
    final isOnline = social != null;

    // Offline: fall back to local Hive feed
    if (!isOnline) {
      return _buildLocalFeed();
    }

    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AppBar(
        title: const Text('Dog Feed'),
        backgroundColor: bgCard,
        actions: [
          IconButton(
            icon: Icon(
              _followedOnly ? Icons.favorite : Icons.favorite_border,
              color: _followedOnly ? Colors.red : textSecondary,
            ),
            tooltip: _followedOnly ? 'Show all' : 'Show followed only',
            onPressed: () => setState(() => _followedOnly = !_followedOnly),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingSkeleton()
          : RefreshIndicator(
              onRefresh: _loadFeed,
              color: accent,
              child: _remotePosts.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      itemCount: _remotePosts.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _remotePosts.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(color: accent),
                            ),
                          );
                        }
                        return _RemoteFeedCard(
                          post: _remotePosts[index],
                          onLikeToggled: () => _loadFeed(),
                        )
                            .animate()
                            .fadeIn(delay: Duration(milliseconds: index * 50))
                            .slideY(begin: 0.1, end: 0);
                      },
                    ),
            ),
    );
  }

  /// Offline fallback using local Hive data.
  Widget _buildLocalFeed() {
    final socialService = ref.watch(dogSocialServiceProvider);
    final feed = socialService.getFeed(followedOnly: _followedOnly, limit: 50);

    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AppBar(
        title: const Text('Dog Feed'),
        backgroundColor: bgCard,
        actions: [
          IconButton(
            icon: Icon(
              _followedOnly ? Icons.favorite : Icons.favorite_border,
              color: _followedOnly ? Colors.red : textSecondary,
            ),
            tooltip: _followedOnly ? 'Show all' : 'Show followed only',
            onPressed: () => setState(() => _followedOnly = !_followedOnly),
          ),
        ],
      ),
      body: feed.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: feed.length,
              itemBuilder: (context, index) {
                return _LocalFeedCard(item: feed[index])
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: index * 50))
                    .slideY(begin: 0.1, end: 0);
              },
            ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 5,
      itemBuilder: (_, index) => Container(
        height: 120,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(12),
        ),
      )
          .animate(onPlay: (c) => c.repeat())
          .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.05)),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        Center(
          child: Column(
            children: [
              Icon(Icons.pets, size: 64, color: textSecondary.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text(
                _followedOnly
                    ? 'No activity from followed dogs yet'
                    : 'No dog activity yet',
                style: TextStyle(color: textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Start identifying dogs to see their activity here!',
                style: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Remote (Supabase) Feed Card ──────────────────────────────

class _RemoteFeedCard extends ConsumerWidget {
  final SocialPost post;
  final VoidCallback onLikeToggled;

  const _RemoteFeedCard({required this.post, required this.onLikeToggled});

  IconData _iconForType(String type) {
    switch (type) {
      case 'breed_discovered': return Icons.camera_alt;
      case 'achievement_unlocked': return Icons.emoji_events;
      case 'streak_milestone': return Icons.local_fire_department;
      case 'level_up': return Icons.arrow_upward;
      case 'rare_find': return Icons.star;
      case 'set_completed': return Icons.collections;
      case 'lost_dog_alert': return Icons.warning_amber;
      case 'lost_dog_found': return Icons.celebration;
      case 'friendship_formed': return Icons.favorite;
      case 'photo_shared': return Icons.photo;
      default: return Icons.pets;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'breed_discovered': return Colors.blue;
      case 'achievement_unlocked': return Colors.purple;
      case 'streak_milestone': return Colors.orange;
      case 'level_up': return Colors.amber;
      case 'rare_find': return Colors.amber.shade700;
      case 'set_completed': return Colors.green;
      case 'lost_dog_alert': return Colors.red;
      case 'lost_dog_found': return Colors.green;
      case 'friendship_formed': return Colors.pink;
      case 'photo_shared': return Colors.teal;
      default: return accent;
    }
  }

  String _timeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${timestamp.month}/${timestamp.day}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeColor = _colorForType(post.postType);

    return Card(
      color: bgCard,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_iconForType(post.postType), color: typeColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.displayName ?? post.username,
                        style: const TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (post.breedName != null)
                        Text(
                          post.breedName!,
                          style: TextStyle(color: textSecondary, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                Text(
                  _timeAgo(post.createdAt),
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
              ],
            ),
            // Content
            if (post.content != null && post.content!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                post.content!,
                style: const TextStyle(color: textPrimary, fontSize: 14),
              ),
            ],
            // Photo
            if (post.photoUrl != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: post.photoUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 180,
                    color: bgDeep,
                    child: const Center(child: CircularProgressIndicator(color: accent)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 100,
                    color: bgDeep,
                    child: Center(child: Icon(Icons.broken_image, color: textSecondary)),
                  ),
                ),
              ),
            ],
            // Like / Comment bar
            const SizedBox(height: 10),
            Row(
              children: [
                _LikeButton(
                  postId: post.id,
                  likeCount: post.likeCount,
                  isLiked: post.userHasLiked,
                  onToggled: onLikeToggled,
                ),
                const SizedBox(width: 16),
                Icon(Icons.comment_outlined, color: textSecondary, size: 18),
                const SizedBox(width: 4),
                Text(
                  '${post.commentCount}',
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LikeButton extends ConsumerStatefulWidget {
  final String postId;
  final int likeCount;
  final bool isLiked;
  final VoidCallback onToggled;

  const _LikeButton({
    required this.postId,
    required this.likeCount,
    required this.isLiked,
    required this.onToggled,
  });

  @override
  ConsumerState<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends ConsumerState<_LikeButton> {
  late bool _liked;
  late int _count;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _liked = widget.isLiked;
    _count = widget.likeCount;
  }

  Future<void> _toggle() async {
    if (_busy) return;
    final social = ref.read(supabaseSocialServiceProvider);
    if (social == null) return;

    setState(() {
      _busy = true;
      _liked = !_liked;
      _count += _liked ? 1 : -1;
    });

    try {
      await social.toggleLike(widget.postId);
    } catch (_) {
      // Revert on error
      if (mounted) {
        setState(() {
          _liked = !_liked;
          _count += _liked ? 1 : -1;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: Row(
        children: [
          Icon(
            _liked ? Icons.favorite : Icons.favorite_border,
            color: _liked ? Colors.red : textSecondary,
            size: 18,
          ),
          const SizedBox(width: 4),
          Text(
            '$_count',
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Local (Hive) Feed Card — offline fallback ────────────────

class _LocalFeedCard extends ConsumerWidget {
  final FeedItem item;
  const _LocalFeedCard({required this.item});

  IconData _iconForType(String type) {
    switch (type) {
      case 'sighting': return Icons.camera_alt;
      case 'new_friend': return Icons.favorite;
      case 'level_up': return Icons.arrow_upward;
      case 'achievement': return Icons.emoji_events;
      case 'photo': return Icons.photo;
      default: return Icons.pets;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'sighting': return Colors.blue;
      case 'new_friend': return Colors.pink;
      case 'level_up': return Colors.amber;
      case 'achievement': return Colors.purple;
      case 'photo': return Colors.green;
      default: return accent;
    }
  }

  String _timeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${timestamp.month}/${timestamp.day}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final socialService = ref.watch(dogSocialServiceProvider);
    final isFollowed = socialService.isFollowing(item.dogName);
    final typeColor = _colorForType(item.type);

    return Card(
      color: bgCard,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_iconForType(item.type), color: typeColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.dogName,
                        style: const TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(item.breed,
                        style: TextStyle(color: textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Text(_timeAgo(item.timestamp),
                  style: TextStyle(color: textSecondary, fontSize: 12)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (isFollowed) {
                      socialService.unfollow(item.dogName);
                    } else {
                      socialService.follow(item.dogName);
                    }
                    (context as Element).markNeedsBuild();
                  },
                  child: Icon(
                    isFollowed ? Icons.favorite : Icons.favorite_border,
                    color: isFollowed ? Colors.red : textSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(item.text, style: const TextStyle(color: textPrimary, fontSize: 14)),
            if (item.photoPath != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(item.photoPath!),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 100, color: bgDeep,
                    child: Center(child: Icon(Icons.broken_image, color: textSecondary)),
                  ),
                ),
              ),
            ],
            if (item.latitude != null && item.longitude != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, color: textSecondary, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${item.latitude!.toStringAsFixed(3)}, ${item.longitude!.toStringAsFixed(3)}',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
