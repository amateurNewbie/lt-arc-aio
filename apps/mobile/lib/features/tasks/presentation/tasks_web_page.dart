import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/web_badge.dart';
import '../../departments/application/department_provider.dart';
import '../../projects/application/project_provider.dart';
import '../../projects/data/project_repository.dart';
import '../../users/application/user_provider.dart';
import '../application/task_filter_provider.dart';
import '../application/task_provider.dart';
import '../data/task_repository.dart';

WebBadgeVariant _priorityVariant(TaskPriority p) => switch (p) {
      TaskPriority.high => WebBadgeVariant.destructive,
      TaskPriority.medium => WebBadgeVariant.warning,
      TaskPriority.low => WebBadgeVariant.secondary,
    };

InputDecoration _webSelectDecoration() => InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.webBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.webBorder)),
    );

/// Trang "Công việc" bản Web — bám `LT-ARC-Web-UI_1.html` (`data-if="isTasks"`):
/// banner nhắc việc sắp đến hạn, 3 bộ lọc, Kanban 3 cột hiện tên dự án + bộ phận.
class TasksWebPage extends ConsumerWidget {
  const TasksWebPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(taskFilterProvider);
    final tasksAsync = ref.watch(taskListProvider(projectId: filter.projectId, departmentId: filter.departmentId, assigneeId: filter.assigneeId));
    final projectsAsync = ref.watch(projectListProvider());
    final departmentsAsync = ref.watch(departmentListProvider);
    final usersAsync = ref.watch(userListProvider);

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final dueTomorrow = (tasksAsync.value ?? const <Task>[])
        .where((t) => t.status != TaskStatus.done && t.dueDate != null && _isSameDay(t.dueDate!, tomorrow))
        .toList();

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1360),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Công việc', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Bảng tiến độ theo trạng thái, gộp từ mọi dự án và bộ phận.', style: TextStyle(fontSize: 13, color: AppColors.webMutedFg)),
              const SizedBox(height: 16),
              if (dueTomorrow.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.08),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.notifications_active_outlined, size: 18, color: AppColors.gold),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: const TextStyle(fontSize: 13),
                            children: [
                              const TextSpan(text: 'Nhắc nhở tự động: ', style: TextStyle(fontWeight: FontWeight.w700)),
                              TextSpan(text: '${dueTomorrow.map((t) => '"${t.title}"').join(', ')} sẽ đến hạn '),
                              const TextSpan(text: 'ngày mai', style: TextStyle(fontWeight: FontWeight.w700)),
                              const TextSpan(text: '. Hệ thống nhắc người phụ trách trước hạn 1 ngày qua thông báo trong app.'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: projectsAsync.when(
                      data: (projects) => DropdownButtonFormField<String?>(
                        initialValue: filter.projectId,
                        isExpanded: true,
                        decoration: _webSelectDecoration(),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Dự án: Tất cả', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                          ),
                          for (final p in projects)
                            DropdownMenuItem(
                              value: p.id,
                              child: Text(p.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (v) => ref.read(taskFilterProvider.notifier).setProject(v),
                      ),
                      loading: () => const SizedBox(height: 36),
                      error: (e, _) => const SizedBox(height: 36),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: departmentsAsync.when(
                      data: (departments) => DropdownButtonFormField<String?>(
                        initialValue: filter.departmentId,
                        isExpanded: true,
                        decoration: _webSelectDecoration(),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Bộ phận: Tất cả', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                          ),
                          for (final d in departments)
                            DropdownMenuItem(
                              value: d.id,
                              child: Text(d.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (v) => ref.read(taskFilterProvider.notifier).setDepartment(v),
                      ),
                      loading: () => const SizedBox(height: 36),
                      error: (e, _) => const SizedBox(height: 36),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: usersAsync.when(
                      data: (users) => DropdownButtonFormField<String?>(
                        initialValue: filter.assigneeId,
                        isExpanded: true,
                        decoration: _webSelectDecoration(),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Người phụ trách: Tất cả', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                          ),
                          for (final u in users)
                            DropdownMenuItem(
                              value: u.id,
                              child: Text(u.displayName, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (v) => ref.read(taskFilterProvider.notifier).setAssignee(v),
                      ),
                      loading: () => const SizedBox(height: 36),
                      error: (e, _) => const SizedBox(height: 36),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              tasksAsync.when(
                data: (tasks) {
                  final projectsById = {for (final p in projectsAsync.value ?? const <Project>[]) p.id: p};
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final status in TaskStatus.values) ...[
                          Expanded(child: _KanbanColumn(status: status, tasks: tasks.where((t) => t.status == status).toList(), projectsById: projectsById)),
                          if (status != TaskStatus.values.last) const SizedBox(width: 16),
                        ],
                      ],
                    ),
                  );
                },
                loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Text('Lỗi tải dữ liệu: $e'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({required this.status, required this.tasks, required this.projectsById});

  final TaskStatus status;
  final List<Task> tasks;
  final Map<String, Project> projectsById;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.webCardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.webBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(status.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                WebBadge('${tasks.length}', variant: WebBadgeVariant.secondary),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(children: [for (final t in tasks) _TaskWebCard(task: t, project: projectsById[t.projectId])]),
          ),
        ],
      ),
    );
  }
}

class _TaskWebCard extends ConsumerWidget {
  const _TaskWebCard({required this.task, required this.project});

  final Task task;
  final Project? project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(userListProvider);
    final assigneeName = task.assigneeId != null ? (usersAsync.value ?? const []).where((u) => u.id == task.assigneeId).firstOrNull?.displayName : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: task.isOverdue ? AppColors.webDestructive.withValues(alpha: 0.4) : AppColors.webBorder),
        borderRadius: BorderRadius.circular(4),
        color: AppColors.webBackground,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(task.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
              WebBadge(task.priority.label, variant: _priorityVariant(task.priority)),
            ],
          ),
          if (project != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(project!.name, style: TextStyle(fontSize: 12, color: AppColors.webForeground))),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: task.progress / 100, minHeight: 6, backgroundColor: AppColors.webMutedBg, color: AppColors.gold)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(assigneeName ?? '—', style: TextStyle(fontSize: 12, color: AppColors.webMutedFg)),
              Text(
                task.dueDate != null ? DateFormat('dd/MM').format(task.dueDate!) + (task.isOverdue ? ' quá hạn' : '') : '—',
                style: TextStyle(fontSize: 12, fontWeight: task.isOverdue ? FontWeight.w500 : FontWeight.normal, color: task.isOverdue ? AppColors.webDestructive : AppColors.webMutedFg),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
