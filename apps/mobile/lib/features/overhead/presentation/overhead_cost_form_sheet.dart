import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../cost_categories/application/cost_category_provider.dart';
import '../../cost_categories/data/cost_category_repository.dart';
import '../application/overhead_provider.dart';
import '../../../shared/widgets/app_toast.dart';

Future<void> showOverheadCostFormSheet(BuildContext context) {
  return showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const _OverheadCostFormSheet());
}

class _OverheadCostFormSheet extends ConsumerStatefulWidget {
  const _OverheadCostFormSheet();

  @override
  ConsumerState<_OverheadCostFormSheet> createState() => _OverheadCostFormSheetState();
}

class _OverheadCostFormSheetState extends ConsumerState<_OverheadCostFormSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _categoryId;
  DateTime _date = DateTime.now();
  bool _saving = false;

  Future<void> _submit() async {
    final amount = int.tryParse(_amountController.text) ?? 0;
    if (amount <= 0 || _categoryId == null) return;
    setState(() => _saving = true);
    final close = PendingDialogClose.of(context);
    try {
      final month = '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}';
      await ref.read(overheadActionsProvider.notifier).declareCost(
            costCategoryId: _categoryId!,
            amount: amount,
            date: _date,
            month: month,
            note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          );
      close.success('Đã thêm chi phí chung');
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(costCategoryListProvider(scope: CostCategoryScope.company));

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Khai báo chi phí chung', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          categoriesAsync.when(
            data: (categories) => DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Hạng mục (phạm vi công ty)'),
              items: [for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Lỗi: $e'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Số tiền (₫)')),
          const SizedBox(height: 12),
          TextField(controller: _noteController, decoration: const InputDecoration(labelText: 'Diễn giải')),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: Text('Ngày ghi nhận: ${DateFormat('dd/MM/yyyy').format(_date)} (tháng ${_date.month}/${_date.year})'),
            onTap: () async {
              final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (picked != null) setState(() => _date = picked);
            },
          ),
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
