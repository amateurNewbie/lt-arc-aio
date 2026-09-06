import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../data/role_permission_repository.dart';

part 'role_permission_provider.g.dart';

@riverpod
RolePermissionRepository rolePermissionRepository(Ref ref) =>
    RolePermissionRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<RolePermissionEntry>> rolePermissionMatrix(Ref ref) =>
    ref.watch(rolePermissionRepositoryProvider).list();

/// keepAlive: Actions chỉ được `ref.read` từ dialog — autoDispose sẽ dispose
/// giữa `await` API rồi nổ khi `invalidate` (Ref after disposed).
@Riverpod(keepAlive: true)
class RolePermissionActions extends _$RolePermissionActions {
  @override
  void build() {}

  Future<void> save(List<RolePermissionEntry> entries) async {
    await ref.read(rolePermissionRepositoryProvider).save(entries);
    if (!ref.mounted) return;
    ref.invalidate(rolePermissionMatrixProvider);
  }
}
