import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

import '../storage/secure_storage.dart';

/// Base URL theo `flutter.mdc`: Android emulator dùng 10.0.2.2, Web/desktop
/// dùng 127.0.0.1. Đổi sang domain thật qua biến môi trường khi build release
/// (`--dart-define=API_BASE_URL=...`), không hardcode production host.
String _defaultBaseUrl() {
  const override = String.fromEnvironment('API_BASE_URL');
  if (override.isNotEmpty) return override;

  if (kIsWeb) return 'http://127.0.0.1:8000';
  if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8000';
  return 'http://127.0.0.1:8000';
}

class ApiClient {
  ApiClient._(this.dio);

  final Dio dio;

  static ApiClient create() {
    final dio = Dio(BaseOptions(baseUrl: _defaultBaseUrl()));

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorage.readAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await SecureStorage.clear();
            // Provider layer (authProvider) quan sát lỗi 401 qua repository và
            // tự chuyển state về đăng xuất — xem features/auth/application.
          }
          handler.next(error);
        },
      ),
    );

    return ApiClient._(dio);
  }
}
