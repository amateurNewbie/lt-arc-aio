import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../data/pay_profile_repository.dart';

part 'pay_profile_provider.g.dart';

@riverpod
PayProfileRepository payProfileRepository(Ref ref) => PayProfileRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<PayProfile>> payProfileList(Ref ref) => ref.watch(payProfileRepositoryProvider).list();

@riverpod
class PayProfileActions extends _$PayProfileActions {
  @override
  void build() {}

  Future<void> create({required String roleTitle, required int dailyRate, required List<Allowance> allowances}) async {
    await ref.read(payProfileRepositoryProvider).create(roleTitle: roleTitle, dailyRate: dailyRate, allowances: allowances);
    ref.invalidate(payProfileListProvider);
  }

  Future<void> update(String id, {int? dailyRate, List<Allowance>? allowances, bool? active}) async {
    await ref.read(payProfileRepositoryProvider).update(id, dailyRate: dailyRate, allowances: allowances, active: active);
    ref.invalidate(payProfileListProvider);
  }
}
