import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/web_badge.dart';
import '../../auth/application/auth_provider.dart';
import '../../departments/application/department_provider.dart';
import '../../users/application/user_provider.dart';
import '../../work_items/application/work_item_provider.dart';
import '../application/task_provider.dart';
import '../data/task_repository.dart';
import '../../../shared/widgets/app_toast.dart';
import 'task_progress_dialog.dart';

/// Tab Công việc trong chi tiết dự án — bảng + popup tạo.
class ProjectTasksTab extends ConsumerWidget {
  const ProjectTasksTab({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(taskListProvider(projectId: projectId));
    final departmentsAsync = ref.watch(departmentListProvider);
    final usersAsync = ref.watch(userListProvider);
    final workItemsAsync = ref.watch(workItemListProvider(projectId));
    final me = ref.watch(authProvider).asData?.value;
    final canUpdateProgress = me?.role == 'EMPLOYEE';
    final dateFmt = DateFormat('dd/MM/yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Danh sách công việc', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
            FilledButton.icon(
              onPressed: () => showProjectTaskDialog(context, projectId),
              style: FilledButton.styleFrom(backgroundColor: AppColors.webForeground, foregroundColor: Colors.white),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tạo công việc'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: tasksAsync.when(
            data: (tasks) {
              if (tasks.isEmpty) return const Center(child: Text('Chưa có công việc nào'));
              final deptNames = {for (final d in departmentsAsync.asData?.value ?? const []) d.id: d.name};
              final userNames = {for (final u in usersAsync.asData?.value ?? const []) u.id: u.displayName};
              final workItemNames = {for (final w in workItemsAsync.asData?.value ?? const []) w.id: w.name};

              final roots = tasks.where((t) => t.parentTaskId == null).toList();
              final childrenOf = <String, List<Task>>{};
              for (final t in tasks.where((t) => t.parentTaskId != null)) {
                childrenOf.putIfAbsent(t.parentTaskId!, () => []).add(t);
              }
              final ordered = <({Task task, bool child})>[];
              for (final root in roots) {
                ordered.add((task: root, child: false));
                for (final child in childrenOf[root.id] ?? const <Task>[]) {
                  ordered.add((task: child, child: true));
                }
              }
              final shown = ordered.map((e) => e.task.id).toSet();
              for (final t in tasks) {
                if (!shown.contains(t.id)) ordered.add((task: t, child: t.parentTaskId != null));
              }

              return SingleChildScrollView(
                child: DataTable(
                  headingRowHeight: 40,
                  dataRowMinHeight: 44,
                  dataRowMaxHeight: 56,
                  columns: const [
                    DataColumn(label: Text('Công việc')),
                    DataColumn(label: Text('Hạng mục')),
                    DataColumn(label: Text('Bộ phận')),
                    DataColumn(label: Text('Người phụ trách')),
                    DataColumn(label: Text('Ưu tiên')),
                    DataColumn(label: Text('Tiến độ')),
                    DataColumn(label: Text('Hạn')),
                  ],
                  rows: [
                    for (final row in ordered)
                      DataRow(
                        color: row.task.isOverdue ? WidgetStatePropertyAll(AppColors.webWarning.withValues(alpha: 0.12)) : null,
                        cells: [
                          DataCell(
                            InkWell(
                              onTap: canUpdateProgress && row.task.assigneeId == me?.id
                                  ? () => showTaskProgressDialog(context, ref, row.task)
                                  : null,
                              child: Padding(
                                padding: EdgeInsets.only(left: row.child ? 20 : 0),
                                child: Text(
                                  row.child ? '↳ ${row.task.title}' : row.task.title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: row.child ? FontWeight.w400 : FontWeight.w500,
                                    color: row.child ? AppColors.webMutedFg : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              row.task.workItemId == null ? '—' : (workItemNames[row.task.workItemId] ?? '—'),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          DataCell(Text(deptNames[row.task.departmentId] ?? '—', style: const TextStyle(fontSize: 13))),
                          DataCell(Text(row.task.assigneeId == null ? '—' : (userNames[row.task.assigneeId] ?? '—'), style: const TextStyle(fontSize: 13))),
                          DataCell(
                            row.child
                                ? const Text('—')
                                : WebBadge(row.task.priority.label, variant: row.task.priority == TaskPriority.high ? WebBadgeVariant.warning : WebBadgeVariant.outline),
                          ),
                          DataCell(
                            row.task.status == TaskStatus.done
                                ? const WebBadge('Hoàn thành', variant: WebBadgeVariant.secondary)
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 70,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(3),
                                          child: LinearProgressIndicator(
                                            value: row.task.progress / 100,
                                            minHeight: 6,
                                            backgroundColor: AppColors.webMutedBg,
                                            color: row.task.isOverdue ? AppColors.webDestructive : AppColors.gold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text('${row.task.progress}%', style: const TextStyle(fontSize: 12)),
                                    ],
                                  ),
                          ),
                          DataCell(
                            Text(
                              row.task.dueDate == null
                                  ? '—'
                                  : '${dateFmt.format(row.task.dueDate!)}${row.task.isOverdue ? ' (quá hạn)' : ''}',
                              style: TextStyle(
                                fontSize: 13,
                                color: row.task.isOverdue ? AppColors.webDestructive : null,
                                fontWeight: row.task.isOverdue ? FontWeight.w600 : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Lỗi tải công việc: $e')),
          ),
        ),
      ],
    );
  }
}

Future<void> showProjectTaskDialog(BuildContext context, String projectId, {String? parentTaskId}) {
  return showDialog(context: context, builder: (_) => _ProjectTaskDialog(projectId: projectId, parentTaskId: parentTaskId));
}

class _ProjectTaskDialog extends ConsumerStatefulWidget {
  const _ProjectTaskDialog({required this.projectId, this.parentTaskId});
  final String projectId;
  final String? parentTaskId;

  @override
  ConsumerState<_ProjectTaskDialog> createState() => _ProjectTaskDialogState();
}

class _ProjectTaskDialogState extends ConsumerState<_ProjectTaskDialog> {
  final _titleController = TextEditingController();
  String? _departmentId;
  String? _workItemId;
  String? _assigneeId;
  String? _parentTaskId;
  TaskPriority _priority = TaskPriority.medium;
  DateTime? _dueDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _parentTaskId = widget.parentTaskId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _departmentId == null || _workItemId == null) {
      showAppToast(context, 'Nhập tên công việc, hạng mục và bộ phận');
      return;
    }
    setState(() => _saving = true);
    final close = PendingDialogClose.of(context);
    try {
      await ref.read(taskActionsProvider.notifier).create(
            title: title,
            projectId: widget.projectId,
            departmentId: _departmentId!,
            workItemId: _workItemId!,
            assigneeId: _assigneeId,
            parentTaskId: _parentTaskId,
            dueDate: _dueDate,
            priority: _priority,
          );
      close.success('Đã tạo công việc');
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final departmentsAsync = ref.watch(departmentListProvider);
    final usersAsync = ref.watch(userListProvider);
    final workItemsAsync = ref.watch(workItemListProvider(widget.projectId));
    final tasksAsync = ref.watch(taskListProvider(projectId: widget.projectId));
    final parents = (tasksAsync.asData?.value ?? const <Task>[]).where((t) => t.parentTaskId == null).toList();

    return AlertDialog(
      title: Text(widget.parentTaskId != null ? 'Tạo đầu việc con' : 'Tạo công việc'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Tên công việc *', isDense: true)),
              const SizedBox(height: 10),
              workItemsAsync.when(
                data: (items) => DropdownButtonFormField<String>(
                  initialValue: _workItemId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Hạng mục công việc *', isDense: true),
                  items: [
                    for (final w in items)
                      DropdownMenuItem(value: w.id, child: Text(w.name, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _workItemId = v;
                      final match = items.where((w) => w.id == v).firstOrNull;
                      if (match != null) _departmentId = match.departmentId;
                    });
                  },
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
              ),
              const SizedBox(height: 10),
              departmentsAsync.when(
                data: (depts) => DropdownButtonFormField<String>(
                  initialValue: _departmentId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Bộ phận *', isDense: true),
                  items: [
                    for (final d in depts)
                      DropdownMenuItem(value: d.id, child: Text(d.name, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _departmentId = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
              ),
              const SizedBox(height: 10),
              usersAsync.when(
                data: (users) => DropdownButtonFormField<String?>(
                  initialValue: _assigneeId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Người phụ trách', isDense: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('—')),
                    for (final u in users)
                      DropdownMenuItem(value: u.id, child: Text(u.displayName, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _assigneeId = v),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<TaskPriority>(
                initialValue: _priority,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Ưu tiên', isDense: true),
                items: [for (final p in TaskPriority.values) DropdownMenuItem(value: p, child: Text(p.label))],
                onChanged: (v) {
                  if (v != null) setState(() => _priority = v);
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: _parentTaskId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Công việc cha (tuỳ chọn)', isDense: true),
                items: [
                  const DropdownMenuItem(value: null, child: Text('— Không —')),
                  for (final t in parents) DropdownMenuItem(value: t.id, child: Text(t.title, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) {
                  setState(() {
                    _parentTaskId = v;
                    final parent = parents.where((t) => t.id == v).firstOrNull;
                    if (parent?.workItemId != null) _workItemId = parent!.workItemId;
                  });
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_dueDate == null ? 'Hạn hoàn thành' : 'Hạn: ${DateFormat('dd/MM/yyyy').format(_dueDate!)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_dueDate != null)
                      IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _dueDate = null)),
                    const Icon(Icons.calendar_today, size: 18),
                  ],
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dueDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2040),
                  );
                  if (picked != null) setState(() => _dueDate = picked);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Huỷ')),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Lưu'),
        ),
      ],
    );
  }
}
