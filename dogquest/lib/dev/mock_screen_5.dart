import 'package:flutter/material.dart';

import 'package:dogquest/constants.dart';
import 'package:dogquest/widgets/network_dog_image.dart';

/// **Mock screen for Play Store screenshot #5 (branded share UI with friends).**
///
/// The shipping app uses the OS-native share sheet (`share_plus`), which is
/// generic and doesn't communicate Hound's social positioning. This widget
/// composites a Hound-branded share modal with friend avatars and social
/// icons — the version we want store visitors to see, not the OS one.
///
/// Reachable from `Settings -> Developer -> Mock screen 5` in debug builds.
/// Capture via `adb shell screencap` (see `scripts/capture_screenshots.ps1`).
class MockScreen5 extends StatelessWidget {
  const MockScreen5({super.key});

  static const _photoUrl =
      'https://commons.wikimedia.org/w/thumb.php?f=Golden_Retriever_Carlos_%2810581910556%29.jpg&w=800';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDeep,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // ── Header ──
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () {},
                  ),
                  const Expanded(
                    child: Text(
                      'Share your discovery',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 16),

              // ── Breed share card preview ──
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.15),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    height: 260,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        NetworkDogImage(
                          url: _photoUrl,
                          height: 260,
                          fit: BoxFit.cover,
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x00000000),
                                Color(0xCC000000),
                              ],
                              stops: [0.4, 1.0],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 18,
                          right: 18,
                          bottom: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _badge('LEVEL 4', accent),
                                  const SizedBox(width: 6),
                                  _badge('COMMON', Colors.white70),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Golden Retriever',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Text(
                                'Spotted by @jesse on Hound',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // ── Send to a friend ──
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Send to a friend',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 80,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: const [
                    _FriendAvatar(initials: 'AM', name: 'Alex', color: accent),
                    _FriendAvatar(
                        initials: 'JR', name: 'Jordan', color: accentGreen),
                    _FriendAvatar(
                        initials: 'SK', name: 'Sam', color: Colors.deepPurple),
                    _FriendAvatar(
                        initials: 'EL', name: 'Elena', color: Colors.teal),
                    _FriendAvatar(
                        initials: 'TW', name: 'Tom', color: Colors.indigo),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ── Share to apps ──
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Share to',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  _SocialButton(
                      icon: Icons.message_rounded,
                      label: 'Messages',
                      color: Color(0xFF34B7F1)),
                  _SocialButton(
                      icon: Icons.camera_alt_rounded,
                      label: 'Instagram',
                      color: Color(0xFFE1306C)),
                  _SocialButton(
                      icon: Icons.chat_bubble_rounded,
                      label: 'WhatsApp',
                      color: Color(0xFF25D366)),
                  _SocialButton(
                      icon: Icons.send_rounded,
                      label: 'Twitter',
                      color: Color(0xFF1DA1F2)),
                  _SocialButton(
                      icon: Icons.more_horiz_rounded,
                      label: 'More',
                      color: Colors.white54),
                ],
              ),
              const Spacer(),

              // ── Copy link button ──
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Copy link'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _FriendAvatar extends StatelessWidget {
  final String initials;
  final String name;
  final Color color;

  const _FriendAvatar({
    required this.initials,
    required this.name,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      margin: const EdgeInsets.only(right: 10),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.22),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.6), width: 2),
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
