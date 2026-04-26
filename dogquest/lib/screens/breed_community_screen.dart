import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dogquest/constants.dart';
import 'package:dogquest/services/dog_service.dart';
import 'package:dogquest/services/sighting_service.dart';
import 'package:dogquest/services/kennel_service.dart';

/// Community page for a specific breed — stats, sightings, breed info,
/// and Supabase-backed community membership + posts.
class BreedCommunityScreen extends ConsumerStatefulWidget {
  final String breedName;
  const BreedCommunityScreen({super.key, required this.breedName});

  @override
  ConsumerState<BreedCommunityScreen> createState() =>
      _BreedCommunityScreenState();
}

class _BreedCommunityScreenState extends ConsumerState<BreedCommunityScreen> {
  bool _isMember = false;
  int _memberCount = 0;
  int _postCount = 0;
  List<Map<String, dynamic>> _communityPosts = [];
  bool _loadingCommunity = true;
  final _postController = TextEditingController();

  SupabaseClient? get _client {
    final session = Supabase.instance.client.auth.currentSession;
    return session != null ? Supabase.instance.client : null;
  }

  @override
  void initState() {
    super.initState();
    _loadCommunityData();
  }

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  Future<void> _loadCommunityData() async {
    final client = _client;
    if (client == null) {
      setState(() => _loadingCommunity = false);
      return;
    }

    try {
      // Ensure breed community row exists (upsert)
      await client.from('breed_communities').upsert(
        {'breed_name': widget.breedName},
        onConflict: 'breed_name',
      );

      // Check membership
      final uid = client.auth.currentUser!.id;
      final membership = await client
          .from('breed_community_memberships')
          .select('id')
          .eq('breed_name', widget.breedName)
          .eq('user_id', uid)
          .maybeSingle();

      // Get counts
      final members = await client
          .from('breed_community_memberships')
          .select('id')
          .eq('breed_name', widget.breedName);

      // Get posts with user info
      final posts = await client
          .from('breed_community_posts')
          .select('*, users!inner(username, display_name)')
          .eq('breed_name', widget.breedName)
          .order('created_at', ascending: false)
          .limit(20);

      if (mounted) {
        setState(() {
          _isMember = membership != null;
          _memberCount = (members as List).length;
          _communityPosts = (posts as List).cast<Map<String, dynamic>>();
          _postCount = _communityPosts.length;
          _loadingCommunity = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCommunity = false);
    }
  }

  Future<void> _toggleMembership() async {
    final client = _client;
    if (client == null) return;
    final uid = client.auth.currentUser!.id;

    if (_isMember) {
      await client
          .from('breed_community_memberships')
          .delete()
          .eq('breed_name', widget.breedName)
          .eq('user_id', uid);
      setState(() {
        _isMember = false;
        _memberCount--;
      });
    } else {
      await client.from('breed_community_memberships').insert({
        'breed_name': widget.breedName,
        'user_id': uid,
      });
      setState(() {
        _isMember = true;
        _memberCount++;
      });
    }
  }

  Future<void> _submitPost() async {
    final text = _postController.text.trim();
    if (text.isEmpty) return;
    final client = _client;
    if (client == null) return;

    await client.from('breed_community_posts').insert({
      'breed_name': widget.breedName,
      'user_id': client.auth.currentUser!.id,
      'content': text,
    });
    _postController.clear();
    FocusScope.of(context).unfocus();
    await _loadCommunityData();
  }

  @override
  Widget build(BuildContext context) {
    final dogSvc = ref.watch(dogServiceProvider);
    final sightingSvc = ref.watch(sightingServiceProvider);
    final kennelSvc = ref.watch(kennelServiceProvider);

    final dog = dogSvc.lookupByCommonName(widget.breedName);
    if (dog == null) {
      return Scaffold(
        backgroundColor: bgDeep,
        appBar: AppBar(title: Text(widget.breedName), backgroundColor: bgCard),
        body: const Center(
          child: Text(
            'Breed not found',
            style: TextStyle(color: textSecondary),
          ),
        ),
      );
    }

    final sightings = sightingSvc.forDog(widget.breedName);
    final isOwned = kennelSvc.contains(widget.breedName);
    final totalSightings = sightings.length;
    final firstSeen = sightings.isNotEmpty ? sightings.last.timestamp : null;
    final lastSeen = sightings.isNotEmpty ? sightings.first.timestamp : null;
    final isOnline = _client != null;

    return Scaffold(
      backgroundColor: bgDeep,
      body: CustomScrollView(
        slivers: [
          // Hero header with breed image
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: bgCard,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                dog.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (dog.imageUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: dog.imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: bgCard),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          bgDeep.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status badges
                  Wrap(
                    spacing: 8,
                    children: [
                      _Badge(
                        label: dog.rarity.label,
                        color: dog.rarity.color,
                      ),
                      if (isOwned)
                        const _Badge(label: 'IN KENNEL', color: Colors.green),
                      _Badge(
                        label: dog.sizeCategory.toUpperCase(),
                        color: Colors.blueGrey,
                      ),
                    ],
                  ).animate().fadeIn(),

                  const SizedBox(height: 20),

                  // Community membership section (Supabase)
                  if (isOnline) ...[
                    const _SectionHeader(title: 'Breed Community'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _StatTile(
                          value: '$_memberCount',
                          label: 'Members',
                          icon: Icons.group,
                        ),
                        const SizedBox(width: 10),
                        _StatTile(
                          value: '$_postCount',
                          label: 'Posts',
                          icon: Icons.forum,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: _toggleMembership,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _isMember
                                    ? accent.withValues(alpha: 0.15)
                                    : bgCard,
                                borderRadius: BorderRadius.circular(10),
                                border: _isMember
                                    ? Border.all(
                                        color: accent.withValues(alpha: 0.5),
                                      )
                                    : null,
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    _isMember
                                        ? Icons.check_circle
                                        : Icons.add_circle_outline,
                                    color: _isMember ? accent : textSecondary,
                                    size: 20,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _isMember ? 'Joined' : 'Join',
                                    style: TextStyle(
                                      color: _isMember ? accent : textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 50.ms),
                    const SizedBox(height: 20),
                  ],

                  // Community Stats
                  const _SectionHeader(title: 'Your Stats'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _StatTile(
                        value: '$totalSightings',
                        label: 'Sightings',
                        icon: Icons.visibility,
                      ),
                      const SizedBox(width: 10),
                      _StatTile(
                        value: '${dog.xp}',
                        label: 'XP Value',
                        icon: Icons.star,
                      ),
                      const SizedBox(width: 10),
                      _StatTile(
                        value: dog.lifespan.isNotEmpty ? dog.lifespan : '?',
                        label: 'Lifespan',
                        icon: Icons.favorite,
                      ),
                    ],
                  ).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: 20),

                  // Community posts (Supabase)
                  if (isOnline && _isMember) ...[
                    const _SectionHeader(title: 'Community Posts'),
                    const SizedBox(height: 10),
                    // Post composer
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _postController,
                            style: const TextStyle(
                              color: textPrimary,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Share with the community...',
                              hintStyle: TextStyle(
                                color: textSecondary.withValues(alpha: 0.5),
                              ),
                              filled: true,
                              fillColor: bgCard,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _submitPost,
                          icon: const Icon(Icons.send, color: accent),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_loadingCommunity)
                      const Center(
                        child: CircularProgressIndicator(color: accent),
                      )
                    else if (_communityPosts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'No posts yet — be the first!',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    else
                      ..._communityPosts
                          .take(10)
                          .map((p) => _CommunityPostCard(post: p)),
                    const SizedBox(height: 20),
                  ],

                  // Breed Info
                  const _SectionHeader(title: 'About'),
                  const SizedBox(height: 10),
                  Text(
                    dog.lore,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 16),

                  // Traits
                  if (dog.temperamentTraits.isNotEmpty) ...[
                    const _SectionHeader(title: 'Temperament'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: dog.temperamentTraits
                          .map(
                            (t) => Chip(
                              label: Text(
                                t,
                                style: const TextStyle(
                                  color: textPrimary,
                                  fontSize: 12,
                                ),
                              ),
                              backgroundColor: bgCard,
                              side: BorderSide(
                                color: accent.withValues(alpha: 0.3),
                              ),
                            ),
                          )
                          .toList(),
                    ).animate().fadeIn(delay: 300.ms),
                    const SizedBox(height: 16),
                  ],

                  // Care Info
                  const _SectionHeader(title: 'Care Guide'),
                  const SizedBox(height: 10),
                  _CareRow(
                    icon: Icons.fitness_center,
                    label: 'Exercise',
                    value: dog.exerciseNeeds,
                  ),
                  _CareRow(
                    icon: Icons.cut,
                    label: 'Grooming',
                    value: dog.groomingNeeds,
                  ),
                  _CareRow(
                    icon: Icons.scale,
                    label: 'Weight',
                    value: dog.weight.isNotEmpty ? dog.weight : 'Unknown',
                  ),
                  if (dog.dietNotes.isNotEmpty)
                    _CareRow(
                      icon: Icons.restaurant,
                      label: 'Diet',
                      value: dog.dietNotes,
                    ),

                  const SizedBox(height: 20),

                  // Recent Sightings Timeline
                  if (sightings.isNotEmpty) ...[
                    const _SectionHeader(title: 'Sighting History'),
                    const SizedBox(height: 10),
                    if (firstSeen != null)
                      Text(
                        'First seen: ${_formatDate(firstSeen)}',
                        style:
                            const TextStyle(color: textSecondary, fontSize: 13),
                      ),
                    if (lastSeen != null)
                      Text(
                        'Last seen: ${_formatDate(lastSeen)}',
                        style:
                            const TextStyle(color: textSecondary, fontSize: 13),
                      ),
                    const SizedBox(height: 10),
                    ...sightings
                        .take(10)
                        .map((s) => _SightingTile(sighting: s)),
                  ],

                  // Health predispositions
                  if (dog.healthPredispositions.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const _SectionHeader(title: 'Health Notes'),
                    const SizedBox(height: 10),
                    ...dog.healthPredispositions.map(
                      (h) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                h,
                                style: const TextStyle(
                                  color: textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.month}/${d.day}/${d.year}';
}

/// A community post card showing user, content, and timestamp.
class _CommunityPostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  const _CommunityPostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final user = post['users'] as Map<String, dynamic>?;
    final username = user?['display_name'] ?? user?['username'] ?? 'Unknown';
    final content = post['content'] as String? ?? '';
    final createdAt = DateTime.tryParse(post['created_at'] as String? ?? '');
    final timeStr = createdAt != null ? _timeAgo(createdAt) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  username,
                  style: const TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                timeStr,
                style: const TextStyle(color: textSecondary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(color: textPrimary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${timestamp.month}/${timestamp.day}';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: accent,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: accent, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(label,
                style: const TextStyle(color: textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _CareRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _CareRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textSecondary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(color: textSecondary, fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: textPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _SightingTile extends StatelessWidget {
  final Sighting sighting;
  const _SightingTile({required this.sighting});

  @override
  Widget build(BuildContext context) {
    final hasGps = sighting.latitude != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration:
                const BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${sighting.timestamp.month}/${sighting.timestamp.day} at ${sighting.timestamp.hour}:${sighting.timestamp.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(color: textPrimary, fontSize: 13),
            ),
          ),
          Text(
            '${(sighting.confidence * 100).toStringAsFixed(0)}%',
            style: const TextStyle(color: textSecondary, fontSize: 12),
          ),
          if (hasGps) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.location_on,
              size: 14,
              color: Colors.green.withValues(alpha: 0.6),
            ),
          ],
        ],
      ),
    );
  }
}
