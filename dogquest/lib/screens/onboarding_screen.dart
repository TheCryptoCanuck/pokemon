import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dogquest/constants.dart';
import 'package:dogquest/services/analytics_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  /// Called when user chooses "Start scanning" (guest mode).
  /// If null, falls back to [onComplete].
  final VoidCallback? onStartGuest;

  const OnboardingScreen({
    super.key,
    required this.onComplete,
    this.onStartGuest,
  });

  /// Returns true if onboarding has been completed.
  static bool isComplete() {
    final box = Hive.box('dogquest_player_stats');
    return box.get('onboarding_complete', defaultValue: false) as bool;
  }

  /// Marks onboarding as complete.
  static void markComplete() {
    Hive.box('dogquest_player_stats').put('onboarding_complete', true);
  }

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPage(
      icon: '🐶',
      title: 'Welcome to Hound',
      body: 'Your pocket dog identification companion.\n\n'
          'Snap a photo of any dog and our on-device AI will identify it instantly — no internet required.',
    ),
    _OnboardingPage(
      icon: '📸',
      title: 'Identify & Collect',
      body: 'Point your camera at a dog and tap Identify.\n\n'
          'Build your breed collection by identifying dogs. '
          'Common backyard visitors to legendary rarities — every dog earns XP.',
    ),
    _OnboardingPage(
      icon: '🏆',
      title: 'Level Up & Learn',
      body: 'Earn XP for every dog you find. Unlock achievements. '
          'Keep your daily streak alive.\n\n'
          'Along the way, discover the fascinating history behind each breed.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback so ref is accessible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsProvider).track('onboarding_started');
    });
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(duration: 300.ms, curve: Curves.easeInOut);
    } else {
      // Last page "Next" should not be reachable — buttons replace it.
      // Fallback: start as guest.
      unawaited(_startAsGuest('onboarding_completed'));
    }
  }

  /// Sets offline_mode = true then navigates to the scan screen.
  Future<void> _startAsGuest(String analyticsEvent) async {
    ref.read(analyticsProvider).track(analyticsEvent, {'path': 'guest'});
    OnboardingScreen.markComplete();
    await Hive.box('dogquest_player_stats').put('offline_mode', true);
    (widget.onStartGuest ?? widget.onComplete)();
  }

  void _skip() {
    ref.read(analyticsProvider).track('onboarding_skipped', {
      'skipped_at_page': _currentPage,
    });
    unawaited(_startAsGuest('onboarding_skipped_guest'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _skip,
                child:
                    const Text('Skip', style: TextStyle(color: Colors.white38)),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) {
                  setState(() => _currentPage = i);
                  ref.read(analyticsProvider).track('onboarding_page_viewed', {
                    'page': i,
                    'page_title': _pages[i].title,
                  });
                },
                itemBuilder: (_, i) => _buildPage(_pages[i]),
              ),
            ),

            // Page indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _currentPage;
                return AnimatedContainer(
                  duration: 300.ms,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? Colors.amber : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),

            // Action button(s)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: _currentPage == _pages.length - 1
                  ? Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => unawaited(
                                _startAsGuest('onboarding_completed')),
                            child: const Text('Start scanning →'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () {
                              ref.read(analyticsProvider).track(
                                  'onboarding_completed', {'path': 'account'});
                              OnboardingScreen.markComplete();
                              widget.onComplete();
                            },
                            child: const Text(
                              'Create account',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _next,
                        child: const Text('Next'),
                      ),
                    ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A3A1A), Color(0xFF2A5A2A)],
              ),
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(page.icon, style: const TextStyle(fontSize: 40)),
            ),
          ).animate().fadeIn().scale(),
          const SizedBox(height: 24),
          Text(
            page.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.amber,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 100.ms).scale(
                begin: const Offset(0.95, 0.95),
                delay: 100.ms,
              ),
          const SizedBox(height: 16),
          Text(
            page.body,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.98, 0.98));
  }
}

class _OnboardingPage {
  final String icon;
  final String title;
  final String body;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
  });
}
