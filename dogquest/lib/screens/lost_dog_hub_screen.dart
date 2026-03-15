import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../constants.dart';
import '../models/lost_dog_report.dart';
import '../services/lost_dog_service.dart';
import '../services/supabase_lost_dog_service.dart';

class LostDogHubScreen extends ConsumerStatefulWidget {
  const LostDogHubScreen({super.key});

  @override
  ConsumerState<LostDogHubScreen> createState() => _LostDogHubScreenState();
}

class _LostDogHubScreenState extends ConsumerState<LostDogHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lostDogSvc = ref.read(lostDogServiceProvider);
    final activeCount = lostDogSvc.activeLostCount;

    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AppBar(
        backgroundColor: bgDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.radar, color: Colors.amber.shade300, size: 22),
            const SizedBox(width: 8),
            const Text(
              'Lost Dog Network',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          indicatorWeight: 3,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Missing Dogs'),
                  if (activeCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$activeCount',
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
            ),
            const Tab(text: 'Help Find'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MissingDogsTab(
            lostDogSvc: lostDogSvc,
            onChanged: () => setState(() {}),
          ),
          _HelpFindTab(lostDogSvc: lostDogSvc),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/lost-dog/report'),
        backgroundColor: Colors.amber.shade700,
        icon: const Icon(Icons.pets, color: Colors.black87),
        label: const Text(
          'Report Lost Dog',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ─── Missing Dogs Tab ─────────────────────────────────────────────────────────

class _MissingDogsTab extends ConsumerStatefulWidget {
  final LostDogService lostDogSvc;
  final VoidCallback onChanged;

  const _MissingDogsTab({required this.lostDogSvc, required this.onChanged});

  @override
  ConsumerState<_MissingDogsTab> createState() => _MissingDogsTabState();
}

class _MissingDogsTabState extends ConsumerState<_MissingDogsTab> {
  List<LostDogReportRemote> _remoteReports = [];
  bool _loadingRemote = false;
  /// IDs of local reports that have a matching remote counterpart (by name+breed).
  final Set<String> _localIdsWithRemote = {};

  @override
  void initState() {
    super.initState();
    _fetchRemoteReports();
  }

  Future<void> _fetchRemoteReports() async {
    final remoteSvc = ref.read(supabaseLostDogServiceProvider);
    if (remoteSvc == null) return;

    setState(() => _loadingRemote = true);
    try {
      final reports = await remoteSvc.getMyReports();
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
    } catch (_) {
      setState(() => _loadingRemote = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localReports = widget.lostDogSvc.activeReports;
    // Remote-only reports: active remote reports whose name does NOT match a local report.
    final localNames =
        localReports.map((r) => r.dogName.toLowerCase()).toSet();
    final remoteOnly = _remoteReports
        .where((r) => r.isActive && !localNames.contains(r.dogName.toLowerCase()))
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
        final adjustedIndex =
            index - 1 - (_loadingRemote ? 1 : 0);

        // Local reports first, then remote-only.
        if (adjustedIndex < localReports.length) {
          final report = localReports[adjustedIndex];
          return _LostDogReportCard(
            report: report,
            lostDogSvc: widget.lostDogSvc,
            onChanged: widget.onChanged,
            hasCloudSync: _localIdsWithRemote.contains(report.id),
          );
        }
        final remoteIndex = adjustedIndex - localReports.length;
        if (remoteIndex < remoteOnly.length) {
          return _RemoteLostDogCard(report: remoteOnly[remoteIndex]);
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

// ─── Lost Dog Report Card ─────────────────────────────────────────────────────

class _LostDogReportCard extends StatelessWidget {
  final LostDogReport report;
  final LostDogService lostDogSvc;
  final VoidCallback onChanged;
  final bool hasCloudSync;

  const _LostDogReportCard({
    required this.report,
    required this.lostDogSvc,
    required this.onChanged,
    this.hasCloudSync = false,
  });

  String _daysSince(DateTime date) {
    final diff = DateTime.now().difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return '1 day ago';
    return '$diff days ago';
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = report.photoPath != null &&
        report.photoPath!.isNotEmpty &&
        File(report.photoPath!).existsSync();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: report.status == LostDogStatus.found
              ? null
              : () => _showReportOptions(context),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: report.status == LostDogStatus.found
                ? Row(
                    children: [
                      // Greyed-out placeholder for reunited dogs
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: Container(
                            color: Colors.green.withValues(alpha: 0.08),
                            child: const Center(
                              child: Icon(Icons.pets, color: Colors.green, size: 30),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Reunited',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                _buildStatusBadge(),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'This dog has been safely returned to their owner.',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      // Dog photo or placeholder
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: hasPhoto
                              ? Image.file(
                                  File(report.photoPath!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _photoPlaceholder(),
                                )
                              : _photoPlaceholder(),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    report.dogName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (hasCloudSync)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Tooltip(
                                      message: 'Synced to cloud',
                                      child: Icon(Icons.cloud_done,
                                          color: Colors.blue.shade300, size: 16),
                                    ),
                                  ),
                                _buildStatusBadge(),
                              ],
                            ),
                            if (report.breed != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                report.breed!,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.schedule,
                                    color: Colors.red.shade300, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'Missing since ${_formatDate(report.lostDate)}',
                                  style: TextStyle(
                                    color: Colors.red.shade300,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _daysSince(report.lostDate),
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                            if (report.lastSeenLocation != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on,
                                      color: Colors.white38, size: 13),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      report.lastSeenLocation!,
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
                    ],
                  ),
          ),
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.03);
  }

  Widget _photoPlaceholder() {
    return Container(
      color: Colors.amber.withValues(alpha: 0.08),
      child: const Center(
        child: Icon(Icons.pets, color: Colors.amber, size: 30),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color badgeColor;
    Color textColor;
    String label;

    switch (report.status) {
      case LostDogStatus.active:
        badgeColor = Colors.red;
        textColor = Colors.red.shade300;
        label = 'Missing';
        break;
      case LostDogStatus.found:
        badgeColor = Colors.green;
        textColor = Colors.green.shade300;
        label = 'Reunited';
        break;
      case LostDogStatus.cancelled:
        badgeColor = Colors.grey;
        textColor = Colors.grey.shade300;
        label = 'Cancelled';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showReportOptions(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final hasPhoto = report.photoPath != null &&
            report.photoPath!.isNotEmpty &&
            File(report.photoPath!).existsSync();
        final daysAgo = DateTime.now().difference(report.lostDate).inDays;

        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) => Container(
            decoration: const BoxDecoration(
              color: bgCard,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Photo ──
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 220,
                    width: double.infinity,
                    child: hasPhoto
                        ? Image.file(
                            File(report.photoPath!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _detailPhotoPlaceholder(),
                          )
                        : _detailPhotoPlaceholder(),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Name + status ──
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        report.dogName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    _buildStatusBadge(),
                  ],
                ),
                if (report.breed != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    report.breed!,
                    style: const TextStyle(color: Colors.white54, fontSize: 15),
                  ),
                ],
                const SizedBox(height: 20),

                // ── Info grid ──
                _detailRow(Icons.schedule, Colors.red.shade300,
                    'Missing Since', '${_formatDate(report.lostDate)} ($daysAgo day${daysAgo == 1 ? '' : 's'} ago)'),
                if (report.lastSeenLocation != null)
                  _detailRow(Icons.location_on, Colors.amber,
                      'Last Seen', report.lastSeenLocation!),
                if (report.lastSeenLat != null && report.lastSeenLon != null)
                  _detailRow(Icons.map_outlined, Colors.blue.shade300,
                      'GPS', '${report.lastSeenLat!.toStringAsFixed(4)}, ${report.lastSeenLon!.toStringAsFixed(4)}'),
                _detailRow(Icons.calendar_today, Colors.white38,
                    'Reported', _formatDate(report.createdAt)),

                // ── Owner contact ──
                if (report.ownerContact != null && report.ownerContact!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.phone, color: Colors.amber.shade300, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Owner Contact',
                                  style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(
                                report.ownerContact!,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Notes ──
                if (report.notes != null && report.notes!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Description & Notes',
                            style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(
                          report.notes!,
                          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ── Actions ──
                // Share poster
                _BottomSheetAction(
                  icon: Icons.share,
                  iconColor: Colors.amber,
                  label: 'Share Lost Dog Poster',
                  subtitle: 'Create a shareable poster to spread the word',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/lost-dog/share', extra: report);
                  },
                ),
                const SizedBox(height: 8),
                // View on map
                _BottomSheetAction(
                  icon: Icons.map,
                  iconColor: Colors.blue.shade300,
                  label: 'View on Map',
                  subtitle: 'See last known location on the network map',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/lost-dog/map');
                  },
                ),
                const SizedBox(height: 8),
                // Mark as Found
                _BottomSheetAction(
                  icon: Icons.celebration,
                  iconColor: Colors.green,
                  label: 'Mark as Found',
                  subtitle: 'Great news! This dog has been reunited.',
                  onTap: () {
                    lostDogSvc.markFound(report.id);
                    Navigator.pop(ctx);
                    onChanged();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: bgCard,
                        content: Text(
                          '${report.dogName} has been reunited!',
                          style: const TextStyle(color: Colors.green),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Cancel Report
                _BottomSheetAction(
                  icon: Icons.cancel_outlined,
                  iconColor: Colors.red.shade300,
                  label: 'Cancel Report',
                  subtitle: 'Remove this report from the active list.',
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmCancel(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailPhotoPlaceholder() {
    return Container(
      color: Colors.amber.withValues(alpha: 0.08),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets, color: Colors.amber.withValues(alpha: 0.4), size: 64),
            const SizedBox(height: 8),
            Text('No photo available',
                style: TextStyle(color: Colors.amber.withValues(alpha: 0.4), fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, Color iconColor, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Report?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove the lost report for ${report.dogName}? This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              lostDogSvc.cancelReport(report.id);
              Navigator.pop(ctx);
              onChanged();
            },
            child: const Text('Cancel Report',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom Sheet Action Row ──────────────────────────────────────────────────

class _BottomSheetAction extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _BottomSheetAction({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Icon(icon, color: iconColor, size: 22)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Remote-Only Lost Dog Card (cloud badge) ─────────────────────────────────

class _RemoteLostDogCard extends StatelessWidget {
  final LostDogReportRemote report;

  const _RemoteLostDogCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final daysAgo = DateTime.now().difference(report.lastSeenAt).inDays;
    final timeLabel = daysAgo == 0
        ? 'Today'
        : daysAgo == 1
            ? '1 day ago'
            : '$daysAgo days ago';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Cloud photo placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 72,
                child: report.photoUrl != null
                    ? Image.network(
                        report.photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.blue.withValues(alpha: 0.08),
                          child: const Center(
                            child: Icon(Icons.cloud, color: Colors.blue, size: 30),
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.blue.withValues(alpha: 0.08),
                        child: const Center(
                          child: Icon(Icons.cloud, color: Colors.blue, size: 30),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          report.dogName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Cloud-only badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.blue.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud,
                                color: Colors.blue.shade300, size: 11),
                            const SizedBox(width: 3),
                            Text(
                              'Cloud',
                              style: TextStyle(
                                color: Colors.blue.shade300,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (report.breed.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      report.breed,
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.schedule, color: Colors.red.shade300, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Missing $timeLabel',
                        style: TextStyle(color: Colors.red.shade300, fontSize: 12),
                      ),
                    ],
                  ),
                  if (report.distanceMiles != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.near_me,
                            color: Colors.white38, size: 13),
                        const SizedBox(width: 3),
                        Text(
                          '${report.distanceMiles!.toStringAsFixed(1)} mi away',
                          style:
                              const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.03);
  }
}

// ─── Help Find Tab ────────────────────────────────────────────────────────────

class _HelpFindTab extends ConsumerStatefulWidget {
  final LostDogService lostDogSvc;

  const _HelpFindTab({required this.lostDogSvc});

  @override
  ConsumerState<_HelpFindTab> createState() => _HelpFindTabState();
}

class _HelpFindTabState extends ConsumerState<_HelpFindTab> {
  List<LostDogReportRemote> _nearbyReports = [];
  bool _loadingNearby = false;
  String? _nearbyError;

  @override
  void initState() {
    super.initState();
    _fetchNearby();
  }

  Future<void> _fetchNearby() async {
    final remoteSvc = ref.read(supabaseLostDogServiceProvider);
    if (remoteSvc == null) return;

    setState(() {
      _loadingNearby = true;
      _nearbyError = null;
    });

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final reports = await remoteSvc.getActiveNearby(
        position.latitude,
        position.longitude,
        radiusMiles: 25.0,
      );
      setState(() {
        _nearbyReports = reports;
        _loadingNearby = false;
      });
    } catch (e) {
      setState(() {
        _loadingNearby = false;
        _nearbyError = 'Could not fetch nearby reports';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final missingCount = widget.lostDogSvc.activeLostCount;
    final scanCount = widget.lostDogSvc.totalScans;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      child: Column(
        children: [
          // Hero illustration area
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.amber.withValues(alpha: 0.10),
                  Colors.orange.withValues(alpha: 0.05),
                  bgCard,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                // Scan icon with pulse ring
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.amber.withValues(alpha: 0.08),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.25),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.1),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.center_focus_strong,
                      color: Colors.amber,
                      size: 52,
                    ),
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                      begin: const Offset(1.0, 1.0),
                      end: const Offset(1.05, 1.05),
                      duration: 2000.ms,
                      curve: Curves.easeInOut,
                    ),
                const SizedBox(height: 28),
                const Text(
                  'Scan a Dog',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Found a dog? Take a photo and we\'ll check\nif it matches any lost dogs in our network.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                // Scan button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/lost-dog/scan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: Colors.amber.withValues(alpha: 0.3),
                    ),
                    icon: const Icon(Icons.camera_alt, size: 24),
                    label: const Text(
                      'Scan a Dog',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),

          const SizedBox(height: 24),

          // Stats row
          Row(
            children: [
              _buildStatCard(
                icon: Icons.search,
                iconColor: Colors.redAccent,
                value: '$missingCount',
                label: 'Dogs Missing',
                bgColor: Colors.red,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                icon: Icons.qr_code_scanner,
                iconColor: Colors.amber,
                value: '$scanCount',
                label: 'Scans Performed',
                bgColor: Colors.amber,
              ),
            ],
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05),

          const SizedBox(height: 24),

          // How it works
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: bgCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How It Works',
                  style: TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStep(
                  number: '1',
                  title: 'Snap a Photo',
                  description: 'Take a clear photo of the dog you found',
                  icon: Icons.camera_alt,
                ),
                const SizedBox(height: 14),
                _buildStep(
                  number: '2',
                  title: 'AI Matching',
                  description:
                      'Our ML model compares visual features against all lost dog reports',
                  icon: Icons.auto_awesome,
                ),
                const SizedBox(height: 14),
                _buildStep(
                  number: '3',
                  title: 'Reunite',
                  description:
                      'If there\'s a match, contact the owner and bring them home',
                  icon: Icons.favorite,
                ),
              ],
            ),
          ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.05),

          const SizedBox(height: 24),

          // Network banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.amber.withValues(alpha: 0.08),
                Colors.orange.withValues(alpha: 0.04),
              ]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(Icons.public, color: Colors.amber.shade300, size: 28),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Global Recognition Network',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Every scan helps. Together, we can bring every lost dog home.',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 500.ms),

          // ── Nearby Lost Dogs from Cloud ──
          if (_loadingNearby)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(
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
                      'Searching for lost dogs nearby...',
                      style: TextStyle(color: Colors.amber.shade300, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          if (_nearbyError != null)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(
                _nearbyError!,
                style: TextStyle(color: Colors.red.shade300, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          if (!_loadingNearby && _nearbyReports.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.red.shade300, size: 18),
                const SizedBox(width: 6),
                Text(
                  '${_nearbyReports.length} Lost Dog${_nearbyReports.length == 1 ? '' : 's'} Nearby',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 600.ms),
            const SizedBox(height: 12),
            ..._nearbyReports.map((report) {
              final daysAgo =
                  DateTime.now().difference(report.lastSeenAt).inDays;
              final timeLabel = daysAgo == 0
                  ? 'Today'
                  : daysAgo == 1
                      ? '1 day ago'
                      : '$daysAgo days ago';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.red.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    // Photo or placeholder
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: report.photoUrl != null
                            ? Image.network(
                                report.photoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.red.withValues(alpha: 0.08),
                                  child: const Center(
                                    child: Icon(Icons.pets,
                                        color: Colors.redAccent, size: 24),
                                  ),
                                ),
                              )
                            : Container(
                                color: Colors.red.withValues(alpha: 0.08),
                                child: const Center(
                                  child: Icon(Icons.pets,
                                      color: Colors.redAccent, size: 24),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.dogName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (report.breed.isNotEmpty)
                            Text(
                              report.breed,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            'Missing $timeLabel',
                            style: TextStyle(
                                color: Colors.red.shade300, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    // Distance badge
                    if (report.distanceMiles != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.near_me,
                                color: Colors.amber, size: 12),
                            const SizedBox(width: 3),
                            Text(
                              '${report.distanceMiles!.toStringAsFixed(1)} mi',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ).animate().fadeIn(delay: 650.ms).slideY(begin: 0.03);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: bgColor.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                color: iconColor,
                fontWeight: FontWeight.bold,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep({
    required String number,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
