import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../cost_categories/application/cost_category_provider.dart';
import '../../cost_categories/data/cost_category_repository.dart';
import '../../funds/application/fund_provider.dart';
import '../../work_items/application/work_item_provider.dart';
import '../application/cashbook_provider.dart';
import '../../../shared/widgets/app_toast.dart';

Future<void> showExpenseDialog(BuildContext context, String projectId) {
  return showDialog(context: context, builder: (_) => ExpenseFormDialog(projectId: projectId));
}

/// FR-6 — tab Chi phí: danh sách + popup ghi nhận khoản chi.
class ExpenseTab extends ConsumerWidget {
  const ExpenseTab({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final costsAsync = ref.watch(projectCostListProvider(projectId));
    final categoriesAsync = ref.watch(costCategoryListProvider(scope: CostCategoryScope.project));
    final workItemsAsync = ref.watch(workItemListProvider(projectId));
    final currency = NumberFormat.decimalPattern('vi');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => showExpenseDialog(context, projectId),
            style: FilledButton.styleFrom(backgroundColor: AppColors.webForeground, foregroundColor: Colors.white),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Thêm khoản chi'),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: costsAsync.when(
            data: (costs) {
              if (costs.isEmpty) return const Center(child: Text('Chưa có khoản chi nào'));
              final catNames = {for (final c in categoriesAsync.asData?.value ?? const []) c.id: c.name};
              final wiNames = {for (final w in workItemsAsync.asData?.value ?? const []) w.id: w.name};
              final total = costs.fold<int>(0, (s, c) => s + c.amount);

              return Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Tổng chi: ${currency.format(total)} ₫', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowHeight: 40,
                        dataRowMinHeight: 40,
                        dataRowMaxHeight: 48,
                        columns: const [
                          DataColumn(label: Text('Ngày')),
                          DataColumn(label: Text('Hạng mục')),
                          DataColumn(label: Text('Hạng mục CV')),
                          DataColumn(label: Text('Diễn giải')),
                          DataColumn(label: Text('Số tiền'), numeric: true),
                        ],
                        rows: [
                          for (final c in costs)
                            DataRow(
                              cells: [
                                DataCell(Text(DateFormat('dd/MM/yyyy').format(c.date))),
                                DataCell(Text(catNames[c.costCategoryId] ?? '—')),
                                DataCell(Text(c.workItemId == null ? '—' : (wiNames[c.workItemId] ?? '—'))),
                                DataCell(Text(c.note ?? '—', overflow: TextOverflow.ellipsis)),
                                DataCell(
                                  Text(
                                    '-${currency.format(c.amount)} ₫',
                                    style: const TextStyle(color: AppColors.webDestructive, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Lỗi tải chi phí: $e')),
          ),
        ),
      ],
    );
  }
}

class ExpenseFormDialog extends ConsumerStatefulWidget {
  const ExpenseFormDialog({super.key, required this.projectId});
  final String projectId;

  @override
  ConsumerState<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends ConsumerState<ExpenseFormDialog> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _categoryId;
  String? _workItemId;
  String? _fundId;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit({bool confirmDuplicate = false, PendingDialogClose? close}) async {
    final amount = int.tryParse(_amountController.text.trim().replaceAll('.', '')) ?? 0;
    if (amount <= 0) {
      showAppToast(context, 'Nhập số tiền hợp lệ');
      return;
    }
    if (_categoryId == null) {
      showAppToast(context, 'Chọn hạng mục chi phí');
      return;
    }
    if (_fundId == null) {
      showAppToast(context, 'Chọn quỹ / tài khoản');
      return;
    }

    final dismiss = close ?? PendingDialogClose.of(context);
    setState(() => _saving = true);
    try {
      final warning = await ref.read(cashbookActionsProvider.notifier).createCost(
            projectId: widget.projectId,
            costCategoryId: _categoryId!,
            amount: amount,
            date: _date,
            workItemId: _workItemId,
            fundAccountId: _fundId,
            note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
            confirmDuplicate: confirmDuplicate,
          );

      if (warning != null) {
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Cảnh báo trùng lặp'),
            content: Text(
              'Đã có khoản chi ${NumberFormat.decimalPattern('vi').format(warning.existingAmount)} ₫ '
              'ngày ${DateFormat('dd/MM/yyyy').format(warning.existingDate)} cùng hạng mục. Vẫn lưu?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Huỷ')),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Vẫn lưu')),
            ],
          ),
        );
        if (confirmed == true) {
          await _submit(confirmDuplicate: true, close: dismiss);
          return;
        }
      } else {
        dismiss.success('Đã ghi nhận khoản chi');
      }
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(costCategoryListProvider(scope: CostCategoryScope.project));
    final workItemsAsync = ref.watch(workItemListProvider(widget.projectId));
    final fundsAsync = ref.watch(fundListProvider);

    return AlertDialog(
      title: const Text('Ghi nhận khoản chi'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              categoriesAsync.when(
                data: (cats) => DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Hạng mục chi phí *', isDense: true),
                  items: [for (final c in cats) DropdownMenuItem(value: c.id, child: Text(c.name))],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
              ),
              const SizedBox(height: 10),
              workItemsAsync.when(
                data: (items) => DropdownButtonFormField<String?>(
                  initialValue: _workItemId,
                  decoration: const InputDecoration(labelText: 'Hạng mục công việc (tuỳ chọn)', isDense: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('—')),
                    for (final w in items) DropdownMenuItem(value: w.id, child: Text(w.name)),
                  ],
                  onChanged: (v) => setState(() => _workItemId = v),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Số tiền (₫) *', isDense: true),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Ngày phát sinh: ${DateFormat('dd/MM/yyyy').format(_date)}'),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
                  if (picked != null) setState(() => _date = picked);
                },
              ),
              fundsAsync.when(
                data: (funds) => DropdownButtonFormField<String>(
                  initialValue: _fundId,
                  decoration: const InputDecoration(labelText: 'Quỹ / Tài khoản *', isDense: true),
                  items: [for (final f in funds) DropdownMenuItem(value: f.id, child: Text(f.name))],
                  onChanged: (v) => setState(() => _fundId = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Nhà cung cấp / Diễn giải', isDense: true),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Huỷ')),
        FilledButton(
          onPressed: _saving ? null : () => _submit(),
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Lưu khoản chi'),
        ),
      ],
    );
  }
}
