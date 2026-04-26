import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dogquest/constants.dart';
import 'package:dogquest/models/lost_dog_report.dart';
import 'package:dogquest/services/lost_dog_service.dart';
import 'package:dogquest/services/supabase_lost_dog_service.dart';

class ScanStrayScreen extends ConsumerStatefulWidget {
  const ScanStrayScreen({super.key});

  @override
  ConsumerState<ScanStrayScreen> createState() => _ScanStrayScreenState();
}

class _ScanStrayScreenState extends ConsumerState<ScanStrayScreen>
    with SingleTickerProviderStateMixin {
  final _picker = ImagePicker();

  File? _scannedPhoto;
  bool _scanning = false;
  StrayScanResult? _result;
  String? _error;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      _runScan(File(picked.path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open camera')),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      _runScan(File(picked.path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load image from gallery')),
      );
    }
  }

  Future<void> _runScan(File photo) async {
    setState(() {
      _scannedPhoto = photo;
      _scanning = true;
      _result = null;
      _error = null;
    });

    try {
      final lostDogSvc = ref.read(lostDogServiceProvider);
      final supabaseSvc = ref.read(supabaseLostDogServiceProvider);
      final result = await lostDogSvc.scanStray(
        photo,
        supabaseSvc: supabaseSvc,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _scanning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Scan failed. Please try again.';
        _scanning = false;
      });
    }
  }

  void _reset() {
    setState(() {
      _scannedPhoto = null;
      _scanning = false;
      _result = null;
      _error = null;
    });
  }

  void _showContactDialog(LostDogMatch match) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.phone_in_talk_rounded,
              color: Colors.amber,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Contact ${match.dogName}\'s Owner',
                style: const TextStyle(color: Colors.white, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Owner Information',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _contactRow(Icons.person_outline, 'Sarah M.'),
                  const SizedBox(height: 6),
                  _contactRow(Icons.phone_outlined, '(555) 012-3456'),
                  const SizedBox(height: 6),
                  _contactRow(Icons.email_outlined, 'sarah.m@email.com'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Please let them know where you spotted ${match.dogName} '
              'and share any details that might help.',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Colors.green.shade800,
                  content: const Text(
                    'Owner has been notified! Thank you for helping.',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Notify Owner'),
          ),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 16),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AppBar(
        backgroundColor: bgDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, color: Colors.amber, size: 22),
            SizedBox(width: 8),
            Text(
              'Scan a Stray',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: _scanning
          ? _buildScanningState()
          : _result != null
              ? _buildResultsState()
              : _error != null
                  ? _buildErrorState()
                  : _buildInitialState(),
    );
  }

  // ─── Initial State: capture prompt ────────────────────────────────────

  Widget _buildInitialState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hero illustration area
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.amber.withValues(alpha: 0.15),
                    Colors.amber.withValues(alpha: 0.03),
                  ],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.pets_rounded,
                  size: 64,
                  color: Colors.amber,
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Found a lost dog?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Take a photo and we\'ll check it against reported missing dogs in your area.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.white54, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 36),

            // Camera button
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) => Transform.scale(
                scale: _pulseAnimation.value,
                child: child,
              ),
              child: GestureDetector(
                onTap: _capturePhoto,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.amber, Color(0xFFD4874E)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.35),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Take Photo',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),

            // Gallery option
            TextButton.icon(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library_rounded, size: 20),
              label: const Text('Choose from Gallery'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white54,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Stats pill
            _buildNetworkStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkStats() {
    final lostDogSvc = ref.watch(lostDogServiceProvider);
    final activeCount = lostDogSvc.activeLostCount;
    final scanCount = lostDogSvc.totalScans;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _statChip(Icons.warning_amber_rounded, '$activeCount', 'Missing'),
          Container(
            width: 1,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: Colors.white12,
          ),
          _statChip(Icons.qr_code_scanner_rounded, '$scanCount', 'Scans'),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.amber, size: 16),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }

  // ─── Scanning State ───────────────────────────────────────────────────

  Widget _buildScanningState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Scanned photo thumbnail
            if (_scannedPhoto != null)
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.5),
                    width: 2,
                  ),
                  image: DecorationImage(
                    image: FileImage(_scannedPhoto!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: Colors.amber,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Checking lost dog database...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Comparing against reported missing dogs',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Error State ──────────────────────────────────────────────────────

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black87,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Results State ────────────────────────────────────────────────────

  Widget _buildResultsState() {
    final matches = _result?.matches ?? [];
    final hasMatches = matches.isNotEmpty;

    return Column(
      children: [
        // Scanned photo banner
        if (_scannedPhoto != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    _scannedPhoto!,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasMatches
                            ? '${matches.length} potential match${matches.length == 1 ? '' : 'es'} found'
                            : 'No matches in database',
                        style: TextStyle(
                          color: hasMatches ? Colors.amber : Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasMatches
                            ? 'Review matches below'
                            : 'This dog may not be reported missing',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _reset,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white38,
                    size: 20,
                  ),
                  tooltip: 'New scan',
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),

        // Results content
        Expanded(
          child: hasMatches
              ? ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: matches.length,
                  itemBuilder: (context, index) => _LostDogMatchCard(
                    match: matches[index],
                    scannedPhoto: _scannedPhoto!,
                    onContact: () => _showContactDialog(matches[index]),
                    isTopMatch: index == 0,
                  ),
                )
              : _buildNoMatchesState(),
        ),

        // Scan again button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.camera_alt_rounded, size: 20),
              label: const Text('Scan Another Dog'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.amber,
                side: const BorderSide(color: Colors.amber, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoMatchesState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.green,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No matches found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This dog doesn\'t match any currently reported missing dogs. '
              'If the dog seems lost, consider contacting local animal services.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.white54, fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Lost Dog Match Card — the "wow moment" for investor demos
// ═══════════════════════════════════════════════════════════════════════════

class _LostDogMatchCard extends StatelessWidget {
  final LostDogMatch match;
  final File scannedPhoto;
  final VoidCallback onContact;
  final bool isTopMatch;

  const _LostDogMatchCard({
    required this.match,
    required this.scannedPhoto,
    required this.onContact,
    this.isTopMatch = false,
  });

  Color get _similarityColor {
    if (match.similarity >= 0.85) return const Color(0xFF4CAF50);
    if (match.similarity >= 0.70) return const Color(0xFFFFC107);
    return const Color(0xFFEF5350);
  }

  Color get _confidenceBadgeColor {
    switch (match.confidence) {
      case MatchConfidence.high:
        return const Color(0xFF4CAF50);
      case MatchConfidence.medium:
        return const Color(0xFFFFC107);
      case MatchConfidence.low:
        return const Color(0xFFEF5350);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(20),
        border: isTopMatch
            ? Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 1.5)
            : Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: isTopMatch
            ? [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.12),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top: Emotional header for top match ──
          if (isTopMatch)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.amber.withValues(alpha: 0.15),
                    Colors.amber.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(19),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.favorite_rounded,
                    color: Colors.amber,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'This could be ${match.dogName}!',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Side-by-side photo comparison ──
                Row(
                  children: [
                    // Scanned photo
                    Expanded(
                      child: _photoFrame('Scanned Dog', scannedPhoto, null),
                    ),
                    const SizedBox(width: 10),
                    // Similarity arrow
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSimilarityGauge(),
                        const SizedBox(height: 4),
                        Icon(
                          Icons.compare_arrows_rounded,
                          color: _similarityColor,
                          size: 22,
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    // Lost dog photo
                    Expanded(
                      child: _photoFrame(
                        match.dogName,
                        null,
                        match.photoPath,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Dog info row ──
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            match.dogName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (match.breed != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              match.breed!,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Confidence badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _confidenceBadgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _confidenceBadgeColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        match.confidence.label,
                        style: TextStyle(
                          color: _confidenceBadgeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Distance info ──
                if (match.distanceKm != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: Colors.white38,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDistance(match.distanceKm!),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'from last seen location',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 14),

                // ── Contact owner button ──
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onContact,
                    icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                    label: const Text(
                      'Contact Owner',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isTopMatch
                          ? Colors.amber
                          : Colors.amber.withValues(alpha: 0.15),
                      foregroundColor:
                          isTopMatch ? Colors.black87 : Colors.amber,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: isTopMatch ? 2 : 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoFrame(String label, File? file, String? path) {
    Widget imageWidget;
    if (file != null) {
      imageWidget = Image.file(file, fit: BoxFit.cover);
    } else if (path != null) {
      final photoFile = File(path);
      imageWidget = Image.file(photoFile, fit: BoxFit.cover);
    } else {
      imageWidget = Container(
        color: Colors.white.withValues(alpha: 0.05),
        child: const Center(
          child: Icon(Icons.pets_rounded, color: Colors.white24, size: 32),
        ),
      );
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 1,
            child: imageWidget,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildSimilarityGauge() {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              value: match.similarity,
              strokeWidth: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(_similarityColor),
            ),
          ),
          Text(
            '${match.similarityPercent}%',
            style: TextStyle(
              color: _similarityColor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDistance(double km) {
    if (km < 1) {
      return '${(km * 1000).round()} m';
    } else if (km < 10) {
      return '${km.toStringAsFixed(1)} km';
    } else {
      return '${km.round()} km';
    }
  }
}
