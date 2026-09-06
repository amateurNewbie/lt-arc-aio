import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../budget/application/budget_provider.dart';
import '../../budget/data/budget_repository.dart';
import '../../cashbook/application/cashbook_provider.dart';
import '../../cost_categories/application/cost_category_provider.dart';
import '../../cost_categories/data/cost_category_repository.dart';
import 'project_ledger_table.dart';

/// Ngân sách vs thực chi theo hạng mục (dự toán mới nhất + chi phí dự án).
class BudgetVsActualTable extends ConsumerWidget {
  const BudgetVsActualTable({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetListProvider(projectId));
    final costsAsync = ref.watch(projectCostListProvider(projectId));
    final categoriesAsync = ref.watch(costCategoryListProvider());
    final currency = NumberFormat.decimalPattern('vi');

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
          const Text('Ngân sách vs thực chi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Expanded(
            child: budgetsAsync.when(
              data: (budgets) {
                final costs = costsAsync.value ?? const [];
                final categoriesById = {for (final c in categoriesAsync.value ?? const <CostCategory>[]) c.id: c};
                BudgetEstimate? latest;
                if (budgets.isNotEmpty) {
                  latest = budgets.reduce((a, b) => a.version >= b.version ? a : b);
                }
                final budgetByCat = <String, int>{};
                for (final line in latest?.lines ?? const <BudgetLine>[]) {
                  budgetByCat[line.costCategoryId] = (budgetByCat[line.costCategoryId] ?? 0) + line.amount;
                }
                final spentByCat = <String, int>{};
                for (final c in costs) {
                  spentByCat[c.costCategoryId] = (spentByCat[c.costCategoryId] ?? 0) + c.amount;
                }
                final keys = {...budgetByCat.keys, ...spentByCat.keys}.toList()
                  ..sort((a, b) => (categoriesById[a]?.name ?? a).compareTo(categoriesById[b]?.name ?? b));

                if (keys.isEmpty) {
                  return const Center(child: Text('Chưa có dữ liệu ngân sách / chi phí', style: TextStyle(fontSize: 12)));
                }

                return SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 32,
                      dataRowMinHeight: 36,
                      dataRowMaxHeight: 44,
                      columns: const [
                        DataColumn(label: Text('HẠNG MỤC', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('NGÂN SÁCH', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('ĐÃ CHI', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('%', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('CÒN LẠI', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                      ],
                      rows: [
                        for (final key in keys)
                          () {
                            final budget = budgetByCat[key] ?? 0;
                            final spent = spentByCat[key] ?? 0;
                            final pct = budget > 0 ? (spent * 100 / budget) : (spent > 0 ? 100.0 : 0.0);
                            final remain = budget - spent;
                            return DataRow(cells: [
                              DataCell(Text(categoriesById[key]?.name ?? '—', style: const TextStyle(fontSize: 12))),
                              DataCell(Text('${currency.format(budget)} ₫', style: const TextStyle(fontSize: 12))),
                              DataCell(Text('${currency.format(spent)} ₫', style: const TextStyle(fontSize: 12))),
                              DataCell(Text('${pct.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12))),
                              DataCell(Text(
                                '${currency.format(remain)} ₫',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: remain < 0 ? AppColors.webDestructive : null,
                                  fontWeight: FontWeight.w500,
                                ),
                              )),
                            ]);
                          }(),
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

/// Panels gắn dưới tab Dự toán khi đang sửa dự án hiện có.
class ProjectFinancePanels extends StatelessWidget {
  const ProjectFinancePanels({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: BudgetVsActualTable(projectId: projectId)),
          const SizedBox(width: 8),
          Expanded(child: ProjectLedgerTable(projectId: projectId)),
        ],
      ),
    );
  }
}
