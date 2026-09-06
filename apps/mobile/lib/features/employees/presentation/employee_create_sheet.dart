import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../pay_profiles/application/pay_profile_provider.dart';
import '../../users/application/user_provider.dart';
import '../../users/data/user_repository.dart';
import '../application/employee_provider.dart';
import '../data/employee_repository.dart';
import '../../../shared/widgets/app_toast.dart';

Future<void> showEmployeeCreateSheet(BuildContext context, {required List<Employee> existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _EmployeeCreateSheet(existing: existing),
  );
}

class _EmployeeCreateSheet extends ConsumerStatefulWidget {
  const _EmployeeCreateSheet({required this.existing});

  final List<Employee> existing;

  @override
  ConsumerState<_EmployeeCreateSheet> createState() => _EmployeeCreateSheetState();
}

class _EmployeeCreateSheetState extends ConsumerState<_EmployeeCreateSheet> {
  UserSummary? _user;
  String? _payProfileId;
  final _phoneController = TextEditingController();
  bool _saving = false;

  Future<void> _submit() async {
    if (_user == null) return;
    setState(() => _saving = true);
    final close = PendingDialogClose.of(context);
    try {
      await ref.read(employeeActionsProvider.notifier).create(
            userId: _user!.id,
            phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
            payProfileId: _payProfileId,
          );
      close.success('Đã tạo nhân viên');
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(userListProvider);
    final profilesAsync = ref.watch(payProfileListProvider);
    final existingUserIds = widget.existing.map((e) => e.userId).toSet();

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thêm hồ sơ nhân sự', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          usersAsync.when(
            data: (users) {
              final available = users.where((u) => !existingUserIds.contains(u.id)).toList();
              return DropdownButtonFormField<UserSummary>(
                initialValue: _user,
                decoration: const InputDecoration(labelText: 'Tài khoản'),
                items: available.map((u) => DropdownMenuItem(value: u, child: Text('${u.email} (${u.role.roleLabel})'))).toList(),
                onChanged: (v) => setState(() => _user = v),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Lỗi tải danh sách tài khoản: $e'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Số điện thoại (không bắt buộc)')),
          const SizedBox(height: 12),
          profilesAsync.when(
            data: (profiles) => DropdownButtonFormField<String>(
              initialValue: _payProfileId,
              decoration: const InputDecoration(labelText: 'Chức danh lương (không bắt buộc)'),
              items: profiles.map((p) => DropdownMenuItem(value: p.id, child: Text(p.roleTitle))).toList(),
              onChanged: (v) => setState(() => _payProfileId = v),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Lỗi tải chức danh: $e'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving || _user == null ? null : _submit,
            child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
