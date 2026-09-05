import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../departments/application/department_provider.dart';
import '../application/work_item_provider.dart';

Future<void> showWorkItemFormSheet(BuildContext context, String projectId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _WorkItemFormSheet(projectId: projectId),
  );
}

class _WorkItemFormSheet extends ConsumerStatefulWidget {
  const _WorkItemFormSheet({required this.projectId});

  final String projectId;

  @override
  ConsumerState<_WorkItemFormSheet> createState() => _WorkItemFormSheetState();
}

class _WorkItemFormSheetState extends ConsumerState<_WorkItemFormSheet> {
  final _nameController = TextEditingController();
  final _unitController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  String? _departmentId;
  bool _saving = false;

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final unit = _unitController.text.trim();
    final quantity = double.tryParse(_quantityController.text.trim());
    final price = int.tryParse(_priceController.text.trim());
    if (name.isEmpty || unit.isEmpty || quantity == null || price == null || _departmentId == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(workItemActionsProvider.notifier).create(
            projectId: widget.projectId,
            departmentId: _departmentId!,
            name: name,
            unit: unit,
            quantity: quantity,
            unitPrice: price,
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
    final departmentsAsync = ref.watch(departmentListProvider);

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thêm hạng mục công việc', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Hạng mục')),
          const SizedBox(height: 12),
          departmentsAsync.when(
            data: (departments) => DropdownButtonFormField<String>(
              initialValue: _departmentId,
              decoration: const InputDecoration(labelText: 'Bộ phận'),
              items: departments.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
              onChanged: (v) => setState(() => _departmentId = v),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Lỗi tải bộ phận: $e'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: _unitController, decoration: const InputDecoration(labelText: 'Đơn vị'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _quantityController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Khối lượng'))),
            ],
          ),
          const SizedBox(height: 12),
          TextField(controller: _priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Đơn giá (₫)')),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
