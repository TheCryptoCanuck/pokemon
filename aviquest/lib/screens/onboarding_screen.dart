import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../constants.dart';
import '../services/analytics_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  /// Returns true if onboarding has been completed.
  static bool isComplete() {
    final box = Hive.box('player_stats');
    return box.get('onboarding_complete', defaultValue: false) as bool;
  }

  /// Marks onboarding as complete.
  static void markComplete() {
    Hive.box('player_stats').put('onboarding_complete', true);
  }

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPage(
      icon: '🐦',
      title: 'Welcome to AviQuest',
      body: 'Your pocket bird identification companion.\n\n'
          'Snap a photo of any bird and our on-device AI will identify it instantly — no internet required.',
    ),
    _OnboardingPage(
      icon: '📸',
      title: 'Identify & Collect',
      body: 'Point your camera at a bird and tap Identify.\n\n'
          'Build your personal aviary by collecting species. '
          'Common backyard visitors to legendary rarities — every bird earns XP.',
    ),
    _OnboardingPage(
      icon: '🏆',
      title: 'Level Up & Learn',
      body: 'Earn XP for every bird you find. Unlock achievements. '
          'Keep your daily streak alive.\n\n'
          'Along the way, discover the fascinating stories behind each species.',
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
      ref.read(analyticsProvider).track('onboarding_completed');
      OnboardingScreen.markComplete();
      widget.onComplete();
    }
  }

  void _skip() {
    ref.read(analyticsProvider).track('onboarding_skipped', {
      'skipped_at_page': _currentPage,
    });
    OnboardingScreen.markComplete();
    widget.onComplete();
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
                child: const Text('Skip', style: TextStyle(color: Colors.white38)),
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

            // Action button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  child: Text(
                    _currentPage == _pages.length - 1 ? "Let's Go!" : 'Next',
                  ),
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
          Text(page.icon, style: const TextStyle(fontSize: 80))
              .animate().fadeIn().scale(),
          const SizedBox(height: 24),
          Text(
            page.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.amber,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 100.ms),
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
    );
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
