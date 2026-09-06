import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/network/api_client.dart';

const _roleLabels = {
  'ADMIN': 'Quản trị',
  'DIRECTOR': 'Giám đốc',
  'DEPARTMENT_HEAD': 'Trưởng bộ phận',
  'EMPLOYEE': 'Nhân viên',
};

const assignableRoles = ['ADMIN', 'DIRECTOR', 'DEPARTMENT_HEAD', 'EMPLOYEE'];

extension RoleLabel on String {
  String get roleLabel => _roleLabels[this] ?? this;
}

class UserSummary {
  const UserSummary({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.departmentId,
  });

  final String id;
  final String email;
  final String? fullName;
  final String role;
  final String? departmentId;

  /// Tên hiển thị — ưu tiên họ tên, chưa có thì tạm dùng email (FR-1).
  String get displayName => (fullName != null && fullName!.trim().isNotEmpty) ? fullName! : email;

  factory UserSummary.fromJson(Map<String, dynamic> json) => UserSummary(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: json['full_name'] as String?,
        role: json['role'] as String,
        departmentId: json['department_id'] as String?,
      );
}

/// Gọi `/api/users` — list / tạo tài khoản (FR-1.3) + chọn user cấp grant (FR-1.7).
class UserRepository {
  UserRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<UserSummary>> list() async {
    try {
      final response = await _apiClient.dio.get('/api/users');
      return (response.data as List).map((e) => UserSummary.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<UserSummary> create({
    required String email,
    required String password,
    required String role,
    String? fullName,
    String? departmentId,
  }) async {
    try {
      final response = await _apiClient.dio.post('/api/users', data: {
        'email': email,
        'password': password,
        'role': role,
        if (fullName != null && fullName.trim().isNotEmpty) 'full_name': fullName.trim(),
        'department_id': ?departmentId,
      });
      return UserSummary.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
