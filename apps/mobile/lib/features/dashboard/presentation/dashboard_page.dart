import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../activities/application/activity_provider.dart';
import '../../auth/application/auth_provider.dart';
import '../../more/presentation/more_page.dart';
import '../../notifications/application/notification_provider.dart';
import '../../notifications/presentation/notifications_page.dart';
import '../../projects/application/project_provider.dart';
import '../../tasks/application/task_provider.dart';
import '../../tasks/data/task_repository.dart';
import 'dashboard_web_page.dart';

/// FR — Tổng quan. Web dùng layout bám `LT-ARC-Web-UI_1.html` (`DashboardWebPage`);
/// Mobile giữ AppBar + stat grid 2 cột theo `LT-ARC-Mobile-UI_1.html`.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kIsWeb) return const DashboardWebPage();
    return const _DashboardMobilePage();
  }
}

class _DashboardMobilePage extends ConsumerWidget {
  const _DashboardMobilePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectListProvider());
    final tasksAsync = ref.watch(taskListProvider());
    final activitiesAsync = ref.watch(recentActivitiesProvider);
    final unreadCount = ref.watch(notificationListProvider).value?.where((n) => !n.read).length ?? 0;

    final activeProjects = projectsAsync.value?.length ?? 0;
    final tasks = tasksAsync.value ?? const [];
    final doingTasks = tasks.where((t) => t.status != TaskStatus.done).length;
    final overdueTasks = tasks.where((t) => t.isOverdue).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tổng quan'),
        actions: [
          IconButton(
            icon: Badge(
              label: Text('$unreadCount'),
              isLabelVisible: unreadCount > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
            tooltip: 'Thông báo',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsPage())),
          ),
          IconButton(
            icon: const Icon(Icons.apps_outlined),
            tooltip: 'Menu',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MorePage())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(projectListProvider);
          ref.invalidate(taskListProvider);
          ref.invalidate(recentActivitiesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                _StatCard(label: 'Dự án đang chạy', value: '$activeProjects', icon: Icons.apartment_outlined),
                _StatCard(label: 'Việc đang làm', value: '$doingTasks', icon: Icons.checklist_outlined),
                _StatCard(
                  label: 'Việc quá hạn',
                  value: '$overdueTasks',
                  icon: Icons.warning_amber_rounded,
                  isWarning: overdueTasks > 0,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Hoạt động gần đây', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            activitiesAsync.when(
              data: (activities) {
                if (activities.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('Chưa có hoạt động nào')),
                  );
                }
                return Column(
                  children: [
                    for (final activity in activities)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.circle_notifications_outlined),
                        title: Text(activity.title),
                        trailing: Text(
                          DateFormat('dd/MM HH:mm').format(activity.createdAt.toLocal()),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Lỗi tải hoạt động: $error'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, this.isWarning = false});

  final String label;
  final String value;
  final IconData icon;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
