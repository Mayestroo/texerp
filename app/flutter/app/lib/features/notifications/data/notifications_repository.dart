import 'package:dio/dio.dart';

import 'package:texerp/core/error/network_exception.dart';
import 'package:texerp/core/network/api_client.dart';
import 'package:texerp/features/notifications/data/notification_models.dart';

class NotificationsRepository {
  NotificationsRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<(List<NotificationItem>, int, int)> fetchNotifications({
    String status = 'ALL',
    int page = 1,
    int limit = 30,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/notifications',
        queryParameters: {
          'status': status,
          'page': page,
          'limit': limit,
        },
      );
      final dataList = response.data!['data'] as List<dynamic>;
      final total = response.data!['total'] as int? ?? dataList.length;
      final unreadCount = response.data!['unread_count'] as int? ?? 0;
      final items = dataList
          .map((json) => NotificationItem.fromJson(json as Map<String, dynamic>))
          .toList();
      return (items, total, unreadCount);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<int> markRead({List<String>? ids, bool markAll = false}) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/notifications/mark-read',
        data: {
          if (ids != null) 'ids': ids,
          'mark_all': markAll,
        },
      );
      final count = response.data!['data']?['count'] as int? ??
          response.data!['count'] as int? ??
          0;
      return count;
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
