import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _log = Logger('SupabaseAuthService');

class SupabaseAuthException implements Exception {
  final String message;
  SupabaseAuthException(this.message);
  @override
  String toString() => message;
}

class SupabaseAuthService {
  final SupabaseClient _client;

  SupabaseAuthService(this._client);

  /// Current session (null if not logged in).
  Session? get currentSession => _client.auth.currentSession;

  /// Current user (null if not logged in).
  User? get currentUser => _client.auth.currentUser;

  /// Whether the user has an active session.
  bool get isAuthenticated => currentSession != null;

  /// Stream of auth state changes for router/UI reactivity.
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// Register with email/password. Passes username and display_name as user metadata.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
    String? displayName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username,
          'display_name': displayName ?? username,
        },
      );
      _log.info('Signed up: $email');
      return response;
    } on AuthException catch (e) {
      _log.warning('Sign up failed: ${e.message}');
      throw SupabaseAuthException(_friendlyMessage(e.message));
    }
  }

  /// Sign in with email/password.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      _log.info('Signed in: $email');
      return response;
    } on AuthException catch (e) {
      _log.warning('Sign in failed: ${e.message}');
      throw SupabaseAuthException(_friendlyMessage(e.message));
    }
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
      _log.info('Signed out');
    } on AuthException catch (e) {
      _log.warning('Sign out failed: ${e.message}');
      throw SupabaseAuthException(e.message);
    }
  }

  /// Send a password reset email.
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      _log.info('Password reset email sent to $email');
    } on AuthException catch (e) {
      _log.warning('Password reset failed: ${e.message}');
      throw SupabaseAuthException(_friendlyMessage(e.message));
    }
  }

  /// Sign in with OAuth (Google, Apple).
  Future<bool> signInWithOAuth(OAuthProvider provider) async {
    try {
      final success = await _client.auth.signInWithOAuth(
        provider,
        redirectTo: 'com.dogquest.app://login-callback',
      );
      _log.info('OAuth sign in initiated: ${provider.name}');
      return success;
    } on AuthException catch (e) {
      _log.warning('OAuth sign in failed: ${e.message}');
      throw SupabaseAuthException(_friendlyMessage(e.message));
    }
  }

  /// Convert Supabase error messages to user-friendly strings.
  String _friendlyMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'Invalid email or password';
    }
    if (lower.contains('user already registered')) {
      return 'An account with this email already exists';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please check your email to confirm your account';
    }
    if (lower.contains('password') && lower.contains('short')) {
      return 'Password must be at least 6 characters';
    }
    return raw;
  }
}

/// Riverpod provider for SupabaseAuthService.
final supabaseAuthServiceProvider = Provider<SupabaseAuthService>((ref) {
  return SupabaseAuthService(Supabase.instance.client);
});

/// Stream provider for auth state changes (used by router refreshListenable).
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseAuthServiceProvider).onAuthStateChange;
});
