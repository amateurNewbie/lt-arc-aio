import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/cashbook_provider.dart';
import '../data/cashbook_repository.dart';
import 'expense_tab.dart';

/// FR-6.4 — sổ Thu & Chi hợp nhất (dùng ở ProjectDetailPage cũ).
class CashbookTab extends ConsumerWidget {
  const CashbookTab({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final costsAsync = ref.watch(projectCostListProvider(projectId));
    final paymentsAsync = ref.watch(projectPaymentListProvider(projectId));
    final currency = NumberFormat.decimalPattern('vi');

    if (costsAsync.isLoading || paymentsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (costsAsync.hasError) return Center(child: Text('Lỗi: ${costsAsync.error}'));
    if (paymentsAsync.hasError) return Center(child: Text('Lỗi: ${paymentsAsync.error}'));

    final costs = costsAsync.asData?.value ?? const <ProjectCost>[];
    final payments = paymentsAsync.asData?.value ?? const <Payment>[];
    final entries = [
      ...costs.map((c) => (isIn: false, amount: c.amount, date: c.date, note: c.note)),
      ...payments.map((p) => (isIn: true, amount: p.amount, date: p.date, note: null as String?)),
    ]..sort((a, b) => b.date.compareTo(a.date));

    final totalIn = payments.fold(0, (s, e) => s + e.amount);
    final totalOut = costs.fold(0, (s, e) => s + e.amount);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => showExpenseDialog(context, projectId),
        tooltip: 'Ghi nhận khoản chi',
        child: const Icon(Icons.remove),
      ),
      body: entries.isEmpty
          ? const Center(child: Text('Chưa có khoản thu/chi nào'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(child: _summaryCard('Tổng thu', totalIn, Colors.green, currency)),
                      const SizedBox(width: 8),
                      Expanded(child: _summaryCard('Tổng chi', totalOut, Colors.red, currency)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return ListTile(
                        leading: Icon(entry.isIn ? Icons.arrow_downward : Icons.arrow_upward, color: entry.isIn ? Colors.green : Colors.red),
                        title: Text(entry.note ?? (entry.isIn ? 'Thu theo đợt hợp đồng' : 'Khoản chi')),
                        subtitle: Text(DateFormat('dd/MM/yyyy').format(entry.date)),
                        trailing: Text(
                          '${entry.isIn ? '+' : '-'}${currency.format(entry.amount)} ₫',
                          style: TextStyle(fontWeight: FontWeight.w600, color: entry.isIn ? Colors.green.shade700 : Colors.red.shade700),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _summaryCard(String label, int amount, Color color, NumberFormat currency) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 12)),
            Text('${currency.format(amount)} ₫', style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
