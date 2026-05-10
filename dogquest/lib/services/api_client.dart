import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';

final _log = Logger('ApiClient');

class ApiClient {
  late final Dio dio;
  final FlutterSecureStorage _storage;

  static const String _baseUrl = String.fromEnvironment('API_BASE_URL');

  static void assertBaseUrl() {
    if (_baseUrl.isEmpty) {
      throw ArgumentError(
        'API_BASE_URL must be set via --dart-define=API_BASE_URL=https://... '
        'The old 10.0.2.2 default has been removed; it only worked on Android '
        'emulators and would silently fail on iOS and physical devices.',
      );
    }
  }

  ApiClient({
    String? baseUrl,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'jwt_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            _log.warning('Auth token expired or invalid — clearing auth state');
            await _storage.delete(key: 'jwt_token');
            // Clear Hive auth flag so router redirects to login
            final box = Hive.box('dogquest_player_stats');
            box.put('has_auth_token', false);
          }
          handler.next(error);
        },
      ),
    );

    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: false,
          responseBody: false,
          logPrint: (obj) => _log.fine('$obj'),
        ),
      );
    }
  }

  Future<void> saveToken(String token) =>
      _storage.write(key: 'jwt_token', value: token);

  Future<String?> getToken() => _storage.read(key: 'jwt_token');

  Future<void> clearToken() => _storage.delete(key: 'jwt_token');

  Future<bool> get isAuthenticated async => (await getToken()) != null;
}

final apiClientProvider = Provider<ApiClient>((ref) {
  throw UnimplementedError('apiClientProvider must be overridden at startup');
});
