import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:dogquest/services/data_consent_service.dart';

/// A reusable banner ad widget for Hound.
///
/// Displays a 320x50 AdMob banner ad. Falls back to Google's test ad unit
/// in debug mode. Silently handles load failures without showing error UI.
class HoundBannerAd extends StatefulWidget {
  const HoundBannerAd({super.key});

  @override
  State<HoundBannerAd> createState() => _HoundBannerAdState();
}

class _HoundBannerAdState extends State<HoundBannerAd> {
  /// Google's documented test banner ad unit. Used in debug only.
  /// Source: https://developers.google.com/admob/android/test-ads
  static const String _testAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  /// Production banner ID — MUST be passed via --dart-define in release.
  /// Empty default prevents serving Google's test unit to real users
  /// when an ADMOB_BANNER_ID isn't configured.
  static const String _configuredAdUnitId = String.fromEnvironment(
    'ADMOB_BANNER_ID',
  );

  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  String get _adUnitId {
    if (kDebugMode) {
      return _testAdUnitId;
    }
    return _configuredAdUnitId;
  }

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  AdRequest get _adRequest {
    if (DataConsentService.hasConsented) {
      return const AdRequest();
    }
    return const AdRequest(nonPersonalizedAds: true);
  }

  void _loadAd() {
    if (_adUnitId.isEmpty) {
      developer.log(
        'HoundBannerAd skipped: ADMOB_BANNER_ID not configured '
        'for this build (expected in release without --dart-define).',
        name: 'HoundBannerAd',
        level: 700, // INFO
      );
      return;
    }
    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      size: AdSize.banner,
      request: _adRequest,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          developer.log(
            'HoundBannerAd failed to load: ${error.message}',
            name: 'HoundBannerAd',
            level: 900, // WARNING
          );
          ad.dispose();
          if (mounted) {
            setState(() {
              _bannerAd = null;
              _isAdLoaded = false;
            });
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 50,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
