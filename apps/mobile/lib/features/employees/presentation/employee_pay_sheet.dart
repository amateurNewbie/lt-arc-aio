import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../pay_profiles/application/pay_profile_provider.dart';
import '../application/employee_provider.dart';
import '../data/employee_repository.dart';

Future<void> showEmployeePaySheet(BuildContext context, Employee employee) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _EmployeePaySheet(employee: employee),
  );
}

class _EmployeePaySheet extends ConsumerStatefulWidget {
  const _EmployeePaySheet({required this.employee});

  final Employee employee;

  @override
  ConsumerState<_EmployeePaySheet> createState() => _EmployeePaySheetState();
}

class _EmployeePaySheetState extends ConsumerState<_EmployeePaySheet> {
  late String? _payProfileId = widget.employee.payProfileId;
  late final _overrideController = TextEditingController(text: widget.employee.dailyRateOverride?.toString() ?? '');
  bool _saving = false;

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final overrideText = _overrideController.text.trim();
      await ref.read(employeeActionsProvider.notifier).updatePay(
            widget.employee.id,
            payProfileId: _payProfileId,
            dailyRateOverride: overrideText.isEmpty ? null : int.tryParse(overrideText),
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
    final profilesAsync = ref.watch(payProfileListProvider);

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lương của nhân viên', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          profilesAsync.when(
            data: (profiles) => DropdownButtonFormField<String?>(
              initialValue: _payProfileId,
              decoration: const InputDecoration(labelText: 'Chức danh lương'),
              items: [
                const DropdownMenuItem(value: null, child: Text('— Không gán —')),
                ...profiles.map((p) => DropdownMenuItem(value: p.id, child: Text(p.roleTitle))),
              ],
              onChanged: (v) => setState(() => _payProfileId = v),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Lỗi tải chức danh: $e'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _overrideController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Ghi đè đơn giá lương ngày (₫)',
              helperText: 'Để trống nếu dùng đơn giá theo chức danh — FR-16.5',
            ),
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
