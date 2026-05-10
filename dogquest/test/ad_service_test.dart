// test/ad_service_test.dart
//
// Unit tests for AdService frequency-cap and time-cap business logic.
//
// Strategy:
//   • Use AdService.testOnly() to skip the real ad-network load.
//   • Inject a MockInterstitialAd via the @visibleForTesting setter so that
//     showInterstitialIfReady() can reach the show() call and update
//     _lastShownAt — letting us assert on timing state without a real SDK.
//   • Focus entirely on counting / timing logic; ad rendering is not tested.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:dogquest/services/ad_service.dart';

// ---------------------------------------------------------------------------
// Mock
// ---------------------------------------------------------------------------

class MockInterstitialAd extends Mock implements InterstitialAd {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Returns a service with a fresh mock ad injected and ready to show.
AdService _serviceWithAd(MockInterstitialAd ad) {
  final svc = AdService.testOnly();
  when(() => ad.fullScreenContentCallback = any()).thenReturn(null);
  when(() => ad.show()).thenAnswer((_) async {});
  svc.interstitialAd = ad;
  return svc;
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const FullScreenContentCallback<InterstitialAd>(),
    );
  });

  // ─── onIdentificationComplete — counter behaviour ───────────────────────

  group('onIdentificationComplete — counter', () {
    test('counter starts at zero', () {
      final svc = AdService.testOnly();
      expect(svc.identificationCount, equals(0));
    });

    test('each call increments counter by 1', () {
      final svc = AdService.testOnly();
      svc.onIdentificationComplete();
      expect(svc.identificationCount, equals(1));
      svc.onIdentificationComplete();
      expect(svc.identificationCount, equals(2));
    });

    test('counter reaches 3 after three calls', () {
      final svc = AdService.testOnly();
      svc.onIdentificationComplete();
      svc.onIdentificationComplete();
      svc.onIdentificationComplete();
      expect(svc.identificationCount, equals(3));
    });
  });

  // ─── Frequency cap — counts 1 and 2 do NOT trigger show ─────────────────

  group('frequency cap — below threshold', () {
    test('count 1: show is never triggered', () {
      final ad = MockInterstitialAd();
      when(() => ad.fullScreenContentCallback = any()).thenReturn(null);
      when(() => ad.show()).thenAnswer((_) async {});
      final svc = AdService.testOnly()..interstitialAd = ad;
      svc.onIdentificationComplete(); // count = 1
      verifyNever(() => ad.show());
    });

    test('count 2: show is never triggered', () {
      final ad = MockInterstitialAd();
      when(() => ad.fullScreenContentCallback = any()).thenReturn(null);
      when(() => ad.show()).thenAnswer((_) async {});
      final svc = AdService.testOnly()..interstitialAd = ad;
      svc.onIdentificationComplete();
      svc.onIdentificationComplete(); // count = 2
      verifyNever(() => ad.show());
    });
  });

  // ─── Frequency cap — count 3 triggers show ──────────────────────────────

  group('frequency cap — threshold hit', () {
    test('count == 3 triggers ad show and records lastShownAt', () {
      final ad = MockInterstitialAd();
      final svc = _serviceWithAd(ad);

      svc.onIdentificationComplete();
      svc.onIdentificationComplete();
      svc.onIdentificationComplete(); // count = 3

      verify(() => ad.show()).called(1);
      expect(svc.lastShownAt, isNotNull);
    });
  });

  // ─── Time cap — 5-minute cooldown ───────────────────────────────────────

  group('time cap (5-minute cooldown)', () {
    test('show within 5 min of previous is blocked', () {
      final ad = MockInterstitialAd();
      when(() => ad.fullScreenContentCallback = any()).thenReturn(null);
      when(() => ad.show()).thenAnswer((_) async {});
      final svc = AdService.testOnly()
        ..interstitialAd = ad
        ..lastShownAt = DateTime.now().subtract(const Duration(minutes: 2));

      final result = svc.showInterstitialIfReady();

      expect(
        result,
        isFalse,
        reason: 'Last show was only 2 min ago — must be blocked',
      );
      verifyNever(() => ad.show());
    });

    test('show is allowed after exactly 5 minutes', () {
      final ad = MockInterstitialAd();
      final svc = _serviceWithAd(ad)
        ..lastShownAt = DateTime.now().subtract(const Duration(minutes: 5));

      final result = svc.showInterstitialIfReady();

      expect(result, isTrue);
      verify(() => ad.show()).called(1);
    });

    test('show is allowed when no previous show exists (lastShownAt == null)',
        () {
      final ad = MockInterstitialAd();
      final svc = _serviceWithAd(ad);
      expect(svc.lastShownAt, isNull);

      final result = svc.showInterstitialIfReady();

      expect(result, isTrue);
      verify(() => ad.show()).called(1);
    });
  });

  // ─── showInterstitialIfReady directly ───────────────────────────────────

  group('showInterstitialIfReady', () {
    test('returns false when no ad is loaded', () {
      final svc = AdService.testOnly(); // no ad injected
      expect(svc.showInterstitialIfReady(), isFalse);
    });

    test('returns true and shows ad when loaded and timecap satisfied', () {
      final ad = MockInterstitialAd();
      final svc = _serviceWithAd(ad);
      expect(svc.showInterstitialIfReady(), isTrue);
    });

    test('returns false when timecap not satisfied', () {
      final ad = MockInterstitialAd();
      when(() => ad.fullScreenContentCallback = any()).thenReturn(null);
      when(() => ad.show()).thenAnswer((_) async {});
      final svc = AdService.testOnly()
        ..interstitialAd = ad
        ..lastShownAt = DateTime.now().subtract(const Duration(seconds: 30));

      expect(svc.showInterstitialIfReady(), isFalse);
    });
  });

  // ─── Rolling window — 6th identification triggers second show ───────────

  group('rolling frequency cap', () {
    test('6th identification triggers a second show after cooldown', () {
      final ad1 = MockInterstitialAd();
      when(() => ad1.fullScreenContentCallback = any()).thenReturn(null);
      when(() => ad1.show()).thenAnswer((_) async {});

      final svc = AdService.testOnly()..interstitialAd = ad1;

      // First batch: counts 1-3 → show at 3.
      svc.onIdentificationComplete();
      svc.onIdentificationComplete();
      svc.onIdentificationComplete();
      verify(() => ad1.show()).called(1);

      // Simulate 6-minute cooldown and reload a fresh ad.
      svc.lastShownAt = DateTime.now().subtract(const Duration(minutes: 6));
      final ad2 = MockInterstitialAd();
      when(() => ad2.fullScreenContentCallback = any()).thenReturn(null);
      when(() => ad2.show()).thenAnswer((_) async {});
      svc.interstitialAd = ad2;

      // Second batch: counts 4-6 → show at 6 (next multiple of 3).
      svc.onIdentificationComplete();
      svc.onIdentificationComplete();
      svc.onIdentificationComplete();
      verify(() => ad2.show()).called(1);
    });
  });
}
