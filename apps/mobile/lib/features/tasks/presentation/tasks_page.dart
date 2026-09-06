import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../application/task_provider.dart';
import '../data/task_repository.dart';
import 'task_progress_dialog.dart';
import 'tasks_web_page.dart';

/// FR-5.4 — Kanban 3 cột: Cần làm / Đang làm / Hoàn thành.
class TasksPage extends ConsumerWidget {
  const TasksPage({super.key, this.projectId, this.embedded = false});

  final String? projectId;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!embedded && kIsWeb) return const TasksWebPage();

    final tasksAsync = ref.watch(taskListProvider(projectId: projectId));
    final me = ref.watch(authProvider).asData?.value;
    final isEmployee = me?.role == 'EMPLOYEE';

    final body = tasksAsync.when(
      data: (tasks) => _KanbanBoard(
        tasks: tasks,
        canUpdate: isEmployee,
        currentUserId: me?.id,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Lỗi tải dữ liệu: $error')),
    );

    if (embedded) return body;
    return Scaffold(appBar: AppBar(title: const Text('Công việc')), body: body);
  }
}

class _KanbanBoard extends StatelessWidget {
  const _KanbanBoard({
    required this.tasks,
    required this.canUpdate,
    required this.currentUserId,
  });

  final List<Task> tasks;
  final bool canUpdate;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final status in TaskStatus.values)
            Expanded(
              child: _KanbanColumn(
                status: status,
                tasks: tasks.where((t) => t.status == status).toList(),
                canUpdate: canUpdate,
                currentUserId: currentUserId,
              ),
            ),
        ],
      ),
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    required this.status,
    required this.tasks,
    required this.canUpdate,
    required this.currentUserId,
  });

  final TaskStatus status;
  final List<Task> tasks;
  final bool canUpdate;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${status.label} (${tasks.length})', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return _TaskCard(
                  task: task,
                  canUpdate: canUpdate && task.assigneeId == currentUserId,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task, required this.canUpdate});

  final Task task;
  final bool canUpdate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: task.isOverdue ? Theme.of(context).colorScheme.errorContainer : null,
      child: InkWell(
        onTap: canUpdate ? () => showTaskProgressDialog(context, ref, task) : null,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: task.progress / 100, minHeight: 4),
              const SizedBox(height: 4),
              Text('${task.progress}% · ${task.status.label}', style: Theme.of(context).textTheme.bodySmall),
              if (canUpdate) ...[
                const SizedBox(height: 6),
                Text('Chạm để cập nhật tiến độ', style: Theme.of(context).textTheme.labelSmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
