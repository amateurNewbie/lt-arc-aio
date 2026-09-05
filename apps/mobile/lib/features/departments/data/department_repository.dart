import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/network/api_client.dart';

class Department {
  const Department({
    required this.id,
    required this.name,
    required this.employeeCount,
    required this.activeTaskCount,
    required this.avgTaskProgress,
    this.headUserId,
  });

  final String id;
  final String name;
  final String? headUserId;
  final int employeeCount;
  final int activeTaskCount;
  final double avgTaskProgress;

  factory Department.fromJson(Map<String, dynamic> json) => Department(
        id: json['id'] as String,
        name: json['name'] as String,
        headUserId: json['head_user_id'] as String?,
        employeeCount: json['employee_count'] as int,
        activeTaskCount: json['active_task_count'] as int,
        avgTaskProgress: (json['avg_task_progress'] as num).toDouble(),
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

  Future<Department> create({required String name, String? headUserId}) async {
    try {
      final response = await _apiClient.dio.post('/api/departments', data: {'name': name, 'head_user_id': headUserId});
      return Department.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
