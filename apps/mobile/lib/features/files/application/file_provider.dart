import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../data/file_repository.dart';

part 'file_provider.g.dart';

@riverpod
FileRepository fileRepository(Ref ref) => FileRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<FileAsset>> projectFiles(Ref ref, String projectId) => ref.watch(fileRepositoryProvider).list(projectId);

/// keepAlive: Actions chỉ được `ref.read` từ dialog — autoDispose sẽ dispose
/// giữa `await` API rồi nổ khi `invalidate` (Ref after disposed).
@Riverpod(keepAlive: true)
class FileActions extends _$FileActions {
  @override
  void build() {}

  Future<void> upload(String projectId, {required String filename, required List<int> bytes, String? contentType}) async {
    await ref.read(fileRepositoryProvider).upload(projectId, filename: filename, bytes: bytes, contentType: contentType);
    if (!ref.mounted) return;
    ref.invalidate(projectFilesProvider);
  }

  Future<List<int>> download(String fileId) => ref.read(fileRepositoryProvider).download(fileId);

  Future<void> delete(String projectId, String fileId) async {
    await ref.read(fileRepositoryProvider).delete(fileId);
    if (!ref.mounted) return;
    ref.invalidate(projectFilesProvider);
  }
}
