import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/web_badge.dart';
import '../../contracts/application/contract_provider.dart';
import '../../contracts/data/contract_repository.dart';
import '../../cost_categories/application/cost_category_provider.dart';
import '../../projects/application/project_provider.dart';
import '../../projects/data/project_repository.dart';
import '../application/debt_provider.dart';
import '../data/debt_repository.dart';
import 'receive_payment_dialog.dart';
import 'settle_payable_dialog.dart';

/// FR-10 — Công nợ phải thu / phải trả, đúng `LT-ARC-Web-UI_1.html` mục "Công nợ".
class DebtsPage extends StatelessWidget {
  const DebtsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Công nợ'),
          bottom: const TabBar(tabs: [Tab(text: 'Phải thu'), Tab(text: 'Phải trả')]),
        ),
        body: const TabBarView(children: [_ReceivablesTab(), _PayablesTab()]),
      ),
    );
  }
}

bool _isOverdue(DateTime? dueDate) => dueDate != null && dueDate.isBefore(DateTime.now());

class _ReceivablesTab extends StatelessWidget {
  const _ReceivablesTab();

  @override
  Widget build(BuildContext context) => kIsWeb ? const _ReceivablesWebTab() : const _ReceivablesMobileTab();
}

class _ReceivablesMobileTab extends ConsumerWidget {
  const _ReceivablesMobileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receivablesAsync = ref.watch(receivableListProvider);
    final currency = NumberFormat.decimalPattern('vi');

    return receivablesAsync.when(
      data: (items) {
        if (items.isEmpty) return const Center(child: Text('Không có công nợ phải thu'));
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final r = items[index];
            return ListTile(
              title: Text(r.milestoneName),
              subtitle: r.dueDate != null ? Text('Hạn thu: ${DateFormat('dd/MM/yyyy').format(r.dueDate!)}') : null,
              trailing: Text('${currency.format(r.remaining)} ₫', style: const TextStyle(fontWeight: FontWeight.w600)),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi tải dữ liệu: $e')),
    );
  }
}

class _ContractDebtRow {
  _ContractDebtRow({required this.contract, required this.project, required this.currentMilestone});
  final Contract contract;
  final Project? project;
  final ContractMilestone? currentMilestone;

