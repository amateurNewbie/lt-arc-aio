import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/network/api_client.dart';

const _permissionGroupLabels = {
  'PROJECT_CASHBOOK': 'Sổ thu chi dự án',
  'OVERHEAD_ALLOCATE': 'Phân bổ chi phí chung',
  'FUNDS': 'Quỹ & dòng tiền',
  'DEBTS': 'Công nợ',
  'CONTRACTS_COLLECT': 'Thu tiền hợp đồng',
  'WORKDAYS_ENTRY': 'Nhập số công',
};

const permissionGroups = ['PROJECT_CASHBOOK', 'OVERHEAD_ALLOCATE', 'FUNDS', 'DEBTS', 'CONTRACTS_COLLECT', 'WORKDAYS_ENTRY'];

extension PermissionGroupLabel on String {
  String get permissionGroupLabel => _permissionGroupLabels[this] ?? this;
}

class PermissionGrant {
  const PermissionGrant({required this.id, required this.userId, required this.permissionGroup, required this.scope, required this.expiresAt, required this.revokedAt});

  final String id;
  final String userId;
  final String permissionGroup;
  final Map<String, dynamic> scope;
  final DateTime? expiresAt;
  final DateTime? revokedAt;

  bool get isActive => revokedAt == null && (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  String get scopeLabel => scope['type'] == 'ALL' ? 'Toàn bộ dự án' : 'Một số dự án (${(scope['project_ids'] as List?)?.length ?? 0})';

  factory PermissionGrant.fromJson(Map<String, dynamic> json) => PermissionGrant(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        permissionGroup: json['permission_group'] as String,
        scope: json['scope'] as Map<String, dynamic>,
        expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at'] as String) : null,
        revokedAt: json['revoked_at'] != null ? DateTime.parse(json['revoked_at'] as String) : null,
      );
}

/// Gọi `/api/users/{id}/permissions` — FR-1.7/1.8.
class PermissionGrantRepository {
  PermissionGrantRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<PermissionGrant>> listFor(String userId) async {
    try {
      final response = await _apiClient.dio.get('/api/users/$userId/permissions');
      return (response.data as List).map((e) => PermissionGrant.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<PermissionGrant> create(String userId, {required String permissionGroup, required List<String>? projectIds, DateTime? expiresAt}) async {
    try {
      final response = await _apiClient.dio.post('/api/users/$userId/permissions', data: {
        'permission_group': permissionGroup,
        'scope': {'type': projectIds == null ? 'ALL' : 'PROJECTS', 'project_ids': projectIds},
        'expires_at': expiresAt?.toIso8601String(),
      });
      return PermissionGrant.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> revoke(String userId, String grantId) async {
    try {
      await _apiClient.dio.delete('/api/users/$userId/permissions/$grantId');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
