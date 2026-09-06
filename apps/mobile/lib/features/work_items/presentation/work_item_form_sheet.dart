import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../departments/application/department_provider.dart';
import '../../tasks/application/task_provider.dart';
import '../application/work_item_provider.dart';
import '../../../shared/widgets/app_toast.dart';

Future<void> showWorkItemDialog(BuildContext context, String projectId) {
  return showDialog(context: context, builder: (_) => WorkItemFormDialog(projectId: projectId));
}

/// Alias cũ — giữ tương thích nếu còn chỗ gọi sheet.
Future<void> showWorkItemFormSheet(BuildContext context, String projectId) => showWorkItemDialog(context, projectId);

class WorkItemFormDialog extends ConsumerStatefulWidget {
  const WorkItemFormDialog({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<WorkItemFormDialog> createState() => _WorkItemFormDialogState();
}

class _WorkItemFormDialogState extends ConsumerState<WorkItemFormDialog> {
  final _nameController = TextEditingController();
  String? _departmentId;
  bool _createTask = true;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _departmentId == null) {
      showAppToast(context, 'Điền đủ hạng mục và bộ phận');
      return;
    }
    setState(() => _saving = true);
    final close = PendingDialogClose.of(context);
    try {
      await ref.read(workItemActionsProvider.notifier).create(
            projectId: widget.projectId,
            departmentId: _departmentId!,
            name: name,
            createTask: _createTask,
          );
      if (_createTask) {
        ref.invalidate(taskListProvider);
      }
      close.success(_createTask ? 'Đã thêm hạng mục và công việc liên kết' : 'Đã thêm hạng mục');
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(workItemActionsProvider);
    final departmentsAsync = ref.watch(departmentListProvider);

    return AlertDialog(
      title: const Text('Thêm hạng mục công việc'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Hạng mục *', isDense: true)),
              const SizedBox(height: 10),
              departmentsAsync.when(
                data: (departments) => DropdownButtonFormField<String>(
                  initialValue: _departmentId,
                  decoration: const InputDecoration(labelText: 'Bộ phận *', isDense: true),
                  items: [for (final d in departments) DropdownMenuItem(value: d.id, child: Text(d.name))],
                  onChanged: (v) => setState(() => _departmentId = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Lỗi tải bộ phận: $e'),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _createTask,
                onChanged: (v) => setState(() => _createTask = v ?? true),
                title: const Text('Tạo luôn 1 công việc ở tab Công việc', style: TextStyle(fontSize: 13)),
                controlAffinity: ListTileControlAffinity.leading,
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
