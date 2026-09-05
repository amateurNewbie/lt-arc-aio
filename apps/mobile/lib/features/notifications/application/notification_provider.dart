import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../data/notification_repository.dart';

part 'notification_provider.g.dart';

@riverpod
NotificationRepository notificationRepository(Ref ref) => NotificationRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<AppNotification>> notificationList(Ref ref) => ref.watch(notificationRepositoryProvider).list();

@riverpod
class NotificationActions extends _$NotificationActions {
  @override
  void build() {}

  Future<void> markRead(String id) async {
    await ref.read(notificationRepositoryProvider).markRead(id);
    ref.invalidate(notificationListProvider);
  }
}
