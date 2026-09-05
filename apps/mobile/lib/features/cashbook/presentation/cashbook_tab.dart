import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/cashbook_provider.dart';
import 'cost_form_sheet.dart';

/// FR-6.4 — sổ Thu & Chi hợp nhất của dự án.
class CashbookTab extends ConsumerWidget {
  const CashbookTab({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(cashbookEntriesProvider(projectId));
    final currency = NumberFormat.decimalPattern('vi');

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCostFormSheet(context, projectId),
        tooltip: 'Ghi nhận khoản chi',
        child: const Icon(Icons.remove),
      ),
      body: entriesAsync.when(
        data: (entries) {
          if (entries.isEmpty) return const Center(child: Text('Chưa có khoản thu/chi nào'));
          final totalIn = entries.where((e) => e.isInflow).fold(0, (s, e) => s + e.amount);
          final totalOut = entries.where((e) => !e.isInflow).fold(0, (s, e) => s + e.amount);

          return Column(
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
                      leading: Icon(entry.isInflow ? Icons.arrow_downward : Icons.arrow_upward, color: entry.isInflow ? Colors.green : Colors.red),
                      title: Text(entry.note ?? (entry.isInflow ? 'Thu theo đợt hợp đồng' : 'Khoản chi')),
                      subtitle: Text(DateFormat('dd/MM/yyyy').format(entry.date)),
                      trailing: Text(
                        '${entry.isInflow ? '+' : '-'}${currency.format(entry.amount)} ₫',
                        style: TextStyle(fontWeight: FontWeight.w600, color: entry.isInflow ? Colors.green.shade700 : Colors.red.shade700),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi tải dữ liệu: $e')),
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
