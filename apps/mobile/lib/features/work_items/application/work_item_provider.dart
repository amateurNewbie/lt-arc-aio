import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../data/work_item_repository.dart';

part 'work_item_provider.g.dart';

@riverpod
WorkItemRepository workItemRepository(Ref ref) => WorkItemRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<WorkItem>> workItemList(Ref ref, String projectId) => ref.watch(workItemRepositoryProvider).list(projectId);

/// keepAlive: Actions chỉ được `ref.read` từ dialog — autoDispose sẽ dispose
/// giữa `await` API rồi nổ khi `invalidate` (Ref after disposed).
@Riverpod(keepAlive: true)
class WorkItemActions extends _$WorkItemActions {
  @override
  void build() {}

  Future<void> create({
    required String projectId,
    required String departmentId,
    required String name,
    required String unit,
    required double quantity,
    required int unitPrice,
  }) async {
    await ref.read(workItemRepositoryProvider).create(
          projectId: projectId,
          departmentId: departmentId,
          name: name,
          unit: unit,
          quantity: quantity,
          unitPrice: unitPrice,
        );
    if (!ref.mounted) return;
    ref.invalidate(workItemListProvider);
  }

  Future<void> updateProgress(String projectId, String workItemId, int progress) async {
    await ref.read(workItemRepositoryProvider).updateProgress(projectId, workItemId, progress);
    if (!ref.mounted) return;
    ref.invalidate(workItemListProvider);
  }
}
