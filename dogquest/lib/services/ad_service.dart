import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logging/logging.dart';

/// Riverpod provider for the [AdService] singleton.
final adServiceProvider = Provider<AdService>((ref) => AdService());

/// Manages interstitial ad loading and display for Hound.
///
/// Frequency cap: shows an interstitial after every 3rd breed identification.
/// Time cap: at most one interstitial per 5 minutes.
///
/// **Prohibited screens** (callers must not trigger ads on these):
/// camera, result overlay, onboarding, login, register, lost dog report, settings.
class AdService {
  AdService() {
    _loadInterstitial();
  }

  /// Named constructor for unit tests — skips the real ad-network load.
  @visibleForTesting
  AdService.testOnly();

  // Expose internal state for white-box testing.
  @visibleForTesting
  int get identificationCount => _identificationCount;

  @visibleForTesting
  DateTime? get lastShownAt => _lastShownAt;

  @visibleForTesting
  set lastShownAt(DateTime? value) => _lastShownAt = value;

  @visibleForTesting
  set interstitialAd(InterstitialAd? ad) => _interstitialAd = ad;

  static final _log = Logger('AdService');

  /// Google's documented test ad-unit ID. Used in debug builds only.
  /// Source: https://developers.google.com/admob/android/test-ads
  static const _testInterstitialId = 'ca-app-pub-3940256099942544/1033173712';

  /// Production ad-unit ID — MUST be passed via --dart-define in release.
  /// Empty default keeps test-ad fallout out of production: a release build
  /// without ADMOB_INTERSTITIAL_ID returns empty, which `_adUnitId` skips
  /// rather than serving Google's test unit to real users (policy risk).
  static const _configuredInterstitialId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ID',
  );

  /// Resolved ad-unit ID. In debug, always test. In release, only the
  /// configured ID — never the test fallback (returns empty string if
  /// unconfigured; callers must check `isAdUnitConfigured`).
  static String get _adUnitId {
    if (kDebugMode) return _testInterstitialId;
    return _configuredInterstitialId;
  }

  /// True when an ad-unit ID is available for the current build mode.
  static bool get isAdUnitConfigured => _adUnitId.isNotEmpty;

  /// Minimum duration between two interstitial displays.
  static const _minInterval = Duration(minutes: 5);

  /// Show an ad every N identifications.
  static const _frequencyCap = 3;

  InterstitialAd? _interstitialAd;
  int _identificationCount = 0;
  DateTime? _lastShownAt;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Call after each successful breed identification.
  ///
  /// Increments the internal counter and, when both the frequency cap (every
  /// 3rd identification) and the time cap (5-minute cooldown) are satisfied,
  /// automatically shows the preloaded interstitial.
  void onIdentificationComplete() {
    _identificationCount++;
    _log.fine('Identification count: $_identificationCount');

    if (_identificationCount % _frequencyCap == 0 && _isTimecapRespected()) {
      showInterstitialIfReady();
    }
  }

  /// Shows the interstitial ad if one is loaded and the time cap allows it.
  ///
  /// Returns `true` when the ad was actually shown.
  bool showInterstitialIfReady() {
    if (_interstitialAd == null) {
      _log.fine('Interstitial not ready — skipping.');
      return false;
    }

    if (!_isTimecapRespected()) {
      _log.fine('Time cap not yet elapsed — skipping.');
      return false;
    }

    try {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          _log.fine('Interstitial dismissed.');
          ad.dispose();
          _interstitialAd = null;
          _loadInterstitial();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          _log.warning('Interstitial failed to show: $error');
          ad.dispose();
          _interstitialAd = null;
          _loadInterstitial();
        },
      );

      _interstitialAd!.show();
      _lastShownAt = DateTime.now();
      _log.info('Interstitial shown.');
      return true;
    } catch (e, st) {
      _log.severe('Error showing interstitial', e, st);
      _interstitialAd?.dispose();
      _interstitialAd = null;
      _loadInterstitial();
      return false;
    }
  }

  /// Disposes the currently loaded interstitial, if any.
  void dispose() {
    try {
      _interstitialAd?.dispose();
      _interstitialAd = null;
      _log.fine('AdService disposed.');
    } catch (e, st) {
      _log.warning('Error disposing interstitial', e, st);
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  void _loadInterstitial() {
    if (!isAdUnitConfigured) {
      _log.fine(
        'Skipping interstitial load: ADMOB_INTERSTITIAL_ID not configured '
        'for this build (expected in release without --dart-define).',
      );
      return;
    }
    try {
      InterstitialAd.load(
        adUnitId: _adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _log.fine('Interstitial loaded.');
          },
          onAdFailedToLoad: (error) {
            _interstitialAd = null;
            _log.warning('Interstitial failed to load: $error');
          },
        ),
      );
    } catch (e, st) {
      _log.severe('Error requesting interstitial load', e, st);
    }
  }

  bool _isTimecapRespected() {
    if (_lastShownAt == null) return true;
    return DateTime.now().difference(_lastShownAt!) >= _minInterval;
  }
}
