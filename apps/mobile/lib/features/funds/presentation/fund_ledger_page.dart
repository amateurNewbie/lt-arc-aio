import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/fund_provider.dart';
import '../data/fund_repository.dart';

/// FR-12.3 — sổ quỹ chi tiết của một quỹ/tài khoản.
class FundLedgerPage extends ConsumerWidget {
  const FundLedgerPage({super.key, required this.fund});

  final FundAccount fund;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerAsync = ref.watch(fundLedgerProvider(fund.id));
    final currency = NumberFormat.decimalPattern('vi');

    return Scaffold(
      appBar: AppBar(title: Text(fund.name)),
      body: ledgerAsync.when(
        data: (entries) {
          if (entries.isEmpty) return const Center(child: Text('Chưa có giao dịch nào'));
          return ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final isInflow = entry.inflow > 0;
              return ListTile(
                title: Text(entry.description),
                subtitle: Text(DateFormat('dd/MM/yyyy').format(entry.date)),
                trailing: Text(
                  '${isInflow ? '+' : '-'}${currency.format(isInflow ? entry.inflow : entry.outflow)} ₫',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isInflow ? Colors.green.shade700 : Colors.red.shade700,
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
