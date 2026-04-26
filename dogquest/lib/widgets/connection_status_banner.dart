import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dogquest/services/supabase_connection_service.dart';

/// A slim banner that slides in at the top when the device is offline.
/// Shows "Offline — local mode" and auto-hides when reconnected.
class ConnectionStatusBanner extends ConsumerWidget {
  const ConnectionStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(connectionStatusProvider);

    return statusAsync.when(
      data: (status) => _buildBanner(status),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => _buildBanner(ConnectionStatus.disconnected),
    );
  }

  Widget _buildBanner(ConnectionStatus status) {
    if (status != ConnectionStatus.disconnected) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      color: Colors.orange.shade800,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 14, color: Colors.white),
          SizedBox(width: 8),
          Text(
            'Offline — local mode',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    )
        .animate()
        .slideY(begin: -1, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
}
