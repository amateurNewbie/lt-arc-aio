import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../data/permission_grant_repository.dart';

part 'permission_grant_provider.g.dart';

@riverpod
PermissionGrantRepository permissionGrantRepository(Ref ref) => PermissionGrantRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<PermissionGrant>> grantsForUser(Ref ref, String userId) => ref.watch(permissionGrantRepositoryProvider).listFor(userId);

@riverpod
class PermissionGrantActions extends _$PermissionGrantActions {
  @override
  void build() {}

  Future<void> create(String userId, {required String permissionGroup, List<String>? projectIds, DateTime? expiresAt}) async {
    await ref.read(permissionGrantRepositoryProvider).create(userId, permissionGroup: permissionGroup, projectIds: projectIds, expiresAt: expiresAt);
    ref.invalidate(grantsForUserProvider);
  }

  Future<void> revoke(String userId, String grantId) async {
    await ref.read(permissionGrantRepositoryProvider).revoke(userId, grantId);
    ref.invalidate(grantsForUserProvider);
  }
}
