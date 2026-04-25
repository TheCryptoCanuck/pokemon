import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';

import '../../constants.dart';
import '../../services/supabase_pack_service.dart';

class RemotePackHeader extends StatelessWidget {
  final PackRemote pack;

  const RemotePackHeader({required this.pack, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.amber.withValues(alpha: 0.12),
          Colors.orange.withValues(alpha: 0.06),
        ]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Text('\u{1F43E}', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          Text(pack.name,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textPrimary)),
          const SizedBox(height: 4),
          Text('${pack.memberCount} member${pack.memberCount == 1 ? '' : 's'}',
              style: const TextStyle(color: textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          // Invite code
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.vpn_key, color: Colors.amber, size: 16),
                const SizedBox(width: 10),
                Text(pack.inviteCode,
                    style: const TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: 3,
                      fontFamily: 'monospace',
                    )),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: pack.inviteCode));
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: bgCard,
                        duration: Duration(seconds: 2),
                        content: Text('Invite code copied!',
                            style: TextStyle(color: Colors.amber)),
                      ),
                    );
                  },
                  child:
                      const Icon(Icons.copy, color: Colors.white54, size: 18),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Share.share(
                      'Join my pack "${pack.name}" on DogQuest! Use invite code: ${pack.inviteCode}',
                    );
                  },
                  child:
                      const Icon(Icons.share, color: Colors.white54, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}
