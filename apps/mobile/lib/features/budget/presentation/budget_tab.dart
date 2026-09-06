import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/web_badge.dart';
import '../../cost_categories/application/cost_category_provider.dart';
import '../../cost_categories/data/cost_category_repository.dart';
import '../../projects/application/project_provider.dart';
import '../application/budget_provider.dart';
import '../data/budget_repository.dart';
import '../../../shared/widgets/app_toast.dart';

WebBadgeVariant _budgetBadge(BudgetStatus s) => switch (s) {
      BudgetStatus.draft => WebBadgeVariant.outline,
      BudgetStatus.pending => WebBadgeVariant.warning,
      BudgetStatus.approved => WebBadgeVariant.secondary,
    };

/// FR-4 — tab Dự toán bám HTML: bảng dòng + popup thêm dòng + gửi/duyệt.
class BudgetTab extends ConsumerWidget {
  const BudgetTab({super.key, required this.projectId});

  final String projectId;

  Future<void> _handle(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } on ApiException catch (e) {
      if (context.mounted) showAppToast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetListProvider(projectId));
    final categoriesAsync = ref.watch(costCategoryListProvider(scope: CostCategoryScope.project));
    final projectAsync = ref.watch(projectDetailProvider(projectId));
    final currency = NumberFormat.decimalPattern('vi');

