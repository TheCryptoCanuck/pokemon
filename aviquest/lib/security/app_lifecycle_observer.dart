import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Observes app lifecycle transitions and applies security measures:
/// - Clears sensitive in-memory data when app is paused/detached
/// - Compacts Hive storage on resume to reduce data leakage window
class AppLifecycleSecurityObserver extends WidgetsBindingObserver {
  final VoidCallback? onSecurityPause;
  final VoidCallback? onSecurityResume;

  AppLifecycleSecurityObserver({
    this.onSecurityPause,
    this.onSecurityResume,
  });

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _onAppBackgrounded();
        break;
      case AppLifecycleState.resumed:
        _onAppResumed();
        break;
      default:
        break;
    }
  }

  void _onAppBackgrounded() {
    // Compact Hive to minimize on-disk data exposure
    _compactHiveBoxes();
    onSecurityPause?.call();
  }

  void _onAppResumed() {
    onSecurityResume?.call();
  }

  void _compactHiveBoxes() {
    // Compact open boxes to reduce disk footprint
    for (final boxName in ['aviary_v2']) {
      if (Hive.isBoxOpen(boxName)) {
        Hive.box(boxName).compact();
      }
    }
  }
}
