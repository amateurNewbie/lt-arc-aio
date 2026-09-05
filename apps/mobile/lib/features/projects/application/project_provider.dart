import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../data/project_repository.dart';

part 'project_provider.g.dart';

@riverpod
ProjectRepository projectRepository(Ref ref) => ProjectRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<Project>> projectList(Ref ref, {ProjectStatus? status, ProjectCategory? category, String? search}) =>
    ref.watch(projectRepositoryProvider).list(status: status, category: category, search: search);

@riverpod
Future<Project> projectDetail(Ref ref, String projectId) => ref.watch(projectRepositoryProvider).getById(projectId);

@riverpod
class ProjectFilter extends _$ProjectFilter {
  @override
  ({ProjectStatus? status, ProjectCategory? category, String search}) build() =>
      (status: null, category: null, search: '');

  void setStatus(ProjectStatus? status) => state = (status: status, category: state.category, search: state.search);

  void setCategory(ProjectCategory? category) => state = (status: state.status, category: category, search: state.search);

  void setSearch(String search) => state = (status: state.status, category: state.category, search: search);
}

@riverpod
class ProjectActions extends _$ProjectActions {
  @override
  void build() {}

  Future<Project> create({
    required String name,
    required String client,
    required ProjectCategory category,
    required String managerId,
    String? type,
    double? area,
    int? budget,
  }) async {
    final project = await ref
        .read(projectRepositoryProvider)
        .create(name: name, client: client, category: category, managerId: managerId, type: type, area: area, budget: budget);
    ref.invalidate(projectListProvider);
    return project;
  }
}