  int get remaining => contract.value - contract.paidAmount;
  bool get overdue => currentMilestone != null && _isOverdue(currentMilestone!.dueDate) && currentMilestone!.remaining > 0;
}

class _ReceivablesWebTab extends ConsumerWidget {
  const _ReceivablesWebTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contractsAsync = ref.watch(contractListAllProvider);
    final projectsAsync = ref.watch(projectListProvider());
    final currency = NumberFormat.decimalPattern('vi');
    final dateFormat = DateFormat('dd/MM/yyyy');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1360),
        child: contractsAsync.when(
          data: (contracts) {
            final projectsById = {for (final p in projectsAsync.value ?? const <Project>[]) p.id: p};
            final rows = <_ContractDebtRow>[];
            for (final c in contracts) {
              final remaining = c.value - c.paidAmount;
              if (remaining <= 0) continue;
              final pending = c.milestones.where((m) => m.remaining > 0).toList()
                ..sort((a, b) => (a.dueDate ?? DateTime(2100)).compareTo(b.dueDate ?? DateTime(2100)));
              rows.add(_ContractDebtRow(contract: c, project: projectsById[c.projectId], currentMilestone: pending.isNotEmpty ? pending.first : null));
            }

            final totalRemaining = rows.fold<int>(0, (s, r) => s + r.remaining);
            final overdueRows = rows.where((r) => r.overdue).toList();
            final overdueAmount = overdueRows.fold<int>(0, (s, r) => s + r.remaining);
            final clientsWithDebt = rows.map((r) => r.project?.client ?? r.project?.name ?? r.contract.projectId).toSet().length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _StatCard(icon: Icons.access_time, color: AppColors.webMutedFg, value: '${currency.format(totalRemaining)} ₫', label: 'Tổng công nợ phải thu')),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(icon: Icons.warning_amber_outlined, color: AppColors.webDestructive, value: '${currency.format(overdueAmount)} ₫', label: 'Đã quá hạn thanh toán', valueColor: AppColors.webDestructive)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(icon: Icons.people_outline, color: AppColors.gold, value: '$clientsWithDebt', label: 'Khách hàng đang có công nợ')),
                  ],
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
                                const Text('Công nợ phải thu theo khách hàng', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text('Theo dõi theo từng đợt thanh toán đã khai báo trong hợp đồng — đợt nào đến hạn/quá hạn sẽ được nhắc tự động.', style: TextStyle(fontSize: 12, color: AppColors.webMutedFg)),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => showReceivePaymentDialog(context, contracts),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Ghi nhận thanh toán'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (rows.isEmpty)
                        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('Không có công nợ phải thu'))
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 32,
                            dataRowMinHeight: 40,
                            dataRowMaxHeight: 48,
                            columns: const [
                              DataColumn(label: Text('KHÁCH HÀNG', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('DỰ ÁN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('GIÁ TRỊ HỢP ĐỒNG', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('ĐÃ THU', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('CÒN PHẢI THU', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('ĐỢT ĐANG CHỜ THU', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('HẠN THU', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('TRẠNG THÁI', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                            ],
                            rows: [
                              for (final r in rows)
                                DataRow(cells: [
                                  DataCell(Text(r.project?.client ?? '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                  DataCell(Text(r.project?.name ?? '—', style: const TextStyle(fontSize: 13))),
                                  DataCell(Text('${currency.format(r.contract.value)} ₫', style: const TextStyle(fontSize: 13))),
                                  DataCell(Text('${currency.format(r.contract.paidAmount)} ₫', style: const TextStyle(fontSize: 13))),
                                  DataCell(Text('${currency.format(r.remaining)} ₫', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: r.overdue ? AppColors.webDestructive : null))),
                                  DataCell(Text(r.currentMilestone != null ? '${r.currentMilestone!.name} (${r.currentMilestone!.ratio.toStringAsFixed(0)}%)' : '—', style: const TextStyle(fontSize: 13))),
                                  DataCell(Text(
                                    r.currentMilestone?.dueDate != null ? '${dateFormat.format(r.currentMilestone!.dueDate!)}${r.overdue ? ' (quá hạn)' : ''}' : '—',
                                    style: TextStyle(fontSize: 13, fontWeight: r.overdue ? FontWeight.w500 : FontWeight.normal, color: r.overdue ? AppColors.webDestructive : null),
                                  )),
                                  DataCell(WebBadge(r.overdue ? 'Quá hạn' : 'Đúng hạn', variant: r.overdue ? WebBadgeVariant.destructive : WebBadgeVariant.outline)),
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
      ),
    );
  }
}

class _PayablesTab extends StatelessWidget {
  const _PayablesTab();

  @override
  Widget build(BuildContext context) => kIsWeb ? const _PayablesWebTab() : const _PayablesMobileTab();
}

class _PayablesMobileTab extends ConsumerWidget {
  const _PayablesMobileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payablesAsync = ref.watch(payableListProvider);
    final currency = NumberFormat.decimalPattern('vi');

    return payablesAsync.when(
      data: (items) {
        if (items.isEmpty) return const Center(child: Text('Không có công nợ phải trả'));
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final p = items[index];
            return ListTile(
              title: Text(p.vendorName),
              subtitle: Text(p.status.label),
              trailing: p.remaining > 0
                  ? TextButton(
                      onPressed: () => showSettlePayableDialog(context, p),
                      child: Text('${currency.format(p.remaining)} ₫'),
                    )
                  : const Icon(Icons.check_circle, color: Colors.green),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi tải dữ liệu: $e')),
    );
  }
}

class _PayablesWebTab extends ConsumerWidget {
  const _PayablesWebTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payablesAsync = ref.watch(payableListProvider);
    final projectsAsync = ref.watch(projectListProvider());
    final categoriesAsync = ref.watch(costCategoryListProvider());
    final currency = NumberFormat.decimalPattern('vi');
    final dateFormat = DateFormat('dd/MM/yyyy');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1360),
        child: payablesAsync.when(
          data: (payables) {
            final projectsById = {for (final p in projectsAsync.value ?? const <Project>[]) p.id: p};
            final categoriesById = {for (final c in categoriesAsync.value ?? const []) c.id: c.name};
            final overdue = payables.where((p) => p.remaining > 0 && _isOverdue(p.dueDate)).toList();

            final totalRemaining = payables.fold<int>(0, (s, p) => s + p.remaining);
            final overdueAmount = overdue.fold<int>(0, (s, p) => s + p.remaining);
            final vendorsWithDebt = payables.where((p) => p.remaining > 0).map((p) => p.vendorName).toSet().length;
            final settleable = payables.where((p) => p.remaining > 0).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _StatCard(icon: Icons.access_time, color: AppColors.webMutedFg, value: '${currency.format(totalRemaining)} ₫', label: 'Tổng công nợ phải trả')),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(icon: Icons.warning_amber_outlined, color: AppColors.webDestructive, value: '${currency.format(overdueAmount)} ₫', label: 'Đã quá hạn thanh toán', valueColor: AppColors.webDestructive)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(icon: Icons.inventory_2_outlined, color: AppColors.gold, value: '$vendorsWithDebt', label: 'NCC/thầu phụ đang nợ')),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(color: AppColors.webCardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.webBorder)),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(child: Text('Công nợ phải trả theo nhà cung cấp / thầu phụ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                          OutlinedButton.icon(
                            onPressed: settleable.isEmpty ? null : () => _pickPayableToSettle(context, settleable),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Ghi nhận thanh toán'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (payables.isEmpty)
                        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('Không có công nợ phải trả'))
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 32,
                            dataRowMinHeight: 40,
                            dataRowMaxHeight: 48,
                            columns: const [
                              DataColumn(label: Text('NHÀ CUNG CẤP / THẦU PHỤ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('DỰ ÁN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('HẠNG MỤC CHI PHÍ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('TỔNG GIÁ TRỊ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('ĐÃ TRẢ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('CÒN PHẢI TRẢ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('HẠN TRẢ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('TRẠNG THÁI', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                            ],
                            rows: [
                              for (final p in payables)
                                DataRow(
                                  onSelectChanged: p.remaining > 0 ? (_) => showSettlePayableDialog(context, p) : null,
                                  cells: [
                                    DataCell(Text(p.vendorName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                    DataCell(Text(projectsById[p.projectId]?.name ?? '—', style: const TextStyle(fontSize: 13))),
                                    DataCell(WebBadge(categoriesById[p.costCategoryId] ?? '—', variant: WebBadgeVariant.outline)),
                                    DataCell(Text('${currency.format(p.totalAmount)} ₫', style: const TextStyle(fontSize: 13))),
                                    DataCell(Text('${currency.format(p.paidAmount)} ₫', style: const TextStyle(fontSize: 13))),
                                    DataCell(Text('${currency.format(p.remaining)} ₫', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: p.remaining > 0 && _isOverdue(p.dueDate) ? AppColors.webDestructive : null))),
                                    DataCell(Text(
                                      p.dueDate == null ? '—' : '${dateFormat.format(p.dueDate!)}${p.remaining > 0 && _isOverdue(p.dueDate) ? ' (quá hạn)' : ''}',
                                      style: TextStyle(fontSize: 13, fontWeight: p.remaining > 0 && _isOverdue(p.dueDate) ? FontWeight.w500 : FontWeight.normal, color: p.remaining > 0 && _isOverdue(p.dueDate) ? AppColors.webDestructive : null),
                                    )),
                                    DataCell(WebBadge(
                                      p.remaining <= 0 ? 'Đã tất toán' : (_isOverdue(p.dueDate) ? 'Quá hạn' : 'Đúng hạn'),
                                      variant: p.remaining <= 0 ? WebBadgeVariant.secondary : (_isOverdue(p.dueDate) ? WebBadgeVariant.destructive : WebBadgeVariant.outline),
                                    )),
                                  ],
                                ),
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
      ),
    );
  }

  Future<void> _pickPayableToSettle(BuildContext context, List<Payable> payables) async {
    final currency = NumberFormat.decimalPattern('vi');
    final picked = await showDialog<Payable>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Chọn công nợ cần thanh toán'),
        children: [
          for (final p in payables)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(p),
              child: Text('${p.vendorName} — còn ${currency.format(p.remaining)} ₫'),
            ),
        ],
      ),
    );
    if (picked != null && context.mounted) {
      await showSettlePayableDialog(context, picked);
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.color, required this.value, required this.label, this.valueColor});

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final Color? valueColor;

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
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: valueColor), overflow: TextOverflow.ellipsis),
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
