import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:texerp/core/l10n/locale_cubit.dart';
import 'package:texerp/core/network/token_provider.dart';
import 'package:texerp/core/storage/secure_storage.dart';

/// Attaches the current access token and locale to every outgoing request.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenProvider, this._localeCubit);

  final TokenProvider _tokenProvider;
  final LocaleCubit _localeCubit;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokenProvider.accessToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    options.headers['Accept-Language'] = _localeCubit.state.languageCode;
    options.headers['Content-Type'] = 'application/json';
    handler.next(options);
  }
}

/// Handles 401 responses by exchanging the refresh token and retrying the
/// original request. On refresh failure the session is cleared and the caller
/// is notified to log the user out.
class RefreshInterceptor extends QueuedInterceptor {
  RefreshInterceptor(
    this._dio,
    this._secureStorage,
    this._tokenProvider,
    this._onSessionExpired,
    this._onAccessTokenRefreshed,
  );

  final Dio _dio;
  final SecureStorage _secureStorage;
  final TokenProvider _tokenProvider;
  final VoidCallback _onSessionExpired;
  final ValueChanged<String> _onAccessTokenRefreshed;

  bool _isRefreshing = false;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final statusCode = err.response?.statusCode;
    final path = err.requestOptions.path;

    if (statusCode != 401 || path == '/auth/refresh' || path == '/auth/login') {
      handler.next(err);
      return;
    }

    final refreshToken = await _secureStorage.loadRefreshToken();
    if (refreshToken == null) {
      _triggerLogout();
      handler.reject(err);
      return;
    }

    if (_isRefreshing) {
      handler.reject(err);
      return;
    }

    _isRefreshing = true;
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final data = response.data?['data'] as Map<String, dynamic>?;
      final newAccess = data?['access_token'] as String?;
      final newRefresh = data?['refresh_token'] as String?;

      if (newAccess == null) {
        throw Exception('Refresh response did not contain access_token');
      }

      _tokenProvider.accessToken = newAccess;
      if (newRefresh != null) {
        await _secureStorage.saveTokens(access: newAccess, refresh: newRefresh);
      }
      _onAccessTokenRefreshed(newAccess);

      final options = err.requestOptions;
      options.headers['Authorization'] = 'Bearer $newAccess';
      final retryResponse = await _dio.fetch(options);
      handler.resolve(retryResponse);
    } catch (_) {
      _triggerLogout();
      handler.reject(err);
    } finally {
      _isRefreshing = false;
    }
  }

  void _triggerLogout() {
    _tokenProvider.accessToken = null;
    _onSessionExpired();
  }
}
