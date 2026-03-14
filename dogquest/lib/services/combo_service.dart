import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Combo state for rapid consecutive identifications, persisted to Hive.
class ComboState {
  final int count;
  final double multiplier;
  final DateTime? expiresAt;
  final bool isActive;

  const ComboState({
    this.count = 0,
    this.multiplier = 1.0,
    this.expiresAt,
    this.isActive = false,
  });

  /// Seconds remaining until this combo expires, or 0 if inactive.
  int get secondsRemaining {
    if (expiresAt == null || !isActive) return 0;
    final remaining = expiresAt!.difference(DateTime.now()).inSeconds;
    return remaining.clamp(0, _comboWindowSeconds);
  }
}

/// Duration of the combo window in seconds (24 hours).
const int _comboWindowSeconds = 86400;

/// Multiplier tiers: 1 ID = 1x, 2 IDs = 1.2x, 3 IDs = 1.5x, 4+ IDs = 2.0x.
double _multiplierForCount(int count) {
  if (count <= 1) return 1.0;
  if (count == 2) return 1.2;
  if (count == 3) return 1.5;
  return 2.0;
}

class ComboNotifier extends StateNotifier<ComboState> {
  final Box _box;

  ComboNotifier(this._box) : super(const ComboState()) {
    _restore();
  }

  Timer? _expiryTimer;

  /// Restore combo from Hive on startup.
  void _restore() {
    final expiresMs = _box.get('combo_expires_ms') as int?;
    final count = _box.get('combo_count') as int? ?? 0;
    if (expiresMs == null || count == 0) return;

    final expiry = DateTime.fromMillisecondsSinceEpoch(expiresMs);
    final remaining = expiry.difference(DateTime.now());
    if (remaining.isNegative) {
      // Combo expired while app was closed
      _box.delete('combo_expires_ms');
      _box.delete('combo_count');
      return;
    }

    state = ComboState(
      count: count,
      multiplier: _multiplierForCount(count),
      expiresAt: expiry,
      isActive: true,
    );

    _expiryTimer = Timer(remaining, _resetCombo);
  }

  /// Record a new identification — increments combo and resets the timer.
  void recordIdentification() {
    _expiryTimer?.cancel();

    final newCount = state.count + 1;
    final expiry =
        DateTime.now().add(const Duration(seconds: _comboWindowSeconds));

    state = ComboState(
      count: newCount,
      multiplier: _multiplierForCount(newCount),
      expiresAt: expiry,
      isActive: true,
    );

    _box.put('combo_count', newCount);
    _box.put('combo_expires_ms', expiry.millisecondsSinceEpoch);

    _expiryTimer = Timer(
      const Duration(seconds: _comboWindowSeconds),
      _resetCombo,
    );
  }

  /// Current multiplier (1.0 when no combo is active).
  double get currentMultiplier => state.multiplier;

  /// Whether a combo is currently active.
  bool get isActive => state.isActive;

  void _resetCombo() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _box.delete('combo_count');
    _box.delete('combo_expires_ms');
    state = const ComboState();
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }
}

final comboProvider = StateNotifierProvider<ComboNotifier, ComboState>((ref) {
  throw UnimplementedError('comboProvider must be overridden after Hive init');
});
