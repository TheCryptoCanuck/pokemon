import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:dogquest/constants.dart';
import 'package:dogquest/models/lost_dog_report.dart';

/// An urgent "MISSING DOG" poster card for sharing lost dog alerts.
///
/// Designed to be wrapped in a [RepaintBoundary] for screenshot/share capture.
/// Fixed 360x560 dimensions (matches [DogPassportCard]).
class LostDogPosterCard extends StatelessWidget {
  final LostDogReport report;

  const LostDogPosterCard({super.key, required this.report});

  // Urgent red accent color (replaces passport gold).
  static const _red = Color(0xFFD84315);
  static const _redLight = Color(0xFFFF6E40);
  static const _bg = Color(0xFF1E140E);

  String get _posterId {
    final raw = '${report.dogName}${report.createdAt.millisecondsSinceEpoch}';
    final hash = raw.hashCode.toUnsigned(32).toRadixString(16).toUpperCase();
    return 'LOST-${hash.padLeft(8, '0')}';
  }

  String get _qrData {
    final contact = report.ownerContact ?? '';
    // Extract digits from contact string to build a tel: URI
    final digits = contact.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 7) {
      return 'tel:+1$digits';
    }
    // Fallback: SMS with pre-filled message if no valid number
    return 'sms:?body=I%20found%20a%20dog%20matching%20${Uri.encodeComponent(report.dogName)}%20(${Uri.encodeComponent(report.breed ?? 'unknown breed')})%20-%20Lost%20Dog%20Network';
  }

  int get _daysMissing => DateTime.now().difference(report.lostDate).inDays;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: 620,
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _red.withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _red.withValues(alpha: 0.15),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background paw pattern watermark
          Positioned(
            right: -40,
            top: -20,
            child: Icon(
              Icons.pets,
              size: 200,
              color: Colors.white.withValues(alpha: 0.015),
            ),
          ),
          Positioned(
            left: -30,
            bottom: 180,
            child: Icon(
              Icons.pets,
              size: 140,
              color: Colors.white.withValues(alpha: 0.015),
            ),
          ),

          // Main content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Header (red gradient bar) ---
                _buildHeader(),

                const SizedBox(height: 14),

                // --- MISSING DOG title ---
                _buildUrgentBanner(),

                const SizedBox(height: 14),

                // --- Photo + Identity ---
                _buildPhotoAndIdentity(),

                const SizedBox(height: 14),

                // --- Divider ---
                _redDivider(),

                const SizedBox(height: 10),

                // --- Notes section ---
                _buildNotesSection(),

                const Spacer(),

                // --- Divider ---
                _redDivider(),

                const SizedBox(height: 10),

                // --- Call-to-action + QR ---
                _buildFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Paw icon in red circle
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [_red, _redLight],
            ),
            boxShadow: [
              BoxShadow(
                color: _red.withValues(alpha: 0.3),
                blurRadius: 8,
              ),
            ],
          ),
          child: const Icon(Icons.pets, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DOGQUEST',
                style: TextStyle(
                  color: _red,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
              Text(
                'LOST DOG NETWORK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
        // Warning icon
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _red.withValues(alpha: 0.3)),
          ),
          child: Icon(
            Icons.warning_amber_rounded,
            color: _red.withValues(alpha: 0.7),
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildUrgentBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_red, Color(0xFFBF360C)],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: _red.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.white, size: 22),
          SizedBox(width: 8),
          Text(
            'MISSING DOG',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          SizedBox(width: 8),
          Icon(Icons.error_outline, color: Colors.white, size: 22),
        ],
      ),
    );
  }

  Widget _buildPhotoAndIdentity() {
    final breed = report.breed ?? 'Unknown Breed';
    final location = report.lastSeenLocation ?? 'Unknown';
    final daysMissing = _daysMissing;
    final missingLabel = daysMissing == 0
        ? 'Today'
        : daysMissing == 1
            ? '1 day ago'
            : '$daysMissing days ago';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Photo with red border
        Container(
          width: 110,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _red.withValues(alpha: 0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child:
              report.photoPath != null && File(report.photoPath!).existsSync()
                  ? Image.file(File(report.photoPath!), fit: BoxFit.cover)
                  : Container(
                      color: bgCard,
                      child: const Center(
                        child: Icon(Icons.pets, color: _red, size: 48),
                      ),
                    ),
        ),

        const SizedBox(width: 16),

        // Identity fields
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _posterField('NAME', report.dogName),
              const SizedBox(height: 10),
              _posterField('BREED', breed),
              const SizedBox(height: 10),
              _posterField('LAST SEEN', location),
              const SizedBox(height: 10),
              _posterField(
                'MISSING SINCE',
                '${_formatDate(report.lostDate)} ($missingLabel)',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _posterField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _red.withValues(alpha: 0.7),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Notes (collar, marks)
        if (report.notes != null && report.notes!.isNotEmpty) ...[
          Text(
            'DISTINGUISHING DETAILS',
            style: TextStyle(
              color: _red.withValues(alpha: 0.7),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _red.withValues(alpha: 0.2)),
            ),
            child: Text(
              report.notes!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Owner contact
        if (report.ownerContact != null && report.ownerContact!.isNotEmpty) ...[
          Text(
            'CONTACT OWNER',
            style: TextStyle(
              color: _red.withValues(alpha: 0.7),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.phone, color: _red.withValues(alpha: 0.6), size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  report.ownerContact!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFooter() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Poster ID + call-to-action
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _posterId,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _red.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'If you see this dog, open\nDogQuest and scan!',
                  style: TextStyle(
                    color: _redLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // QR Code
        Container(
          width: 80,
          height: 80,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: QrImageView(
            data: _qrData,
            version: QrVersions.auto,
            size: 72,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF1E140E),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Color(0xFF1E140E),
            ),
          ),
        ),
      ],
    );
  }

  Widget _redDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            _red.withValues(alpha: 0.4),
            _red.withValues(alpha: 0.4),
            Colors.transparent,
          ],
          stops: const [0, 0.2, 0.8, 1],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
