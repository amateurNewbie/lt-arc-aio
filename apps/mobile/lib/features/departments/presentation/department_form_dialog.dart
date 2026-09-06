import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../users/application/user_provider.dart';
import '../application/department_provider.dart';
import '../../../shared/widgets/app_toast.dart';

Future<void> showDepartmentFormDialog(BuildContext context) {
  return showDialog(context: context, builder: (_) => const _DepartmentFormDialog());
}

class _DepartmentFormDialog extends ConsumerStatefulWidget {
  const _DepartmentFormDialog();

  @override
  ConsumerState<_DepartmentFormDialog> createState() => _DepartmentFormDialogState();
}

class _DepartmentFormDialogState extends ConsumerState<_DepartmentFormDialog> {
  final _nameController = TextEditingController();
  String? _headUserId;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final close = PendingDialogClose.of(context);
    try {
      await ref.read(departmentActionsProvider.notifier).create(name: name, headUserId: _headUserId);
      close.success('Đã tạo bộ phận');
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(userListProvider);
    return AlertDialog(
      title: const Text('Tạo bộ phận'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Tên bộ phận')),
            const SizedBox(height: 12),
            usersAsync.when(
              data: (users) => DropdownButtonFormField<String?>(
                initialValue: _headUserId,
                decoration: const InputDecoration(labelText: 'Trưởng bộ phận'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('— Chưa gán —')),
                  for (final u in users) DropdownMenuItem(value: u.id, child: Text(u.displayName)),
                ],
                onChanged: (v) => setState(() => _headUserId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Lỗi tải danh sách: $e'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Huỷ')),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Tạo'),
        ),
      ],
    );
  }
}
