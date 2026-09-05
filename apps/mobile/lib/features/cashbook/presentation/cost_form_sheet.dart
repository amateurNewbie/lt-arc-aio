import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../cost_categories/application/cost_category_provider.dart';
import '../../cost_categories/data/cost_category_repository.dart';
import '../application/cashbook_provider.dart';

Future<void> showCostFormSheet(BuildContext context, String projectId) {
  return showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => _CostFormSheet(projectId: projectId));
}

class _CostFormSheet extends ConsumerStatefulWidget {
  const _CostFormSheet({required this.projectId});
  final String projectId;

  @override
  ConsumerState<_CostFormSheet> createState() => _CostFormSheetState();
}

class _CostFormSheetState extends ConsumerState<_CostFormSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _categoryId;
  DateTime _date = DateTime.now();
  bool _saving = false;

  Future<void> _submit({bool confirmDuplicate = false}) async {
    final amount = int.tryParse(_amountController.text) ?? 0;
    if (amount <= 0 || _categoryId == null) return;

    setState(() => _saving = true);
    try {
      final warning = await ref.read(cashbookActionsProvider.notifier).createCost(
            projectId: widget.projectId,
            costCategoryId: _categoryId!,
            amount: amount,
            date: _date,
            note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
            confirmDuplicate: confirmDuplicate,
          );

      if (warning != null) {
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Có thể trùng khoản chi'),
            content: Text(
              'Đã có khoản chi ${warning.existingAmount} ₫ ngày ${DateFormat('dd/MM/yyyy').format(warning.existingDate)} '
              'cùng dự án, cùng hạng mục, cùng số tiền. Vẫn lưu tiếp?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Huỷ')),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Vẫn lưu')),
            ],
          ),
        );
        if (confirmed == true) {
          await _submit(confirmDuplicate: true);
          return;
        }
      } else if (mounted) {
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(costCategoryListProvider(scope: CostCategoryScope.project));

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ghi nhận khoản chi', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          categoriesAsync.when(
            data: (categories) => DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Hạng mục chi phí'),
              items: [for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Lỗi tải danh mục: $e'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Số tiền (₫)'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _noteController, decoration: const InputDecoration(labelText: 'Diễn giải')),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: Text('Ngày phát sinh: ${DateFormat('dd/MM/yyyy').format(_date)}'),
            onTap: () async {
              final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (picked != null) setState(() => _date = picked);
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : () => _submit(),
            child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Lưu khoản chi'),
          ),
        ],
      ),
    );
  }
}
