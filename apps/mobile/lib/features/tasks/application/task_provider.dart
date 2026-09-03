import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../data/task_repository.dart';

part 'task_provider.g.dart';

@riverpod
TaskRepository taskRepository(Ref ref) => TaskRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<Task>> taskList(Ref ref, {String? projectId}) =>
    ref.watch(taskRepositoryProvider).list(projectId: projectId);

@riverpod
class TaskActions extends _$TaskActions {
  @override
  void build() {}

  Future<Task> create({
    required String title,
    required String projectId,
    required String departmentId,
  }) async {
    final task = await ref.read(taskRepositoryProvider).create(
          title: title,
          projectId: projectId,
          departmentId: departmentId,
        );
    ref.invalidate(taskListProvider);
    return task;
  }

  Future<Task> updateProgress(String taskId, int progress) async {
    final task = await ref.read(taskRepositoryProvider).updateProgress(taskId, progress);
    ref.invalidate(taskListProvider);
    return task;
  }
}
