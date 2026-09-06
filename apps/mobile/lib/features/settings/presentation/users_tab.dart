import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../auth/application/auth_provider.dart';
import '../../departments/application/department_provider.dart';
import '../../users/application/user_provider.dart';
import '../../users/data/user_repository.dart';

bool _canManageUsers(String? role) => role == 'ADMIN' || role == 'DIRECTOR';

/// Danh sách tài khoản + tạo mới (chỉ Admin / Giám đốc — khớp API FR-1.3).
class UsersTab extends ConsumerWidget {
  const UsersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authProvider).value;
    if (!_canManageUsers(me?.role)) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Chỉ Quản trị và Giám đốc được quản lý tài khoản người dùng.'),
        ),
      );
    }

    final usersAsync = ref.watch(userListProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateUserDialog(context),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Tạo user'),
      ),
      body: usersAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('Chưa có tài khoản nào'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: users.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final u = users[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.webCardBg,
                  child: Text(u.displayName.isNotEmpty ? u.displayName[0].toUpperCase() : '?'),
                ),
                title: Text(u.displayName),
                subtitle: Text('${u.email} · ${u.role.roleLabel}'),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi tải danh sách: $e')),
      ),
    );
  }

  Future<void> _showCreateUserDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const _CreateUserDialog(),
    );
  }
}

class _CreateUserDialog extends ConsumerStatefulWidget {
  const _CreateUserDialog();

  @override
  ConsumerState<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends ConsumerState<_CreateUserDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _fullName = TextEditingController();
  String _role = 'EMPLOYEE';
  String? _departmentId;
  bool _saving = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _fullName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.length < 6) {
      showAppToast(context, 'Email và mật khẩu (≥6 ký tự) là bắt buộc', error: true);
      return;
    }

    setState(() => _saving = true);
    final close = PendingDialogClose.of(context);
    try {
      await ref.read(userActionsProvider.notifier).create(
            email: email,
            password: password,
            role: _role,
            fullName: _fullName.text.trim().isEmpty ? null : _fullName.text.trim(),
            departmentId: _departmentId,
          );
      close.success('Đã tạo tài khoản');
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final departmentsAsync = ref.watch(departmentListProvider);

    return AlertDialog(
      title: const Text('Tạo tài khoản mới'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                decoration: const InputDecoration(labelText: 'Mật khẩu'),
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _fullName,
                decoration: const InputDecoration(labelText: 'Họ tên (không bắt buộc)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Vai trò'),
                items: assignableRoles
                    .map((r) => DropdownMenuItem(value: r, child: Text(r.roleLabel)))
                    .toList(),
                onChanged: (v) => setState(() => _role = v!),
              ),
              const SizedBox(height: 12),
              departmentsAsync.when(
                data: (deps) => DropdownButtonFormField<String?>(
                  initialValue: _departmentId,
                  decoration: const InputDecoration(labelText: 'Bộ phận (không bắt buộc)'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('— Không gán —')),
                    ...deps.map((d) => DropdownMenuItem<String?>(value: d.id, child: Text(d.name))),
                  ],
                  onChanged: (v) => setState(() => _departmentId = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Lỗi tải bộ phận: $e'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Huỷ')),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Tạo'),
        ),
      ],
    );
  }
}
