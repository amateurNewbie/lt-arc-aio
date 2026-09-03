import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/network/api_client.dart';

class Activity {
  const Activity({
    required this.id,
    required this.icon,
    required this.title,
    required this.createdAt,
    this.projectId,
  });

  final String id;
  final String icon;
  final String title;
  final String? projectId;
  final DateTime createdAt;

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
        id: json['id'] as String,
        icon: json['icon'] as String,
        title: json['title'] as String,
        projectId: json['project_id'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class ActivityRepository {
  ActivityRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Activity>> listRecent({int limit = 20}) async {
    try {
      final response = await _apiClient.dio.get('/api/activities', queryParameters: {'limit': limit});
      return (response.data as List).map((e) => Activity.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
