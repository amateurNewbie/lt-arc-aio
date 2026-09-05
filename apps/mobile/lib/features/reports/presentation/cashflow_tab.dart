import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../funds/application/fund_provider.dart';
import '../../funds/data/fund_repository.dart';
import '../../funds/presentation/funds_page.dart';
import '../application/reports_provider.dart';

/// FR-12.4 — Quỹ & Dòng tiền, bám `LT-ARC-Web-UI_1.html` mục "Quỹ & Dòng tiền":
/// thẻ số dư từng quỹ/TK + báo cáo dòng tiền theo tháng. Sổ quỹ chi tiết từng
/// quỹ xem tại trang Quỹ (đã có sẵn, tránh trùng lặp UI hiển thị sổ quỹ).
class CashflowTab extends ConsumerStatefulWidget {
  const CashflowTab({super.key});

  @override
  ConsumerState<CashflowTab> createState() => _CashflowTabState();
}

class _CashflowTabState extends ConsumerState<CashflowTab> {
  late DateTime _month = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.decimalPattern('vi');
    final cashflowAsync = ref.watch(cashflowReportProvider(year: _month.year, month: _month.month));
    final fundsAsync = ref.watch(fundListProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          fundsAsync.when(
            data: (funds) {
              final total = funds.fold<int>(0, (s, f) => s + f.balance);
              return Row(
                children: [
                  for (final f in funds) ...[
                    Expanded(child: _StatCard(icon: f.type == FundType.cash ? Icons.payments_outlined : Icons.account_balance_outlined, value: '${currency.format(f.balance)} ₫', label: f.name)),
                    const SizedBox(width: 12),
                  ],
                  Expanded(child: _StatCard(icon: Icons.trending_up, value: '${currency.format(total)} ₫', label: 'Tổng số dư mọi quỹ', color: AppColors.webSuccess)),
                ],
              );
            },
            loading: () => const SizedBox(height: 90, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('Lỗi tải dữ liệu: $e'),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(color: AppColors.webCardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.webBorder)),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Dòng tiền theo tháng', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1))),
                        Text(DateFormat('MM/yyyy').format(_month)),
                        IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                cashflowAsync.when(
                  data: (report) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 32,
                      dataRowMinHeight: 40,
                      dataRowMaxHeight: 48,
                      columns: const [
                        DataColumn(label: Text('THÁNG', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('SỐ DƯ ĐẦU KỲ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('TIỀN THU VÀO', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('TIỀN CHI RA', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('SỐ DƯ CUỐI KỲ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                      ],
                      rows: [
                        DataRow(cells: [
                          DataCell(Text(DateFormat('MM/yyyy').format(_month), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                          DataCell(Text('${currency.format(report.openingBalance)} ₫', style: const TextStyle(fontSize: 13))),
                          DataCell(Text('+${currency.format(report.totalInflow)} ₫', style: TextStyle(fontSize: 13, color: AppColors.webSuccess))),
                          DataCell(Text('-${currency.format(report.totalOutflow)} ₫', style: TextStyle(fontSize: 13, color: AppColors.webDestructive))),
                          DataCell(Text('${currency.format(report.closingBalance)} ₫', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                        ]),
                      ],
                    ),
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Lỗi tải dữ liệu: $e'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FundsPage())),
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: const Text('Xem quỹ & sổ quỹ chi tiết'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.value, required this.label, this.color});

  final IconData icon;
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.gold;
    return Container(
      decoration: BoxDecoration(color: AppColors.webCardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.webBorder)),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(4)),
            child: Icon(icon, size: 18, color: c),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 11, color: AppColors.webMutedFg), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
