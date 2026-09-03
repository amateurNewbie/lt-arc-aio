import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tasks/presentation/tasks_page.dart';
import '../application/project_provider.dart';
import '../data/project_repository.dart';

/// FR-3.3 — skeleton: thông tin cơ bản + tab Công việc. Tab Dự toán/Hạng mục/
/// Thu&Chi phí thêm ở Phase 2.
class ProjectDetailPage extends ConsumerWidget {
  const ProjectDetailPage({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(projectDetailProvider(projectId));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: projectAsync.whenOrNull(data: (p) => Text(p.name)) ?? const Text('Dự án'),
          bottom: const TabBar(tabs: [Tab(text: 'Tổng quan'), Tab(text: 'Công việc')]),
        ),
        body: projectAsync.when(
          data: (project) => TabBarView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(project.code, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Text('Khách hàng: ${project.client}'),
                    Text('Phân loại: ${project.category.label}'),
                    Text('Trạng thái: ${project.status.label}'),
                    if (project.area != null) Text('Diện tích: ${project.area} m²'),
                    if (project.budget != null) Text('Ngân sách: ${project.budget} ₫'),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: project.progress / 100, minHeight: 8),
                    const SizedBox(height: 4),
                    Text('Tiến độ tổng thể: ${project.progress}%'),
                  ],
                ),
              ),
              TasksPage(projectId: project.id, embedded: true),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Lỗi tải dữ liệu: $error')),
        ),
      ),
    );
  }
}
