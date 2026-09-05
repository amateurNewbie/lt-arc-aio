import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../application/pay_profile_provider.dart';
import '../data/pay_profile_repository.dart';

Future<void> showPayProfileFormSheet(BuildContext context, {PayProfile? profile}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PayProfileFormSheet(profile: profile),
  );
}

class _PayProfileFormSheet extends ConsumerStatefulWidget {
  const _PayProfileFormSheet({this.profile});

  final PayProfile? profile;

  @override
  ConsumerState<_PayProfileFormSheet> createState() => _PayProfileFormSheetState();
}

class _AllowanceRow {
  _AllowanceRow({String name = '', int amount = 0}) : nameController = TextEditingController(text: name), amountController = TextEditingController(text: amount == 0 ? '' : '$amount');

  final TextEditingController nameController;
  final TextEditingController amountController;
}

class _PayProfileFormSheetState extends ConsumerState<_PayProfileFormSheet> {
  late final _roleTitleController = TextEditingController(text: widget.profile?.roleTitle ?? '');
  late final _dailyRateController = TextEditingController(text: widget.profile != null ? '${widget.profile!.dailyRate}' : '');
  late final List<_AllowanceRow> _allowances = widget.profile?.allowances.map((a) => _AllowanceRow(name: a.name, amount: a.amount)).toList() ?? [];
  bool _saving = false;

  bool get _isEdit => widget.profile != null;

  Future<void> _submit() async {
    final roleTitle = _roleTitleController.text.trim();
    final dailyRate = int.tryParse(_dailyRateController.text.trim()) ?? 0;
    if (!_isEdit && roleTitle.isEmpty) return;
    if (dailyRate <= 0) return;

    final allowances = _allowances
        .where((r) => r.nameController.text.trim().isNotEmpty)
        .map((r) => Allowance(name: r.nameController.text.trim(), amount: int.tryParse(r.amountController.text.trim()) ?? 0))
        .toList();

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await ref.read(payProfileActionsProvider.notifier).update(widget.profile!.id, dailyRate: dailyRate, allowances: allowances);
      } else {
        await ref.read(payProfileActionsProvider.notifier).create(roleTitle: roleTitle, dailyRate: dailyRate, allowances: allowances);
      }
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isEdit ? 'Sửa chức danh lương' : 'Thêm chức danh lương', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _roleTitleController,
              enabled: !_isEdit,
              decoration: const InputDecoration(labelText: 'Chức danh'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dailyRateController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Đơn giá lương ngày (₫)'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Phụ cấp', style: Theme.of(context).textTheme.labelLarge),
                TextButton.icon(
                  onPressed: () => setState(() => _allowances.add(_AllowanceRow())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Thêm phụ cấp'),
                ),
              ],
            ),
            for (var i = 0; i < _allowances.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: TextField(controller: _allowances[i].nameController, decoration: const InputDecoration(labelText: 'Tên phụ cấp'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: _allowances[i].amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Số tiền'))),
                    IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _allowances.removeAt(i))),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
