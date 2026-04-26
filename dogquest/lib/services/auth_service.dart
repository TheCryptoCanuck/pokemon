import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';

import 'package:dogquest/services/api_client.dart';

final _log = Logger('AuthService');

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  final ApiClient _api;

  AuthService(this._api);

  Future<bool> register(String username, String email, String password) async {
    try {
      final response = await _api.dio.post(
        '/auth/register',
        data: {
          'username': username,
          'email': email,
          'password': password,
        },
      );
      final token = response.data['access_token'] as String;
      await _api.saveToken(token);
      Hive.box('dogquest_player_stats').put('has_auth_token', true);
      _log.info('Registered successfully: $username');
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw AuthException('Email or username already taken');
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw AuthException('Cannot reach server — check your connection');
      }
      throw AuthException('Registration failed: ${e.message}');
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      final response = await _api.dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );
      final token = response.data['access_token'] as String;
      await _api.saveToken(token);
      Hive.box('dogquest_player_stats').put('has_auth_token', true);
      _log.info('Logged in successfully');
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw AuthException('Invalid email or password');
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw AuthException('Cannot reach server — check your connection');
      }
      throw AuthException('Login failed: ${e.message}');
    }
  }

  Future<void> logout() async {
    await _api.clearToken();
    Hive.box('dogquest_player_stats').put('has_auth_token', false);
    _log.info('Logged out');
  }

  Future<bool> get isAuthenticated => _api.isAuthenticated;
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(apiClientProvider));
});
