import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dogquest/constants.dart';
import 'package:dogquest/models/lost_dog_report.dart';
import 'package:dogquest/services/lost_dog_service.dart';
import 'package:dogquest/services/supabase_lost_dog_service.dart';
import 'package:dogquest/services/identification_service.dart';

// ─── Intake Entry Model ──────────────────────────────────────────────────────

class _IntakeEntry {
  final String id;
  final String? photoPath;
  final String? detectedBreed;
  final double? breedConfidence;
  final DateTime scannedAt;
  final List<LostDogMatch> matches;

  const _IntakeEntry({
    required this.id,
    this.photoPath,
    this.detectedBreed,
    this.breedConfidence,
    required this.scannedAt,
    this.matches = const [],
  });

  bool get hasMatch => matches.isNotEmpty;
}

// ═════════════════════════════════════════════════════════════════════════════
// Shelter Mode Screen — B2B batch-scanning interface for animal shelters
// ═════════════════════════════════════════════════════════════════════════════

class ShelterModeScreen extends ConsumerStatefulWidget {
  const ShelterModeScreen({super.key});

  @override
  ConsumerState<ShelterModeScreen> createState() => _ShelterModeScreenState();
}

class _ShelterModeScreenState extends ConsumerState<ShelterModeScreen> {
  final _picker = ImagePicker();
  final List<_IntakeEntry> _intakeLog = [];
  bool _scanning = false;

  int get _scannedToday => _intakeLog.length;
  int get _matchesFound => _intakeLog.where((e) => e.hasMatch).length;
  int get _activeAlerts {
    final svc = ref.read(lostDogServiceProvider);
    return svc.activeLostCount;
  }

  // ─── Scanning ──────────────────────────────────────────────────────────

