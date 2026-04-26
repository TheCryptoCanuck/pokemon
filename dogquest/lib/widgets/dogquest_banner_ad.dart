import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:dogquest/services/data_consent_service.dart';

/// A reusable banner ad widget for DogQuest.
///
/// Displays a 320x50 AdMob banner ad. Falls back to Google's test ad unit
/// in debug mode. Silently handles load failures without showing error UI.
class DogQuestBannerAd extends StatefulWidget {
  const DogQuestBannerAd({super.key});

  @override
  State<DogQuestBannerAd> createState() => _DogQuestBannerAdState();
}

class _DogQuestBannerAdState extends State<DogQuestBannerAd> {
  static const String _testAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  static const String _configuredAdUnitId = String.fromEnvironment(
    'ADMOB_BANNER_ID',
    defaultValue: _testAdUnitId,
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
            'DogQuestBannerAd failed to load: ${error.message}',
            name: 'DogQuestBannerAd',
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
