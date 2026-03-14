import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import '../services/dog_social_service.dart';

class DogFeedScreen extends ConsumerStatefulWidget {
  const DogFeedScreen({super.key});

  @override
  ConsumerState<DogFeedScreen> createState() => _DogFeedScreenState();
}

class _DogFeedScreenState extends ConsumerState<DogFeedScreen> {
  bool _followedOnly = false;

  @override
  Widget build(BuildContext context) {
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
                return _FeedCard(item: feed[index])
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: index * 50))
                    .slideY(begin: 0.1, end: 0);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
    );
  }
}

class _FeedCard extends ConsumerWidget {
  final FeedItem item;
  const _FeedCard({required this.item});

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
            // Header: dog name + type icon + time + follow button
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
                      Text(
                        item.dogName,
                        style: const TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        item.breed,
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  _timeAgo(item.timestamp),
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (isFollowed) {
                      socialService.unfollow(item.dogName);
                    } else {
                      socialService.follow(item.dogName);
                    }
                    // Force rebuild
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
            // Activity text
            Text(
              item.text,
              style: const TextStyle(color: textPrimary, fontSize: 14),
            ),
            // Photo if available
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
                    height: 100,
                    color: bgDeep,
                    child: Center(
                      child: Icon(Icons.broken_image, color: textSecondary),
                    ),
                  ),
                ),
              ),
            ],
            // Location if available
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
