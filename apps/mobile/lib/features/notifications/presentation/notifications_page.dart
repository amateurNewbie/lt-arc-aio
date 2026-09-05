import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/notification_provider.dart';

/// FR-19 — thông báo/nhắc việc.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Thông báo')),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) return const Center(child: Text('Không có thông báo nào'));
          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final n = notifications[index];
              return ListTile(
                leading: Icon(n.read ? Icons.notifications_none : Icons.notifications_active, color: n.read ? null : Theme.of(context).colorScheme.primary),
                title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.w600)),
                subtitle: Text(n.message),
                trailing: Text(DateFormat('dd/MM HH:mm').format(n.createdAt.toLocal()), style: Theme.of(context).textTheme.bodySmall),
                onTap: n.read ? null : () => ref.read(notificationActionsProvider.notifier).markRead(n.id),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi tải dữ liệu: $e')),
      ),
    );
  }
}
