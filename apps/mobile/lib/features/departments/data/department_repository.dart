import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/network/api_client.dart';

class Department {
  const Department({required this.id, required this.name, this.headUserId});

  final String id;
  final String name;
  final String? headUserId;

  factory Department.fromJson(Map<String, dynamic> json) => Department(
        id: json['id'] as String,
        name: json['name'] as String,
        headUserId: json['head_user_id'] as String?,
      );
}

class DepartmentRepository {
  DepartmentRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Department>> list() async {
    try {
      final response = await _apiClient.dio.get('/api/departments');
      return (response.data as List).map((e) => Department.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
