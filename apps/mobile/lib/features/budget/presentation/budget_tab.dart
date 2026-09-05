import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../application/budget_provider.dart';
import '../data/budget_repository.dart';
import 'budget_form_sheet.dart';

/// FR-4 — tab "Dự toán" trong chi tiết dự án.
class BudgetTab extends ConsumerWidget {
  const BudgetTab({super.key, required this.projectId});

  final String projectId;

  Future<void> _handle(BuildContext context, WidgetRef ref, Future<void> Function() action) async {
    try {
      await action();
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetListProvider(projectId));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => showBudgetFormSheet(context, projectId),
        child: const Icon(Icons.add),
      ),
      body: budgetsAsync.when(
        data: (budgets) {
          if (budgets.isEmpty) {
            return const Center(child: Text('Chưa có dự toán nào'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: budgets.length,
            itemBuilder: (context, index) {
              final budget = budgets[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Phiên bản v${budget.version}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Chip(label: Text(budget.status.label)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Tổng dự toán: ${budget.total} ₫'),
                      const SizedBox(height: 4),
                      for (final line in budget.lines)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('• ${line.unit} × ${line.quantity} × ${line.unitPrice} ₫ = ${line.amount} ₫',
                              style: Theme.of(context).textTheme.bodySmall),
                        ),
                      const SizedBox(height: 10),
                      if (budget.status == BudgetStatus.draft)
                        FilledButton(
                          onPressed: () => _handle(context, ref, () => ref.read(budgetActionsProvider.notifier).submit(projectId, budget.id)),
                          child: const Text('Gửi duyệt'),
                        ),
                      if (budget.status == BudgetStatus.pending)
                        FilledButton(
                          onPressed: () => _handle(context, ref, () => ref.read(budgetActionsProvider.notifier).approve(projectId, budget.id)),
                          child: const Text('Duyệt dự toán'),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi tải dữ liệu: $e')),
      ),
    );
  }
}
