import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../../auth/data/auth_repository.dart';
import 'settings_provider.dart';

part 'role_preview_provider.g.dart';

/// FR-1.6 — Admin xem thử giao diện/dữ liệu như vai trò khác, chỉ đọc. Token
/// xem thử chỉ giữ trong bộ nhớ của `ApiClient` (không lưu `SecureStorage`,
/// không đụng tới phiên đăng nhập thật) — thoát xem thử là phục hồi ngay.
@riverpod
class RolePreview extends _$RolePreview {
  @override
  CurrentUser? build() => null;

  Future<void> activate(String role) async {
    final apiClient = ref.read(apiClientProvider);
    final token = await ref.read(settingsRepositoryProvider).previewRole(role);
    apiClient.setPreviewToken(token);
    try {
      state = await ref.read(authRepositoryProvider).me();
    } catch (_) {
      apiClient.setPreviewToken(null);
      rethrow;
    }
  }

  void exit() {
    ref.read(apiClientProvider).setPreviewToken(null);
    state = null;
  }
}
