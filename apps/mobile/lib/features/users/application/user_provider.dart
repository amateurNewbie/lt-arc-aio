import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../data/user_repository.dart';

part 'user_provider.g.dart';

@riverpod
UserRepository userRepository(Ref ref) => UserRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<UserSummary>> userList(Ref ref) => ref.watch(userRepositoryProvider).list();

/// keepAlive: Actions chỉ được `ref.read` từ dialog — autoDispose sẽ dispose
/// giữa `await` API rồi nổ khi `invalidate` (Ref after disposed).
@Riverpod(keepAlive: true)
class UserActions extends _$UserActions {
  @override
  void build() {}

  Future<UserSummary> create({
    required String email,
    required String password,
    required String role,
    String? fullName,
    String? departmentId,
  }) async {
    final user = await ref.read(userRepositoryProvider).create(
          email: email,
          password: password,
          role: role,
          fullName: fullName,
          departmentId: departmentId,
        );
    if (!ref.mounted) return user;
    ref.invalidate(userListProvider);
    return user;
  }
}
