import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../data/department_repository.dart';

part 'department_provider.g.dart';

@riverpod
DepartmentRepository departmentRepository(Ref ref) => DepartmentRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<Department>> departmentList(Ref ref) => ref.watch(departmentRepositoryProvider).list();
