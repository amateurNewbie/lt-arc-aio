import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../cost_categories/application/cost_category_provider.dart';
import '../../cost_categories/data/cost_category_repository.dart';
import '../../funds/application/fund_provider.dart';
import '../application/overhead_provider.dart';
import '../data/overhead_repository.dart';

String _monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

DateTime _parseMonth(String month) {
  final parts = month.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]));
}

String _shiftMonth(String month, int delta) {
  final d = _parseMonth(month);
  return _monthKey(DateTime(d.year, d.month + delta));
}

/// FR-8 — Chi phí chung & phân bổ tay theo dự án (tháng tự chọn).
class OverheadAllocationTab extends ConsumerStatefulWidget {
  const OverheadAllocationTab({super.key});

  @override
  ConsumerState<OverheadAllocationTab> createState() => _OverheadAllocationTabState();
}

class _OverheadAllocationTabState extends ConsumerState<OverheadAllocationTab> {
  late String _month = _monthKey(DateTime.now());

  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _categoryId;
  String? _fundId;
  DateTime _date = DateTime.now();
  bool _savingCost = false;
  bool _applying = false;

  final Map<String, TextEditingController> _allocControllers = {};

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    for (final c in _allocControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String projectId) {
    return _allocControllers.putIfAbsent(projectId, () => TextEditingController(text: '0'));
  }

