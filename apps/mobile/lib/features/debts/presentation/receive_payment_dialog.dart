import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../contracts/application/contract_provider.dart';
import '../../contracts/data/contract_repository.dart';
import '../../funds/application/fund_provider.dart';
import '../../projects/application/project_provider.dart';
import '../../projects/data/project_repository.dart';
import '../../../shared/widgets/app_toast.dart';

/// FR-10.1/9.3 — ghi nhận thu tiền một đợt thanh toán từ trang Công nợ,
/// không giới hạn theo dự án đang xem (khác `contract_form_sheet.dart` vốn
/// gắn với 1 dự án cụ thể trong màn hình Chi tiết dự án).
Future<void> showReceivePaymentDialog(BuildContext context, List<Contract> contracts) {
  final withPending = contracts.where((c) => c.milestones.any((m) => m.remaining > 0)).toList();
  return showDialog(context: context, builder: (_) => _ReceivePaymentDialog(contracts: withPending));
}

class _ReceivePaymentDialog extends ConsumerStatefulWidget {
  const _ReceivePaymentDialog({required this.contracts});
  final List<Contract> contracts;

  @override
  ConsumerState<_ReceivePaymentDialog> createState() => _ReceivePaymentDialogState();
}

class _ReceivePaymentDialogState extends ConsumerState<_ReceivePaymentDialog> {
  Contract? _contract;
  String? _milestoneId;
  final _amountController = TextEditingController();
  String? _fundAccountId;
  bool _saving = false;

  Future<void> _submit() async {
    final amount = int.tryParse(_amountController.text.trim());
    if (_contract == null || _milestoneId == null || amount == null || _fundAccountId == null) return;
    setState(() => _saving = true);
    final close = PendingDialogClose.of(context);
    try {
      await ref.read(contractActionsProvider.notifier).collect(
            contractId: _contract!.id,
            milestoneId: _milestoneId!,
            amount: amount,
            fundAccountId: _fundAccountId!,
          );
      close.success('Đã ghi nhận thanh toán');
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectListProvider());
    final fundsAsync = ref.watch(fundListProvider);
    final projectsById = {for (final p in projectsAsync.value ?? const <Project>[]) p.id: p};
    final pendingMilestones = _contract?.milestones.where((m) => m.remaining > 0).toList() ?? const [];

    return AlertDialog(
      title: const Text('Ghi nhận thanh toán — Phải thu'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Contract>(
              initialValue: _contract,
              decoration: const InputDecoration(labelText: 'Hợp đồng / Dự án'),
              items: [
                for (final c in widget.contracts)
                  DropdownMenuItem(value: c, child: Text('${c.code} — ${projectsById[c.projectId]?.name ?? c.projectId}', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() {
                _contract = v;
                _milestoneId = null;
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _milestoneId,
              decoration: const InputDecoration(labelText: 'Đợt thanh toán'),
              items: [for (final m in pendingMilestones) DropdownMenuItem(value: m.id, child: Text('${m.name} (còn ${m.remaining} ₫)', overflow: TextOverflow.ellipsis))],
              onChanged: (v) => setState(() => _milestoneId = v),
            ),
            const SizedBox(height: 12),
            TextField(controller: _amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Số tiền thu')),
            const SizedBox(height: 12),
            fundsAsync.when(
              data: (funds) => DropdownButtonFormField<String>(
                initialValue: _fundAccountId,
                decoration: const InputDecoration(labelText: 'Quỹ nhận'),
                items: [for (final f in funds) DropdownMenuItem(value: f.id, child: Text(f.name))],
                onChanged: (v) => setState(() => _fundAccountId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Lỗi: $e'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Huỷ')),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Lưu khoản thu'),
        ),
      ],
    );
  }
}
