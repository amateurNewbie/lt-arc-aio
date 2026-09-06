import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../../work_items/application/work_item_provider.dart';
import '../data/task_repository.dart';

part 'task_provider.g.dart';

@riverpod
TaskRepository taskRepository(Ref ref) => TaskRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<Task>> taskList(Ref ref, {String? projectId, String? departmentId, String? assigneeId}) =>
    ref.watch(taskRepositoryProvider).list(projectId: projectId, departmentId: departmentId, assigneeId: assigneeId);

/// keepAlive: Actions chỉ được `ref.read` từ dialog — autoDispose sẽ dispose
/// giữa `await` API rồi nổ khi `invalidate` (Ref after disposed).
@Riverpod(keepAlive: true)
class TaskActions extends _$TaskActions {
  @override
  void build() {}

  Future<Task> create({
    required String title,
    required String projectId,
    required String departmentId,
    required String workItemId,
    String? parentTaskId,
    String? assigneeId,
    DateTime? dueDate,
    TaskPriority priority = TaskPriority.medium,
  }) async {
    final task = await ref.read(taskRepositoryProvider).create(
          title: title,
          projectId: projectId,
          departmentId: departmentId,
          workItemId: workItemId,
          parentTaskId: parentTaskId,
          assigneeId: assigneeId,
          dueDate: dueDate,
          priority: priority,
        );
    if (!ref.mounted) return task;
    ref.invalidate(taskListProvider);
    ref.invalidate(workItemListProvider);
    return task;
  }

  Future<Task> updateProgress(String taskId, int progress) async {
    final task = await ref.read(taskRepositoryProvider).updateProgress(taskId, progress);
    if (!ref.mounted) return task;
    ref.invalidate(taskListProvider);
    ref.invalidate(workItemListProvider);
    return task;
  }
}
