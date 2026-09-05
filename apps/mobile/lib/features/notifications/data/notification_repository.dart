import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/network/api_client.dart';

class AppNotification {
  const AppNotification({required this.id, required this.title, required this.message, required this.read, required this.createdAt});

  final String id;
  final String title;
  final String message;
  final bool read;
  final DateTime createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        message: json['message'] as String,
        read: json['read'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

/// Gọi `/api/notifications` — FR-19.
class NotificationRepository {
  NotificationRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<AppNotification>> list({bool unreadOnly = false}) async {
    try {
      final response = await _apiClient.dio.get('/api/notifications', queryParameters: {'unread_only': unreadOnly});
      return (response.data as List).map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<AppNotification> markRead(String id) async {
    try {
      final response = await _apiClient.dio.patch('/api/notifications/$id/read');
      return AppNotification.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
