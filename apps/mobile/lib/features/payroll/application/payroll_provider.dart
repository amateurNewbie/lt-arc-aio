import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../data/payroll_repository.dart';

part 'payroll_provider.g.dart';

@riverpod
PayrollRepository payrollRepository(Ref ref) => PayrollRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<PayrollRecord>> payrollMonth(Ref ref, String month) => ref.watch(payrollRepositoryProvider).listMonth(month);

@riverpod
class PayrollActions extends _$PayrollActions {
  @override
  void build() {}

  Future<void> run(String month) async {
    await ref.read(payrollRepositoryProvider).run(month);
    ref.invalidate(payrollMonthProvider);
  }

  Future<void> pay(String month, {required String fundAccountId}) async {
    await ref.read(payrollRepositoryProvider).pay(month, fundAccountId: fundAccountId);
    ref.invalidate(payrollMonthProvider);
  }
}
