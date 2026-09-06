import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../application/lead_provider.dart';
import '../../../shared/widgets/app_toast.dart';

Future<void> showLeadFormSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _LeadFormSheet(),
  );
}

class _LeadFormSheet extends ConsumerStatefulWidget {
  const _LeadFormSheet();

  @override
  ConsumerState<_LeadFormSheet> createState() => _LeadFormSheetState();
}

class _LeadFormSheetState extends ConsumerState<_LeadFormSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _needController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _needController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final close = PendingDialogClose.of(context);
    try {
      await ref.read(leadActionsProvider.notifier).create(
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
            need: _needController.text.trim().isEmpty ? null : _needController.text.trim(),
          );
      close.success('Đã tạo khách hàng tiềm năng');
    } on ApiException catch (e) {
      if (mounted) {
        showAppToast(context, e.message, error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thêm khách hàng tiềm năng', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Họ tên khách hàng')),
          const SizedBox(height: 12),
          TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Số điện thoại')),
          const SizedBox(height: 12),
          TextField(controller: _needController, decoration: const InputDecoration(labelText: 'Nhu cầu / Loại công trình')),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Lưu khách hàng tiềm năng'),
          ),
        ],
      ),
    );
  }
}
