import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../data/overhead_repository.dart';

part 'overhead_provider.g.dart';

@riverpod
OverheadRepository overheadRepository(Ref ref) => OverheadRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<OverheadCost>> overheadCostList(Ref ref, {String? month}) => ref.watch(overheadRepositoryProvider).list(month: month);

@riverpod
class OverheadActions extends _$OverheadActions {
  @override
  void build() {}

  Future<void> declareCost({required String costCategoryId, required int amount, required DateTime date, required String month, String? note}) async {
    await ref.read(overheadRepositoryProvider).declareCost(costCategoryId: costCategoryId, amount: amount, date: date, month: month, note: note);
    ref.invalidate(overheadCostListProvider);
  }

  Future<List<OverheadAllocationPreview>> preview({required String month, required AllocationBasis basis}) =>
      ref.read(overheadRepositoryProvider).preview(month: month, basis: basis);

  Future<List<OverheadAllocationPreview>> apply({required String month, required AllocationBasis basis}) =>
      ref.read(overheadRepositoryProvider).apply(month: month, basis: basis);
}
