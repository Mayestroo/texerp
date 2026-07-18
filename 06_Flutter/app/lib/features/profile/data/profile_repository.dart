import 'package:dio/dio.dart';

import 'package:texerp/core/error/network_exception.dart';
import 'package:texerp/core/network/api_client.dart';
import 'package:texerp/features/auth/data/auth_models.dart';

/// Repository for profile-related operations.
class ProfileRepository {
  ProfileRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Fetches the current user profile.
  Future<UserProfile> getProfile(String userId) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>('/users/$userId');
      final data = response.data!['data'] as Map<String, dynamic>;
      return UserProfile.fromJson(data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Fetches workers assigned to the foreman.
  Future<List<UserProfile>> fetchMyWorkers() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>('/users/me/workers');
      final dataList = response.data!['data'] as List<dynamic>;
      return dataList
          .map((json) => UserProfile.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Fetches all users (with optional role, status, and search filters).
  Future<(List<UserProfile> data, int total)> fetchUsers({
    String? role,
    String status = 'ACTIVE',
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/users',
        queryParameters: {
          if (role != null) 'role': role,
          'status': status,
          if (search != null && search.isNotEmpty) 'search': search,
          'page': page,
          'limit': limit,
        },
      );
      final dataList = response.data!['data'] as List<dynamic>;
      final total = response.data!['total'] as int? ?? dataList.length;
      final users = dataList
          .map((json) => UserProfile.fromJson(json as Map<String, dynamic>))
          .toList();
      return (users, total);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Creates a new user.
  Future<UserProfile> createUser({
    required String fullName,
    required String phone,
    required String workerCode,
    required String role,
    required String initialPin,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/users',
        data: {
          'full_name': fullName,
          'phone': phone,
          'worker_code': workerCode,
          'role': role,
          'initial_pin': initialPin,
        },
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return UserProfile.fromJson(data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Updates an existing user.
  Future<UserProfile> updateUser({
    required String id,
    required String fullName,
  }) async {
    try {
      final response = await _apiClient.dio.patch<Map<String, dynamic>>(
        '/users/$id',
        data: {
          'full_name': fullName,
        },
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return UserProfile.fromJson(data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Deactivates a user.
  Future<void> deactivateUser(String id) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        '/users/$id/deactivate',
        data: {},
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Reactivates a user.
  Future<void> reactivateUser(String id) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        '/users/$id/reactivate',
        data: {},
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Fetches departments.
  Future<List<Department>> fetchDepartments() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>('/departments');
      final dataList = response.data!['data'] as List<dynamic>;
      return dataList
          .map((json) => Department.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Assigns a foreman and department to a worker.
  /// Foreman is inferred from the department's foreman_id on the backend.
  Future<void> assignForeman({
    required String workerId,
    required String foremanId,
    required String departmentId,
  }) async {
    try {
      await _apiClient.dio.put<Map<String, dynamic>>(
        '/users/$workerId/foreman-assignment',
        data: {
          'department_id': departmentId,
        },
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Creates a new department.
  Future<Department> createDepartment({
    required String name,
    required String code,
    required String foremanId,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/departments',
        data: {
          'name': name,
          'code': code,
          'foreman_id': foremanId,
        },
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return Department.fromJson(data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Updates a department.
  Future<Department> updateDepartment({
    required String id,
    String? name,
    String? code,
    String? foremanId,
    bool? isActive,
  }) async {
    try {
      final response = await _apiClient.dio.patch<Map<String, dynamic>>(
        '/departments/$id',
        data: {
          if (name != null) 'name': name,
          if (code != null) 'code': code,
          if (foremanId != null) 'foreman_id': foremanId,
          if (isActive != null) 'is_active': isActive,
        },
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return Department.fromJson(data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Unassigns foreman from a worker.
  Future<void> unassignForeman({required String workerId}) async {
    try {
      await _apiClient.dio.delete<Map<String, dynamic>>(
        '/users/$workerId/foreman-assignment',
      );
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
