import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../funds/application/fund_provider.dart';
import '../../funds/data/fund_repository.dart';
import '../../funds/presentation/fund_form_sheet.dart';
import '../../funds/presentation/fund_ledger_page.dart';

/// Embeddable quỹ list for Settings — no nested Scaffold AppBar.
class FundsSettingsTab extends ConsumerWidget {
  const FundsSettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fundsAsync = ref.watch(fundListProvider);
    final currency = NumberFormat.decimalPattern('vi');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text('Quỹ & tiền mặt', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              FilledButton.icon(
                onPressed: () => showFundFormSheet(context),
                style: FilledButton.styleFrom(backgroundColor: AppColors.webForeground, foregroundColor: Colors.white),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Thêm quỹ'),
              ),
            ],
          ),
        ),
        Expanded(
          child: fundsAsync.when(
            data: (funds) {
              if (funds.isEmpty) {
                return const Center(child: Text('Chưa có quỹ/tài khoản nào'));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: funds.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final fund = funds[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.webCardBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.webBorder),
                    ),
                    child: ListTile(
                      title: Text(fund.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      subtitle: Text(fund.type.label, style: TextStyle(fontSize: 12, color: AppColors.webMutedFg)),
                      trailing: Text(
                        '${currency.format(fund.balance)} ₫',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => FundLedgerPage(fund: fund)),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Lỗi tải dữ liệu: $e')),
          ),
        ),
      ],
    );
  }
}
