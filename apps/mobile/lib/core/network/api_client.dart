import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

import '../storage/secure_storage.dart';
import 'session_events.dart';

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

  /// FR-1.6 — token xem thử vai trò khác; chỉ giữ trong bộ nhớ (không lưu
  /// `SecureStorage`), ưu tiên hơn token đăng nhập thật khi có.
  String? _previewToken;

  void setPreviewToken(String? token) => _previewToken = token;

  bool get isPreviewActive => _previewToken != null;

  /// Gộp các lần refresh xảy ra đồng thời (nhiều request 401 cùng lúc) thành
  /// 1 lệnh gọi `/api/auth/refresh` duy nhất — request sau chờ chung kết quả
  /// thay vì mỗi request tự refresh, dễ dính race đá nhau (refresh token
  /// dùng 1 lần bị xoay, request 2 gửi refresh token cũ đã hết hiệu lực).
  Future<String?>? _refreshInFlight;

  Future<String?> _refreshAccessToken() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() => _refreshInFlight = null);
  }

  /// `null` = refresh_token không còn hợp lệ → phải đăng xuất. Ném lỗi nếu là
  /// sự cố tạm thời (mất mạng, server lỗi) — trường hợp đó KHÔNG được coi là
  /// hết phiên, để lần gọi API kế tiếp còn có cơ hội thử lại.
  Future<String?> _doRefresh() async {
    final refreshToken = await SecureStorage.readRefreshToken();
    if (refreshToken == null) return null;

    // Dio riêng, không qua interceptor của `dio` chính — tránh đệ quy và tránh
    // đính kèm access token cũ (không cần thiết, endpoint refresh không đọc nó).
    final plainDio = Dio(BaseOptions(baseUrl: dio.options.baseUrl));
    try {
      final response = await plainDio.post('/api/auth/refresh', data: {'refresh_token': refreshToken});
      final newAccessToken = response.data['access_token'] as String;
      final newRefreshToken = response.data['refresh_token'] as String;
      await SecureStorage.saveTokens(accessToken: newAccessToken, refreshToken: newRefreshToken);
      return newAccessToken;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return null;
      rethrow;
    }
  }

  static ApiClient create() {
    final dio = Dio(BaseOptions(baseUrl: _defaultBaseUrl()));
    final client = ApiClient._(dio);

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = client._previewToken ?? await SecureStorage.readAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final isUnauthorized = error.response?.statusCode == 401;
          final alreadyRetried = error.requestOptions.extra['retried'] == true;

          // Preview mode dùng token riêng, không liên quan access/refresh
          // token thật — 401 ở đó là do hết quyền xem thử, không phải hết phiên.
          if (!isUnauthorized || client.isPreviewActive || alreadyRetried) {
            handler.next(error);
            return;
          }

          String? newAccessToken;
          try {
            newAccessToken = await client._refreshAccessToken();
          } catch (_) {
            // Lỗi tạm thời khi refresh — giữ nguyên phiên, trả lỗi gốc cho caller.
            handler.next(error);
            return;
          }

          if (newAccessToken == null) {
            await SecureStorage.clear();
            SessionEvents.instance.notifyUnauthorized();
            handler.next(error);
            return;
          }

          try {
            final retryOptions = error.requestOptions;
            retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
            retryOptions.extra['retried'] = true;
            final response = await dio.fetch(retryOptions);
            handler.resolve(response);
          } on DioException catch (e) {
            handler.next(e);
          }
        },
      ),
    );

    return client;
  }
}
