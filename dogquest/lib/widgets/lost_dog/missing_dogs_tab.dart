import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../constants.dart';
import '../../models/lost_dog_report.dart';
import '../../services/lost_dog_service.dart';
import '../../services/supabase_lost_dog_service.dart';
import 'lost_dog_report_card.dart';
import 'remote_lost_dog_card.dart';

final _log = Logger('MissingDogsTab');

class MissingDogsTab extends ConsumerStatefulWidget {
  final LostDogService lostDogSvc;
  final VoidCallback onChanged;

  const MissingDogsTab({
    required this.lostDogSvc,
    required this.onChanged,
  });

  @override
  ConsumerState<MissingDogsTab> createState() => _MissingDogsTabState();
}

class _MissingDogsTabState extends ConsumerState<MissingDogsTab> {
  List<LostDogReportRemote> _remoteReports = [];
  bool _loadingRemote = false;

  /// IDs of local reports that have a matching remote counterpart (by name+breed).
  final Set<String> _localIdsWithRemote = {};

  @override
  void initState() {
    super.initState();
    unawaited(_fetchRemoteReports()); // sec-C1: explicit fire-and-forget
  }

  Future<void> _fetchRemoteReports() async {
    final remoteSvc = ref.read(supabaseLostDogServiceProvider);
    if (remoteSvc == null) return;

    setState(() => _loadingRemote = true);
    try {
      final reports = await remoteSvc.getMyReports();
      if (!mounted) return; // sec-C1
      // Deduplicate: mark local reports that match a remote report by dogName.
      final localReports = widget.lostDogSvc.activeReports;
      final remoteNames = reports
          .where((r) => r.isActive)
          .map((r) => r.dogName.toLowerCase())
          .toSet();
      _localIdsWithRemote.clear();
      for (final local in localReports) {
        if (remoteNames.contains(local.dogName.toLowerCase())) {
          _localIdsWithRemote.add(local.id);
        }
      }
      setState(() {
        _remoteReports = reports;
        _loadingRemote = false;
      });
    } catch (e, st) {
      // sec-C3: don't swallow remote-fetch failures.
      _log.warning('Failed to fetch remote lost-dog reports', e, st);
      unawaited(
        FirebaseCrashlytics.instance.recordError(
          e,
          st,
          reason: 'missing_dogs_tab._fetchRemoteReports',
          fatal: false,
        ),
      );
      if (!mounted) return;
      setState(() => _loadingRemote = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localReports = widget.lostDogSvc.activeReports;
    // Remote-only reports: active remote reports whose name does NOT match a local report.
    final localNames = localReports.map((r) => r.dogName.toLowerCase()).toSet();
    final remoteOnly = _remoteReports
        .where(
            (r) => r.isActive && !localNames.contains(r.dogName.toLowerCase()))
        .toList();

    final totalCount = localReports.length + remoteOnly.length;

    if (totalCount == 0 && !_loadingRemote) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: totalCount + 1 + (_loadingRemote ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildNetworkHeader(totalCount);
        }
        if (_loadingRemote && index == 1) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.amber.shade300,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Syncing cloud reports...',
                  style: TextStyle(color: Colors.amber.shade300, fontSize: 12),
                ),
              ],
            ),
          );
        }
        final adjustedIndex = index - 1 - (_loadingRemote ? 1 : 0);

        // Local reports first, then remote-only.
        if (adjustedIndex < localReports.length) {
          final report = localReports[adjustedIndex];
          return LostDogReportCard(
            report: report,
            lostDogSvc: widget.lostDogSvc,
            onChanged: widget.onChanged,
            hasCloudSync: _localIdsWithRemote.contains(report.id),
          );
        }
        final remoteIndex = adjustedIndex - localReports.length;
        if (remoteIndex < remoteOnly.length) {
          return RemoteLostDogCard(report: remoteOnly[remoteIndex]);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildNetworkHeader(int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.red.withValues(alpha: 0.12),
          Colors.orange.withValues(alpha: 0.06),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.warning_amber_rounded,
                  color: Colors.redAccent, size: 24),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count dog${count == 1 ? '' : 's'} currently missing',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Help reunite them with their families',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Icon(Icons.pets, color: Colors.amber, size: 48),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Missing Dogs',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'All dogs are safe and accounted for.\nIf your dog goes missing, tap the button\nbelow to alert the network.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ).animate().fadeIn().slideY(begin: 0.1),
      ),
    );
  }
}
