import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/web_badge.dart';
import '../../debts/application/debt_provider.dart';
import '../../debts/data/debt_repository.dart';
import '../../projects/application/project_provider.dart';
import '../../projects/data/project_repository.dart';
import '../application/reports_provider.dart';
import '../data/reports_repository.dart';

WebBadgeVariant _categoryVariant(ProjectCategory c) => switch (c) {
      ProjectCategory.construction => WebBadgeVariant.warning,
      ProjectCategory.turnkey => WebBadgeVariant.primary,
      ProjectCategory.design => WebBadgeVariant.outline,
    };

/// FR-11.3 — Tổng quan & P&L theo từng dự án + bộ lọc client-side.
class ProfitLossTab extends ConsumerStatefulWidget {
  const ProfitLossTab({super.key});

  @override
  ConsumerState<ProfitLossTab> createState() => _ProfitLossTabState();
}

class _ProfitLossTabState extends ConsumerState<ProfitLossTab> {
  DateTime? _from;
  DateTime? _to;
  ProjectCategory? _category;
  String? _projectId;

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _from = picked);
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _to = picked);
  }

  void _applyQuarter(int quarter) {
    final year = DateTime.now().year;
    final startMonth = (quarter - 1) * 3 + 1;
    setState(() {
      _from = DateTime(year, startMonth, 1);
      _to = DateTime(year, startMonth + 3, 0);
    });
  }

  bool _projectInDateRange(Project? project) {
    if (_from == null && _to == null) return true;
    if (project == null) return true;
    final start = project.startDate;
    final due = project.dueDate;
    // If project has no dates, keep it when filtering by range (API P&L has no dates yet).
    if (start == null && due == null) return true;
    final rangeStart = _from ?? DateTime(2000);
    final rangeEnd = _to ?? DateTime(2100);
    final pStart = start ?? due!;
    final pEnd = due ?? start!;
    return !pEnd.isBefore(rangeStart) && !pStart.isAfter(rangeEnd);
  }

  List<ProjectPnl> _filterRows(List<ProjectPnl> rows, Map<String, Project> projectsById, Map<String, Project> projectsByCode) {
    return rows.where((r) {
      final project = projectsById[r.projectId] ?? projectsByCode[r.projectCode];
      if (_projectId != null && r.projectId != _projectId && project?.id != _projectId) return false;
      if (_category != null && project?.category != _category) return false;
      if (!_projectInDateRange(project)) return false;
      return true;
    }).toList();
  }

  List<Receivable> _filterReceivables(List<Receivable> list, Set<String> allowedProjectIds) {
    if (_projectId == null && _category == null && _from == null && _to == null) return list;
    return list.where((r) => allowedProjectIds.contains(r.projectId)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pnlAsync = ref.watch(
      profitLossReportProvider(
        category: _category?.wire,
        projectId: _projectId,
        dateFrom: _from,
        dateTo: _to,
      ),
    );
    final projectsAsync = ref.watch(projectListProvider());
    final receivablesAsync = ref.watch(receivableListProvider);
    final currency = NumberFormat.decimalPattern('vi');
    final dateFmt = DateFormat('dd/MM/yyyy');

    final projects = projectsAsync.value ?? const <Project>[];
    final projectsById = {for (final p in projects) p.id: p};
    final projectsByCode = {for (final p in projects) p.code: p};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.webCardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.webBorder),
            ),
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickFrom,
                  icon: const Icon(Icons.calendar_today, size: 14),
                  label: Text(_from == null ? 'Từ ngày' : dateFmt.format(_from!), style: const TextStyle(fontSize: 12)),
                ),
                OutlinedButton.icon(
                  onPressed: _pickTo,
                  icon: const Icon(Icons.event, size: 14),
                  label: Text(_to == null ? 'Đến ngày' : dateFmt.format(_to!), style: const TextStyle(fontSize: 12)),
                ),
                for (final q in [1, 2, 3, 4])
                  TextButton(
                    onPressed: () => _applyQuarter(q),
                    child: Text('Q$q', style: const TextStyle(fontSize: 12)),
                  ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<ProjectCategory?>(
                    initialValue: _category,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Phân loại dự án', isDense: true),
                    items: [
                      const DropdownMenuItem<ProjectCategory?>(value: null, child: Text('Tất cả')),
                      for (final c in ProjectCategory.values) DropdownMenuItem(value: c, child: Text(c.label)),
                    ],
                    onChanged: (v) => setState(() => _category = v),
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _projectId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Dự án', isDense: true),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Tất cả dự án')),
                      for (final p in projects)
                        DropdownMenuItem(value: p.id, child: Text('${p.code} · ${p.name}', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() => _projectId = v),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _from = null;
                    _to = null;
                    _category = null;
                    _projectId = null;
                  }),
                  child: const Text('Xoá lọc'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          pnlAsync.when(
            data: (rows) {
              if (rows.isEmpty) return const Text('Chưa có dữ liệu');
              final filtered = _filterRows(rows, projectsById, projectsByCode);
              final allowedIds = filtered.map((r) => r.projectId).toSet();
              final receivables = _filterReceivables(receivablesAsync.value ?? const [], allowedIds);

              final totalRevenue = filtered.fold<int>(0, (s, r) => s + r.revenue);
              final totalCost = filtered.fold<int>(0, (s, r) => s + r.totalCost);
              final totalProfit = filtered.fold<int>(0, (s, r) => s + r.profit);
              final totalReceivable = receivables.fold<int>(0, (s, r) => s + r.remaining);

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
                        if (filtered.isEmpty)
                          const Text('Không có dự án khớp bộ lọc')
                        else
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
                                for (final r in filtered)
                                  DataRow(cells: [
                                    DataCell(Text(r.projectName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                    DataCell(projectsByCode[r.projectCode] != null
                                        ? WebBadge(projectsByCode[r.projectCode]!.category.label, variant: _categoryVariant(projectsByCode[r.projectCode]!.category))
                                        : const Text('—')),
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
        ],
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
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 12, color: AppColors.webMutedFg)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
