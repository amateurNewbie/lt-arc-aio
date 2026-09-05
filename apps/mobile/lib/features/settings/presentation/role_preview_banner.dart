import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../users/data/user_repository.dart';
import '../application/role_preview_provider.dart';

/// FR-1.6 — dải cảnh báo cố định khi đang xem thử vai trò khác, luôn hiển thị
/// để không ai nhầm dữ liệu đang xem là phiên đăng nhập thật.
class RolePreviewBanner extends ConsumerWidget {
  const RolePreviewBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(rolePreviewProvider);
    if (preview == null) return const SizedBox.shrink();

    return Material(
      color: Colors.amber.shade700,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.visibility_outlined, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đang xem thử vai trò: ${preview.role.roleLabel} — chỉ đọc',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () => ref.read(rolePreviewProvider.notifier).exit(),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Thoát'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
