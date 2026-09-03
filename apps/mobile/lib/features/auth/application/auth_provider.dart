import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_client.dart';
import '../data/auth_repository.dart';

part 'auth_provider.g.dart';

@riverpod
ApiClient apiClient(Ref ref) => ApiClient.create();

@riverpod
AuthRepository authRepository(Ref ref) => AuthRepository(ref.watch(apiClientProvider));

@riverpod
class Auth extends _$Auth {
  @override
  Future<CurrentUser?> build() {
    return ref.watch(authRepositoryProvider).tryRestoreSession();
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    final repository = ref.read(authRepositoryProvider);
    state = await AsyncValue.guard(() => repository.login(email, password));
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }
}
