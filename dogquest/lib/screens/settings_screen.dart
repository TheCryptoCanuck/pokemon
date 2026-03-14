import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../constants.dart';
import '../services/auth_service.dart';
import '../services/backend_sync_service.dart';
import '../services/data_consent_service.dart';
import '../services/demo_service.dart';
import '../services/notification_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isSyncing = false;
  bool _isClearingCache = false;
  bool _isDeletingSightings = false;
  bool _isDeletingAllData = false;
  bool _isSeedingDemo = false;
  Map<String, dynamic>? _profile;
  bool _loadingProfile = true;
  bool _streakReminders = NotificationService.streakRemindersEnabled;
  bool _dailyDogAlerts = NotificationService.dailyDogAlertsEnabled;
  bool _dataSharing = DataConsentService.hasConsented;


  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final syncService = ref.read(backendSyncProvider);
      final profile = await syncService.fetchProfile();
      // Cache username for greeting on profile screen
      final uname = profile?['username'] as String?;
      if (uname != null && uname.isNotEmpty) {
        Hive.box('dogquest_player_stats').put('cached_username', uname);
      }
      if (mounted) {
        setState(() {
          _profile = profile;
          _loadingProfile = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _handleSync() async {
    setState(() => _isSyncing = true);
    try {
      final syncService = ref.read(backendSyncProvider);
      await syncService.flushPendingSyncs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync complete'),
            backgroundColor: Color(0xFFD4874E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _handleClearCache() async {
    setState(() => _isClearingCache = true);
    try {
      imageCache.clear();
      imageCache.clearLiveImages();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image cache cleared'),
            backgroundColor: Color(0xFFD4874E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isClearingCache = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log Out', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await NotificationService.cancelAll();
      final authService = ref.read(authServiceProvider);
      await authService.logout();
      if (mounted) context.go('/login');
    }
  }

  Future<void> _handleDeleteSightings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Sighting History',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will permanently delete all your sighting and location history. '
          'This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isDeletingSightings = true);
      try {
        await Hive.deleteBoxFromDisk('dogquest_sightings_v1');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sighting history deleted'),
              backgroundColor: Color(0xFFD4874E),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete sightings: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isDeletingSightings = false);
      }
    }
  }


  Future<void> _handleSeedDemo() async {
    if (_isSeedingDemo) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Activate Demo Mode',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will replace your current data with pre-seeded demo data '
          '(25+ breeds, sightings, achievements, stats). '
          'Your existing data will be overwritten.\n\n'
          'Use "Clear Demo Data" to reset afterwards.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Seed Demo', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isSeedingDemo = true);
      final success = await DemoService.seedDemoData(ref);
      if (mounted) {
        setState(() {
          _isSeedingDemo = false;
        });
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Demo data seeded! Redirecting to Kennel...'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
          // Navigate to kennel so screens rebuild with fresh Hive data
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) context.go('/kennel');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to seed demo data.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleClearDemo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Demo Data',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will clear all demo data and reset the app to a fresh state. '
          'This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await DemoService.clearDemoData(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Demo data cleared. App reset to fresh state.'
                : 'Failed to clear demo data.'),
            backgroundColor: success ? const Color(0xFFD4874E) : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (success) {
          context.go('/identify');
        }
      }
    }
  }

  Future<void> _handleDeleteAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete All App Data',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will permanently delete ALL app data including your collection, '
          'sightings, stats, challenges, and preferences. '
          'The app will restart from scratch. This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Everything',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isDeletingAllData = true);
      try {
        // Close and delete all known Hive boxes
        final boxNames = [
          'dogquest_sightings_v1',
          'dogquest_kennel',
          'dogquest_player_stats',
          'dogquest_pending_syncs',
          'dogquest_flash_challenges',
        ];
        for (final name in boxNames) {
          try {
            if (Hive.isBoxOpen(name)) {
              await Hive.box(name).close();
            }
            await Hive.deleteBoxFromDisk(name);
          } catch (_) {
            // Box may not exist yet, that is fine
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All app data deleted. Restarting...'),
              backgroundColor: Color(0xFFD4874E),
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Navigate to splash / initial route to force fresh start
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) context.go('/identify');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete data: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isDeletingAllData = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerBox = Hive.box('dogquest_player_stats');
    final isOffline = playerBox.get('offline_mode', defaultValue: false) as bool;
    final hasToken = playerBox.get('has_auth_token', defaultValue: false) as bool;

    int pendingSyncCount = 0;
    try {
      final pendingBox = Hive.box<Map>('dogquest_pending_syncs');
      pendingSyncCount = pendingBox.length;
    } catch (_) {}

    final username = _profile?['username'] as String?;
    final email = _profile?['email'] as String?;

    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AppBar(
        backgroundColor: bgDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Account Section ──
            _sectionHeader('Account'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _infoTile(
                    icon: Icons.person_outline,
                    title: 'Username',
                    subtitle: _loadingProfile
                        ? 'Loading...'
                        : username ?? (isOffline ? 'Offline Mode' : 'Unknown'),
                  ),
                  const Divider(color: Colors.white10, height: 1, indent: 56),
                  _infoTile(
                    icon: Icons.email_outlined,
                    title: 'Email',
                    subtitle: _loadingProfile
                        ? 'Loading...'
                        : email ?? (isOffline ? 'N/A' : 'Unknown'),
                  ),
                  if (hasToken || !isOffline) ...[
                    const Divider(color: Colors.white10, height: 1, indent: 56),
                    _actionTile(
                      icon: Icons.logout,
                      title: 'Log Out',
                      iconColor: Colors.redAccent,
                      titleColor: Colors.redAccent,
                      onTap: _handleLogout,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Sync Section ──
            _sectionHeader('Sync'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _actionTile(
                    icon: Icons.sync,
                    title: 'Sync Now',
                    trailing: _isSyncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.amber,
                            ),
                          )
                        : pendingSyncCount > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$pendingSyncCount pending',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            : const Text(
                                'All synced',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 12),
                              ),
                    onTap: _isSyncing ? null : _handleSync,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Notifications Section ──
            _sectionHeader('Notifications'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.local_fire_department_outlined,
                        color: Colors.orangeAccent, size: 22),
                    title: const Text('Streak Reminders',
                        style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: const Text('Daily at 8:00 PM',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                    value: _streakReminders,
                    activeTrackColor: Colors.amber.withValues(alpha: 0.5),
                    activeThumbColor: Colors.amber,
                    dense: true,
                    onChanged: (val) async {
                      setState(() => _streakReminders = val);
                      await NotificationService.setStreakReminders(val);
                    },
                  ),
                  const Divider(color: Colors.white10, height: 1, indent: 56),
                  SwitchListTile(
                    secondary: const Icon(Icons.sunny,
                        color: Colors.amberAccent, size: 22),
                    title: const Text('Daily Dog Alerts',
                        style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: const Text('Daily at 9:00 AM',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                    value: _dailyDogAlerts,
                    activeTrackColor: Colors.amber.withValues(alpha: 0.5),
                    activeThumbColor: Colors.amber,
                    dense: true,
                    onChanged: (val) async {
                      setState(() => _dailyDogAlerts = val);
                      await NotificationService.setDailyDogAlerts(val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Data & Privacy Section ──
            _sectionHeader('Data & Privacy'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.science_outlined,
                        color: Color(0xFFD4874E), size: 22),
                    title: const Text('Contribute to Science',
                        style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: const Text(
                        'Share anonymized sighting data with researchers',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                    value: _dataSharing,
                    activeTrackColor: const Color(0xFFD4874E).withValues(alpha: 0.5),
                    activeThumbColor: const Color(0xFFD4874E),
                    dense: true,
                    onChanged: (val) async {
                      setState(() => _dataSharing = val);
                      await DataConsentService.setConsent(val);
                    },
                  ),
                  if (_dataSharing) ...[
                    const Divider(color: Colors.white10, height: 1, indent: 56),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(56, 4, 16, 12),
                      child: Text(
                        'Your sighting data (species, location, date) may be shared '
                        'in aggregated form with conservation and research partners. '
                        'No personal info (name, email, photos) is ever shared.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                  const Divider(color: Colors.white10, height: 1, indent: 56),
                  _actionTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    trailing: const Icon(Icons.chevron_right,
                        color: Colors.white24, size: 20),
                    onTap: () => context.push('/privacy'),
                  ),
                  const Divider(color: Colors.white10, height: 1, indent: 56),
                  _actionTile(
                    icon: Icons.delete_outline,
                    title: 'Delete Sighting History',
                    iconColor: Colors.orangeAccent,
                    titleColor: Colors.orangeAccent,
                    trailing: _isDeletingSightings
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.orangeAccent,
                            ),
                          )
                        : null,
                    onTap: _isDeletingSightings ? null : _handleDeleteSightings,
                  ),
                  const Divider(color: Colors.white10, height: 1, indent: 56),
                  _actionTile(
                    icon: Icons.delete_forever,
                    title: 'Delete All App Data',
                    iconColor: Colors.redAccent,
                    titleColor: Colors.redAccent,
                    trailing: _isDeletingAllData
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.redAccent,
                            ),
                          )
                        : null,
                    onTap: _isDeletingAllData ? null : _handleDeleteAllData,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── App Section ──
            _sectionHeader('App'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: Colors.white54, size: 22),
                    title: const Text('Version',
                        style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: const Text('0.1.0',
                        style: TextStyle(color: Colors.white54, fontSize: 13)),
                    dense: true,
                  ),
                  const Divider(color: Colors.white10, height: 1, indent: 56),
                  _actionTile(
                    icon: Icons.delete_sweep_outlined,
                    title: 'Clear Image Cache',
                    trailing: _isClearingCache
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.amber,
                            ),
                          )
                        : null,
                    onTap: _isClearingCache ? null : _handleClearCache,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Demo Mode Section ──
            if (kDebugMode) ...[
              _sectionHeader('Demo Mode'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          Icon(
                            DemoService.isDemoMode
                                ? Icons.science
                                : Icons.science_outlined,
                            color: Colors.amber,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              DemoService.isDemoMode
                                  ? 'Demo mode is active'
                                  : 'Seeds 25+ breeds, sightings, and stats for investor demos',
                              style: TextStyle(
                                color: DemoService.isDemoMode
                                    ? Colors.amber
                                    : Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white10, height: 1, indent: 16),
                    _actionTile(
                      icon: Icons.play_arrow_rounded,
                      title: 'Seed Demo Data',
                      iconColor: Colors.green,
                      titleColor: Colors.green,
                      trailing: _isSeedingDemo
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.green,
                              ),
                            )
                          : null,
                      onTap: _isSeedingDemo ? null : _handleSeedDemo,
                    ),
                    if (DemoService.isDemoMode) ...[
                      const Divider(color: Colors.white10, height: 1, indent: 56),
                      _actionTile(
                        icon: Icons.cleaning_services_rounded,
                        title: 'Clear Demo Data',
                        iconColor: Colors.orangeAccent,
                        titleColor: Colors.orangeAccent,
                        onTap: _handleClearDemo,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── About Section ──
            _sectionHeader('About'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                          colors: [Colors.amber, Color(0xFFD4874E)]),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: const Center(
                      child: Text('A', style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      )),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'DogQuest v0.1.0',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Powered by on-device AI',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.amber,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white54, size: 22),
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: Colors.white54, fontSize: 13)),
      dense: true,
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    Color iconColor = Colors.white54,
    Color titleColor = Colors.white,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(title,
          style: TextStyle(color: titleColor, fontSize: 14)),
      trailing: trailing ??
          const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
      dense: true,
      onTap: onTap,
    );
  }
}
