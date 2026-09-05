import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/fund_provider.dart';
import '../data/fund_repository.dart';
import 'fund_form_sheet.dart';
import 'fund_ledger_page.dart';

/// FR-12 — Quỹ & dòng tiền.
class FundsPage extends ConsumerWidget {
  const FundsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fundsAsync = ref.watch(fundListProvider);
    final currency = NumberFormat.decimalPattern('vi');

    return Scaffold(
      appBar: AppBar(title: const Text('Quỹ & dòng tiền')),
      floatingActionButton: FloatingActionButton(onPressed: () => showFundFormSheet(context), child: const Icon(Icons.add)),
      body: fundsAsync.when(
        data: (funds) {
          if (funds.isEmpty) return const Center(child: Text('Chưa có quỹ/tài khoản nào'));
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: funds.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final fund = funds[index];
              return Card(
                child: ListTile(
                  title: Text(fund.name),
                  subtitle: Text(fund.type.label),
                  trailing: Text('${currency.format(fund.balance)} ₫', style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FundLedgerPage(fund: fund))),
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
