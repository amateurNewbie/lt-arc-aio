import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/settings_provider.dart';

/// FR-20.4 — minh bạch hoá các biện pháp bảo mật đang áp dụng.
class SecurityStatusTab extends ConsumerWidget {
  const SecurityStatusTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(securityStatusProvider);

    return statusAsync.when(
      data: (items) => ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            leading: Icon(item.active ? Icons.check_circle : Icons.remove_circle_outline, color: item.active ? Colors.green : Colors.grey),
            title: Text(item.name),
            subtitle: Text(item.active ? 'Đang áp dụng' : 'Chưa áp dụng'),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi tải dữ liệu: $e')),
    );
  }
}
