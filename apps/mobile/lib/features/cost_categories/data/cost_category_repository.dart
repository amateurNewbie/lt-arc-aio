import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/network/api_client.dart';

enum CostCategoryScope { project, company }

const _scopeWire = {CostCategoryScope.project: 'PROJECT', CostCategoryScope.company: 'COMPANY'};

extension CostCategoryScopeWire on CostCategoryScope {
  String get wire => _scopeWire[this]!;
}

CostCategoryScope costCategoryScopeFromJson(String value) => _scopeWire.entries.firstWhere((e) => e.value == value).key;

class CostCategory {
  const CostCategory({required this.id, required this.name, required this.scope, required this.active, this.description});

  final String id;
  final String name;
  final CostCategoryScope scope;
  final bool active;
  final String? description;

  factory CostCategory.fromJson(Map<String, dynamic> json) => CostCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        scope: costCategoryScopeFromJson(json['scope'] as String),
        active: json['active'] as bool,
        description: json['description'] as String?,
      );
}

class CostCategoryRepository {
  CostCategoryRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<CostCategory>> list({CostCategoryScope? scope}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/cost-categories',
        queryParameters: {if (scope != null) 'scope': scope.wire},
      );
      return (response.data as List).map((e) => CostCategory.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<CostCategory> create({required String name, required CostCategoryScope scope, String? description}) async {
    try {
      final response = await _apiClient.dio.post('/api/cost-categories', data: {'name': name, 'scope': scope.wire, 'description': description});
      return CostCategory.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<CostCategory> update(String id, {String? description, bool? active}) async {
    try {
      final response = await _apiClient.dio.patch('/api/cost-categories/$id', data: {'description': description, 'active': active});
      return CostCategory.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
