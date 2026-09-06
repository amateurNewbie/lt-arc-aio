import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/network/api_client.dart';

class RolePermissionEntry {
  const RolePermissionEntry({
    required this.role,
    required this.permissionGroup,
    required this.enabled,
  });

  final String role;
  final String permissionGroup;
  final bool enabled;

  RolePermissionEntry copyWith({bool? enabled}) => RolePermissionEntry(
        role: role,
        permissionGroup: permissionGroup,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() => {
        'role': role,
        'permission_group': permissionGroup,
        'enabled': enabled,
      };

  factory RolePermissionEntry.fromJson(Map<String, dynamic> json) => RolePermissionEntry(
        role: json['role'] as String,
        permissionGroup: json['permission_group'] as String,
        enabled: json['enabled'] as bool,
      );
}

/// Gọi `/api/roles/permissions` — quyền mặc định 4 role × 6 nhóm.
class RolePermissionRepository {
  RolePermissionRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<RolePermissionEntry>> list() async {
    try {
      final response = await _apiClient.dio.get('/api/roles/permissions');
      final entries = (response.data as Map<String, dynamic>)['entries'] as List;
      return entries.map((e) => RolePermissionEntry.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<RolePermissionEntry>> save(List<RolePermissionEntry> entries) async {
    try {
      final response = await _apiClient.dio.put(
        '/api/roles/permissions',
        data: {'entries': entries.map((e) => e.toJson()).toList()},
      );
      final body = (response.data as Map<String, dynamic>)['entries'] as List;
      return body.map((e) => RolePermissionEntry.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
