import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../cashbook/application/cashbook_provider.dart';

/// Sổ thu/chi dự án — gộp payments + costs.
class ProjectLedgerTable extends ConsumerWidget {
  const ProjectLedgerTable({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(projectPaymentListProvider(projectId));
    final costsAsync = ref.watch(projectCostListProvider(projectId));
    final currency = NumberFormat.decimalPattern('vi');
    final dateFmt = DateFormat('dd/MM/yyyy');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.webCardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.webBorder),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sổ thu / chi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Expanded(
            child: paymentsAsync.when(
              data: (payments) {
                final costs = costsAsync.value ?? const [];
                final rows = <({DateTime date, String type, String note, int amount})>[
                  for (final p in payments)
                    (
                      date: p.date,
                      type: 'Thu',
                      note: p.note?.trim().isNotEmpty == true ? p.note! : 'Khoản thu',
                      amount: p.amount,
                    ),
                  for (final c in costs)
                    (
                      date: c.date,
                      type: 'Chi',
                      note: c.note?.trim().isNotEmpty == true ? c.note! : 'Chi phí',
                      amount: c.amount,
                    ),
                ]..sort((a, b) => b.date.compareTo(a.date));

                if (rows.isEmpty) {
                  return const Center(child: Text('Chưa có giao dịch thu/chi', style: TextStyle(fontSize: 12)));
                }

                return SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 32,
                      dataRowMinHeight: 36,
                      dataRowMaxHeight: 44,
                      columns: const [
                        DataColumn(label: Text('NGÀY', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('LOẠI', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('DIỄN GIẢI', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('SỐ TIỀN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                      ],
                      rows: [
                        for (final r in rows)
                          DataRow(cells: [
                            DataCell(Text(dateFmt.format(r.date), style: const TextStyle(fontSize: 12))),
                            DataCell(Text(
                              r.type,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: r.type == 'Thu' ? AppColors.webSuccess : AppColors.webWarning,
                              ),
                            )),
                            DataCell(ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 260),
                              child: Text(r.note, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                            )),
                            DataCell(Text(
                              '${r.type == 'Thu' ? '+' : '-'}${currency.format(r.amount)} ₫',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: r.type == 'Thu' ? AppColors.webSuccess : AppColors.webDestructive,
                              ),
                            )),
                          ]),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Lỗi: $e', style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
