import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dogquest/constants.dart';

/// Social hub — single entry point for all community features.
/// Reached from the "Community" chip on the Profile screen.
class SocialHubScreen extends StatelessWidget {
  const SocialHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AppBar(
        backgroundColor: bgNav,
        title: const Text(
          'Community',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: BackButton(
          color: Colors.white70,
          onPressed: () => context.pop(),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SocialTile(
            icon: Icons.dynamic_feed_rounded,
            color: const Color(0xFFD4874E),
            title: 'Dog Feed',
            subtitle: 'See what dogs the community has been spotting',
            onTap: () => context.push('/feed'),
          ),
          const SizedBox(height: 12),
          _SocialTile(
            icon: Icons.explore_rounded,
            color: const Color(0xFF2196F3),
            title: 'Dogs Nearby',
            subtitle: 'Discover dog owners and breeds in your area',
            onTap: () => context.push('/dogs-nearby'),
          ),
          const SizedBox(height: 12),
          _SocialTile(
            icon: Icons.leaderboard_rounded,
            color: Colors.amber,
            title: 'Leaderboard',
            subtitle: 'See who\'s leading the pack this week',
            onTap: () => context.push('/leaderboard'),
          ),
          const SizedBox(height: 12),
          _SocialTile(
            icon: Icons.people_rounded,
            color: const Color(0xFF7C4DFF),
            title: 'Friends',
            subtitle: 'Follow dog lovers and share your discoveries',
            onTap: () => context.push('/friends'),
          ),
        ],
      ),
    );
  }
}

class _SocialTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SocialTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white24,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
