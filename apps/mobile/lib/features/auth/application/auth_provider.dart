import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/session_events.dart';
import '../../notifications/application/notification_provider.dart';
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
    // Huỷ đăng ký token FCM TRƯỚC khi xoá SecureStorage — nếu làm sau,
    // request unregister sẽ không còn access token để đính kèm Authorization.
    if (!kIsWeb) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await ref.read(notificationRepositoryProvider).unregisterDevice(token);
        }
      } catch (_) {
        // best-effort — lỗi huỷ token không được chặn luồng logout.
      }
    }

    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }
}
