import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/contract_provider.dart';
import '../data/contract_repository.dart';
import 'collect_milestone_dialog.dart';
import 'contract_form_sheet.dart';

/// FR-9 — tab "Hợp đồng" trong chi tiết dự án.
class ContractsTab extends ConsumerWidget {
  const ContractsTab({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contractsAsync = ref.watch(contractListProvider(projectId));
    final currency = NumberFormat.decimalPattern('vi');

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => showContractFormSheet(context, projectId),
        child: const Icon(Icons.add),
      ),
      body: contractsAsync.when(
        data: (contracts) {
          if (contracts.isEmpty) return const Center(child: Text('Chưa có hợp đồng nào'));
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: contracts.length,
            itemBuilder: (context, index) {
              final contract = contracts[index];
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
                          Text(contract.code, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('${currency.format(contract.value)} ₫'),
                        ],
                      ),
                      const Divider(),
                      for (final milestone in contract.milestones)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(milestone.name),
                          subtitle: Text('${milestone.ratio.toStringAsFixed(0)}% · ${currency.format(milestone.amount)} ₫ · ${milestone.status.label}'),
                          trailing: milestone.remaining > 0
                              ? TextButton(
                                  onPressed: () => showCollectMilestoneDialog(context, milestone),
                                  child: const Text('Thu tiền'),
                                )
                              : const Icon(Icons.check_circle, color: Colors.green),
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
