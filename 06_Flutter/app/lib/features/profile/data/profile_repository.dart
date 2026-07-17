import 'package:dio/dio.dart';

import 'package:texerp/core/error/network_exception.dart';
import 'package:texerp/core/network/api_client.dart';
import 'package:texerp/features/auth/data/auth_models.dart';

/// Repository for profile-related operations.
class ProfileRepository {
  ProfileRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Fetches the current user profile.
  Future<UserProfile> getProfile() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>('/users/me');
      final data = response.data!['data'] as Map<String, dynamic>;
      return UserProfile.fromJson(data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  NetworkException _mapDioError(DioException e) {
    final response = e.response;
    if (response != null) {
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final error = data['error'] as Map<String, dynamic>?;
        final code = error?['code'] as String? ?? 'UNKNOWN_ERROR';
        final message = error?['message'] as String? ?? e.message ?? 'Unknown error';
        return NetworkException(code: code, message: message);
      }
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const NetworkException(code: 'NETWORK_ERROR', message: 'No internet connection');
    }
    return NetworkException(code: 'UNKNOWN_ERROR', message: e.message ?? 'Unknown error');
  }
}
