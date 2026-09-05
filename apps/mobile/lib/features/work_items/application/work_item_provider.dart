import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../data/work_item_repository.dart';

part 'work_item_provider.g.dart';

@riverpod
WorkItemRepository workItemRepository(Ref ref) => WorkItemRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<WorkItem>> workItemList(Ref ref, String projectId) => ref.watch(workItemRepositoryProvider).list(projectId);

@riverpod
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
    await ref.read(workItemRepositoryProvider).create(projectId: projectId, departmentId: departmentId, name: name, unit: unit, quantity: quantity, unitPrice: unitPrice);
    ref.invalidate(workItemListProvider);
  }

  Future<void> updateProgress(String projectId, String workItemId, int progress) async {
    await ref.read(workItemRepositoryProvider).updateProgress(projectId, workItemId, progress);
    ref.invalidate(workItemListProvider);
  }
}
