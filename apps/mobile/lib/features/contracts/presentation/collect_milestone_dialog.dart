import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../funds/application/fund_provider.dart';
import '../application/contract_provider.dart';
import '../data/contract_repository.dart';

Future<void> showCollectMilestoneDialog(BuildContext context, ContractMilestone milestone) {
  return showDialog(context: context, builder: (_) => _CollectDialog(milestone: milestone));
}

class _CollectDialog extends ConsumerStatefulWidget {
  const _CollectDialog({required this.milestone});
  final ContractMilestone milestone;

  @override
  ConsumerState<_CollectDialog> createState() => _CollectDialogState();
}

class _CollectDialogState extends ConsumerState<_CollectDialog> {
  late final _amountController = TextEditingController(text: widget.milestone.remaining.toString());
  String? _fundId;
  bool _saving = false;

  Future<void> _submit() async {
    final amount = int.tryParse(_amountController.text) ?? 0;
    if (amount <= 0 || _fundId == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(contractActionsProvider.notifier).collect(
            contractId: widget.milestone.contractId,
            milestoneId: widget.milestone.id,
            amount: amount,
            fundAccountId: _fundId!,
          );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fundsAsync = ref.watch(fundListProvider);

    return AlertDialog(
      title: Text('Thu tiền — ${widget.milestone.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Số tiền (còn lại ${widget.milestone.remaining} ₫)'),
          ),
          const SizedBox(height: 12),
          fundsAsync.when(
            data: (funds) => DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Quỹ/Tài khoản nhận'),
              items: [for (final f in funds) DropdownMenuItem(value: f.id, child: Text(f.name))],
              onChanged: (v) => setState(() => _fundId = v),
            ),
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Lỗi: $e'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Huỷ')),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Ghi nhận thu'),
        ),
      ],
    );
  }
}
