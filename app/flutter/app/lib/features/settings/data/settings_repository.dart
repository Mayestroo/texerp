import 'package:dio/dio.dart';

import 'package:texerp/core/error/network_exception.dart';
import 'package:texerp/core/network/api_client.dart';
import 'package:texerp/features/settings/data/settings_models.dart';

class SettingsRepository {
  SettingsRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<TenantSettings> fetchSettings() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/settings',
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return TenantSettings.fromJson(data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<TenantSettings> updateSettings({
    int? backDateWindowDays,
    int? suspiciousQuantityMultiplier,
    int? payrollMinPay,
    int? duplicateWindowMinutes,
  }) async {
    final data = <String, dynamic>{
      if (backDateWindowDays != null)
        'back_date_window_days': backDateWindowDays,
      if (suspiciousQuantityMultiplier != null)
        'suspicious_quantity_multiplier': suspiciousQuantityMultiplier,
      if (payrollMinPay != null) 'payroll_min_pay': payrollMinPay,
      if (duplicateWindowMinutes != null)
        'duplicate_window_minutes': duplicateWindowMinutes,
    };

    if (data.isEmpty) {
      return fetchSettings();
    }

    try {
      final response = await _apiClient.dio.patch<Map<String, dynamic>>(
        '/settings',
        data: data,
      );
      final responseData = response.data!['data'] as Map<String, dynamic>;
      return TenantSettings.fromJson(responseData);
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
        final message =
            error?['message'] as String? ?? e.message ?? 'Unknown error';
        return NetworkException(code: code, message: message);
      }
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const NetworkException(
        code: 'NETWORK_ERROR',
        message: 'No internet connection',
      );
    }
    return NetworkException(
      code: 'UNKNOWN_ERROR',
      message: e.message ?? 'Unknown error',
    );
  }
}
