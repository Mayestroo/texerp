import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import 'package:texerp/core/error/network_exception.dart';
import 'package:texerp/core/network/api_client.dart';
import 'package:texerp/features/warehouse/data/warehouse_models.dart';

/// Repository for warehouse materials and stock movements.
class WarehouseRepository {
  WarehouseRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Lists materials with optional filters.
  Future<(List<Material> data, int total)> fetchMaterials({
    bool? isActive,
    String? category,
    String? search,
    int page = 1,
    int limit = 25,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/warehouse/materials',
        queryParameters: {
          if (isActive != null) 'is_active': isActive,
          if (category != null && category.isNotEmpty) 'category': category,
          if (search != null && search.isNotEmpty) 'search': search,
          'page': page,
          'limit': limit,
        },
      );
      final dataList = response.data!['data'] as List<dynamic>;
      final pagination = response.data!['pagination'] as Map<String, dynamic>?;
      final total = _toTotal(pagination, response.data);
      final materials = dataList
          .map((json) => Material.fromJson(json as Map<String, dynamic>))
          .toList();
      return (materials, total);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Creates a new material.
  Future<Material> createMaterial({
    required String code,
    required String name,
    String? category,
    required String unit,
    double? minQuantity,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/warehouse/materials',
        data: {
          'code': code,
          'name': name,
          if (category != null && category.isNotEmpty) 'category': category,
          'unit': unit,
          if (minQuantity != null) 'min_quantity': minQuantity,
        },
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return Material.fromJson(data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Updates an existing material.
  Future<Material> updateMaterial({
    required String id,
    String? name,
    String? category,
    double? minQuantity,
  }) async {
    try {
      final response = await _apiClient.dio.patch<Map<String, dynamic>>(
        '/warehouse/materials/$id',
        data: {
          if (name != null && name.isNotEmpty) 'name': name,
          'category': category,
          if (minQuantity != null) 'min_quantity': minQuantity,
        },
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return Material.fromJson(data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Deactivates a material.
  Future<void> deactivateMaterial(String id) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        '/warehouse/materials/$id/deactivate',
        data: {},
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Activates a material.
  Future<void> activateMaterial(String id) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        '/warehouse/materials/$id/activate',
        data: {},
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Records a receipt (incoming stock).
  Future<void> recordReceipt({
    required String materialId,
    required double quantity,
    required DateTime movementDate,
    String? supplierName,
    String? note,
  }) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        '/warehouse/materials/$materialId/receipts',
        data: {
          'quantity': quantity,
          'movement_date': DateFormat('yyyy-MM-dd').format(movementDate),
          if (supplierName != null && supplierName.isNotEmpty)
            'supplier_name': supplierName,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Records an issuance (outgoing stock).
  Future<void> recordIssuance({
    required String materialId,
    required double quantity,
    required DateTime movementDate,
    String? destination,
    String? note,
  }) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        '/warehouse/materials/$materialId/issuances',
        data: {
          'quantity': quantity,
          'movement_date': DateFormat('yyyy-MM-dd').format(movementDate),
          if (destination != null && destination.isNotEmpty)
            'destination': destination,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Lists stock movements for a material.
  Future<(List<StockMovement> data, int total)> fetchMovements(
    String materialId, {
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/warehouse/materials/$materialId/movements',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );
      final dataList = response.data!['data'] as List<dynamic>;
      final pagination = response.data!['pagination'] as Map<String, dynamic>?;
      final total = _toTotal(pagination, response.data);
      final movements = dataList
          .map((json) => StockMovement.fromJson(json as Map<String, dynamic>))
          .toList();
      return (movements, total);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Fetches the current balance for a material.
  Future<MaterialBalance> fetchBalance(String materialId) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/warehouse/materials/$materialId/balance',
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return MaterialBalance.fromJson(data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  int _toTotal(
    Map<String, dynamic>? pagination,
    Map<String, dynamic>? responseData,
  ) {
    if (pagination != null) {
      return _toInt(pagination['total']);
    }
    return _toInt(responseData?['total']);
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
