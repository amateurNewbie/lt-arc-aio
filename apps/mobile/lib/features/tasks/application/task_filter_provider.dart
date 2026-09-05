import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_filter_provider.g.dart';

/// FR-5.4 — bộ lọc trang Công việc toàn công ty (dự án/bộ phận/người phụ trách).
@riverpod
class TaskFilter extends _$TaskFilter {
  @override
  ({String? projectId, String? departmentId, String? assigneeId}) build() =>
      (projectId: null, departmentId: null, assigneeId: null);

  void setProject(String? projectId) => state = (projectId: projectId, departmentId: state.departmentId, assigneeId: state.assigneeId);

  void setDepartment(String? departmentId) => state = (projectId: state.projectId, departmentId: departmentId, assigneeId: state.assigneeId);

  void setAssignee(String? assigneeId) => state = (projectId: state.projectId, departmentId: state.departmentId, assigneeId: assigneeId);
}
