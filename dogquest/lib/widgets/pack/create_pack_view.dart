import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dogquest/services/supabase_pack_service.dart';

class CreatePackView extends ConsumerWidget {
  final VoidCallback onCreatePack;
  final VoidCallback onJoinPack;

  const CreatePackView({
    required this.onCreatePack,
    required this.onJoinPack,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasRemote = ref.read(supabasePackServiceProvider) != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('\u{1F43E}', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 20),
            const Text(
              'Start Your Pack',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a family pack to share your dogs, track combined stats, and see weekly reports together.',
              style:
                  TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onCreatePack,
              icon: const Icon(Icons.group_add),
              label: const Text('Create Pack'),
            ),
            const SizedBox(height: 16),
            // Join existing pack option (remote only)
            if (hasRemote)
              OutlinedButton.icon(
                onPressed: onJoinPack,
                icon: const Icon(Icons.vpn_key, size: 18),
                label: const Text('Join with Invite Code'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amber,
                  side: BorderSide(color: Colors.amber.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ).animate().fadeIn().slideY(begin: 0.1),
      ),
    );
  }
}
