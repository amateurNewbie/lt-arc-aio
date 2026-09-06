import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../contracts/application/contract_provider.dart';
import '../../contracts/data/contract_repository.dart';
import '../../funds/application/fund_provider.dart';
import '../application/cashbook_provider.dart';
import '../../../shared/widgets/app_toast.dart';

class _MilestoneChoice {
  const _MilestoneChoice({required this.contractId, required this.milestone});
  final String contractId;
  final ContractMilestone milestone;
  String get key => '${contractId}_${milestone.id}';
  String get label => '${milestone.name} (còn ${NumberFormat.decimalPattern('vi').format(milestone.remaining)} ₫)';
}

/// FR-6 / FR-9.3 — tab Thu: danh sách + popup ghi nhận thu theo đợt hợp đồng.
class IncomeTab extends ConsumerWidget {
  const IncomeTab({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(projectPaymentListProvider(projectId));
    final contractsAsync = ref.watch(contractListProvider(projectId));
    final currency = NumberFormat.decimalPattern('vi');

    final milestoneNames = <String, String>{};
    for (final c in contractsAsync.asData?.value ?? const <Contract>[]) {
      for (final m in c.milestones) {
        milestoneNames[m.id] = '${c.code} · ${m.name}';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => showDialog(context: context, builder: (_) => _IncomeDialog(projectId: projectId)),
            style: FilledButton.styleFrom(backgroundColor: AppColors.webForeground, foregroundColor: Colors.white),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Thêm khoản thu'),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: paymentsAsync.when(
            data: (payments) {
              if (payments.isEmpty) {
                return const Center(child: Text('Chưa có khoản thu nào. Cần có hợp đồng + đợt thanh toán trước.'));
              }
              final total = payments.fold<int>(0, (s, p) => s + p.amount);
              return Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Tổng thu: ${currency.format(total)} ₫', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowHeight: 40,
                        dataRowMinHeight: 40,
                        dataRowMaxHeight: 48,
                        columns: const [
                          DataColumn(label: Text('Ngày')),
                          DataColumn(label: Text('Đợt thanh toán')),
                          DataColumn(label: Text('Số tiền'), numeric: true),
                        ],
                        rows: [
                          for (final p in payments)
                            DataRow(
                              cells: [
                                DataCell(Text(DateFormat('dd/MM/yyyy').format(p.date))),
                                DataCell(Text(milestoneNames[p.contractMilestoneId] ?? p.contractMilestoneId)),
                                DataCell(Text('+${currency.format(p.amount)} ₫', style: const TextStyle(color: AppColors.webSuccess, fontWeight: FontWeight.w600))),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Lỗi tải thu: $e')),
          ),
        ),
      ],
    );
  }
}

class _IncomeDialog extends ConsumerStatefulWidget {
  const _IncomeDialog({required this.projectId});
  final String projectId;

  @override
  ConsumerState<_IncomeDialog> createState() => _IncomeDialogState();
}

class _IncomeDialogState extends ConsumerState<_IncomeDialog> {
  final _amountController = TextEditingController();
  String? _choiceKey;
  String? _fundId;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  List<_MilestoneChoice> _openMilestones(List<Contract> contracts) {
    final list = <_MilestoneChoice>[];
    for (final c in contracts) {
      for (final m in c.milestones) {
        if (m.remaining > 0 && m.status != MilestoneStatus.retained) {
          list.add(_MilestoneChoice(contractId: c.id, milestone: m));
        }
      }
    }
    return list;
  }

  Future<void> _submit(List<_MilestoneChoice> choices) async {
    final choice = choices.where((c) => c.key == _choiceKey).firstOrNull;
    final amount = int.tryParse(_amountController.text.trim().replaceAll('.', '')) ?? 0;
    if (choice == null) {
      showAppToast(context, 'Chọn đợt thanh toán hợp đồng');
      return;
    }
    if (amount <= 0) {
      showAppToast(context, 'Nhập số tiền hợp lệ');
      return;
    }
    if (amount > choice.milestone.remaining) {
      showAppToast(
        context,
        'Số tiền vượt phần còn lại (${NumberFormat.decimalPattern('vi').format(choice.milestone.remaining)} ₫)',
        error: true,
      );
      return;
    }
    if (_fundId == null) {
      showAppToast(context, 'Chọn quỹ / tài khoản');
      return;
    }

    setState(() => _saving = true);
    final close = PendingDialogClose.of(context);
    try {
      await ref.read(cashbookActionsProvider.notifier).collectPayment(
            projectId: widget.projectId,
            contractId: choice.contractId,
            milestoneId: choice.milestone.id,
            amount: amount,
            fundAccountId: _fundId!,
            date: _date,
          );
      close.success('Đã ghi nhận khoản thu');
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message, error: true);
    } catch (e) {
      if (mounted) showAppToast(context, 'Không lưu được: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contractsAsync = ref.watch(contractListProvider(widget.projectId));
    final fundsAsync = ref.watch(fundListProvider);

    return AlertDialog(
      title: const Text('Ghi nhận khoản thu'),
      content: SizedBox(
        width: 480,
        child: contractsAsync.when(
          data: (contracts) {
            final choices = _openMilestones(contracts);
            if (choices.isEmpty) {
              return const Text(
                'Chưa có đợt thanh toán còn phải thu.\nTạo hợp đồng và các đợt ở tab Hợp đồng (hoặc trang Hợp đồng) trước.',
              );
            }
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _choiceKey,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Đợt thanh toán hợp đồng *', isDense: true),
                    items: [for (final c in choices) DropdownMenuItem(value: c.key, child: Text(c.label, overflow: TextOverflow.ellipsis))],
                    onChanged: (v) {
                      setState(() {
                        _choiceKey = v;
                        final choice = choices.where((c) => c.key == v).firstOrNull;
                        if (choice != null && _amountController.text.isEmpty) {
                          _amountController.text = choice.milestone.remaining.toString();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Số tiền (₫) *', isDense: true),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Ngày thu: ${DateFormat('dd/MM/yyyy').format(_date)}'),
                    trailing: const Icon(Icons.calendar_today, size: 18),
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
                      if (picked != null) setState(() => _date = picked);
                    },
                  ),
                  fundsAsync.when(
                    data: (funds) => DropdownButtonFormField<String>(
                      initialValue: _fundId,
                      decoration: const InputDecoration(labelText: 'Quỹ / Tài khoản *', isDense: true),
                      items: [for (final f in funds) DropdownMenuItem(value: f.id, child: Text(f.name))],
                      onChanged: (v) => setState(() => _fundId = v),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('$e'),
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('Lỗi tải hợp đồng: $e'),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Huỷ')),
        FilledButton(
          onPressed: _saving
              ? null
              : () {
                  final contracts = contractsAsync.asData?.value;
                  if (contracts == null) return;
                  _submit(_openMilestones(contracts));
                },
          child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Lưu khoản thu'),
        ),
      ],
    );
  }
}
