import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/session_events.dart';
import '../data/auth_repository.dart';

part 'auth_provider.g.dart';

@Riverpod(keepAlive: true)
ApiClient apiClient(Ref ref) => ApiClient.create();

@riverpod
AuthRepository authRepository(Ref ref) => AuthRepository(ref.watch(apiClientProvider));

@Riverpod(keepAlive: true)
class Auth extends _$Auth {
  @override
  Future<CurrentUser?> build() {
    final sub = SessionEvents.instance.unauthorized.listen((_) {
      if (ref.mounted) state = const AsyncData(null);
    });
    ref.onDispose(sub.cancel);
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
