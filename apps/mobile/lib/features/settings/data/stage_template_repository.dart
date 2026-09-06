import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/network/api_client.dart';

class StageTemplate {
  const StageTemplate({
    required this.id,
    required this.key,
    required this.name,
    required this.sortOrder,
    required this.active,
  });

  final String id;
  final String key;
  final String name;
  final int sortOrder;
  final bool active;

  factory StageTemplate.fromJson(Map<String, dynamic> json) => StageTemplate(
        id: json['id'].toString(),
        key: json['key'] as String,
        name: json['name'] as String,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        active: json['active'] as bool? ?? true,
      );
}

class StageTemplateRepository {
  StageTemplateRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<StageTemplate>> list({bool activeOnly = false}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/project-stage-templates',
        queryParameters: {if (activeOnly) 'active_only': true},
      );
      return (response.data as List)
          .map((e) => StageTemplate.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<StageTemplate> create({required String name, String? key, int sortOrder = 0}) async {
    try {
      final slug = (key ?? name).trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
      final response = await _apiClient.dio.post(
        '/api/project-stage-templates',
        data: {
          'key': slug.isEmpty ? 'stage_$sortOrder' : slug,
          'name': name.trim(),
          'sort_order': sortOrder,
        },
      );
      return StageTemplate.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<StageTemplate> update(String id, {String? name, int? sortOrder, bool? active}) async {
    try {
      final response = await _apiClient.dio.patch(
        '/api/project-stage-templates/$id',
        data: {
          if (name != null) 'name': name,
          if (sortOrder != null) 'sort_order': sortOrder,
          if (active != null) 'active': active,
        },
      );
      return StageTemplate.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _apiClient.dio.delete('/api/project-stage-templates/$id');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
