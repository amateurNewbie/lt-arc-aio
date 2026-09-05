import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/web_badge.dart';
import '../../reports/application/reports_provider.dart';
import '../../reports/data/reports_repository.dart';
import '../application/project_provider.dart';
import '../data/project_repository.dart';
import 'project_detail_page.dart';
import 'project_form_dialog.dart';

WebBadgeVariant _categoryVariant(ProjectCategory c) => switch (c) {
      ProjectCategory.construction => WebBadgeVariant.warning,
      ProjectCategory.turnkey => WebBadgeVariant.primary,
      ProjectCategory.design => WebBadgeVariant.outline,
    };

InputDecoration _webSelectDecoration() => InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.webBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.webBorder)),
    );

/// Trang "Dự án" bản Web — bám `LT-ARC-Web-UI_1.html` (`data-if="isProjects"`):
/// bộ lọc + lưới thẻ dự án 3 cột kèm tiến độ và lãi/lỗ tạm tính (từ P&L thật).
class ProjectsWebPage extends ConsumerWidget {
  const ProjectsWebPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(projectFilterProvider);
    final projectsAsync = ref.watch(projectListProvider(status: filter.status, category: filter.category, search: filter.search));
    final pnlAsync = ref.watch(profitLossReportProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1360),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dự án', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('Theo dõi tiến độ và lợi nhuận từ ý tưởng đến bàn giao.', style: TextStyle(fontSize: 13, color: AppColors.webMutedFg)),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => showProjectFormDialog(context),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.webForeground, foregroundColor: Colors.white),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Tạo dự án'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: _webSelectDecoration().copyWith(hintText: 'Tìm theo tên, mã hoặc khách hàng...', prefixIcon: const Icon(Icons.search, size: 18)),
                      onChanged: (v) => ref.read(projectFilterProvider.notifier).setSearch(v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<ProjectCategory?>(
                      initialValue: filter.category,
                      decoration: _webSelectDecoration(),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Phân loại: Tất cả', style: TextStyle(fontSize: 13))),
                        for (final c in ProjectCategory.values) DropdownMenuItem(value: c, child: Text(c.label, style: const TextStyle(fontSize: 13))),
                      ],
                      onChanged: (v) => ref.read(projectFilterProvider.notifier).setCategory(v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<ProjectStatus?>(
                      initialValue: filter.status,
                      decoration: _webSelectDecoration(),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Trạng thái: Tất cả', style: TextStyle(fontSize: 13))),
                        for (final s in ProjectStatus.values) DropdownMenuItem(value: s, child: Text(s.label, style: const TextStyle(fontSize: 13))),
                      ],
                      onChanged: (v) => ref.read(projectFilterProvider.notifier).setStatus(v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              projectsAsync.when(
                data: (projects) {
                  if (projects.isEmpty) return const Text('Chưa có dự án nào');
                  final pnlByProject = {for (final p in pnlAsync.value ?? const <ProjectPnl>[]) p.projectId: p};
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [for (final p in projects) SizedBox(width: 420, child: _ProjectCard(project: p, pnl: pnlByProject[p.id]))],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Lỗi tải dữ liệu: $e'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.pnl});

  final Project project;
  final ProjectPnl? pnl;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.decimalPattern('vi');
    final profit = pnl?.profit;

    return Container(
      decoration: BoxDecoration(color: AppColors.webCardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.webBorder)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProjectDetailPage(projectId: project.id))),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(project.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        Text(project.code, style: TextStyle(fontSize: 12, color: AppColors.webMutedFg)),
                      ],
                    ),
                  ),
                  WebBadge(project.status.label, variant: WebBadgeVariant.secondary),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  WebBadge(project.category.label, variant: _categoryVariant(project.category)),
                  if (project.area != null) ...[const SizedBox(width: 6), WebBadge('${project.area} m²', variant: WebBadgeVariant.outline)],
                ],
              ),
              const SizedBox(height: 8),
              Text('KH: ${project.client}', style: TextStyle(fontSize: 13, color: AppColors.webMutedFg)),
              const SizedBox(height: 10),
              ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: project.progress / 100, minHeight: 6, backgroundColor: AppColors.webMutedBg, color: AppColors.gold)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Tiến độ ${project.progress}%', style: TextStyle(fontSize: 12, color: AppColors.webMutedFg)),
                  if (project.budget != null) Text('${currency.format(pnl?.revenue ?? 0)} / ${currency.format(project.budget)} ₫', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
              if (profit != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.webBorder))),
                  child: Text(
                    '${profit >= 0 ? 'Lãi' : 'Lỗ'} tạm tính ${profit >= 0 ? '+' : ''}${currency.format(profit)} ₫',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: profit >= 0 ? AppColors.webSuccess : AppColors.webDestructive),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
