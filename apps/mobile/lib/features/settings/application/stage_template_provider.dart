import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../data/stage_template_repository.dart';

part 'stage_template_provider.g.dart';

@riverpod
StageTemplateRepository stageTemplateRepository(Ref ref) =>
    StageTemplateRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<StageTemplate>> stageTemplateList(Ref ref, {bool activeOnly = false}) =>
    ref.watch(stageTemplateRepositoryProvider).list(activeOnly: activeOnly);

/// keepAlive: Actions chỉ được `ref.read` từ dialog — autoDispose sẽ dispose
/// giữa `await` API rồi nổ khi `invalidate` (Ref after disposed).
@Riverpod(keepAlive: true)
class StageTemplateActions extends _$StageTemplateActions {
  @override
  void build() {}

  Future<void> create({required String name, String? key, int sortOrder = 0}) async {
    await ref.read(stageTemplateRepositoryProvider).create(name: name, key: key, sortOrder: sortOrder);
    if (!ref.mounted) return;
    ref.invalidate(stageTemplateListProvider);
  }

  Future<void> update(String id, {String? name, int? sortOrder, bool? active}) async {
    await ref.read(stageTemplateRepositoryProvider).update(id, name: name, sortOrder: sortOrder, active: active);
    if (!ref.mounted) return;
    ref.invalidate(stageTemplateListProvider);
  }

  Future<void> delete(String id) async {
    await ref.read(stageTemplateRepositoryProvider).delete(id);
    if (!ref.mounted) return;
    ref.invalidate(stageTemplateListProvider);
  }
}
