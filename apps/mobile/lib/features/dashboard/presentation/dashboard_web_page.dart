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

/// Trang "Tổng quan" bản Web — bám `LT-ARC-Web-UI_3.html` (`data-if="isDashboard"`):
/// tông than/kem/vàng đồng, thẻ có độ bóng, 4 thẻ KPI, "Dự án gần đây" +
/// "Hoạt động gần đây" cạnh nhau, bảng "Công việc trễ hạn". Màu đọc qua
/// [LtArcColors] — tự đổi sáng/tối theo `webThemeModeProvider`.
class DashboardWebPage extends ConsumerWidget {
  const DashboardWebPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final projectsAsync = ref.watch(projectListProvider());
    final tasksAsync = ref.watch(taskListProvider());
    final activitiesAsync = ref.watch(recentActivitiesProvider);
    final pnlAsync = ref.watch(profitLossReportProvider());
    final currency = NumberFormat.decimalPattern('vi');

    final tasks = tasksAsync.value ?? const <Task>[];
    final doingTasks = tasks.where((t) => t.status == TaskStatus.doing).length;
    final overdueTasks = tasks.where((t) => t.isOverdue).toList();
    final totalProfit = (pnlAsync.value ?? const <ProjectPnl>[]).fold<int>(0, (s, p) => s + p.profit);
    final projects = projectsAsync.value ?? const <Project>[];

    return Scaffold(
      backgroundColor: c.bg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1360),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tổng quan', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: c.goldBright)),
              const SizedBox(height: 4),
              Text('Toàn cảnh dự án, công việc và tài chính studio.', style: TextStyle(fontSize: 13, color: c.mutedFg)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _StatCard(icon: Icons.apartment_outlined, iconColor: c.gold, value: '${projects.length}', label: 'Dự án đang chạy')),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(icon: Icons.checklist_outlined, iconColor: c.gold, value: '$doingTasks', label: 'Việc đang làm')),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(icon: Icons.access_time, iconColor: c.warning, value: '${overdueTasks.length}', label: 'Việc quá hạn')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.trending_up,
                      iconColor: c.success,
                      value: '${totalProfit >= 0 ? '+' : ''}${currency.format(totalProfit)} ₫',
                      valueColor: c.success,
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
                          if (recent.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text('Chưa có dự án nào', style: TextStyle(color: c.mutedFg)),
                            );
                          }
                          return Column(
                            children: [
                              for (final p in recent)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(p.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.fg)),
                                            const SizedBox(height: 2),
                                            Text('${p.code} · ${p.client}', style: TextStyle(fontSize: 12, color: c.mutedFg)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Wrap(
                                        spacing: 6,
                                        children: [
                                          WebBadge(p.category.label, variant: _categoryVariant(p.category)),
                                          WebBadge(p.status.label, variant: WebBadgeVariant.secondary),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                        loading: () => Center(child: Padding(padding: const EdgeInsets.all(16), child: CircularProgressIndicator(color: c.gold))),
                        error: (e, _) => Text('Lỗi tải dữ liệu: $e', style: TextStyle(color: c.destructive)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _WebCard(
                      title: 'Hoạt động gần đây',
                      icon: Icons.bolt_outlined,
                      child: activitiesAsync.when(
                        data: (activities) {
                          if (activities.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text('Chưa có hoạt động nào', style: TextStyle(color: c.mutedFg)),
                            );
                          }
                          return Column(
                            children: [
                              for (final a in activities.take(6))
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 7),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: Text(a.title, style: TextStyle(fontSize: 13, color: c.fg))),
                                      const SizedBox(width: 8),
                                      Text(
                                        DateFormat('dd/MM HH:mm').format(a.createdAt.toLocal()),
                                        style: TextStyle(fontSize: 12, color: c.mutedFg),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                        loading: () => Center(child: Padding(padding: const EdgeInsets.all(16), child: CircularProgressIndicator(color: c.gold))),
                        error: (e, _) => Text('Lỗi tải hoạt động: $e', style: TextStyle(color: c.destructive)),
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

/// Khung thẻ có độ bóng: viền đồng mờ, nền gradient than, sheen mờ ở mép trên —
/// tương ứng `.card` trong LT-ARC-Web-UI_3.html.
class _WebCard extends StatelessWidget {
  const _WebCard({required this.title, required this.child, this.titleColor, this.icon});

  final String title;
  final Widget child;
  final Color? titleColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c.cardGradTop, c.cardGradBottom]),
        boxShadow: [BoxShadow(color: c.shadowAmbient, blurRadius: 24, offset: const Offset(0, 12))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: titleColor ?? c.gold), const SizedBox(width: 8)],
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: titleColor ?? c.fg)),
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
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c.cardGradTop, c.cardGradBottom]),
        boxShadow: [BoxShadow(color: c.shadowAmbient, blurRadius: 24, offset: const Offset(0, 12))],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, size: 19, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: valueColor ?? c.fg), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(label.toUpperCase(), style: TextStyle(fontSize: 10.5, letterSpacing: 0.5, color: c.mutedFg)),
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
    final c = context.colors;
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
      titleColor: c.warning,
      child: tasks.isEmpty
          ? Text('Không có công việc quá hạn', style: TextStyle(color: c.mutedFg))
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 32,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 48,
                columns: const [
                  DataColumn(label: Text('CÔNG VIỆC')),
                  DataColumn(label: Text('DỰ ÁN')),
                  DataColumn(label: Text('BỘ PHẬN')),
                  DataColumn(label: Text('NGƯỜI PHỤ TRÁCH')),
                  DataColumn(label: Text('TRỄ')),
                ],
                rows: [
                  for (final t in tasks)
                    DataRow(cells: [
                      DataCell(Text(t.title)),
                      DataCell(Text(projectsById[t.projectId]?.name ?? '—')),
                      DataCell(Text(departmentsById[t.departmentId]?.name ?? '—')),
                      DataCell(Text(t.assigneeId != null ? (usersById[t.assigneeId]?.displayName ?? '—') : '—')),
                      DataCell(Text(
                        t.dueDate != null ? '${today.difference(t.dueDate!).inDays} ngày' : '—',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.destructive),
                      )),
                    ]),
                ],
              ),
            ),
    );
  }
}
