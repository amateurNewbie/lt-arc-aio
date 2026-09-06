import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../data/project_repository.dart';

part 'project_provider.g.dart';

/// Điều hướng trong tab Dự án (giữ sidebar WebShell — không push full-screen).
sealed class ProjectPane {
  const ProjectPane();
}

class ProjectPaneList extends ProjectPane {
  const ProjectPaneList();
}

class ProjectPaneCreate extends ProjectPane {
  const ProjectPaneCreate();
}

class ProjectPaneDetail extends ProjectPane {
  const ProjectPaneDetail(this.projectId, {this.seed});
  final String projectId;
  /// Dự án vừa tạo — hydrate form ngay, không chờ GET.
  final Project? seed;
}

class ProjectPaneController extends Notifier<ProjectPane> {
  @override
  ProjectPane build() => const ProjectPaneList();

  void showList() => state = const ProjectPaneList();

  void showCreate() => state = const ProjectPaneCreate();

  void showDetail(String projectId, {Project? seed}) => state = ProjectPaneDetail(projectId, seed: seed);
}

final projectPaneProvider = NotifierProvider<ProjectPaneController, ProjectPane>(ProjectPaneController.new);

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

/// keepAlive: Actions chỉ được `ref.read` từ dialog — autoDispose sẽ dispose
/// giữa `await` API rồi nổ khi `invalidate` (Ref after disposed).
@Riverpod(keepAlive: true)
class ProjectActions extends _$ProjectActions {
  @override
  void build() {}

  Future<Project> create({
    required String name,
    required String client,
    required ProjectCategory category,
    required String managerId,
    String? constructionHeadId,
    String? designHeadId,
    List<String> memberIds = const [],
    String? leadId,
    String? type,
    double? area,
    int? budget,
    Map<String, ProjectStageProgress>? stageProgress,
  }) async {
    final project = await ref.read(projectRepositoryProvider).create(
          name: name,
          client: client,
          category: category,
          managerId: managerId,
          constructionHeadId: constructionHeadId,
          designHeadId: designHeadId,
          memberIds: memberIds,
          leadId: leadId,
          type: type,
          area: area,
          budget: budget,
          stageProgress: stageProgress,
        );
    if (!ref.mounted) return project;
    ref.invalidate(projectListProvider);
    return project;
  }

  Future<Project> update(
    String projectId, {
    String? name,
    String? client,
    ProjectCategory? category,
    String? managerId,
    String? constructionHeadId,
    String? designHeadId,
    List<String>? memberIds,
    String? leadId,
    String? type,
    double? area,
    int? budget,
    ProjectStatus? status,
    Map<String, ProjectStageProgress>? stageProgress,
    bool clearOptionalHeads = false,
  }) async {
    final project = await ref.read(projectRepositoryProvider).update(
          projectId,
          name: name,
          client: client,
          category: category,
          managerId: managerId,
          constructionHeadId: constructionHeadId,
          designHeadId: designHeadId,
          memberIds: memberIds,
          leadId: leadId,
          type: type,
          area: area,
          budget: budget,
          status: status,
          stageProgress: stageProgress,
          clearOptionalHeads: clearOptionalHeads,
        );
    if (!ref.mounted) return project;
    ref.invalidate(projectListProvider);
    ref.invalidate(projectDetailProvider(projectId));
    return project;
  }
}
