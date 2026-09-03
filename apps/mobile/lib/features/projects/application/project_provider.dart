import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../data/project_repository.dart';

part 'project_provider.g.dart';

@riverpod
ProjectRepository projectRepository(Ref ref) => ProjectRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<Project>> projectList(Ref ref) => ref.watch(projectRepositoryProvider).list();

@riverpod
Future<Project> projectDetail(Ref ref, String projectId) => ref.watch(projectRepositoryProvider).getById(projectId);

@riverpod
class ProjectActions extends _$ProjectActions {
  @override
  void build() {}

  Future<Project> create({
    required String name,
    required String client,
    required ProjectCategory category,
    required String managerId,
  }) async {
    final project = await ref
        .read(projectRepositoryProvider)
        .create(name: name, client: client, category: category, managerId: managerId);
    ref.invalidate(projectListProvider);
    return project;
  }
}
