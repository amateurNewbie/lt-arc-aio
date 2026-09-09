import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../data/department_repository.dart';

part 'department_provider.g.dart';

@riverpod
DepartmentRepository departmentRepository(Ref ref) => DepartmentRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<Department>> departmentList(Ref ref) async {
  // GET /api/departments chỉ ADMIN/DIRECTOR/DEPARTMENT_HEAD gọi được ở backend
  // — Nhân viên luôn 403; trả rỗng ngay từ đầu (xem lý do ở userListProvider).
  final role = ref.watch(authProvider).value?.role;
  if (role != 'ADMIN' && role != 'DIRECTOR' && role != 'DEPARTMENT_HEAD') return const [];
  return ref.watch(departmentRepositoryProvider).list();
}

/// keepAlive: Actions chỉ được `ref.read` từ dialog — autoDispose sẽ dispose
/// giữa `await` API rồi nổ khi `invalidate` (Ref after disposed).
@Riverpod(keepAlive: true)
class DepartmentActions extends _$DepartmentActions {
  @override
  void build() {}

  Future<Department> create({required String name, String? headUserId}) async {
    final department = await ref.read(departmentRepositoryProvider).create(name: name, headUserId: headUserId);
    if (!ref.mounted) return department;
    ref.invalidate(departmentListProvider);
    return department;
  }
}
