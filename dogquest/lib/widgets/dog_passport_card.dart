import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../constants.dart';
import '../models/dog.dart';
import '../models/my_dog_profile.dart';

/// A beautiful passport-style card for a user's personal dog.
///
/// Designed to be wrapped in a [RepaintBoundary] for screenshot/share capture.
/// Fixed 360×560 dimensions (close to credit-card proportions).
class DogPassportCard extends StatelessWidget {
  final MyDogProfile profile;
  final Dog? breedData;
  final int playerLevel;
  final String playerTitle;

  const DogPassportCard({
    super.key,
    required this.profile,
    this.breedData,
    required this.playerLevel,
    required this.playerTitle,
  });

  String get _passportId {
    // Deterministic 8-char ID from dog name + creation date
    final raw = '${profile.name}${profile.createdAt.millisecondsSinceEpoch}';
    final hash = raw.hashCode.toUnsigned(32).toRadixString(16).toUpperCase();
    return 'DQ-${hash.padLeft(8, '0')}';
  }

  String get _qrData {
    final data = {
      'app': 'DogQuest',
      'id': _passportId,
      'name': profile.name,
      'breed': profile.breed ?? 'Unknown',
      'registered': profile.createdAt.toIso8601String().split('T').first,
    };
    return jsonEncode(data);
  }

  @override
  Widget build(BuildContext context) {
    final age = profile.ageYears;
    final breed = profile.breed ?? 'Mixed Breed';
    final sizeCategory = breedData?.sizeCategory ?? 'medium';
    final dogYearsValue = age != null ? dogYears(age, sizeCategory) : null;

    return Container(
      width: 360,
      height: 560,
      decoration: BoxDecoration(
        color: const Color(0xFF1E140E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFD4874E).withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4874E).withValues(alpha: 0.15),
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
            child: Icon(Icons.pets,
              size: 200,
              color: Colors.white.withValues(alpha: 0.015),
            ),
          ),
          Positioned(
            left: -30,
            bottom: 60,
            child: Icon(Icons.pets,
              size: 160,
              color: Colors.white.withValues(alpha: 0.015),
            ),
          ),

          // Main content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Header ───────────────────────────────
                _buildHeader(),

                const SizedBox(height: 20),

                // ─── Photo + Identity ─────────────────────
                _buildPhotoAndIdentity(breed, age, dogYearsValue),

                const SizedBox(height: 20),

                // ─── Divider ──────────────────────────────
                _goldDivider(),

                const SizedBox(height: 16),

                // ─── Traits ───────────────────────────────
                _buildTraitsSection(),

                const Spacer(),

                // ─── Divider ──────────────────────────────
                _goldDivider(),

                const SizedBox(height: 14),

                // ─── Footer: QR + Passport ID ─────────────
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
        // Paw icon
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFD4874E), Color(0xFFE6A96E)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4874E).withValues(alpha: 0.3),
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
                  color: Color(0xFFD4874E),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
              Text(
                'DOG PASSPORT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
        // Microchip icon
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD4874E).withValues(alpha: 0.3)),
          ),
          child: Icon(Icons.memory, color: const Color(0xFFD4874E).withValues(alpha: 0.5), size: 20),
        ),
      ],
    );
  }

  Widget _buildPhotoAndIdentity(String breed, int? age, int? dogYearsValue) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Photo with gold border
        Container(
          width: 120,
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD4874E).withValues(alpha: 0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: profile.photoPath != null && File(profile.photoPath!).existsSync()
              ? Image.file(File(profile.photoPath!), fit: BoxFit.cover)
              : Container(
                  color: bgCard,
                  child: const Center(
                    child: Icon(Icons.pets, color: Colors.amber, size: 48),
                  ),
                ),
        ),

        const SizedBox(width: 16),

        // Identity fields
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _passportField('NAME', profile.name),
              const SizedBox(height: 10),
              _passportField('BREED', breed),
              const SizedBox(height: 10),
              if (age != null) ...[
                Row(
                  children: [
                    Expanded(child: _passportField('AGE', '$age ${age == 1 ? "yr" : "yrs"}')),
                    if (dogYearsValue != null)
                      Expanded(child: _passportField('DOG YRS', '$dogYearsValue')),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              if (profile.celebrationDate != null)
                _passportField(
                  profile.usesGotchaDay ? 'GOTCHA DAY' : 'BIRTHDAY',
                  _formatDate(profile.celebrationDate!),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _passportField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFFD4874E).withValues(alpha: 0.7),
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
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildTraitsSection() {
    if (profile.personalityTags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PERSONALITY',
          style: TextStyle(
            color: const Color(0xFFD4874E).withValues(alpha: 0.7),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: profile.personalityTags.take(6).map((tag) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFD4874E).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFD4874E).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                tag,
                style: const TextStyle(
                  color: Color(0xFFE6A96E),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),

        // Breed quick stats
        if (breedData != null) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              if (breedData!.lifespan.isNotEmpty)
                _miniStat(Icons.favorite_border, breedData!.lifespan),
              if (breedData!.weight.isNotEmpty) ...[
                const SizedBox(width: 12),
                _miniStat(Icons.monitor_weight_outlined, breedData!.weight),
              ],
              if (breedData!.sizeCategory.isNotEmpty) ...[
                const SizedBox(width: 12),
                _miniStat(Icons.straighten, _sizeLabel(breedData!.sizeCategory)),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _miniStat(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white38, size: 13),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Passport ID + player info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _passportId,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text('🐕', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playerTitle,
                          style: const TextStyle(
                            color: Color(0xFFD4874E),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          'Level $playerLevel  •  Since ${_formatDate(profile.createdAt)}',
                          style: const TextStyle(color: Colors.white38, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ],
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

  Widget _goldDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            const Color(0xFFD4874E).withValues(alpha: 0.4),
            const Color(0xFFD4874E).withValues(alpha: 0.4),
            Colors.transparent,
          ],
          stops: const [0, 0.2, 0.8, 1],
        ),
      ),
    );
  }

  static String _sizeLabel(String s) => switch (s) {
    'small' => 'Small',
    'medium' => 'Medium',
    'large' => 'Large',
    'giant' => 'Giant',
    _ => 'Medium',
  };

  String _formatDate(DateTime date) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
