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

@riverpod
class SettingsActions extends _$SettingsActions {
  @override
  void build() {}

  Future<void> update(Map<String, dynamic> updates) async {
    await ref.read(settingsRepositoryProvider).update(updates);
    ref.invalidate(companySettingsProvider);
  }
}
