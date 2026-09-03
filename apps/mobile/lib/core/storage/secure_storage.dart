import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Lưu access/refresh token — không lưu bằng SharedPreferences (không mã hoá).
class SecureStorage {
  SecureStorage._();

  static const _storage = FlutterSecureStorage();
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  static Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  static Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  static Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  static Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
