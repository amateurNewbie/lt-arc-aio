import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/web_badge.dart';
import '../../activities/application/activity_provider.dart';
import '../../departments/application/department_provider.dart';
import '../../projects/application/project_provider.dart';
import '../../projects/data/project_repository.dart';
import '../../reports/application/reports_provider.dart';
import '../../reports/data/reports_repository.dart';
import '../../tasks/application/task_provider.dart';
import '../../tasks/data/task_repository.dart';
import '../../users/application/user_provider.dart';

WebBadgeVariant _categoryVariant(ProjectCategory c) => switch (c) {
      ProjectCategory.construction => WebBadgeVariant.warning,
      ProjectCategory.turnkey => WebBadgeVariant.primary,
      ProjectCategory.design => WebBadgeVariant.outline,
    };

/// Trang "Tổng quan" bản Web — bám `LT-ARC-Web-UI_1.html` (`data-if="isDashboard"`):
/// 4 thẻ KPI, "Dự án gần đây" + "Hoạt động gần đây" cạnh nhau, bảng "Công việc trễ hạn".
class DashboardWebPage extends ConsumerWidget {
  const DashboardWebPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectListProvider());
    final tasksAsync = ref.watch(taskListProvider());
    final activitiesAsync = ref.watch(recentActivitiesProvider);
    final pnlAsync = ref.watch(profitLossReportProvider);
    final currency = NumberFormat.decimalPattern('vi');

    final tasks = tasksAsync.value ?? const <Task>[];
    final doingTasks = tasks.where((t) => t.status == TaskStatus.doing).length;
    final overdueTasks = tasks.where((t) => t.isOverdue).toList();
    final totalProfit = (pnlAsync.value ?? const <ProjectPnl>[]).fold<int>(0, (s, p) => s + p.profit);
    final projects = projectsAsync.value ?? const <Project>[];

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1360),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tổng quan', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Toàn cảnh dự án, công việc và tài chính studio.', style: TextStyle(fontSize: 13, color: AppColors.webMutedFg)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _StatCard(icon: Icons.apartment_outlined, iconColor: AppColors.gold, value: '${projects.length}', label: 'Dự án đang chạy')),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(icon: Icons.checklist_outlined, iconColor: AppColors.gold, value: '$doingTasks', label: 'Việc đang làm')),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(icon: Icons.access_time, iconColor: AppColors.webWarning, value: '${overdueTasks.length}', label: 'Việc quá hạn')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.trending_up,
                      iconColor: AppColors.webSuccess,
                      value: '${totalProfit >= 0 ? '+' : ''}${currency.format(totalProfit)} ₫',
                      valueColor: AppColors.webSuccess,
                      label: 'Lãi/lỗ tạm tính',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _WebCard(
                      title: 'Dự án gần đây',
                      child: projectsAsync.when(
                        data: (list) {
                          final recent = list.take(5).toList();
                          if (recent.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('Chưa có dự án nào'));
                          return Column(
                            children: [
                              for (final p in recent)
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(p.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                  subtitle: Text('${p.code} · ${p.client}', style: TextStyle(fontSize: 12, color: AppColors.webMutedFg)),
                                  trailing: Wrap(
                                    spacing: 6,
                                    children: [
                                      WebBadge(p.category.label, variant: _categoryVariant(p.category)),
                                      WebBadge(p.status.label, variant: WebBadgeVariant.secondary),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('Lỗi tải dữ liệu: $e'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _WebCard(
                      title: 'Hoạt động gần đây',
                      child: activitiesAsync.when(
                        data: (activities) {
                          if (activities.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('Chưa có hoạt động nào'));
                          return Column(
                            children: [
                              for (final a in activities.take(6))
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 7),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: Text(a.title, style: const TextStyle(fontSize: 13))),
                                      const SizedBox(width: 8),
                                      Text(DateFormat('dd/MM HH:mm').format(a.createdAt.toLocal()), style: TextStyle(fontSize: 12, color: AppColors.webMutedFg)),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('Lỗi tải hoạt động: $e'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _OverdueTasksCard(tasks: overdueTasks),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebCard extends StatelessWidget {
  const _WebCard({required this.title, required this.child, this.titleColor, this.icon});

  final String title;
  final Widget child;
  final Color? titleColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: AppColors.webCardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.webBorder)),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: titleColor ?? AppColors.webForeground), const SizedBox(width: 8)],
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: titleColor)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.iconColor, required this.value, required this.label, this.valueColor});

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.webCardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.webBorder)),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(4)),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: valueColor), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(label.toUpperCase(), style: TextStyle(fontSize: 10.5, letterSpacing: 0.5, color: AppColors.webMutedFg)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverdueTasksCard extends ConsumerWidget {
  const _OverdueTasksCard({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectListProvider());
    final departmentsAsync = ref.watch(departmentListProvider);
    final usersAsync = ref.watch(userListProvider);

    final projectsById = {for (final p in projectsAsync.value ?? const <Project>[]) p.id: p};
    final departmentsById = {for (final d in departmentsAsync.value ?? const []) d.id: d};
    final usersById = {for (final u in usersAsync.value ?? const []) u.id: u};
    final today = DateTime.now();

    return _WebCard(
      title: 'Công việc trễ hạn',
      icon: Icons.warning_amber_rounded,
      titleColor: AppColors.webWarning,
      child: tasks.isEmpty
          ? const Text('Không có công việc quá hạn')
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 32,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 48,
                columns: const [
                  DataColumn(label: Text('CÔNG VIỆC', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('DỰ ÁN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('BỘ PHẬN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('NGƯỜI PHỤ TRÁCH', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('TRỄ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                ],
                rows: [
                  for (final t in tasks)
                    DataRow(cells: [
                      DataCell(Text(t.title, style: const TextStyle(fontSize: 13))),
                      DataCell(Text(projectsById[t.projectId]?.name ?? '—', style: const TextStyle(fontSize: 13))),
                      DataCell(Text(departmentsById[t.departmentId]?.name ?? '—', style: const TextStyle(fontSize: 13))),
                      DataCell(Text(t.assigneeId != null ? (usersById[t.assigneeId]?.displayName ?? '—') : '—', style: const TextStyle(fontSize: 13))),
                      DataCell(Text(
                        t.dueDate != null ? '${today.difference(t.dueDate!).inDays} ngày' : '—',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.webDestructive),
                      )),
                    ]),
                ],
              ),
            ),
    );
  }
}
