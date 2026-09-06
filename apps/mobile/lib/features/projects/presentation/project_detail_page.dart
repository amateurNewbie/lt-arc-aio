import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../budget/presentation/budget_tab.dart';
import '../../cashbook/presentation/cashbook_tab.dart';
import '../../contracts/presentation/contracts_tab.dart';
import '../../debts/application/debt_provider.dart';
import '../../files/presentation/files_tab.dart';
import '../../reports/application/reports_provider.dart';
import '../../reports/data/reports_repository.dart';
import '../../tasks/presentation/project_tasks_tab.dart';
import '../../work_items/presentation/work_items_tab.dart';
import '../application/project_provider.dart';
import '../data/project_repository.dart';

/// FR-3.3 — trung tâm điều phối dữ liệu dự án, bám `LT-ARC-Web-UI_1.html`
/// (`data-if="isProjectDetail"`): Tổng quan/Dự toán/Hợp đồng/Công việc/Hạng
/// mục công việc/Thu&Chi (+ Tệp, mở rộng ngoài mockup nhưng vẫn giữ vì là chức
/// năng thật đã có).
///
/// Phase A: navigation chính dùng [ProjectEditorPage]; page này giữ cho mobile
/// tabbed fallback / tương thích.
class ProjectDetailPage extends ConsumerWidget {
  const ProjectDetailPage({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(projectDetailProvider(projectId));

    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: projectAsync.whenOrNull(data: (p) => Text(p.name)) ?? const Text('Dự án'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Tổng quan'),
              Tab(text: 'Dự toán'),
              Tab(text: 'Hợp đồng'),
              Tab(text: 'Hạng mục công việc'),
              Tab(text: 'Công việc'),
              Tab(text: 'Thu & Chi'),
              Tab(text: 'Tệp'),
            ],
          ),
        ),
        body: projectAsync.when(
          data: (project) => TabBarView(
            children: [
              _OverviewTab(project: project),
              BudgetTab(projectId: project.id),
              ContractsTab(projectId: project.id),
              WorkItemsTab(projectId: project.id),
              ProjectTasksTab(projectId: project.id),
              CashbookTab(projectId: project.id),
              FilesTab(projectId: project.id),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Lỗi tải dữ liệu: $error')),
        ),
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pnlAsync = ref.watch(profitLossReportProvider());
    final receivablesAsync = ref.watch(receivableListProvider);

    final pnl = (pnlAsync.value ?? const <ProjectPnl>[]).where((p) => p.projectId == project.id).firstOrNull;
    final receivable = (receivablesAsync.value ?? const []).where((r) => r.projectId == project.id).fold<int>(0, (s, r) => s + r.remaining);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(project.code, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text('${project.client} · ${project.category.label}${project.type != null ? ' — ${project.type}' : ''}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MiniStat(label: 'Tiến độ', value: '${project.progress}%'),
              _MiniStat(label: 'Ngân sách', value: project.budget != null ? formatCompactVnd(project.budget!) : '—'),
              _MiniStat(label: 'Đã thu', value: pnl != null ? formatCompactVnd(pnl.revenue) : '—'),
              _MiniStat(label: 'Tổng chi phí', value: pnl != null ? formatCompactVnd(pnl.totalCost) : '—'),
              _MiniStat(
                label: 'Lãi/Lỗ',
                value: pnl != null ? formatCompactVnd(pnl.profit, showSign: true) : '—',
                valueColor: pnl != null ? (pnl.profit >= 0 ? AppColors.webSuccess : AppColors.webDestructive) : null,
              ),
              _MiniStat(label: 'Công nợ phải thu', value: formatCompactVnd(receivable)),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(color: AppColors.webCardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.webBorder)),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tiến độ theo giai đoạn', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Theo dõi chi tiết tiến độ thi công & thiết kế của dự án.', style: TextStyle(fontSize: 12, color: AppColors.webMutedFg)),
                const SizedBox(height: 16),
                if (project.stageProgress == null || project.stageProgress!.isEmpty)
                  const Text('Chưa có dữ liệu tiến độ theo giai đoạn cho dự án này.')
                else
                  for (final stage in project.stages.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(projectStageLabels[stage.key] ?? stage.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                              Builder(
                                builder: (context) {
                                  final overdue = stage.value.deadline != null &&
                                      stage.value.progress < 100 &&
                                      DateTime(stage.value.deadline!.year, stage.value.deadline!.month, stage.value.deadline!.day)
                                          .isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
                                  return Text(
                                    overdue ? '${stage.value.progress}% · trễ kế hoạch' : '${stage.value.progress}%',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: overdue ? AppColors.webDestructive : AppColors.webMutedFg,
                                      fontWeight: overdue ? FontWeight.w600 : null,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: stage.value.progress / 100,
                              minHeight: 6,
                              backgroundColor: AppColors.webMutedBg,
                              color: stage.value.progress >= 100
                                  ? AppColors.webSuccess
                                  : (stage.value.deadline != null &&
                                          stage.value.progress < 100 &&
                                          DateTime(stage.value.deadline!.year, stage.value.deadline!.month, stage.value.deadline!.day)
                                              .isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))
                                      ? AppColors.webDestructive
                                      : AppColors.gold),
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        decoration: BoxDecoration(color: AppColors.webCardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.webBorder)),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: AppColors.webMutedFg)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: valueColor), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
