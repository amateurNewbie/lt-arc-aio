import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../funds/application/fund_provider.dart';
import '../application/payroll_provider.dart';

Future<void> showPayrollPayDialog(BuildContext context, String month) {
  return showDialog(context: context, builder: (_) => _PayrollPayDialog(month: month));
}

class _PayrollPayDialog extends ConsumerStatefulWidget {
  const _PayrollPayDialog({required this.month});

  final String month;

  @override
  ConsumerState<_PayrollPayDialog> createState() => _PayrollPayDialogState();
}

class _PayrollPayDialogState extends ConsumerState<_PayrollPayDialog> {
  String? _fundId;
  bool _saving = false;

  Future<void> _submit() async {
    if (_fundId == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(payrollActionsProvider.notifier).pay(widget.month, fundAccountId: _fundId!);
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
      title: const Text('Trả lương'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tháng ${widget.month} — trả toàn bộ bản lương chưa trả, khoá số công tháng này.'),
          const SizedBox(height: 12),
          fundsAsync.when(
            data: (funds) => DropdownButtonFormField<String>(
              initialValue: _fundId,
              decoration: const InputDecoration(labelText: 'Chi từ quỹ/tài khoản'),
              items: funds.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name))).toList(),
              onChanged: (v) => setState(() => _fundId = v),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Lỗi tải quỹ: $e'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Huỷ')),
        FilledButton(
          onPressed: _saving || _fundId == null ? null : _submit,
          child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Xác nhận trả lương'),
        ),
      ],
    );
  }
}
