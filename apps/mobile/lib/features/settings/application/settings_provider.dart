import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../data/settings_repository.dart';

part 'settings_provider.g.dart';

@riverpod
SettingsRepository settingsRepository(Ref ref) => SettingsRepository(ref.watch(apiClientProvider));

@riverpod
Future<CompanySettings> companySettings(Ref ref) => ref.watch(settingsRepositoryProvider).get();

@riverpod
Future<List<SecurityStatusItem>> securityStatus(Ref ref) => ref.watch(settingsRepositoryProvider).securityStatus();

/// keepAlive: Actions chỉ được `ref.read` từ dialog — autoDispose sẽ dispose
/// giữa `await` API rồi nổ khi `invalidate` (Ref after disposed).
@Riverpod(keepAlive: true)
class SettingsActions extends _$SettingsActions {
  @override
  void build() {}

  Future<void> update(Map<String, dynamic> updates) async {
    await ref.read(settingsRepositoryProvider).update(updates);
    if (!ref.mounted) return;
    ref.invalidate(companySettingsProvider);
  }
}
