import 'package:dio/dio.dart';

/// Bọc lỗi HTTP không phải 2xx thành 1 kiểu dùng chung cho mọi repository.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int? statusCode;
  final String message;

  factory ApiException.fromDio(DioException e) {
    final detail = e.response?.data is Map ? (e.response?.data as Map)['detail'] : null;
    return ApiException(e.response?.statusCode, detail?.toString() ?? e.message ?? 'Lỗi không xác định');
  }

  bool get isForbidden => statusCode == 403;
  bool get isConflict => statusCode == 409;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => message;
}