  Future<void> _saveCost() async {
    final amount = int.tryParse(_amountController.text.trim().replaceAll('.', '').replaceAll(',', '')) ?? 0;
    if (_categoryId == null || _fundId == null || amount <= 0) {
      showAppToast(context, 'Chọn loại chi phí, quỹ và nhập số tiền', error: true);
      return;
    }
    setState(() => _savingCost = true);
    try {
      await ref.read(overheadActionsProvider.notifier).declareCost(
            costCategoryId: _categoryId!,
            amount: amount,
            date: _date,
            month: _month,
            fundAccountId: _fundId!,
            note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          );
      if (mounted) {
        _amountController.clear();
        _noteController.clear();
        showAppToast(context, 'Đã lưu chi phí chung');
      }
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _savingCost = false);
    }
  }

  Future<void> _applyAllocation(List<OverheadActiveProject> projects, int totalMonth) async {
    final items = <({String projectId, int allocatedAmount})>[];
    for (final p in projects) {
      final amount = int.tryParse(_controllerFor(p.projectId).text.trim().replaceAll('.', '').replaceAll(',', '')) ?? 0;
      if (amount > 0) {
        items.add((projectId: p.projectId, allocatedAmount: amount));
      }
    }
    final sum = items.fold<int>(0, (s, i) => s + i.allocatedAmount);
    if (items.isEmpty) {
      showAppToast(context, 'Nhập số tiền phân bổ cho ít nhất một dự án', error: true);
      return;
    }
    if (sum != totalMonth) {
      showAppToast(
        context,
        'Tổng phân bổ (${NumberFormat.decimalPattern('vi').format(sum)}) phải bằng tổng tháng (${NumberFormat.decimalPattern('vi').format(totalMonth)})',
        error: true,
      );
      return;
    }
    setState(() => _applying = true);
    try {
      await ref.read(overheadActionsProvider.notifier).applyManual(month: _month, items: items);
      if (mounted) showAppToast(context, 'Đã áp dụng phân bổ');
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.decimalPattern('vi');
    final dateFormat = DateFormat('dd/MM/yyyy');
    final costsAsync = ref.watch(overheadCostListProvider(month: _month));
    final categoriesAsync = ref.watch(costCategoryListProvider(scope: CostCategoryScope.company));
    final fundsAsync = ref.watch(fundListProvider);
    final projectsAsync = ref.watch(overheadActiveProjectsProvider);
    final categoriesById = {for (final c in categoriesAsync.value ?? const <CostCategory>[]) c.id: c};

    final costs = costsAsync.value ?? const <OverheadCost>[];
    final totalMonth = costs.fold<int>(0, (s, c) => s + c.amount);

    final projects = projectsAsync.value ?? const <OverheadActiveProject>[];
    final allocatedSum = projects.fold<int>(0, (s, p) {
      return s + (int.tryParse(_controllerFor(p.projectId).text.trim().replaceAll('.', '').replaceAll(',', '')) ?? 0);
    });
    final remaining = totalMonth - allocatedSum;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Tháng trước',
                onPressed: () => setState(() => _month = _shiftMonth(_month, -1)),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                'Tháng $_month',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              IconButton(
                tooltip: 'Tháng sau',
                onPressed: () => setState(() => _month = _shiftMonth(_month, 1)),
                icon: const Icon(Icons.chevron_right),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _month = _monthKey(DateTime.now())),
                child: const Text('Tháng hiện tại'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.webCardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.webBorder),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Khai báo chi phí chung', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    SizedBox(
                      width: 220,
                      child: categoriesAsync.when(
                        data: (categories) => DropdownButtonFormField<String>(
                          initialValue: _categoryId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Loại chi phí *', isDense: true),
                          items: [
                            for (final c in categories)
                              DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (v) => setState(() => _categoryId = v),
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('$e'),
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Số tiền *', isDense: true),
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Ngày *', isDense: true),
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() {
                                _date = picked;
                                _month = _monthKey(picked);
                              });
                            }
                          },
                          child: Text(dateFormat.format(_date), style: const TextStyle(fontSize: 13)),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _noteController,
                        decoration: const InputDecoration(labelText: 'Diễn giải', isDense: true),
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: fundsAsync.when(
                        data: (funds) => DropdownButtonFormField<String>(
                          initialValue: _fundId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Quỹ *', isDense: true),
                          items: [
                            for (final f in funds)
                              DropdownMenuItem(value: f.id, child: Text(f.name, overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (v) => setState(() => _fundId = v),
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('$e'),
                      ),
                    ),
                    FilledButton(
                      onPressed: _savingCost ? null : _saveCost,
                      style: FilledButton.styleFrom(backgroundColor: AppColors.webForeground, foregroundColor: Colors.white),
                      child: _savingCost
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Lưu'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.webCardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.webBorder),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Chi phí tháng $_month', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                costsAsync.when(
                  data: (list) {
                    if (list.isEmpty) return const Text('Chưa có chi phí chung nào tháng này');
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowHeight: 32,
                        dataRowMinHeight: 40,
                        dataRowMaxHeight: 48,
                        columns: const [
                          DataColumn(label: Text('LOẠI', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('SỐ TIỀN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('NGÀY', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('DIỄN GIẢI', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                        ],
                        rows: [
                          for (final c in list)
                            DataRow(cells: [
                              DataCell(Text(categoriesById[c.costCategoryId]?.name ?? '—', style: const TextStyle(fontSize: 13))),
                              DataCell(Text('${currency.format(c.amount)} ₫', style: const TextStyle(fontSize: 13))),
                              DataCell(Text(dateFormat.format(c.date), style: const TextStyle(fontSize: 13))),
                              DataCell(Text(c.note ?? '—', style: TextStyle(fontSize: 13, color: AppColors.webMutedFg))),
                            ]),
                          DataRow(cells: [
                            const DataCell(Text('Tổng', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                            DataCell(Text('${currency.format(totalMonth)} ₫', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                            const DataCell(Text('')),
                            const DataCell(Text('')),
                          ]),
                        ],
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Lỗi tải dữ liệu: $e'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.webCardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.webBorder),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Phân bổ — Tháng $_month', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                    Text(
                      'Còn lại: ${currency.format(remaining)} ₫',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: remaining == 0 ? AppColors.webSuccess : AppColors.webWarning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _applying || projects.isEmpty || totalMonth <= 0
                          ? null
                          : () => _applyAllocation(projects, totalMonth),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.webForeground, foregroundColor: Colors.white),
                      child: _applying
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Apply'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Nhập số tiền phân bổ từng dự án đang hoạt động. Tổng phải bằng tổng chi phí chung tháng.',
                  style: TextStyle(fontSize: 12, color: AppColors.webMutedFg),
                ),
                const SizedBox(height: 12),
                projectsAsync.when(
                  data: (list) {
                    if (list.isEmpty) return const Text('Không có dự án đang hoạt động để phân bổ');
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowHeight: 32,
                        dataRowMinHeight: 48,
                        dataRowMaxHeight: 56,
                        columns: const [
                          DataColumn(label: Text('DỰ ÁN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('MÃ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('SỐ TIỀN PHÂN BỔ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                        ],
                        rows: [
                          for (final p in list)
                            DataRow(cells: [
                              DataCell(Text(p.projectName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                              DataCell(Text(p.projectCode, style: TextStyle(fontSize: 12, color: AppColors.webMutedFg))),
                              DataCell(
                                SizedBox(
                                  width: 160,
                                  child: TextField(
                                    controller: _controllerFor(p.projectId),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(isDense: true, suffixText: '₫'),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ),
                            ]),
                        ],
                      ),
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Lỗi tải dự án: $e'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
