import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';

import 'package:dogquest/constants.dart';
import 'package:dogquest/helpers/game_helpers.dart';
import 'package:dogquest/models/dog.dart';
import 'package:dogquest/services/analytics_service.dart';
import 'package:dogquest/services/kennel_service.dart';
import 'package:dogquest/services/dog_service.dart';
import 'package:dogquest/services/daily_dog_service.dart';
import 'package:dogquest/services/daily_challenge_service.dart';
import 'package:dogquest/services/identification_orchestrator.dart';
import 'package:dogquest/services/identification_service.dart';
import 'package:dogquest/services/location_service.dart';
import 'package:dogquest/services/haptic_service.dart';
import 'package:dogquest/widgets/data_consent_dialog.dart';
import 'package:dogquest/widgets/achievement_unlock_overlay.dart';
import 'package:dogquest/widgets/dog_catch_animation.dart';
import 'package:dogquest/widgets/capture_button.dart';
import 'package:dogquest/widgets/dog_found_dialog.dart';
import 'package:dogquest/widgets/breed_share_sheet.dart';
import 'package:dogquest/widgets/combo_counter.dart';
import 'package:dogquest/widgets/flash_challenge_banner.dart';
import 'package:dogquest/widgets/mystery_bone_reveal.dart';
import 'package:dogquest/widgets/seasonal_event_banner.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCameraAndLocation();
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
      _cam = CameraController(cameras[0], ResolutionPreset.medium);
      await _cam!.initialize();
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
                    style: TextStyle(color: Colors.white54, fontSize: 14),
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
              : 'Could not identify a dog in this photo. Try getting a clearer shot with the dog centered in frame.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Try Again'),
          ),
          if (showManualSearch)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showBreedSearchDialog();
              },
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Search Breeds'),
            ),
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

    showDialog(
      context: context,
      builder: (ctx) => DogFoundDialog(
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

    // ── UI: Queued rewards (mystery bone, then achievements, spaced out) ─
    var delayMs = 2800; // after catch animation finishes

    if (outcome.mysteryReward != null) {
      Future.delayed(Duration(milliseconds: delayMs), () {
        if (!mounted) return;
        HapticService.celebration();
        MysteryBoneReveal.show(context, reward: outcome.mysteryReward!);
      });
      delayMs += 2800;
    }

    // Queue achievements one at a time
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
      delayMs += 3000;
    }

    // ── UI: Encounter milestone snackbar (after all overlays) ────────────
    if (outcome.milestoneText != null && mounted) {
      Future.delayed(Duration(milliseconds: delayMs), () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.deepPurple.withValues(alpha: 0.9),
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

    // ── UI: Share prompt (after all overlays settle) ────────────────────
    final isSpecialFind =
        dog.rarity == Rarity.rare || dog.rarity == Rarity.legendary;
    if (isSpecialFind) {
      // Auto-show share sheet for rare/legendary finds
      Future.delayed(Duration(milliseconds: delayMs + 500), () {
        if (!mounted) return;
        BreedShareSheet.show(context, dog);
      });
    } else {
      // Subtle snackbar with share action for common/uncommon
      Future.delayed(Duration(milliseconds: delayMs + 300), () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: bgCard,
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
    final topPadding = MediaQuery.of(context).padding.top;

    return Column(
      children: [
        // Camera viewfinder fills all available space
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Camera preview or error state ──
              if (_camReady && _cam != null)
                GestureDetector(
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
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(24),
                    ),
                    child: CameraPreview(_cam!),
                  ),
                )
              else
                GestureDetector(
                  onTap: _cameraError != null ? _initCamera : null,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: bgCard,
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(24),
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _cameraError != null
                                ? Icons.videocam_off_rounded
                                : Icons.camera_alt,
                            size: 64,
                            color: Colors.white24,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _cameraError != null
                                ? 'Camera not available'
                                : 'Camera loading...',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_cameraError != null) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Tap to retry',
                              style:
                                  TextStyle(color: Colors.amber, fontSize: 14),
                            ),
                          ] else ...[
                            const SizedBox(height: 12),
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white24,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Shutter flash overlay (always mounted so animation plays) ──
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _shutterFlash ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(color: Colors.white),
                ),
              ),

              // ── Top overlays (compact pills to preserve viewfinder) ──
              Positioned(
                top: topPadding + 8,
                left: 12,
                right: 80, // leave room for combo counter
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FlashChallengeBanner(),
                    SeasonalEventBanner(),
                    _DailyDogPill(),
                  ],
                ),
              ),

              // ── Combo counter overlay (offset below top overlays) ──
              Positioned(
                top: topPadding + 8,
                right: 12,
                child: const ComboCounter(),
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

              // ── Daily challenge progress pill (#10) ──
              const Positioned(
                bottom: 130,
                left: 0,
                right: 0,
                child: Center(child: _DailyChallengePill()),
              ),

              // ── First-time tip (#7) ──
              if (!_camReady || _identifying)
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
                                TextStyle(color: Colors.white54, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 28),
                    // Main capture button (center)
                    CaptureButton(
                      onTap: _takePhoto,
                      isProcessing: _identifying,
                      mode: CaptureMode.photo,
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
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38),
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
                            style: TextStyle(color: Colors.white38),
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
                                  color: Colors.white54,
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
                                color: Colors.white38,
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

// ── Compact daily dog pill for camera overlay (#5) ──────────────────────
class _DailyDogPill extends ConsumerWidget {
  const _DailyDogPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailySvc = ref.watch(dailyDogServiceProvider);
    final dog = dailySvc.todaysDog;
    final claimed = dailySvc.isBonusClaimed;

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wb_sunny, color: Colors.amber, size: 14),
          const SizedBox(width: 6),
          Text(
            claimed
                ? '${dog.name} (claimed)'
                : '${dog.name} — ${DailyDogService.bonusMultiplier}x XP',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Daily challenge progress pill for camera screen (#10) ───────────────
class _DailyChallengePill extends ConsumerWidget {
  const _DailyChallengePill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dailyChallengeProvider);
    final completed = state.challenges.where((c) => c.completed).length;
    final total = state.challenges.length;
    if (total == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            completed == total ? Icons.check_circle : Icons.flag_rounded,
            color: completed == total ? Colors.green : Colors.amber,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            completed == total
                ? 'Challenges complete!'
                : '$completed/$total challenges',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
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
