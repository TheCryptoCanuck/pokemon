import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../constants.dart';
import '../models/dog.dart';
import '../services/analytics_service.dart';
import '../services/dog_mastery_service.dart';
import '../services/kennel_service.dart';
import '../services/dog_service.dart';
import '../services/identification_service.dart';
import '../services/player_service.dart';
import 'network_dog_image.dart';
import 'rarity_discovery_badge.dart';
import 'share_dog_card.dart';

class DogFoundDialog extends ConsumerStatefulWidget {
  final Dog dog;
  final double confidence;
  final String source;
  final List<IdentificationResult> alternatives;
  final bool alreadyOwned;
  final VoidCallback onAdd;
  final ValueChanged<IdentificationResult>? onSelectAlternative;
  final VoidCallback? onManualSearch;

  const DogFoundDialog({
    super.key,
    required this.dog,
    this.confidence = 1.0,
    this.source = 'mock',
    this.alternatives = const [],
    this.alreadyOwned = false,
    required this.onAdd,
    this.onSelectAlternative,
    this.onManualSearch,
  });

  @override
  ConsumerState<DogFoundDialog> createState() => _DogFoundDialogState();
}

class _DogFoundDialogState extends ConsumerState<DogFoundDialog> {
  final GlobalKey _shareCardKey = GlobalKey();
  bool _isSharing = false;
  bool _hapticFired = false;

  // sec-E5: v1 telemetry — baseline for the T2 dog_found_dialog redesign.
  // Events feed `docs/session_2026-04-26/dog_found_dialog_redesign_spec.md`
  // §(d) D3/D5 acceptance criteria. Remove once the redesign ships and a
  // v2 event series replaces this one.
  final Stopwatch _dialogStopwatch = Stopwatch()..start();
  bool _v1OpenEmitted = false;
  bool _v1ActionEmitted = false;

  Dog get dog => widget.dog;
  bool get _isSpecial =>
      dog.rarity == Rarity.rare || dog.rarity == Rarity.legendary;

  void _v1Emit(String event, [Map<String, dynamic>? extra]) {
    if (widget.source == 'mock') {
      // Demo mode — emit with sentinel so dashboards can filter without gaps.
      ref.read(analyticsProvider).track(event, {
        'source': 'mock',
        'picked_index': -2,
        ...?extra,
      });
      return;
    }
    ref.read(analyticsProvider).track(event, {
      'top1_breed': widget.dog.name,
      'top1_confidence': widget.confidence,
      'has_alternatives': widget.alternatives.isNotEmpty,
      ...?extra,
    });
  }

  void _v1MaybeEmitOpen() {
    if (_v1OpenEmitted) return;
    _v1OpenEmitted = true;
    _v1Emit('dog_found_dialog_v1_open');
  }

  void _v1HandleAdd() {
    if (!_v1ActionEmitted) {
      _v1ActionEmitted = true;
      _v1Emit('dog_found_dialog_v1_pick', {
        'picked_index': 0,
        'time_to_pick_ms': _dialogStopwatch.elapsedMilliseconds,
      });
    }
    widget.onAdd();
  }

  void _v1HandleAlt(IdentificationResult alt) {
    if (!_v1ActionEmitted) {
      _v1ActionEmitted = true;
      final altIdx = widget.alternatives.indexOf(alt);
      _v1Emit('dog_found_dialog_v1_pick', {
        'picked_index': altIdx >= 0 ? altIdx + 1 : -1,
        'time_to_pick_ms': _dialogStopwatch.elapsedMilliseconds,
      });
    }
    widget.onSelectAlternative?.call(alt);
  }

  void _v1HandleManualSearch() {
    if (!_v1ActionEmitted) {
      _v1ActionEmitted = true;
      _v1Emit('dog_found_dialog_v1_manual_search', {
        'time_to_action_ms': _dialogStopwatch.elapsedMilliseconds,
      });
    }
    widget.onManualSearch?.call();
  }

  @override
  void dispose() {
    if (!_v1ActionEmitted) {
      _v1Emit('dog_found_dialog_v1_dismissed', {
        'time_to_dismiss_ms': _dialogStopwatch.elapsedMilliseconds,
      });
    }
    _dialogStopwatch.stop();
    super.dispose();
  }

  /// Derive confidence tier from the raw confidence value.
  /// Uses recalibrated thresholds for label-smoothed models.
  ConfidenceTier get _tier {
    if (widget.confidence >= 0.35) return ConfidenceTier.high;
    if (widget.confidence >= 0.20) return ConfidenceTier.medium;
    return ConfidenceTier.low;
  }

