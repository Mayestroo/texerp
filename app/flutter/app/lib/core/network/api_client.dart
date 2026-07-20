import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:texerp/core/l10n/locale_cubit.dart';
import 'package:texerp/core/network/auth_interceptor.dart';
import 'package:texerp/core/network/token_provider.dart';
import 'package:texerp/core/storage/secure_storage.dart';

/// Configured Dio client for the TexERP backend.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required SecureStorage secureStorage,
    required TokenProvider tokenProvider,
    required LocaleCubit localeCubit,
  }) : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        ) {
    _dio.interceptors.addAll(
      <Interceptor>[
        AuthInterceptor(tokenProvider, localeCubit),
        RefreshInterceptor(
          _dio,
          secureStorage,
          tokenProvider,
          () => onSessionExpired?.call(),
          (token) => onAccessTokenRefreshed?.call(token),
        ),
        if (kDebugMode) LogInterceptor(requestBody: true, responseBody: true),
      ],
    );
  }

  final Dio _dio;

  Dio get dio => _dio;

  VoidCallback? onSessionExpired;
  ValueChanged<String>? onAccessTokenRefreshed;
}
