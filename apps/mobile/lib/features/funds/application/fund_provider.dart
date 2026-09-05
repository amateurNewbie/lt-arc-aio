import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../data/fund_repository.dart';

part 'fund_provider.g.dart';

@riverpod
FundRepository fundRepository(Ref ref) => FundRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<FundAccount>> fundList(Ref ref) => ref.watch(fundRepositoryProvider).list();

@riverpod
Future<List<CashLedgerEntry>> fundLedger(Ref ref, String fundId) => ref.watch(fundRepositoryProvider).ledger(fundId);

@riverpod
class FundActions extends _$FundActions {
  @override
  void build() {}

  Future<FundAccount> create({required String name, required FundType type, int balance = 0}) async {
    final fund = await ref.read(fundRepositoryProvider).create(name: name, type: type, balance: balance);
    ref.invalidate(fundListProvider);
    return fund;
  }
}
