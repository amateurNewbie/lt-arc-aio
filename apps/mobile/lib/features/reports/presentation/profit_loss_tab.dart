import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/web_badge.dart';
import '../../debts/application/debt_provider.dart';
import '../../projects/application/project_provider.dart';
import '../../projects/data/project_repository.dart';
import '../application/reports_provider.dart';

WebBadgeVariant _categoryVariant(ProjectCategory c) => switch (c) {
      ProjectCategory.construction => WebBadgeVariant.warning,
      ProjectCategory.turnkey => WebBadgeVariant.primary,
      ProjectCategory.design => WebBadgeVariant.outline,
    };

/// FR-11.3 — Tổng quan & P&L theo từng dự án, bám `LT-ARC-Web-UI_1.html`.
///
/// Ghi chú phạm vi: chỉ dựng "Báo cáo P&L theo từng dự án" (dùng
/// `/api/reports/profit-loss` sẵn có) — bảng "P&L theo từng tháng" và "P&L
/// theo hạng mục chi phí" trong file thiết kế cần thêm dữ liệu tổng hợp nhiều
/// tháng/theo hạng mục mà giao diện chưa kịp dựng ở lượt này.
class ProfitLossTab extends ConsumerWidget {
  const ProfitLossTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pnlAsync = ref.watch(profitLossReportProvider);
    final projectsAsync = ref.watch(projectListProvider());
    final receivablesAsync = ref.watch(receivableListProvider);
    final currency = NumberFormat.decimalPattern('vi');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: pnlAsync.when(
        data: (rows) {
          if (rows.isEmpty) return const Text('Chưa có dữ liệu');
          final totalRevenue = rows.fold<int>(0, (s, r) => s + r.revenue);
          final totalCost = rows.fold<int>(0, (s, r) => s + r.totalCost);
          final totalProfit = rows.fold<int>(0, (s, r) => s + r.profit);
          final totalReceivable = (receivablesAsync.value ?? const []).fold<int>(0, (s, r) => s + r.remaining);
          final projectsByCode = {for (final p in projectsAsync.value ?? const <Project>[]) p.code: p};

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _StatCard(icon: Icons.trending_up, color: AppColors.webSuccess, value: '${currency.format(totalRevenue)} ₫', label: 'Tổng doanh thu đã thu')),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(icon: Icons.trending_down, color: AppColors.webWarning, value: '${currency.format(totalCost)} ₫', label: 'Tổng chi phí đã chi')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.account_balance_outlined,
                      color: totalProfit >= 0 ? AppColors.webSuccess : AppColors.webDestructive,
                      value: '${totalProfit >= 0 ? '+' : ''}${currency.format(totalProfit)} ₫',
                      label: 'Lãi/Lỗ ròng',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(icon: Icons.hourglass_empty, color: AppColors.webMutedFg, value: '${currency.format(totalReceivable)} ₫', label: 'Công nợ phải thu')),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(color: AppColors.webCardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.webBorder)),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Báo cáo P&L theo từng dự án', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      'Doanh thu đã thu − Chi phí trực tiếp − Chi phí chung phân bổ = Lãi/Lỗ, kèm biên lợi nhuận.',
                      style: TextStyle(fontSize: 12, color: AppColors.webMutedFg),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowHeight: 32,
                        dataRowMinHeight: 40,
                        dataRowMaxHeight: 48,
                        columns: const [
                          DataColumn(label: Text('DỰ ÁN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('PHÂN LOẠI', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('DOANH THU ĐÃ THU', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('CHI PHÍ TRỰC TIẾP', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('CP CHUNG PHÂN BỔ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('TỔNG CHI PHÍ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('LÃI/LỖ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('BIÊN LN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                        ],
                        rows: [
                          for (final r in rows)
                            DataRow(cells: [
                              DataCell(Text(r.projectName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                              DataCell(projectsByCode[r.projectCode] != null ? WebBadge(projectsByCode[r.projectCode]!.category.label, variant: _categoryVariant(projectsByCode[r.projectCode]!.category)) : const Text('—')),
                              DataCell(Text('${currency.format(r.revenue)} ₫', style: const TextStyle(fontSize: 13))),
                              DataCell(Text('${currency.format(r.directCost)} ₫', style: const TextStyle(fontSize: 13))),
                              DataCell(Text('${currency.format(r.overheadAllocated)} ₫', style: const TextStyle(fontSize: 13))),
                              DataCell(Text('${currency.format(r.totalCost)} ₫', style: const TextStyle(fontSize: 13))),
                              DataCell(Text(
                                '${r.profit >= 0 ? '+' : ''}${currency.format(r.profit)} ₫',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: r.profit >= 0 ? AppColors.webSuccess : AppColors.webDestructive),
                              )),
                              DataCell(Text(
                                '${r.marginPercent.toStringAsFixed(0)}%',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: r.profit >= 0 ? AppColors.webSuccess : AppColors.webDestructive),
                              )),
                            ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Lỗi tải dữ liệu: $e'),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.color, required this.value, required this.label});

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.webCardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.webBorder)),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(4)),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(label.toUpperCase(), style: TextStyle(fontSize: 10, letterSpacing: 0.3, color: AppColors.webMutedFg)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
