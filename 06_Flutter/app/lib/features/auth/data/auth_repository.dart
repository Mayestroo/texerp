import 'package:dio/dio.dart';

import 'package:texerp/core/error/network_exception.dart';
import 'package:texerp/core/network/api_client.dart';
import 'package:texerp/core/storage/secure_storage.dart';
import 'package:texerp/features/auth/data/auth_models.dart';

/// Repository for authentication operations.
class AuthRepository {
  AuthRepository({required ApiClient apiClient, required SecureStorage secureStorage})
      : _apiClient = apiClient,
        _secureStorage = secureStorage;

  final ApiClient _apiClient;
  final SecureStorage _secureStorage;

  /// Logs in with phone + PIN, persists the refresh token and returns the
  /// user profile together with the in-memory access token.
  Future<(UserProfile user, String accessToken)> login({
    required String phone,
    required String pin,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'phone': phone, 'pin': pin},
      );
      final loginResponse = LoginResponse.fromJson(response.data!);
      await _secureStorage.saveTokens(
        access: loginResponse.accessToken,
        refresh: loginResponse.refreshToken,
      );
      return (loginResponse.user, loginResponse.accessToken);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Exchanges a refresh token for a new access token.
  Future<String> refreshToken(String refreshToken) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      final accessToken = data['access_token'] as String;
      final newRefreshToken = data['refresh_token'] as String?;
      if (newRefreshToken != null) {
        await _secureStorage.saveTokens(
          access: accessToken,
          refresh: newRefreshToken,
        );
      }
      return accessToken;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Revokes the current refresh token on the backend and clears local tokens.
  Future<void> logout() async {
    final refreshToken = await _secureStorage.loadRefreshToken();
    if (refreshToken != null) {
      try {
        await _apiClient.dio.post<Map<String, dynamic>>(
          '/auth/logout',
          data: {'refresh_token': refreshToken},
        );
      } on DioException {
        // Still clear local tokens even if the server call fails.
      }
    }
    await _secureStorage.clearTokens();
  }

  /// Fetches the currently authenticated user profile.
  Future<UserProfile> getProfile(String userId) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>('/users/$userId');
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
