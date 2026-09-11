import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/network/api_client.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.read,
    required this.createdAt,
    this.kind,
    this.entityType,
    this.entityId,
  });

  final String id;
  final String title;
  final String message;
  final bool read;
  final DateTime createdAt;
  final String? kind;
  final String? entityType;
  final String? entityId;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        message: json['message'] as String,
        read: json['read'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
        kind: json['kind'] as String?,
        entityType: json['entity_type'] as String?,
        entityId: json['entity_id'] as String?,
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

  /// Đăng ký/refresh token FCM của thiết bị hiện tại — gọi sau khi đăng nhập
  /// và mỗi khi Firebase phát `onTokenRefresh`.
  Future<void> registerDevice({required String fcmToken, required String platform}) async {
    try {
      await _apiClient.dio.post('/api/notifications/devices', data: {'fcm_token': fcmToken, 'platform': platform});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Huỷ đăng ký token khi logout để ngừng nhận push trên thiết bị đó.
  Future<void> unregisterDevice(String fcmToken) async {
    try {
      await _apiClient.dio.delete('/api/notifications/devices/$fcmToken');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
