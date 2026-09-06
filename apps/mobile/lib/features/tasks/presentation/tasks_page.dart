import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../application/task_provider.dart';
import '../data/task_repository.dart';
import 'tasks_web_page.dart';
import '../../../shared/widgets/app_toast.dart';

/// FR-5.4 — Kanban 3 cột: Cần làm / Đang làm / Đã hoàn thành. Web (trang toàn
/// công ty, không embedded) dùng layout bám `LT-ARC-Web-UI_1.html` qua `TasksWebPage`.
class TasksPage extends ConsumerWidget {
  const TasksPage({super.key, this.projectId, this.embedded = false});

  final String? projectId;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!embedded && kIsWeb) return const TasksWebPage();

    final tasksAsync = ref.watch(taskListProvider(projectId: projectId));

    final body = tasksAsync.when(
      data: (tasks) => _KanbanBoard(tasks: tasks),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Lỗi tải dữ liệu: $error')),
    );

    if (embedded) return body;
    return Scaffold(appBar: AppBar(title: const Text('Công việc')), body: body);
  }
}

class _KanbanBoard extends StatelessWidget {
  const _KanbanBoard({required this.tasks});

  final List<Task> tasks;

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
              ),
            ),
        ],
      ),
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({required this.status, required this.tasks});

  final TaskStatus status;
  final List<Task> tasks;

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
              itemBuilder: (context, index) => _TaskCard(task: tasks[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task});

  final Task task;

  Future<void> _openProgressSheet(BuildContext context, WidgetRef ref) async {
    var progress = task.progress;
    await showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Slider(
                value: progress.toDouble(),
                min: 0,
                max: 100,
                divisions: 20,
                label: '$progress%',
                onChanged: (value) => setState(() => progress = value.round()),
              ),
              FilledButton(
                onPressed: () async {
                  final close = PendingDialogClose.of(context);
                  try {
                    await ref.read(taskActionsProvider.notifier).updateProgress(task.id, progress);
                    close.success('Đã cập nhật tiến độ');
                  } on ApiException catch (e) {
                    if (context.mounted) {
                      showAppToast(context, e.message, error: true);
                    }
                  }
                },
                child: const Text('Cập nhật tiến độ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: task.isOverdue ? Theme.of(context).colorScheme.errorContainer : null,
      child: InkWell(
        onTap: () => _openProgressSheet(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: task.progress / 100, minHeight: 4),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(task.priority.label, style: Theme.of(context).textTheme.bodySmall),
                  if (task.isOverdue)
                    const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
