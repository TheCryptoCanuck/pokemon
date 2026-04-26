import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'package:dogquest/services/api_client.dart';

final _log = Logger('SocialService');

class SocialService {
  final ApiClient _api;

  SocialService({required ApiClient apiClient}) : _api = apiClient;

  // ── Leaderboard ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchLeaderboard() async {
    try {
      final response = await _api.dio.get('/leaderboard');
      return List<Map<String, dynamic>>.from(response.data);
    } on DioException catch (e) {
      _log.warning('Failed to fetch leaderboard: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchWeeklyLeaderboard() async {
    try {
      final response = await _api.dio.get('/leaderboard/weekly');
      return List<Map<String, dynamic>>.from(response.data);
    } on DioException catch (e) {
      _log.warning('Failed to fetch weekly leaderboard: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchFriendsLeaderboard() async {
    try {
      final response = await _api.dio.get('/friends/leaderboard');
      return List<Map<String, dynamic>>.from(response.data);
    } on DioException catch (e) {
      _log.warning('Failed to fetch friends leaderboard: $e');
      return [];
    }
  }

  // ── Friends ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> fetchFriends() async {
    try {
      final response = await _api.dio.get('/friends');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      _log.warning('Failed to fetch friends: $e');
      return null;
    }
  }

  Future<bool> sendFriendRequest(int userId) async {
    try {
      await _api.dio.post('/friends/request/$userId');
      return true;
    } on DioException catch (e) {
      _log.warning('Failed to send friend request: $e');
      return false;
    }
  }

  Future<bool> acceptFriendRequest(int friendshipId) async {
    try {
      await _api.dio.post('/friends/accept/$friendshipId');
      return true;
    } on DioException catch (e) {
      _log.warning('Failed to accept friend request: $e');
      return false;
    }
  }

  Future<bool> removeFriend(int friendshipId) async {
    try {
      await _api.dio.delete('/friends/$friendshipId');
      return true;
    } on DioException catch (e) {
      _log.warning('Failed to remove friend: $e');
      return false;
    }
  }

  // ── User Search ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final response = await _api.dio.get(
        '/users/search',
        queryParameters: {'q': query},
      );
      return List<Map<String, dynamic>>.from(response.data);
    } on DioException catch (e) {
      _log.warning('Failed to search users: $e');
      return [];
    }
  }
}

final socialServiceProvider = Provider<SocialService>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return SocialService(apiClient: apiClient);
});
