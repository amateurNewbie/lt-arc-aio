import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/web_badge.dart';
import '../../cost_categories/application/cost_category_provider.dart';
import '../../cost_categories/data/cost_category_repository.dart';
import '../application/overhead_provider.dart';
import '../data/overhead_repository.dart';
import 'overhead_cost_form_sheet.dart';

/// FR-8 — Chi phí chung công ty & phân bổ, bám `LT-ARC-Web-UI_1.html` mục
/// "Chi phí chung & Phân bổ": danh sách chi phí chung đã khai báo + phân bổ.
class OverheadAllocationTab extends ConsumerStatefulWidget {
  const OverheadAllocationTab({super.key});

  @override
  ConsumerState<OverheadAllocationTab> createState() => _OverheadAllocationTabState();
}

class _OverheadAllocationTabState extends ConsumerState<OverheadAllocationTab> {
  late String _month = () {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }();
  AllocationBasis _basis = AllocationBasis.revenue;
  List<OverheadAllocationPreview>? _preview;
  bool _loading = false;

  Future<void> _runPreview() async {
    setState(() => _loading = true);
    try {
      final result = await ref.read(overheadActionsProvider.notifier).preview(month: _month, basis: _basis);
      setState(() => _preview = result);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _apply() async {
    setState(() => _loading = true);
    try {
      await ref.read(overheadActionsProvider.notifier).apply(month: _month, basis: _basis);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã áp dụng phân bổ vào P&L')));
        setState(() => _preview = null);
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.decimalPattern('vi');
    final costsAsync = ref.watch(overheadCostListProvider(month: _month));
    final categoriesAsync = ref.watch(costCategoryListProvider());
    final categoriesById = {for (final c in categoriesAsync.value ?? const <CostCategory>[]) c.id: c};
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: () => showOverheadCostFormSheet(context), child: const Icon(Icons.add)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(color: AppColors.webCardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.webBorder)),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Danh sách chi phí chung — Tháng $_month', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                      SizedBox(
                        width: 140,
                        child: TextFormField(initialValue: _month, decoration: const InputDecoration(labelText: 'Tháng (YYYY-MM)', isDense: true), onChanged: (v) => setState(() => _month = v)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  costsAsync.when(
                    data: (costs) {
                      if (costs.isEmpty) return const Text('Chưa có chi phí chung nào tháng này');
                      final total = costs.fold<int>(0, (s, c) => s + c.amount);
                      return Column(
                        children: [
                          for (final c in costs)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(flex: 2, child: Text(categoriesById[c.costCategoryId]?.name ?? '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                  Expanded(child: Text('${currency.format(c.amount)} ₫', style: const TextStyle(fontSize: 13))),
                                  Expanded(flex: 2, child: Text(c.note ?? '—', style: TextStyle(fontSize: 13, color: AppColors.webMutedFg))),
                                  Expanded(child: Text(dateFormat.format(c.date), style: const TextStyle(fontSize: 13))),
                                ],
                              ),
                            ),
                          const Divider(),
                          Row(
                            children: [
                              const Expanded(flex: 2, child: Text('Tổng chi phí chung tháng', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                              Expanded(child: Text('${currency.format(total)} ₫', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                              const Expanded(flex: 3, child: SizedBox()),
                            ],
                          ),
                        ],
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
              decoration: BoxDecoration(color: AppColors.webCardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.webBorder)),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Phân bổ chi phí chung — Tháng $_month', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              'Xem trước không ghi DB; xác nhận mới cộng vào Tổng chi phí của P&L, idempotent theo tháng.',
                              style: TextStyle(fontSize: 12, color: AppColors.webMutedFg),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 160,
                        child: DropdownButtonFormField<AllocationBasis>(
                          initialValue: _basis,
                          decoration: const InputDecoration(labelText: 'Tiêu thức', isDense: true),
                          items: [for (final b in AllocationBasis.values) DropdownMenuItem(value: b, child: Text(b.label, style: const TextStyle(fontSize: 13)))],
                          onChanged: (v) => setState(() => _basis = v!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(onPressed: _loading ? null : _runPreview, child: const Text('Xem trước')),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _loading || _preview == null ? null : _apply,
                        style: FilledButton.styleFrom(backgroundColor: AppColors.webForeground, foregroundColor: Colors.white),
                        child: const Text('Xác nhận & áp dụng'),
                      ),
                    ],
                  ),
                  if (_loading) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
                  if (_preview != null) ...[
                    const SizedBox(height: 12),
                    if (_preview!.isEmpty)
                      const Text('Không có dự án nào để phân bổ tháng này')
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 32,
                          dataRowMinHeight: 40,
                          dataRowMaxHeight: 48,
                          columns: const [
                            DataColumn(label: Text('DỰ ÁN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('TỶ TRỌNG', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                            DataColumn(label: Text('CHI PHÍ CHUNG PHÂN BỔ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                          ],
                          rows: [
                            for (final item in _preview!)
                              DataRow(cells: [
                                DataCell(Text(item.projectCode.isEmpty ? item.projectId : item.projectCode, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                DataCell(WebBadge('${(item.revenueShare * 100).toStringAsFixed(0)}%', variant: WebBadgeVariant.outline)),
                                DataCell(Text('${currency.format(item.allocatedAmount)} ₫', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                              ]),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
