import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';

class LoginFailure implements Exception {
  LoginFailure(this.locked);

  /// true nếu bị khoá tài khoản (HTTP 423 — FR-1.4), false nếu sai email/mật khẩu.
  final bool locked;
}

class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.email,
    required this.role,
    this.fullName,
    this.effectivePermissions = const {},
  });

  final String id;
  final String email;
  final String role;
  final String? fullName;

  /// FR-1.7 — quyền hiệu lực theo 6 nhóm (mặc định vai trò ∪ grant còn hạn),
  /// dùng để ẩn/hiện nút bấm đúng thay vì chỉ dựa vào role — xem `PermissionGroup`.
  final Map<String, bool> effectivePermissions;

  /// Tên hiển thị — ưu tiên họ tên, chưa có thì tạm dùng email (FR-1).
  String get displayName => (fullName != null && fullName!.trim().isNotEmpty) ? fullName! : email;

  bool hasPermission(String group) => effectivePermissions[group] ?? false;

  factory CurrentUser.fromJson(Map<String, dynamic> json) => CurrentUser(
        id: json['id'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
        fullName: json['full_name'] as String?,
        effectivePermissions: (json['effective_permissions'] as Map<String, dynamic>? ?? const {})
            .map((k, v) => MapEntry(k, v as bool)),
      );
}

/// Gọi `/api/auth/*` — widget không bao giờ gọi Dio trực tiếp (xem
/// `add-flutter-feature` skill).
class AuthRepository {
  AuthRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<CurrentUser> login(String email, String password) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/auth/login',
        data: {'email': email, 'password': password},
      );
      final accessToken = response.data['access_token'] as String;
      final refreshToken = response.data['refresh_token'] as String;
      await SecureStorage.saveTokens(accessToken: accessToken, refreshToken: refreshToken);
      return await me();
    } on DioException catch (e) {
      if (e.response?.statusCode == 423) throw LoginFailure(true);
      throw LoginFailure(false);
    }
  }

  Future<CurrentUser> me() async {
    final response = await _apiClient.dio.get('/api/auth/me');
    return CurrentUser.fromJson(response.data as Map<String, dynamic>);
  }

  Future<CurrentUser?> tryRestoreSession() async {
    final token = await SecureStorage.readAccessToken();
    if (token == null) return null;
    try {
      return await me();
    } on DioException {
      await SecureStorage.clear();
      return null;
    }
  }

  Future<void> logout() => SecureStorage.clear();
}
