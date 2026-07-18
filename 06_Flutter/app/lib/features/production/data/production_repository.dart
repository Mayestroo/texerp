import 'package:dio/dio.dart';

import 'package:texerp/core/error/network_exception.dart';
import 'package:texerp/core/network/api_client.dart';
import 'package:texerp/features/production/data/production_models.dart';

class ProductionRepository {
  ProductionRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Fetches operations. By default fetches active ones.
  Future<List<Operation>> fetchOperations({
    String status = 'ACTIVE',
    String? search,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/operations',
        queryParameters: {
          'status': status,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );
      final dataList = response.data!['data'] as List<dynamic>;
      return dataList
          .map((json) => Operation.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Creates a new operation.
  Future<Operation> createOperation({
    required String name,
    String? code,
    required String unit,
    required double unitPrice,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/operations',
        data: {
          'name': name,
          if (code != null && code.isNotEmpty) 'code': code,
          'unit': unit,
          'unit_price': unitPrice.toInt(),
        },
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return Operation.fromJson(data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Updates an existing operation.
  Future<Operation> updateOperation({
    required String id,
    String? name,
    String? code,
    double? unitPrice,
  }) async {
    try {
      final response = await _apiClient.dio.patch<Map<String, dynamic>>(
        '/operations/$id',
        data: {
          if (name != null) 'name': name,
          'code': code, // can be null to clear
          if (unitPrice != null) 'unit_price': unitPrice.toInt(),
        },
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return Operation.fromJson(data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Deactivates an operation.
  Future<void> deactivateOperation(String id) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        '/operations/$id/deactivate',
        data: {},
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Activates an operation.
  Future<void> activateOperation(String id) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        '/operations/$id/activate',
        data: {},
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Submits a new production entry.
  Future<ProductionEntry> createProductionEntry({
    required String operationId,
    required double quantity,
    required String recordDate,
    String? workerNote,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/production/entries',
        data: {
          'operation_id': operationId,
          'quantity': quantity.toInt(), // The backend expects an integer for quantity (@IsInt())
          'record_date': recordDate,
          if (workerNote != null && workerNote.isNotEmpty)
            'worker_note': workerNote,
        },
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return ProductionEntry.fromJson(data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Fetches the authenticated worker's production entries.
  Future<(List<ProductionEntry> data, int total)> fetchMyEntries({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/production/entries/me',
        queryParameters: {
          if (status != null) 'status': status,
          'limit': limit,
          'offset': offset,
        },
      );
      final dataList = response.data!['data'] as List<dynamic>;
      final total = response.data!['total'] as int? ?? dataList.length;
      final entries = dataList
          .map((json) => ProductionEntry.fromJson(json as Map<String, dynamic>))
          .toList();
      return (entries, total);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Fetches pending entries for the foreman.
  Future<List<ProductionEntry>> fetchPendingEntriesForForeman() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/production/entries/foreman/pending',
      );
      final dataList = response.data!['data'] as List<dynamic>;
      return dataList
          .map((json) => ProductionEntry.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Approves a pending production entry.
  Future<ProductionEntry> approveEntry(String id) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/production/entries/$id/approve',
        data: {}, // ApproveEntryDto is empty
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return ProductionEntry.fromJson(data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Rejects a pending production entry.
  Future<ProductionEntry> rejectEntry(String id, String reason) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/production/entries/$id/reject',
        data: {
          'reason': reason,
        },
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return ProductionEntry.fromJson(data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Corrects and approves a pending production entry.
  Future<ProductionEntry> correctAndApproveEntry({
    required String id,
    required double correctedQuantity,
    String? comment,
  }) async {
    try {
      final response = await _apiClient.dio.patch<Map<String, dynamic>>(
        '/production/entries/$id/correct-approve',
        data: {
          'corrected_quantity': correctedQuantity.toInt(),
          if (comment != null && comment.isNotEmpty)
            'correction_comment': comment,
        },
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return ProductionEntry.fromJson(data);
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
