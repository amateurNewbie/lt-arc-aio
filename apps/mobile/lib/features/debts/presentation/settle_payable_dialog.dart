import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../funds/application/fund_provider.dart';
import '../application/debt_provider.dart';
import '../data/debt_repository.dart';

Future<void> showSettlePayableDialog(BuildContext context, Payable payable) {
  return showDialog(context: context, builder: (_) => _SettleDialog(payable: payable));
}

class _SettleDialog extends ConsumerStatefulWidget {
  const _SettleDialog({required this.payable});
  final Payable payable;

  @override
  ConsumerState<_SettleDialog> createState() => _SettleDialogState();
}

class _SettleDialogState extends ConsumerState<_SettleDialog> {
  late final _amountController = TextEditingController(text: widget.payable.remaining.toString());
  String? _fundId;
  bool _saving = false;

  Future<void> _submit() async {
    final amount = int.tryParse(_amountController.text) ?? 0;
    if (amount <= 0 || _fundId == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(debtActionsProvider.notifier).settlePayable(payableId: widget.payable.id, amount: amount, fundAccountId: _fundId!);
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
      title: Text('Trả nợ — ${widget.payable.vendorName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Số tiền (còn lại ${widget.payable.remaining} ₫)'),
          ),
          const SizedBox(height: 12),
          fundsAsync.when(
            data: (funds) => DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Quỹ/Tài khoản chi'),
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
          child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Ghi nhận trả'),
        ),
      ],
    );
  }
}
