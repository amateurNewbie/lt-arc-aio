import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/project_provider.dart';
import '../data/project_repository.dart';
import 'project_detail_page.dart';

class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dự án')),
      body: projectsAsync.when(
        data: (projects) {
          if (projects.isEmpty) {
            return const Center(child: Text('Chưa có dự án nào'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(projectListProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: projects.length,
              itemBuilder: (context, index) => _ProjectCard(project: projects[index]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Lỗi tải dữ liệu: $error')),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProjectDetailPage(projectId: project.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(project.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(project.code, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Chip(label: Text(project.status.label)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Chip(label: Text(project.category.label), visualDensity: VisualDensity.compact),
                  const SizedBox(width: 6),
                  Text('KH: ${project.client}', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: project.progress / 100, minHeight: 6),
              ),
              const SizedBox(height: 4),
              Text('Tiến độ ${project.progress}%', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
