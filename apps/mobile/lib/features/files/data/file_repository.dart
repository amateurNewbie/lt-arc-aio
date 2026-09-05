import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/network/api_client.dart';

class FileAsset {
  const FileAsset({required this.id, required this.projectId, required this.name, required this.type, required this.sizeBytes, required this.createdAt});

  final String id;
  final String projectId;
  final String name;
  final String type;
  final int sizeBytes;
  final DateTime createdAt;

  factory FileAsset.fromJson(Map<String, dynamic> json) => FileAsset(
        id: json['id'] as String,
        projectId: json['project_id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        sizeBytes: json['size_bytes'] as int,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

/// Gọi `/api/files` — FR-17, tệp đính kèm theo dự án.
class FileRepository {
  FileRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<FileAsset>> list(String projectId) async {
    try {
      final response = await _apiClient.dio.get('/api/files', queryParameters: {'project_id': projectId});
      return (response.data as List).map((e) => FileAsset.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<FileAsset> upload(String projectId, {required String filename, required List<int> bytes, String? contentType}) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/files',
        queryParameters: {'project_id': projectId},
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: filename, contentType: contentType != null ? DioMediaType.parse(contentType) : null),
        }),
      );
      return FileAsset.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<int>> download(String fileId) async {
    try {
      final response = await _apiClient.dio.get('/api/files/$fileId/download', options: Options(responseType: ResponseType.bytes));
      return response.data as List<int>;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> delete(String fileId) async {
    try {
      await _apiClient.dio.delete('/api/files/$fileId');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
