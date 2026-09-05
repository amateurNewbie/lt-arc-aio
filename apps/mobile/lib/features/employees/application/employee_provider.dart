import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../../pay_profiles/data/pay_profile_repository.dart';
import '../data/employee_repository.dart';

part 'employee_provider.g.dart';

@riverpod
EmployeeRepository employeeRepository(Ref ref) => EmployeeRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<Employee>> employeeList(Ref ref) => ref.watch(employeeRepositoryProvider).list();

@riverpod
class EmployeeActions extends _$EmployeeActions {
  @override
  void build() {}

  Future<void> create({required String userId, String? phone, DateTime? hireDate, String? payProfileId}) async {
    await ref.read(employeeRepositoryProvider).create(userId: userId, phone: phone, hireDate: hireDate, payProfileId: payProfileId);
    ref.invalidate(employeeListProvider);
  }

  Future<void> updatePay(String employeeId, {String? payProfileId, int? dailyRateOverride, List<Allowance>? allowanceOverrides}) async {
    await ref
        .read(employeeRepositoryProvider)
        .updatePay(employeeId, payProfileId: payProfileId, dailyRateOverride: dailyRateOverride, allowanceOverrides: allowanceOverrides);
    ref.invalidate(employeeListProvider);
  }
}
