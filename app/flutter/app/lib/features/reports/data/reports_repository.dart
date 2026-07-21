import 'package:dio/dio.dart';

import 'package:texerp/core/error/network_exception.dart';
import 'package:texerp/core/network/api_client.dart';
import 'package:texerp/features/reports/data/report_models.dart';

class ReportsRepository {
  ReportsRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<ProductionReport> fetchProductionReport({
    required String dateFrom,
    required String dateTo,
    required String groupBy,
    String? workerId,
    String? foremanId,
    String? operationId,
    String? departmentId,
    int page = 1,
    int limit = 100,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/reports/production',
        queryParameters: {
          'date_from': dateFrom,
          'date_to': dateTo,
          'group_by': groupBy,
          if (workerId != null && workerId.isNotEmpty) 'worker_id': workerId,
          if (foremanId != null && foremanId.isNotEmpty) 'foreman_id': foremanId,
          if (operationId != null && operationId.isNotEmpty)
            'operation_id': operationId,
          if (departmentId != null && departmentId.isNotEmpty)
            'department_id': departmentId,
          'page': page,
          'limit': limit,
        },
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      final pagination = response.data!['pagination'] as Map<String, dynamic>?;
      return ProductionReport.fromJson(
        data,
        groupBy: groupBy,
        pagination: pagination,
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<String> queueExport({
    required String dateFrom,
    required String dateTo,
    required String groupBy,
    String? workerId,
    String? foremanId,
    String? operationId,
    String? departmentId,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/reports/production/export',
        data: {
          'date_from': dateFrom,
          'date_to': dateTo,
          'group_by': groupBy,
          if (workerId != null && workerId.isNotEmpty) 'worker_id': workerId,
          if (foremanId != null && foremanId.isNotEmpty) 'foreman_id': foremanId,
          if (operationId != null && operationId.isNotEmpty)
            'operation_id': operationId,
          if (departmentId != null && departmentId.isNotEmpty)
            'department_id': departmentId,
        },
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return data['export_id'] as String;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<ExportStatus> getExportStatus(String exportId) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/reports/exports/$exportId',
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return ExportStatus.fromJson(data);
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