  /// Whether confidence is so low we should hedge ("We're not sure...").
  bool get _isVerySlow => widget.confidence < 0.15;

  /// Whether top-2 results are close enough for "Did you mean?" comparison.
  bool get _showComparison =>
      widget.alternatives.isNotEmpty &&
      (widget.confidence - widget.alternatives.first.confidence).abs() < 0.10;

  Future<void> _shareDog() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      // Wait a frame so the offscreen ShareDogCard is fully painted
      await Future.delayed(const Duration(milliseconds: 200));

      final boundary = _shareCardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        setState(() => _isSharing = false);
        return;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        setState(() => _isSharing = false);
        return;
      }

      final bytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/dogquest_dog.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'I found a ${dog.name} on DogQuest!',
      );
    } catch (_) {
      // Silently handle share failures
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUnknown = dog.rarity == Rarity.unknown;
    final isMock = widget.source == 'mock';
    final tier = _tier;
    final playerState = ref.watch(playerProvider);

    // Haptic for rare/legendary finds (fire once, not on every rebuild)
    if (_isSpecial && !_hapticFired) {
      _hapticFired = true;
      HapticFeedback.heavyImpact();
    }

    // sec-E5: emit v1 telemetry on first build (one-shot, before user interacts).
    _v1MaybeEmitOpen();

    return Stack(
      children: [
        Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: bgCard,
              borderRadius: BorderRadius.circular(24),
              border: _isSpecial
                  ? Border.all(
                      color: dog.rarity.color.withValues(alpha: 0.8), width: 2)
                  : null,
              boxShadow: _isSpecial
                  ? [
                      BoxShadow(
                          color: dog.rarity.color.withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 5)
                    ]
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // "NEW BREED DISCOVERED!" banner for first-time finds
                    if (!widget.alreadyOwned) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.star, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'NEW BREED DISCOVERED!',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                letterSpacing: 1.0,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.star, color: Colors.white, size: 20),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 300.ms)
                          .scale(
                              begin: const Offset(0.8, 0.8),
                              curve: Curves.elasticOut,
                              duration: 500.ms)
                          .then()
                          .shimmer(
                              duration: 1200.ms,
                              color: Colors.white.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                    ],

                    // Special header for rare/legendary, standard for others
                    if (dog.rarity == Rarity.legendary)
                      _legendaryHeader(isMock)
                    else if (dog.rarity == Rarity.rare)
                      _rareHeader(isMock)
                    else
                      _standardHeader(isMock),
                    const SizedBox(height: 12),

                    // Dog name with shimmer for special finds
                    Text(
                      isUnknown ? '\u{1F52D} ${dog.name}' : dog.name,
                      style: TextStyle(
                        color: _isSpecial
                            ? dog.rarity.color
                            : (isUnknown ? dog.rarity.color : Colors.amber),
                        fontSize: _isSpecial ? 26 : 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 100.ms).then().shimmer(
                        duration: _isSpecial ? 1500.ms : 0.ms,
                        color: dog.rarity.color.withValues(alpha: 0.3)),
                    Text(
                      dog.scientificName,
                      style: const TextStyle(
                          color: Colors.white54, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 12),

                    // Dog image with dramatic scaling for special finds
                    if (isUnknown)
                      Container(
                        height: 140,
                        decoration: BoxDecoration(
                          color: dog.rarity.color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: dog.rarity.color.withValues(alpha: 0.4)),
                        ),
                        child: Center(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            const Text('\u2753',
                                style: TextStyle(fontSize: 56)),
                            const SizedBox(height: 6),
                            Text('Not in our database yet',
                                style: TextStyle(
                                    color: dog.rarity.color,
                                    fontWeight: FontWeight.bold)),
                          ]),
                        ),
                      ).animate().fadeIn(delay: 200.ms)
                    else
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: NetworkDogImage(url: dog.imageUrl, height: 220),
                      ).animate().fadeIn(delay: 200.ms).scale(
                            begin: _isSpecial
                                ? const Offset(0.8, 0.8)
                                : const Offset(0.95, 0.95),
                            duration: _isSpecial ? 600.ms : 300.ms,
                            curve:
                                _isSpecial ? Curves.elasticOut : Curves.easeOut,
                          ),
                    const SizedBox(height: 12),

                    // Lore
                    Text(dog.lore,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),

                    // XP display -- bigger for special dogs
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: _isSpecial ? 16 : 8,
                        vertical: _isSpecial ? 8 : 4,
                      ),
                      decoration: _isSpecial
                          ? BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.3)),
                            )
                          : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bolt,
                              color: Colors.amber, size: _isSpecial ? 22 : 16),
                          Text(
                            ' +${dog.xp} XP',
                            style: TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: _isSpecial ? 18 : 14,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 400.ms),

                    // Collection progress
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Breeds ${ref.read(kennelServiceProvider).count + (widget.alreadyOwned ? 0 : 1)} / ${ref.read(dogServiceProvider).all.length} in your kennel',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                      ),
                    ),

                    // Rarity discovery badge (FOMO)
                    if (!isUnknown) ...[
                      const SizedBox(height: 8),
                      RarityDiscoveryBadge(
                        rarity: dog.rarity,
                        dogName: dog.name,
                      ).animate().fadeIn(delay: 500.ms),
                    ],

                    // ── Confidence quality bar (replaces raw %) ──
                    if (!isMock) ...[
                      const SizedBox(height: 10),
                      _confidenceBar().animate().fadeIn(delay: 350.ms),
                    ],

                    // ── Very low confidence: hedging language ──
                    if (!isMock && _isVerySlow) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFFF7043).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFFF7043)
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.help_outline_rounded,
                                color: Color(0xFFFF7043), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "We're not sure, but it might be a ${dog.name}. Check the alternatives or search manually.",
                                style: const TextStyle(
                                    color: Color(0xFFFFAB91), fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (widget.alreadyOwned) ...[
                      const SizedBox(height: 10),
                      _masteryProgressSection(),
                    ],

                    // ── "Did you mean?" comparison card (when top-2 close) ──
                    if (!isMock &&
                        _showComparison &&
                        widget.onSelectAlternative != null) ...[
                      const SizedBox(height: 14),
                      _comparisonCard().animate().fadeIn(delay: 450.ms),
                    ],

                    // ── Remaining alternatives ──
                    if (widget.alternatives.isNotEmpty &&
                        widget.onSelectAlternative != null) ...[
                      const SizedBox(height: 14),
                      const Divider(color: Colors.white12),
                      const SizedBox(height: 6),
                      Text(
                        _showComparison
                            ? 'Other possibilities:'
                            : (tier == ConfidenceTier.low
                                ? 'Did you mean one of these?'
                                : 'Could also be:'),
                        style: TextStyle(
                          color: tier == ConfidenceTier.low
                              ? const Color(0xFFFFAB91)
                              : Colors.white38,
                          fontSize: tier == ConfidenceTier.low ? 13 : 12,
                          fontWeight: tier == ConfidenceTier.low
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Skip the first alt if it's already shown in comparison card
                      ...((_showComparison && widget.alternatives.length > 1)
                              ? widget.alternatives.sublist(1)
                              : widget.alternatives)
                          .map((alt) => _AlternativeChip(
                                result: alt,
                                onTap: () => _v1HandleAlt(alt),
                              )),
                    ],

                    // ── Manual search fallback ──
                    // Prominent button when confidence is low; subtle link otherwise
                    if (widget.onManualSearch != null && !isMock) ...[
                      const SizedBox(height: 12),
                      if (tier == ConfidenceTier.low)
                        _prominentManualSearch()
                      else
                        InkWell(
                          onTap: _v1HandleManualSearch,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.search,
                                    color: Colors.white38, size: 15),
                                const SizedBox(width: 6),
                                Text(
                                  'Not the right breed? Search manually',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.white24,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],

                    const SizedBox(height: 16),

                    // Action buttons with share
                    Row(
                      children: [
                        // Small share icon (hidden for rare/legendary since they get the prominent button)
                        if (!isUnknown && !_isSpecial)
                          IconButton(
                            onPressed: _isSharing ? null : _shareDog,
                            icon: _isSharing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white54,
                                    ),
                                  )
                                : const Icon(Icons.share,
                                    color: Colors.white54, size: 20),
                            tooltip: 'Share',
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.06),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        if (!isUnknown && !_isSpecial) const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white54),
                            child: Text(widget.alreadyOwned ? 'OK' : 'Skip'),
                          ),
                        ),
                        if (!widget.alreadyOwned) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: !isMock && _isVerySlow
                                ? OutlinedButton(
                                    onPressed: () {
                                      HapticFeedback.mediumImpact();
                                      Navigator.pop(context);
                                      _v1HandleAdd();
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFFFAB91),
                                      side: BorderSide(
                                          color: const Color(0xFFFF7043)
                                              .withValues(alpha: 0.5)),
                                    ),
                                    child: const Text('Add Anyway'),
                                  )
                                : ElevatedButton(
                                    onPressed: () {
                                      HapticFeedback.mediumImpact();
                                      Navigator.pop(context);
                                      _v1HandleAdd();
                                    },
                                    child: const Text('Add to Kennel'),
                                  ),
                          ),
                        ],
                      ],
                    ),

                    // Prominent share button for rare/legendary finds
                    if (_isSpecial && !isUnknown) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSharing ? null : _shareDog,
                          icon: _isSharing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white70,
                                  ),
                                )
                              : const Icon(Icons.share, size: 18),
                          label: Text(
                              _isSharing ? 'Sharing...' : 'Share this catch!'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                dog.rarity.color.withValues(alpha: 0.25),
                            foregroundColor: dog.rarity.color,
                            side: BorderSide(
                                color: dog.rarity.color.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ).animate().fadeIn(delay: 600.ms),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),

        // Offscreen ShareDogCard for capture
        Positioned(
          left: -1000,
          top: -1000,
          child: RepaintBoundary(
            key: _shareCardKey,
            child: Material(
              color: Colors.transparent,
              child: ShareDogCard(
                dog: dog,
                playerLevel: playerState.level,
                playerTitle: playerState.title,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _masteryProgressSection() {
    final masteryState = ref.read(dogMasteryProvider);
    final info = masteryState.infoFor(dog.name);
    final level = info.level;
    final nextLevel = level.next;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: level.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: level.color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sighting logged confirmation
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade300, size: 16),
              const SizedBox(width: 6),
              Text(
                'Sighting logged',
                style: TextStyle(
                    color: Colors.green.shade300,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Mastery level and count
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(level.icon, color: level.color, size: 18),
              const SizedBox(width: 6),
              Text(
                'Spotted ${info.sightingCount} ${info.sightingCount == 1 ? "time" : "times"} \u2014 ${level.label}!',
                style: TextStyle(
                  color: level.color,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // Progress bar toward next level
          if (nextLevel != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: info.progressToNext,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(level.color),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${info.sightingsToNextLevel} more to ${nextLevel.label}',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              'Max mastery reached!',
              style: TextStyle(
                  color: Colors.amber.shade300,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _legendaryHeader(bool isMock) {
    return Column(
      children: [
        const Text('\u2728\u{1F3C6}\u2728', style: TextStyle(fontSize: 32))
            .animate(onPlay: (c) => c.repeat())
            .shimmer(
                duration: 2000.ms, color: Colors.amber.withValues(alpha: 0.8)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.amber.withValues(alpha: 0.3),
                  Colors.orange.withValues(alpha: 0.2),
                  Colors.amber.withValues(alpha: 0.3),
                ]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber),
              ),
              child: const Text(
                'LEGENDARY!',
                style: TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.5),
              ),
            ).animate().fadeIn().scale().then().shimmer(
                delay: 500.ms,
                duration: 1500.ms,
                color: Colors.amber.withValues(alpha: 0.4)),
            if (!isMock) ...[
              const SizedBox(width: 8),
              _confidenceBadge(),
            ],
          ],
        ),
      ],
    );
  }

  Widget _rareHeader(bool isMock) {
    return Column(
      children: [
        const Text('\u{1F48E}', style: TextStyle(fontSize: 36))
            .animate()
            .fadeIn()
            .scale(begin: const Offset(0.5, 0.5), curve: Curves.elasticOut),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF2196F3)),
              ),
              child: const Text(
                'RARE FIND!',
                style: TextStyle(
                    color: Color(0xFF2196F3),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1.2),
              ),
            ).animate().fadeIn().scale(),
            if (!isMock) ...[
              const SizedBox(width: 8),
              _confidenceBadge(),
            ],
          ],
        ),
      ],
    );
  }

  Widget _standardHeader(bool isMock) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: dog.rarity.color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: dog.rarity.color),
          ),
          child: Text(
            dog.rarity.label,
            style: TextStyle(
                color: dog.rarity.color,
                fontWeight: FontWeight.bold,
                fontSize: 12),
          ),
        ),
        if (!isMock) ...[
          const SizedBox(width: 8),
          _confidenceBadge(),
        ],
      ],
    ).animate().fadeIn().scale();
  }

  Widget _confidenceBadge() {
    final tier = _tier;
    final color = tier.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tier.icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            tier.label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// A mini horizontal bar that shows normalized confidence visually,
  /// avoiding raw percentages that confuse users.
  Widget _confidenceBar() {
    final tier = _tier;
    final normalizedValue = ConfidenceTier.normalizedDisplay(widget.confidence);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: tier.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(tier.icon, color: tier.color, size: 16),
              const SizedBox(width: 8),
              Text(
                tier.label,
                style: TextStyle(
                  color: tier.color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              // Show tier descriptor, not raw percentage
              Text(
                _tierDescriptor,
                style: TextStyle(
                  color: tier.color.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: normalizedValue),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation<Color>(tier.color),
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Human-readable descriptor that avoids showing raw percentages.
  String get _tierDescriptor {
    if (widget.confidence >= 0.50) return 'Very confident';
    if (widget.confidence >= 0.35) return 'Confident';
    if (widget.confidence >= 0.25) return 'Fairly sure';
    if (widget.confidence >= 0.20) return 'Reasonable match';
    if (widget.confidence >= 0.15) return 'Worth checking';
    return 'Best guess';
  }

  /// "Did you mean?" comparison card shown when top-2 are close.
  Widget _comparisonCard() {
    final alt = widget.alternatives.first;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.compare_arrows_rounded,
                  color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Could be either breed',
                style: TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Current pick
              Expanded(
                child: _ComparisonBreedTile(
                  name: dog.name,
                  imageUrl: dog.imageUrl,
                  confidence: widget.confidence,
                  isSelected: true,
                  onTap: null,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('or',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
              // Alternative
              Expanded(
                child: _ComparisonBreedTile(
                  name: alt.dog.name,
                  imageUrl: alt.dog.imageUrl,
                  confidence: alt.confidence,
                  isSelected: false,
                  onTap: widget.onSelectAlternative != null
                      ? () => _v1HandleAlt(alt)
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Prominent manual search fallback for low-confidence results.
  Widget _prominentManualSearch() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: OutlinedButton.icon(
        onPressed: _v1HandleManualSearch,
        icon: const Icon(Icons.search_rounded, size: 18),
        label: const Text('Search breeds manually'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.amber,
          side: BorderSide(color: Colors.amber.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _AlternativeChip extends StatelessWidget {
  final IdentificationResult result;
  final VoidCallback onTap;

  const _AlternativeChip({required this.result, required this.onTap});

  String get _altLabel {
    if (result.confidence >= 0.35) return 'Strong';
    if (result.confidence >= 0.20) return 'Good';
    return 'Possible';
  }

  Color get _altColor {
    if (result.confidence >= 0.35) return const Color(0xFF4CAF50);
    if (result.confidence >= 0.20) return const Color(0xFFFFB300);
    return const Color(0xFFFF7043);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              if (result.dog.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: NetworkDogImage(
                      url: result.dog.imageUrl,
                      height: 36,
                      width: 36,
                      fit: BoxFit.cover),
                )
              else
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: result.dog.rarity.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                      child: Text('\u{1F436}', style: TextStyle(fontSize: 18))),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.dog.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                    Text(
                      result.dog.scientificName,
                      style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _altColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _altColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _altLabel,
                  style: TextStyle(
                      color: _altColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact breed tile used inside the "Did you mean?" comparison card.
class _ComparisonBreedTile extends StatelessWidget {
  final String name;
  final String imageUrl;
  final double confidence;
  final bool isSelected;
  final VoidCallback? onTap;

  const _ComparisonBreedTile({
    required this.name,
    required this.imageUrl,
    required this.confidence,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tier = confidence >= 0.35
        ? ConfidenceTier.high
        : (confidence >= 0.20 ? ConfidenceTier.medium : ConfidenceTier.low);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.amber.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.amber.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Breed image thumbnail
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: NetworkDogImage(
                    url: imageUrl, height: 64, width: 64, fit: BoxFit.cover),
              )
            else
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                    child: Text('\u{1F436}', style: TextStyle(fontSize: 28))),
              ),
            const SizedBox(height: 8),
            // Breed name
            Text(
              name,
              style: TextStyle(
                color: isSelected ? Colors.amber : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Tier label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: tier.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tier.label,
                style: TextStyle(
                    color: tier.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ),
            // "Current pick" / "Tap to switch" label
            const SizedBox(height: 4),
            Text(
              isSelected ? 'Current pick' : 'Tap to switch',
              style: TextStyle(
                color: isSelected
                    ? Colors.amber.withValues(alpha: 0.6)
                    : Colors.white38,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
