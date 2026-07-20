import 'package:dio/dio.dart';

import 'package:texerp/core/error/network_exception.dart';
import 'package:texerp/core/network/api_client.dart';
import 'package:texerp/features/payroll/data/payroll_models.dart';

class PayrollRepository {
  PayrollRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<(List<PayrollPeriod> data, int total)> fetchPeriods({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/payroll/periods',
        queryParameters: {
          if (status != null && status != 'ALL') 'status': status,
          'page': page,
          'limit': limit,
        },
      );
      final dataList = response.data!['data'] as List<dynamic>;
      final total = response.data!['total'] as int? ?? dataList.length;
      final periods = dataList
          .map((json) => PayrollPeriod.fromJson(json as Map<String, dynamic>))
          .toList();
      return (periods, total);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<PeriodDetail> fetchPeriodDetail(String id) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/payroll/periods/$id',
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return PeriodDetail.fromJson(data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<PayrollPeriod> createPeriod({
    required String name,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/payroll/periods',
        data: {
          'name': name,
          'start_date': startDate,
          'end_date': endDate,
        },
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return PayrollPeriod.fromJson(data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<void> calculatePeriod(String id) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        '/payroll/periods/$id/calculate',
        data: {},
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<void> finalizePeriod(String id, {required bool confirmed}) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        '/payroll/periods/$id/finalize',
        data: {'confirmed': confirmed},
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<Map<String, dynamic>> addAdjustment({
    required String periodId,
    required String workerId,
    required String type,
    required int amount,
    required String reason,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/payroll/periods/$periodId/adjustments',
        data: {
          'worker_id': workerId,
          'type': type,
          'amount': amount,
          'reason': reason,
        },
      );
      return response.data!['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<void> removeAdjustment(String periodId, String adjustmentId) async {
    try {
      await _apiClient.dio.delete<Map<String, dynamic>>(
        '/payroll/periods/$periodId/adjustments/$adjustmentId',
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<Map<String, dynamic>> addAdvance({
    required String periodId,
    required String workerId,
    required int amount,
    required String givenDate,
    String? reason,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/payroll/periods/$periodId/advances',
        data: {
          'worker_id': workerId,
          'amount': amount,
          'given_date': givenDate,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
      );
      return response.data!['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<WorkerCalculationDetail> fetchWorkerCalculation({
    required String periodId,
    required String workerId,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/payroll/periods/$periodId/calculations/$workerId',
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return WorkerCalculationDetail.fromJson(data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<List<PayrollPeriod>> fetchMyPayroll() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/payroll/me',
      );
      final dataList = response.data!['data'] as List<dynamic>;
      return dataList
          .map((json) => PayrollPeriod.fromJson(json as Map<String, dynamic>))
          .toList();
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
          code: 'NETWORK_ERROR', message: 'No internet connection');
    }
    return NetworkException(
        code: 'UNKNOWN_ERROR', message: e.message ?? 'Unknown error');
  }
}
