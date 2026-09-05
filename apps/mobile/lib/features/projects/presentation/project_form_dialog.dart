import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../users/application/user_provider.dart';
import '../application/project_provider.dart';
import '../data/project_repository.dart';

Future<void> showProjectFormDialog(BuildContext context) {
  return showDialog(context: context, builder: (_) => const _ProjectFormDialog());
}

class _ProjectFormDialog extends ConsumerStatefulWidget {
  const _ProjectFormDialog();

  @override
  ConsumerState<_ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends ConsumerState<_ProjectFormDialog> {
  final _nameController = TextEditingController();
  final _clientController = TextEditingController();
  final _typeController = TextEditingController();
  final _areaController = TextEditingController();
  final _budgetController = TextEditingController();
  ProjectCategory _category = ProjectCategory.construction;
  String? _managerId;
  bool _saving = false;

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final client = _clientController.text.trim();
    if (name.isEmpty || client.isEmpty || _managerId == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(projectActionsProvider.notifier).create(
            name: name,
            client: client,
            category: _category,
            managerId: _managerId!,
            type: _typeController.text.trim().isEmpty ? null : _typeController.text.trim(),
            area: double.tryParse(_areaController.text.trim()),
            budget: int.tryParse(_budgetController.text.trim()),
          );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(userListProvider);
    return AlertDialog(
      title: const Text('Tạo dự án'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Tên dự án')),
              const SizedBox(height: 10),
              TextField(controller: _clientController, decoration: const InputDecoration(labelText: 'Khách hàng')),
              const SizedBox(height: 10),
              DropdownButtonFormField<ProjectCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Phân loại'),
                items: ProjectCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label))).toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 10),
              TextField(controller: _typeController, decoration: const InputDecoration(labelText: 'Loại hình công trình (VD: Nhà phố, Biệt thự...)')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: _areaController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Diện tích (m²)'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _budgetController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ngân sách (₫)'))),
                ],
              ),
              const SizedBox(height: 10),
              usersAsync.when(
                data: (users) => DropdownButtonFormField<String>(
                  initialValue: _managerId,
                  decoration: const InputDecoration(labelText: 'Quản lý dự án'),
                  items: users.map((u) => DropdownMenuItem(value: u.id, child: Text(u.displayName))).toList(),
                  onChanged: (v) => setState(() => _managerId = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Lỗi tải danh sách: $e'),
              ),
            ],
          ),
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
