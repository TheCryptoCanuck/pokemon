import 'dart:async';
import 'dart:io';

import 'package:flutter_animate/flutter_animate.dart';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';

import 'package:hive_flutter/hive_flutter.dart';

import 'package:dogquest/constants.dart';
import 'package:dogquest/helpers/game_helpers.dart';
import 'package:dogquest/models/dog.dart';
import 'package:dogquest/services/analytics_service.dart';
import 'package:dogquest/services/kennel_service.dart';
import 'package:dogquest/services/dog_service.dart';
import 'package:dogquest/services/daily_challenge_service.dart';
import 'package:dogquest/services/identification_orchestrator.dart';
import 'package:dogquest/services/identification_service.dart';
import 'package:dogquest/services/location_service.dart';
import 'package:dogquest/services/haptic_service.dart';
import 'package:dogquest/services/sighting_service.dart';
import 'package:dogquest/widgets/data_consent_dialog.dart';
import 'package:dogquest/widgets/achievement_unlock_overlay.dart';
import 'package:dogquest/widgets/dog_catch_animation.dart';
import 'package:dogquest/widgets/capture_button.dart';
import 'package:dogquest/widgets/dog_found_dialog.dart';
import 'package:dogquest/widgets/breed_share_sheet.dart';
import 'package:dogquest/widgets/mystery_bone_reveal.dart';
import 'package:dogquest/widgets/xp_gain_animation.dart';

final _log = Logger('IdentifyScreen');

class IdentifyScreen extends ConsumerStatefulWidget {
  const IdentifyScreen({super.key});

  @override
  ConsumerState<IdentifyScreen> createState() => _IdentifyScreenState();
}

