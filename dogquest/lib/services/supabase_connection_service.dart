import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _log = Logger('SupabaseConnectionService');

enum ConnectionStatus { connected, disconnected, connecting }

class SupabaseConnectionService {
  final Connectivity _connectivity = Connectivity();
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  ConnectionStatus _currentStatus = ConnectionStatus.connecting;

  ConnectionStatus get currentStatus => _currentStatus;
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  SupabaseConnectionService() {
    _init();
  }

  void _init() {
    // Check initial connectivity
    _checkConnection();

    // Listen for connectivity changes
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      if (results.contains(ConnectivityResult.none)) {
        _updateStatus(ConnectionStatus.disconnected);
      } else {
        _checkConnection();
      }
    });
  }

  Future<void> _checkConnection() async {
    _updateStatus(ConnectionStatus.connecting);
    try {
      // Quick health check — try to read from Supabase
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        _updateStatus(ConnectionStatus.connected);
      } else {
        // No session but we have network — still "connected" to Supabase infra
        final results = await _connectivity.checkConnectivity();
        if (results.contains(ConnectivityResult.none)) {
          _updateStatus(ConnectionStatus.disconnected);
        } else {
          _updateStatus(ConnectionStatus.connected);
        }
      }
    } catch (e) {
      _log.warning('Connection check failed: $e');
      _updateStatus(ConnectionStatus.disconnected);
    }
  }

  void _updateStatus(ConnectionStatus status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      _statusController.add(status);
      _log.fine('Connection status: $status');
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
    _statusController.close();
  }
}

/// Riverpod provider for the connection service (singleton).
final supabaseConnectionServiceProvider = Provider<SupabaseConnectionService>((ref) {
  final svc = SupabaseConnectionService();
  ref.onDispose(() => svc.dispose());
  return svc;
});

/// Stream provider for reactive UI updates.
final connectionStatusProvider = StreamProvider<ConnectionStatus>((ref) {
  final svc = ref.watch(supabaseConnectionServiceProvider);
  return svc.statusStream;
});
