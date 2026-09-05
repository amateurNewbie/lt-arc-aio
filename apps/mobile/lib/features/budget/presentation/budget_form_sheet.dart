import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../cost_categories/application/cost_category_provider.dart';
import '../../cost_categories/data/cost_category_repository.dart';
import '../application/budget_provider.dart';
import '../data/budget_repository.dart';

Future<void> showBudgetFormSheet(BuildContext context, String projectId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _BudgetFormSheet(projectId: projectId),
  );
}

class _DraftLine {
  String? costCategoryId;
  String unit = 'm2';
  double quantity = 0;
  int unitPrice = 0;
}

class _BudgetFormSheet extends ConsumerStatefulWidget {
  const _BudgetFormSheet({required this.projectId});
  final String projectId;

  @override
  ConsumerState<_BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends ConsumerState<_BudgetFormSheet> {
  final List<_DraftLine> _lines = [_DraftLine()];
  bool _saving = false;

  Future<void> _submit() async {
    final valid = _lines.where((l) => l.costCategoryId != null && l.quantity > 0 && l.unitPrice > 0).toList();
    if (valid.isEmpty) return;

    setState(() => _saving = true);
    try {
      await ref.read(budgetActionsProvider.notifier).create(
            widget.projectId,
            valid
                .map((l) => BudgetLineInput(costCategoryId: l.costCategoryId!, unit: l.unit, quantity: l.quantity, unitPrice: l.unitPrice))
                .toList(),
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
    final categoriesAsync = ref.watch(costCategoryListProvider(scope: CostCategoryScope.project));

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lập dự toán mới', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            categoriesAsync.when(
              data: (categories) => Column(
                children: [
                  for (var i = 0; i < _lines.length; i++) _lineRow(i, categories),
                  TextButton.icon(
                    onPressed: () => setState(() => _lines.add(_DraftLine())),
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm dòng'),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Lỗi tải danh mục: $e'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Lưu dự toán (Nháp)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineRow(int index, List<CostCategory> categories) {
    final line = _lines[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              initialValue: line.costCategoryId,
              decoration: const InputDecoration(labelText: 'Hạng mục'),
              items: [for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))],
              onChanged: (value) => setState(() => line.costCategoryId = value),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              decoration: const InputDecoration(labelText: 'K.lượng'),
              keyboardType: TextInputType.number,
              onChanged: (v) => line.quantity = double.tryParse(v) ?? 0,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              decoration: const InputDecoration(labelText: 'Đơn giá'),
              keyboardType: TextInputType.number,
              onChanged: (v) => line.unitPrice = int.tryParse(v) ?? 0,
            ),
          ),
        ],
      ),
    );
  }
}