class _IdentifyScreenState extends ConsumerState<IdentifyScreen>
    with WidgetsBindingObserver {
  static List<CameraDescription>? _cachedCameras;
  final _player = AudioPlayer();
  CameraController? _cam;
  bool _camReady = false;
  String? _cameraError;
  bool _identifying = false;

  bool _shutterFlash = false;

  // Zoom state
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _baseZoom = 1.0; // zoom level when pinch gesture starts
  final _viewfinderKey = GlobalKey();

  bool _hasSeenCoachMark = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final seen = Hive.box('hound_prefs')
          .get('hasSeenIdentifyPrompt', defaultValue: false) as bool;
      final sightings = ref.read(sightingServiceProvider).totalSightings;
      // Show coach mark only if user has never dismissed it AND has zero sightings.
      if (!seen && sightings == 0 && mounted) {
        setState(() => _hasSeenCoachMark = false);
      }
    });
    _initCameraAndLocation();
  }

  void _dismissCoachMark() {
    if (_hasSeenCoachMark) return;
    unawaited(Hive.box('hound_prefs').put('hasSeenIdentifyPrompt', true));
    if (mounted) setState(() => _hasSeenCoachMark = true);
  }

  Future<void> _initCameraAndLocation() async {
    await _initCamera();
    unawaited(
      _initLocation(),
    ); // fire-and-forget after camera permission completes (sec-C5)
  }

  /// Request location permission and pre-cache GPS coordinates for species filtering.
  Future<void> _initLocation() async {
    final locationSvc = ref.read(locationServiceProvider);
    final granted = await locationSvc.requestPermission();
    if (granted) {
      await locationSvc.getLocation();
      _log.info('GPS ready: ${locationSvc.latitude?.toStringAsFixed(2)}, '
          '${locationSvc.longitude?.toStringAsFixed(2)}');
    } else {
      _log.info('Location permission not granted — species filtering disabled');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanOverlay?.remove();
    _cam?.dispose();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _cam?.dispose();
      _cam = null;
      if (mounted) setState(() => _camReady = false);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = _cachedCameras ??= await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraError = 'No camera found on this device');
        return;
      }
      _cam = CameraController(cameras[0], ResolutionPreset.high);
      await _cam!.initialize();
      // Enable auto focus and exposure — not all HALs support these; swallow errors.
      try {
        await _cam!
            .setFocusMode(FocusMode.auto)
            .timeout(const Duration(seconds: 2));
        await _cam!
            .setExposureMode(ExposureMode.auto)
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
      if (!mounted) return;
      _minZoom = await _cam!.getMinZoomLevel();
      _maxZoom = await _cam!.getMaxZoomLevel();
      _currentZoom = _minZoom;
      setState(() => _camReady = true);
    } catch (e) {
      _log.warning('Camera init failed', e);
      if (!mounted) return;
      setState(() => _cameraError = 'Camera unavailable: ${_friendlyError(e)}');
    }
  }

  Future<void> _reinitCamera() async {
    try {
      setState(() => _camReady = false);
      await _cam?.dispose();
      _cam = null;
    } catch (_) {}
    await _initCamera();
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('permission') || msg.contains('Permission')) {
      return 'Camera permission denied';
    }
    if (msg.contains('CameraAccessDenied')) {
      return 'Camera access denied — check Settings';
    }
    return 'Could not start camera';
  }

  Future<void> _takePhoto() async {
    _dismissCoachMark();
    if (_identifying) return;
    if (_cam == null || !_camReady) {
      _log.warning('Camera not ready, reinitializing...');
      await _reinitCamera();
      return;
    }
    setState(() {
      _identifying = true;
      _shutterFlash = true;
    });
    // Brief white flash for shutter feedback
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _shutterFlash = false);
    });
    try {
      final file = await _cam!.takePicture();
      if (!mounted) return;
      ref.read(analyticsProvider).track('identify_attempted', {
        'method': 'photo',
      });
      await _identify(File(file.path));
    } catch (e) {
      _log.warning('Photo capture failed', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not capture photo — please try again'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _identifying = false);
      }
      // Reinitialize camera — resumePreview is unreliable on some devices
      if (mounted) {
        await _reinitCamera();
      }
    }
  }

  Future<void> _pickFromGallery() async {
    _dismissCoachMark();
    if (_identifying) return;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;
      setState(() => _identifying = true);
      ref.read(analyticsProvider).track('identify_attempted', {
        'method': 'gallery',
      });
      await _identify(File(picked.path));
    } catch (e) {
      _log.warning('Gallery pick failed', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load image from gallery')),
      );
    } finally {
      if (mounted) setState(() => _identifying = false);
    }
  }

  OverlayEntry? _scanOverlay;
  bool _identifyCancelled = false;

  void _showScanOverlay() {
    _identifyCancelled = false;
    _scanOverlay?.remove();
    _scanOverlay = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: Container(
          color: Colors.black54,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    color: Colors.amber,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sniffing for a match...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    _identifyCancelled = true;
                    _scanOverlay?.remove();
                    _scanOverlay = null;
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_scanOverlay!);
  }

  void _removeScanOverlay() {
    _scanOverlay?.remove();
    _scanOverlay = null;
  }

  Future<void> _identify(File imageFile) async {
    final idService = ref.read(identificationServiceProvider);

    // Guard: model must be loaded before attempting identification
    if (!idService.isModelLoaded) {
      _log.warning('ML model not loaded — cannot identify');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Dog identification model is still loading — please wait a moment',
          ),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    _showScanOverlay();

    List<IdentificationResult> rawResults;
    try {
      rawResults = await idService
          .identify(imageFile)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      if (!mounted) return;
      _removeScanOverlay();
      _log.warning('Visual identification timed out after 15s');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Identification timed out — please try again'),
        ),
      );
      return;
    }
    if (!mounted || _identifyCancelled) {
      _removeScanOverlay();
      return;
    }
    _removeScanOverlay();
    if (!mounted) return;

    // Dog breeds are globally distributed (domesticated), so geographic
    // filtering is not applicable — pass results through unmodified.
    final results = rawResults;

    if (results.isEmpty) {
      ref.read(analyticsProvider).track('identify_failed', {
        'method': 'photo',
        'raw_results': rawResults.length,
        'filtered_out': rawResults.length,
      });
      if (!mounted) return;
      _showNoResultDialog();
      return;
    }

    // Handle unrecognized sentinel — model detected something but no breed match
    if (results.first.isUnrecognized) {
      ref.read(analyticsProvider).track('identify_unrecognized', {
        'method': 'photo',
      });
      if (!mounted) return;
      _showNoResultDialog(showManualSearch: true);
      return;
    }

    final top = results.first;
    ref.read(analyticsProvider).track('identify_succeeded', {
      'dog_name': top.dog.name,
      'rarity': top.dog.rarity.name,
      'confidence': top.confidence,
      'source': top.source,
      'alternative_count': results.length - 1,
      'location_filtered': rawResults.length != results.length,
    });

    if (!mounted) return;

    // Show low-confidence guidance if the top result is weak
    if (results.first.confidence < 0.15 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFB8860B), // dark amber
          duration: const Duration(seconds: 5),
          content: const Row(
            children: [
              Icon(Icons.photo_camera_outlined, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Photo is blurry or distant — results may be less accurate.',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'Retake',
            textColor: Colors.amber,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              _reinitCamera();
            },
          ),
        ),
      );
    }
    _showFoundDialog(results);
  }

  void _showNoResultDialog({bool showManualSearch = false}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            const Text('No match found', style: TextStyle(color: Colors.amber)),
        content: Text(
          showManualSearch
              ? 'Could not match this dog to a known breed. You can search for the breed manually, or try a different photo.'
              : 'The dog may be too small or distant in the photo.\n\nTry moving closer or zooming in before taking the shot.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          if (showManualSearch) ...[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Try Again'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showBreedSearchDialog();
              },
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Search Breeds'),
            ),
          ] else ...[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Dismiss'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _reinitCamera();
              },
              child: const Text('Retake'),
            ),
          ],
        ],
      ),
    );
  }

  void _showBreedSearchDialog() {
    final dogService = ref.read(dogServiceProvider);
    showDialog(
      context: context,
      builder: (ctx) => _BreedSearchDialog(
        dogService: dogService,
        onSelect: (dog) {
          Navigator.pop(ctx);
          ref.read(analyticsProvider).track('manual_breed_selected', {
            'dog_name': dog.name,
          });
          _showFoundDialog([
            IdentificationResult(dog: dog, confidence: 1.0, source: 'manual'),
          ]);
        },
      ),
    );
  }

  void _showFoundDialog(List<IdentificationResult> results) {
    final topResult = results.first;
    final alternatives =
        results.length > 1 ? results.sublist(1) : <IdentificationResult>[];
    final kennelSvc = ref.read(kennelServiceProvider);
    final alreadyOwned = kennelSvc.contains(topResult.dog.name);

    // Inject Poodle (generic) as an alternative when a poodle variant is identified
    final dogService = ref.read(dogServiceProvider);
    final poodleAlt = dogService.poodleAlternative(topResult.dog.name);
    final allAlternatives = [...alternatives];
    if (poodleAlt != null &&
        !allAlternatives.any((a) => a.dog.name == poodleAlt.name) &&
        topResult.dog.name != poodleAlt.name) {
      allAlternatives.add(
        IdentificationResult(
          dog: poodleAlt,
          confidence: topResult.confidence * 0.8,
          source: topResult.source,
        ),
      );
    }

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (ctx, _, __) => DogFoundDialog(
        dog: topResult.dog,
        confidence: topResult.confidence,
        source: topResult.source,
        alternatives: allAlternatives,
        alreadyOwned: alreadyOwned,
        onAdd: () => _addDog(
          topResult.dog,
          confidence: topResult.confidence,
          source: topResult.source,
        ),
        onSelectAlternative: (alt) {
          ref.read(analyticsProvider).track('alternative_selected', {
            'original_dog': topResult.dog.name,
            'selected_dog': alt.dog.name,
          });
          Navigator.pop(ctx);
          _showFoundDialog([alt, ...results.where((r) => r != alt)]);
        },
        onManualSearch: () {
          Navigator.pop(ctx);
          _showBreedSearchDialog();
        },
      ),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  Future<void> _addDog(
    Dog dog, {
    double confidence = 0.0,
    String source = 'ml',
  }) async {
    final alreadyOwned = ref.read(kennelServiceProvider).contains(dog.name);

    // ── Delegate all business logic to the orchestrator ──────────────────
    final orchestrator = ref.read(identificationOrchestratorProvider);
    final outcome = await orchestrator.processIdentification(
      dog,
      confidence,
      source,
    );
    if (!mounted) return;

    // ── UI: Data consent prompt (needs BuildContext) ─────────────────────
    if (outcome.hasLocation && mounted) {
      DataConsentDialog.showIfNeeded(context);
    }

    // ── UI: Catch animation (fires immediately, ~2.5s) ──────────────────
    DogCatchAnimation.show(
      context,
      dogName: dog.name,
      rarity: dog.rarity,
      confidence: confidence,
      isNew: !alreadyOwned,
    );

    // If already owned, no further UI to show
    if (!outcome.isNewDog) return;

    // ── UI: XP gain animation (merged timing with catch) ────────────────
    if (mounted) {
      XpGainAnimation.show(
        context,
        xp: outcome.xpEarned,
        streakMultiplier:
            outcome.totalMultiplier > 1.0 ? outcome.totalMultiplier : null,
        didLevelUp: outcome.leveledUp,
        newLevel: outcome.leveledUp ? outcome.newLevel : null,
      );
    }

    // ── UI: Daily dog bonus snackbar ────────────────────────────────────
    if (outcome.isDailyDogBonus && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.amber.withValues(alpha: 0.9),
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              const Text('⭐', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily Dog Bonus!',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '+${outcome.dailyDogBonusXp} bonus XP',
                    style: const TextStyle(color: Colors.black87),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // ── UI: Queued rewards — hard-capped at 5 000 ms total ──────────────
    // Timing budget:
    //   0–2 800 ms  : catch animation runs (base delay)
    //   2 800 ms    : mystery bone reveal (if any)
    //   2 800/3 000 ms + : achievement overlays, staggered 1 500 ms apart
    //   ≤ 5 000 ms  : share prompt (capped regardless of chain length)
    const kBaseDelayMs = 2800;
    const kAchievementStaggerMs = 1500;
    const kMaxShareDelayMs = 5000;

    var delayMs = kBaseDelayMs;

    if (outcome.mysteryReward != null) {
      Future.delayed(Duration(milliseconds: delayMs), () {
        if (!mounted) return;
        HapticService.celebration();
        MysteryBoneReveal.show(context, reward: outcome.mysteryReward!);
      });
      // Mystery runs in parallel — offset achievements by only 400 ms so
      // they don't obscure the reveal but the chain doesn't stall waiting.
      delayMs += 400;
    }

    // Queue achievements with a tight stagger so all fit inside the budget.
    for (final key in outcome.achievementsUnlocked) {
      final a = achievements[key];
      if (a == null) continue;
      Future.delayed(Duration(milliseconds: delayMs), () {
        if (!mounted) return;
        HapticService.achievement();
        AchievementUnlockOverlay.show(
          context,
          achievementKey: key,
          emoji: a.$1,
          title: a.$2,
          description: a.$3,
        );
      });
      delayMs += kAchievementStaggerMs;
    }

    // ── UI: Encounter milestone snackbar (after all overlays) ────────────
    if (outcome.milestoneText != null && mounted) {
      Future.delayed(Duration(milliseconds: delayMs), () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.deepPurple.withValues(alpha: 0.9),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            content: Row(
              children: [
                const Text('🔄', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    outcome.milestoneText!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      });
    }

    // ── UI: Share prompt — cap to kMaxShareDelayMs regardless of chain ──
    final isSpecialFind =
        dog.rarity == Rarity.rare || dog.rarity == Rarity.legendary;
    final shareDelayMs =
        (delayMs + (isSpecialFind ? 500 : 300)).clamp(0, kMaxShareDelayMs);
    if (isSpecialFind) {
      // Auto-show share sheet for rare/legendary finds
      Future.delayed(Duration(milliseconds: shareDelayMs), () {
        if (!mounted) return;
        BreedShareSheet.show(context, dog);
      });
    } else {
      // Subtle snackbar with share action for common/uncommon
      Future.delayed(Duration(milliseconds: shareDelayMs), () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: bgCard,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            content: const Text(
              'New breed added!',
              style: TextStyle(color: Colors.white70),
            ),
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.amber,
              onPressed: () {
                if (mounted) BreedShareSheet.show(context, dog);
              },
            ),
          ),
        );
      });
    }

    // ── Audio playback (in background, non-blocking) ─────────────────────
    if (outcome.hasAudio) {
      _player.setUrl(outcome.audioUrl).then((_) {
        if (mounted) _player.play();
      }).catchError((e) {
        _log.fine('Audio playback failed for ${dog.name}: $e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Camera viewfinder fills all available space
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Camera preview or error state ──
              if (_camReady && _cam != null)
                AnimatedOpacity(
                  opacity: _camReady ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  child: GestureDetector(
                    key: _viewfinderKey,
                    onScaleStart: (_) => _baseZoom = _currentZoom,
                    onScaleUpdate: (details) {
                      final newZoom =
                          (_baseZoom * details.scale).clamp(_minZoom, _maxZoom);
                      if ((newZoom - _currentZoom).abs() > 0.05) {
                        _currentZoom = newZoom;
                        _cam?.setZoomLevel(
                          _currentZoom,
                        ); // fire-and-forget to avoid HAL race
                        setState(() {});
                      }
                    },
                    // Tap-to-focus disabled for beta — setFocusPoint blocks
                    // the platform channel on some Android HALs (Sony XQ-CT54),
                    // freezing the entire app. Autofocus via FocusMode.auto
                    // set during _initCamera() still works.
                    // TODO: re-enable after camera package upgrade or isolate workaround
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(24),
                      ),
                      child: CameraPreview(_cam!),
                    ),
                  ),
                )
              else
                _CameraLoadingWidget(
                  cameraError: _cameraError,
                  onRetry: _initCamera,
                  onGallery: _pickFromGallery,
                ),

              // ── Shutter flash overlay (always mounted so animation plays) ──
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _shutterFlash ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(color: Colors.white),
                ),
              ),

              // ── Zoom level indicator ──
              if (_currentZoom > _minZoom + 0.05)
                Positioned(
                  bottom: 100,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${_currentZoom.toStringAsFixed(1)}x',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Daily challenge progress pill — hidden while coach mark is active ──
              if (_hasSeenCoachMark)
                const Positioned(
                  bottom: 130,
                  left: 0,
                  right: 0,
                  child: Center(child: _DailyChallengePill()),
                ),

              // ── First-time tip (#7) — hidden while coach mark is active ──
              if (!_camReady || _identifying || !_hasSeenCoachMark)
                const SizedBox.shrink()
              else
                const _FirstTimeTip(),

              // ── Bottom controls: gallery, capture button ──
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Gallery picker button (left) with label
                    Semantics(
                      label: 'Pick image from gallery',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Material(
                            color: Colors.black45,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: _pickFromGallery,
                              child: const Padding(
                                padding: EdgeInsets.all(14),
                                child: Icon(
                                  Icons.photo_library_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Gallery',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 28),
                    // Main capture button (center) — wrapped with coach mark on first visit
                    if (_hasSeenCoachMark)
                      CaptureButton(
                        onTap: _takePhoto,
                        isProcessing: _identifying,
                        mode: CaptureMode.photo,
                      )
                    else
                      Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: -44,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Start here.',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.amber,
                                width: 3,
                              ),
                            ),
                          )
                              .animate(onPlay: (c) => c.repeat())
                              .scale(
                                begin: const Offset(0.85, 0.85),
                                end: const Offset(1.45, 1.45),
                                duration: 900.ms,
                                curve: Curves.easeOut,
                              )
                              .fadeOut(
                                duration: 900.ms,
                                curve: Curves.easeOut,
                              ),
                          CaptureButton(
                            onTap: _takePhoto,
                            isProcessing: _identifying,
                            mode: CaptureMode.photo,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Manual breed search dialog ──────────────────────────────────────────
class _BreedSearchDialog extends StatefulWidget {
  final DogService dogService;
  final ValueChanged<Dog> onSelect;

  const _BreedSearchDialog({required this.dogService, required this.onSelect});

  @override
  State<_BreedSearchDialog> createState() => _BreedSearchDialogState();
}

class _BreedSearchDialogState extends State<_BreedSearchDialog> {
  final _controller = TextEditingController();
  List<Dog> _results = [];

  @override
  void initState() {
    super.initState();
    _results = widget.dogService.searchBreeds('', limit: 30);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() {
      _results = widget.dogService.searchBreeds(query, limit: 30);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Search Breeds',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type breed name...',
                  hintStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: _onSearch,
              ),
              const SizedBox(height: 12),
              Flexible(
                child: _results.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No breeds match your search',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _results.length,
                        itemBuilder: (ctx, i) {
                          final dog = _results[i];
                          return ListTile(
                            dense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: dog.rarity.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.pets,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                              ),
                            ),
                            title: Text(
                              dog.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              dog.habitat,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: dog.rarity.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                dog.rarity.label,
                                style: TextStyle(
                                  color: dog.rarity.color,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            onTap: () => widget.onSelect(dog),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// _DailyDogPill and _PriorityContextBanner removed — camera overlays
// moved to result screen per Sprint 9 Phase 3 design critique.

// ── Daily challenge progress pill — visible only to new users (< 10 sightings)
class _DailyChallengePill extends ConsumerWidget {
  const _DailyChallengePill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dailyChallengeProvider);
    final completed = state.challenges.where((c) => c.completed).length;
    final total = state.challenges.length;

    // Hide once all challenges are done or all have been completed at least once.
    if (total == 0 || completed == total) return const SizedBox.shrink();

    // Hide for experienced users — they know to check the profile.
    final sightingCount = ref.read(sightingServiceProvider).totalSightings;
    if (sightingCount >= 10) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.amber, size: 13),
          const SizedBox(width: 6),
          Text(
            'Daily: $completed / $total',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Camera loading / error placeholder ─────────────────────────────────
class _CameraLoadingWidget extends StatefulWidget {
  final String? cameraError;
  final VoidCallback onRetry;
  final VoidCallback onGallery;

  const _CameraLoadingWidget({
    required this.cameraError,
    required this.onRetry,
    required this.onGallery,
  });

  @override
  State<_CameraLoadingWidget> createState() => _CameraLoadingWidgetState();
}

class _CameraLoadingWidgetState extends State<_CameraLoadingWidget> {
  static const _tips = [
    'Point at any dog to identify it!',
    'Try the Gallery for saved photos',
    'Discover $kDeployedBreedCount breeds!',
    'Earn XP for every new breed',
  ];

  int _tipIndex = 0;
  Timer? _tipTimer;

  @override
  void initState() {
    super.initState();
    if (widget.cameraError == null) {
      _tipTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (mounted) {
          setState(() => _tipIndex = (_tipIndex + 1) % _tips.length);
        }
      });
    }
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.cameraError != null;

    return Semantics(
      label: hasError
          ? 'Camera is not available.'
          : 'Camera is loading. Please wait.',
      child: GestureDetector(
        onTap: hasError ? widget.onRetry : null,
        child: Container(
          decoration: const BoxDecoration(
            color: bgCard,
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
          ),
          child: Center(
            child: hasError ? _buildErrorState() : _buildLoadingState(),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.videocam_off_rounded,
          size: 64,
          color: Colors.white70,
        ),
        const SizedBox(height: 12),
        const Text(
          'Camera not available',
          style: TextStyle(color: textSecondary, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Tap to retry',
          style: TextStyle(color: Colors.amber, fontSize: 14),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: widget.onGallery,
          icon: const Icon(Icons.photo_library_rounded, size: 18),
          label: const Text('Use Gallery instead'),
          style: TextButton.styleFrom(foregroundColor: accent),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.pets, size: 80, color: accent)
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              begin: const Offset(1.0, 1.0),
              end: const Offset(1.05, 1.05),
              duration: 2000.ms,
              curve: Curves.easeInOut,
            ),
        const SizedBox(height: 16),
        const Text(
          'Preparing camera...',
          style: TextStyle(color: textSecondary, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: Text(
            '\u{1F4A1} ${_tips[_tipIndex]}',
            key: ValueKey<int>(_tipIndex),
            style: const TextStyle(color: textMuted, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

// ── First-time tip overlay (#7) ─────────────────────────────────────────
class _FirstTimeTip extends ConsumerWidget {
  const _FirstTimeTip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kennelSvc = ref.read(kennelServiceProvider);
    if (kennelSvc.count > 0) return const SizedBox.shrink();

    return Positioned(
      bottom: 160,
      left: 24,
      right: 24,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.pets, color: Colors.black87, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Point at a dog and tap the button to identify the breed!',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
