import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:dogquest/constants.dart';

class SplashScreen extends StatefulWidget {
  final Stream<String> statusStream;
  final Stream<double> progressStream;

  const SplashScreen({
    super.key,
    required this.statusStream,
    required this.progressStream,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _showLogo = false;
  bool _showTitle = false;
  bool _showTagline = false;
  bool _showProgress = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Stagger each element's entrance
      setState(() => _showLogo = true);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _showTitle = true);
      });
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _showTagline = true);
      });
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _showProgress = true);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDeep,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dog logo — scale + fade
            AnimatedScale(
              scale: _showLogo ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 1200),
              curve: Curves.elasticOut,
              child: AnimatedOpacity(
                opacity: _showLogo ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Image.asset(
                    'assets/splash_logo.png',
                    width: 140,
                    height: 140,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // App name — slide up + fade
            AnimatedSlide(
              offset: _showTitle ? Offset.zero : const Offset(0, 0.5),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _showTitle ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                child: const Text(
                  'Hound',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Tagline — fade
            AnimatedOpacity(
              opacity: _showTagline ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeIn,
              child: const Text(
                'Discover. Identify. Collect.',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 48),

            // Progress bar + status
            AnimatedOpacity(
              opacity: _showProgress ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeIn,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: StreamBuilder<double>(
                        stream: widget.progressStream,
                        initialData: 0.0,
                        builder: (context, snap) {
                          final p = snap.data ?? 0.0;
                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: p),
                            duration: const Duration(milliseconds: 300),
                            builder: (context, value, _) {
                              return LinearProgressIndicator(
                                value: value > 0 ? value : null,
                                minHeight: 4,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.06),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.amber,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<String>(
                      stream: widget.statusStream,
                      initialData: '',
                      builder: (context, snap) {
                        final status = snap.data ?? '';
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            status,
                            key: ValueKey(status),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
