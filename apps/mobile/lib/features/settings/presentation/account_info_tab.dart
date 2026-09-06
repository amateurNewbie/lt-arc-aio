import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../auth/application/auth_provider.dart';
import '../../users/data/user_repository.dart';

/// FR-1 — "Tài khoản đang đăng nhập" + đăng xuất.
class AccountInfoTab extends ConsumerWidget {
  const AccountInfoTab({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(authProvider.notifier).logout();
    if (context.mounted) showAppToast(context, 'Đã đăng xuất');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.webCardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.webBorder),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tài khoản đang đăng nhập', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            if (user != null)
              Text(
                '${user.displayName} · ${user.email} · Vai trò: ${user.role.roleLabel}',
                style: TextStyle(fontSize: 13, color: AppColors.webMutedFg),
              ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => _logout(context, ref),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Đăng xuất'),
            ),
          ],
        ),
      ),
    );
  }
}