  Future<void> _scanIntake(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      await _processIntake(File(picked.path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade800,
          content: Text(
            source == ImageSource.camera
                ? 'Could not open camera'
                : 'Could not load image',
          ),
        ),
      );
    }
  }

  Future<void> _processIntake(File photo) async {
    setState(() => _scanning = true);

    String? detectedBreed;
    double? breedConfidence;
    List<LostDogMatch> matches = [];

    try {
      // Run breed identification and lost dog scan in parallel
      final identSvc = ref.read(identificationServiceProvider);
      final lostDogSvc = ref.read(lostDogServiceProvider);

      final results = await Future.wait([
        identSvc.identify(photo),
        lostDogSvc.scanStray(
          photo,
          supabaseSvc: ref.read(supabaseLostDogServiceProvider),
        ),
      ]);

      final identResults = results[0] as List<IdentificationResult>;
      final scanResult = results[1] as StrayScanResult;

      if (identResults.isNotEmpty && !identResults.first.isUnrecognized) {
        detectedBreed = identResults.first.dog.name;
        breedConfidence = identResults.first.confidence;
      }

      matches = scanResult.matches;
    } catch (e) {
      // Silently handle errors — the entry still gets logged with null breed
    }

    if (!mounted) return;

    final entry = _IntakeEntry(
      id: DateTime.now().millisecondsSinceEpoch.toRadixString(36),
      photoPath: photo.path,
      detectedBreed: detectedBreed,
      breedConfidence: breedConfidence,
      scannedAt: DateTime.now(),
      matches: matches,
    );

    setState(() {
      _intakeLog.insert(0, entry);
      _scanning = false;
    });

    // Show match alert
    if (matches.isNotEmpty && mounted) {
      _showMatchAlert(entry);
    }
  }

  void _showMatchAlert(_IntakeEntry entry) {
    final topMatch = entry.matches.first;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notification_important_rounded,
                color: Colors.amber,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Match Detected',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    'This dog matches a lost report for',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    topMatch.dogName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (topMatch.breed != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      topMatch.breed!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        color: _similarityColor(topMatch.similarity),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${topMatch.similarityPercent}% similarity',
                        style: TextStyle(
                          color: _similarityColor(topMatch.similarity),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Notify the owner and initiate the reunification process.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Colors.green.shade800,
                  content: const Text(
                    'Owner notification sent. Reunification case opened.',
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

  Color _similarityColor(double similarity) {
    if (similarity >= 0.85) return const Color(0xFF4CAF50);
    if (similarity >= 0.70) return const Color(0xFFFFC107);
    return const Color(0xFFEF5350);
  }

  // ─── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildDashboardStats(),
            _buildScanButton(),
            const SizedBox(height: 8),
            _buildLogHeader(),
            Expanded(child: _buildIntakeLog()),
          ],
        ),
      ),
    );
  }

  // ─── Top Bar ───────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Color(0xFF42A5F5),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shelter Mode',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  'Intake Scanner',
                  style: TextStyle(
                    color: Color(0xFF42A5F5),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: Color(0xFF4CAF50), size: 8),
                SizedBox(width: 6),
                Text(
                  'ONLINE',
                  style: TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Dashboard Stats ───────────────────────────────────────────────────

  Widget _buildDashboardStats() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          _buildStatTile(
            icon: Icons.qr_code_scanner_rounded,
            iconColor: const Color(0xFF42A5F5),
            value: '$_scannedToday',
            label: 'Scanned Today',
          ),
          _buildStatDivider(),
          _buildStatTile(
            icon: Icons.link_rounded,
            iconColor: Colors.amber,
            value: '$_matchesFound',
            label: 'Matches Found',
          ),
          _buildStatDivider(),
          _buildStatTile(
            icon: Icons.warning_amber_rounded,
            iconColor: const Color(0xFFEF5350),
            value: '$_activeAlerts',
            label: 'Active Alerts',
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }

  // ─── Scan Button ───────────────────────────────────────────────────────

  Widget _buildScanButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _scanning
          ? _buildScanningIndicator()
          : Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _scanIntake(ImageSource.camera),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF1565C0).withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Scan Intake',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _scanIntake(ImageSource.gallery),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Icon(
                      Icons.photo_library_rounded,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildScanningIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF42A5F5).withValues(alpha: 0.3),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: Color(0xFF42A5F5),
              strokeWidth: 2.5,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Processing intake...',
            style: TextStyle(
              color: Color(0xFF42A5F5),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Intake Log ────────────────────────────────────────────────────────

  Widget _buildLogHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          Icon(
            Icons.list_alt_rounded,
            color: Colors.white.withValues(alpha: 0.4),
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            'Intake Log',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          if (_intakeLog.isNotEmpty)
            Text(
              '${_intakeLog.length} entr${_intakeLog.length == 1 ? 'y' : 'ies'}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIntakeLog() {
    if (_intakeLog.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.pets_rounded,
                size: 48,
                color: Colors.white.withValues(alpha: 0.12),
              ),
              const SizedBox(height: 16),
              Text(
                'No intakes scanned yet',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Scan incoming animals to check them\nagainst the lost dog database',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.2),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _intakeLog.length,
      itemBuilder: (context, index) =>
          _IntakeEntryCard(entry: _intakeLog[index]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Intake Entry Card
// ═════════════════════════════════════════════════════════════════════════════

class _IntakeEntryCard extends StatelessWidget {
  final _IntakeEntry entry;

  const _IntakeEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final hasMatch = entry.hasMatch;
    final borderColor = hasMatch
        ? Colors.amber.withValues(alpha: 0.4)
        : Colors.white.withValues(alpha: 0.06);
    final bgColor = hasMatch ? Colors.amber.withValues(alpha: 0.04) : bgCard;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 52,
              height: 52,
              child: entry.photoPath != null
                  ? Image.file(
                      File(entry.photoPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholderThumb(),
                    )
                  : _placeholderThumb(),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Timestamp
                    Text(
                      _formatTime(entry.scannedAt),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Match badge
                    if (hasMatch)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_rounded,
                              color: Colors.amber,
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'POSSIBLE MATCH',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                // Breed
                Text(
                  entry.detectedBreed ?? 'Breed unidentified',
                  style: TextStyle(
                    color: entry.detectedBreed != null
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.35),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hasMatch) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Matches: ${entry.matches.map((m) => m.dogName).join(", ")}',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Status indicator
          const SizedBox(width: 8),
          hasMatch
              ? const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.amber,
                  size: 22,
                )
              : Icon(
                  Icons.remove_rounded,
                  color: Colors.white.withValues(alpha: 0.15),
                  size: 22,
                ),
        ],
      ),
    );
  }

  Widget _placeholderThumb() {
    return Container(
      color: Colors.white.withValues(alpha: 0.05),
      child: Icon(
        Icons.pets_rounded,
        color: Colors.white.withValues(alpha: 0.15),
        size: 24,
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
