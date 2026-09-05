import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../data/department_repository.dart';

part 'department_provider.g.dart';

@riverpod
DepartmentRepository departmentRepository(Ref ref) => DepartmentRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<Department>> departmentList(Ref ref) => ref.watch(departmentRepositoryProvider).list();

@riverpod
class DepartmentActions extends _$DepartmentActions {
  @override
  void build() {}

  Future<Department> create({required String name, String? headUserId}) async {
    final department = await ref.read(departmentRepositoryProvider).create(name: name, headUserId: headUserId);
    ref.invalidate(departmentListProvider);
    return department;
  }
}
