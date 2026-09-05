import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../application/fund_provider.dart';
import '../data/fund_repository.dart';

Future<void> showFundFormSheet(BuildContext context) {
  return showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const _FundFormSheet());
}

class _FundFormSheet extends ConsumerStatefulWidget {
  const _FundFormSheet();

  @override
  ConsumerState<_FundFormSheet> createState() => _FundFormSheetState();
}

class _FundFormSheetState extends ConsumerState<_FundFormSheet> {
  final _nameController = TextEditingController();
  FundType _type = FundType.cash;
  bool _saving = false;

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(fundActionsProvider.notifier).create(name: _nameController.text.trim(), type: _type);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tạo quỹ / tài khoản', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Tên quỹ / tài khoản')),
          const SizedBox(height: 12),
          SegmentedButton<FundType>(
            segments: const [
              ButtonSegment(value: FundType.cash, label: Text('Tiền mặt')),
              ButtonSegment(value: FundType.bank, label: Text('Ngân hàng')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