    return budgetsAsync.when(
      data: (budgets) {
        final display = budgets.isEmpty ? null : budgets.first;
        final catNames = {for (final c in categoriesAsync.asData?.value ?? const []) c.id: c.name};
        final contractBudget = projectAsync.asData?.value.budget;
        final estimateTotal = display?.total ?? 0;
        final expectedProfit = contractBudget == null ? null : contractBudget - estimateTotal;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Dự toán dự án', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          if (display != null) ...[
                            const SizedBox(width: 8),
                            WebBadge(display.status.label, variant: _budgetBadge(display.status)),
                            const SizedBox(width: 8),
                            Text('v${display.version}', style: TextStyle(fontSize: 12, color: AppColors.webMutedFg)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mọi dự toán phải được Giám đốc duyệt trước khi có hiệu lực.',
                        style: TextStyle(fontSize: 12, color: AppColors.webMutedFg),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => showBudgetLineDialog(context, projectId),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.webForeground, foregroundColor: Colors.white),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Thêm dòng dự toán'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (display == null)
              const Expanded(child: Center(child: Text('Chưa có dự toán — bấm Thêm dòng dự toán để lập nháp')))
            else ...[
              Expanded(
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowHeight: 40,
                    dataRowMinHeight: 40,
                    dataRowMaxHeight: 52,
                    columns: const [
                      DataColumn(label: Text('Hạng mục chi phí')),
                      DataColumn(label: Text('Diễn giải')),
                      DataColumn(label: Text('Đơn vị')),
                      DataColumn(label: Text('Khối lượng'), numeric: true),
                      DataColumn(label: Text('Đơn giá'), numeric: true),
                      DataColumn(label: Text('Thành tiền'), numeric: true),
                    ],
                    rows: [
                      for (final line in display.lines)
                        DataRow(
                          cells: [
                            DataCell(Text(catNames[line.costCategoryId] ?? '—', style: const TextStyle(fontWeight: FontWeight.w500))),
                            DataCell(Text(line.description ?? '—', overflow: TextOverflow.ellipsis)),
                            DataCell(Text(line.unit)),
                            DataCell(Text(line.quantity % 1 == 0 ? line.quantity.toInt().toString() : line.quantity.toString())),
                            DataCell(Text('${currency.format(line.unitPrice)} ₫')),
                            DataCell(Text('${currency.format(line.amount)} ₫', style: const TextStyle(fontWeight: FontWeight.w500))),
                          ],
                        ),
                      DataRow(
                        cells: [
                          const DataCell(Text('Tổng dự toán chi phí', style: TextStyle(fontWeight: FontWeight.w700))),
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                          DataCell(Text('${currency.format(display.total)} ₫', style: const TextStyle(fontWeight: FontWeight.w700))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.webCardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.webBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _metric('Giá trị hợp đồng / ngân sách', contractBudget == null ? '—' : '${currency.format(contractBudget)} ₫'),
                    ),
                    Expanded(child: _metric('Tổng dự toán chi phí', '${currency.format(estimateTotal)} ₫')),
                    Expanded(
                      child: _metric(
                        'Lãi dự kiến theo dự toán',
                        expectedProfit == null ? '—' : '${expectedProfit >= 0 ? '+' : ''}${currency.format(expectedProfit)} ₫',
                        color: expectedProfit == null
                            ? null
                            : (expectedProfit >= 0 ? AppColors.webSuccess : AppColors.webDestructive),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (display.status == BudgetStatus.draft)
                    FilledButton(
                      onPressed: () => _handle(context, () async {
                        await ref.read(budgetActionsProvider.notifier).submit(projectId, display.id);
                        if (context.mounted) {
                          showAppToast(context, 'Đã gửi duyệt dự toán');
                        }
                      }),
                      child: const Text('Gửi duyệt'),
                    ),
                  if (display.status == BudgetStatus.pending) ...[
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _handle(context, () async {
                        await ref.read(budgetActionsProvider.notifier).approve(projectId, display.id);
                        if (context.mounted) {
                          showAppToast(context, 'Đã duyệt dự toán');
                        }
                      }),
                      child: const Text('Duyệt dự toán'),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi tải dự toán: $e')),
    );
  }

  Widget _metric(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.webMutedFg)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

Future<void> showBudgetLineDialog(BuildContext context, String projectId) {
  return showDialog(context: context, builder: (_) => _BudgetLineDialog(projectId: projectId));
}

class _BudgetLineDialog extends ConsumerStatefulWidget {
  const _BudgetLineDialog({required this.projectId});
  final String projectId;

  @override
  ConsumerState<_BudgetLineDialog> createState() => _BudgetLineDialogState();
}

class _BudgetLineDialogState extends ConsumerState<_BudgetLineDialog> {
  final _unitController = TextEditingController(text: 'm²');
  final _qtyController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  String? _categoryId;
  bool _saving = false;

  @override
  void dispose() {
    _unitController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final qty = double.tryParse(_qtyController.text.trim().replaceAll(',', '.'));
    final price = int.tryParse(_priceController.text.trim().replaceAll('.', ''));
    if (_categoryId == null || qty == null || qty <= 0 || price == null || price < 0) {
      showAppToast(context, 'Nhập đủ hạng mục, khối lượng và đơn giá');
      return;
    }
    setState(() => _saving = true);
    final close = PendingDialogClose.of(context);
    try {
      await ref.read(budgetActionsProvider.notifier).addLine(
            widget.projectId,
            BudgetLineInput(
              costCategoryId: _categoryId!,
              unit: _unitController.text.trim().isEmpty ? 'm²' : _unitController.text.trim(),
              quantity: qty,
              unitPrice: price,
              description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
            ),
          );
      close.success('Đã thêm dòng dự toán');
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(costCategoryListProvider(scope: CostCategoryScope.project));
    final amountPreview = () {
      final q = double.tryParse(_qtyController.text.trim().replaceAll(',', '.'));
      final p = int.tryParse(_priceController.text.trim().replaceAll('.', ''));
      if (q == null || p == null) return null;
      return (q * p).round();
    }();

    return AlertDialog(
      title: const Text('Lập dòng dự toán mới'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              categoriesAsync.when(
                data: (cats) => DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: 'Hạng mục chi phí *', isDense: true),
                  items: [for (final c in cats) DropdownMenuItem(value: c.id, child: Text(c.name))],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(controller: _unitController, decoration: const InputDecoration(labelText: 'Đơn vị tính', isDense: true)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Khối lượng *', isDense: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Đơn giá dự toán (₫) *', isDense: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Diễn giải', hintText: 'VD: Sơn hoàn thiện ngoại thất', isDense: true),
              ),
              if (amountPreview != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Thành tiền: ${NumberFormat.decimalPattern('vi').format(amountPreview)} ₫',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
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
              : const Text('Lưu nháp'),
        ),
      ],
    );
  }
}
