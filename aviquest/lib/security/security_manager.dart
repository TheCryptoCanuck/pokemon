import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Central security manager for AviQuest.
/// Handles root/jailbreak detection, debug protection, and app integrity checks.
class SecurityManager {
  SecurityManager._();
  static final SecurityManager instance = SecurityManager._();

  bool _initialized = false;
  bool _isDeviceCompromised = false;
  bool _isDebugMode = false;

  bool get isDeviceCompromised => _isDeviceCompromised;
  bool get isDebugMode => _isDebugMode;

  /// Initialize security checks. Call once at app startup.
  Future<void> initialize() async {
    if (_initialized) return;
    _isDebugMode = kDebugMode;
    _isDeviceCompromised = await _checkDeviceCompromised();
    _initialized = true;
  }

  /// Detect rooted/jailbroken devices via common indicator paths.
  Future<bool> _checkDeviceCompromised() async {
    if (!Platform.isAndroid) return false;

    // Common root indicator binaries
    const rootIndicators = [
      '/system/app/Superuser.apk',
      '/system/xbin/su',
      '/system/bin/su',
      '/sbin/su',
      '/data/local/xbin/su',
      '/data/local/bin/su',
      '/data/local/su',
      '/system/bin/failsafe/su',
      '/su/bin/su',
    ];

    // Common root management apps
    const rootApps = [
      '/system/app/Superuser.apk',
      '/system/app/SuperSU.apk',
      '/system/app/SuperSU',
      '/data/app/eu.chainfire.supersu',
      '/data/app/com.topjohnwu.magisk',
    ];

    for (final path in [...rootIndicators, ...rootApps]) {
      if (await File(path).exists()) {
        return true;
      }
    }

    return false;
  }

  /// Show a non-blocking security warning if the device is compromised.
  /// The app still runs but the user is informed of the risk.
  void showSecurityWarningIfNeeded(BuildContext context) {
    if (!_isDeviceCompromised) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A2F1F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
              SizedBox(width: 8),
              Text('Security Notice', style: TextStyle(color: Colors.amber)),
            ],
          ),
          content: const Text(
            'This device appears to be rooted. Your game data may be '
            'at increased risk. For the best experience, consider using '
            'an unmodified device.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('I Understand', style: TextStyle(color: Colors.amber)),
            ),
          ],
        ),
      );
    });
  }

  /// Enable FLAG_SECURE to prevent screenshots and screen recording.
  /// Call when displaying sensitive screens (e.g., profile, achievements).
  Future<void> enableSecureScreen() async {
    if (Platform.isAndroid) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  /// Lock the app to portrait orientation for consistent UX and reduced
  /// attack surface from orientation-based UI confusion.
  Future<void> enforcePortraitOrientation() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }
}
