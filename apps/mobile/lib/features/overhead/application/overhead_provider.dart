import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../../funds/application/fund_provider.dart';
import '../data/overhead_repository.dart';

part 'overhead_provider.g.dart';

@riverpod
OverheadRepository overheadRepository(Ref ref) => OverheadRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<OverheadCost>> overheadCostList(Ref ref, {String? month}) =>
    ref.watch(overheadRepositoryProvider).list(month: month);

@riverpod
Future<List<OverheadActiveProject>> overheadActiveProjects(Ref ref) =>
    ref.watch(overheadRepositoryProvider).activeProjects();

/// keepAlive: Actions chỉ được `ref.read` từ dialog — autoDispose sẽ dispose
/// giữa `await` API rồi nổ khi `invalidate` (Ref after disposed).
@Riverpod(keepAlive: true)
class OverheadActions extends _$OverheadActions {
  @override
  void build() {}

  Future<void> declareCost({
    required String costCategoryId,
    required int amount,
    required DateTime date,
    required String month,
    required String fundAccountId,
    String? note,
  }) async {
    await ref.read(overheadRepositoryProvider).declareCost(
          costCategoryId: costCategoryId,
          amount: amount,
          date: date,
          month: month,
          fundAccountId: fundAccountId,
          note: note,
        );
    if (!ref.mounted) return;
    ref.invalidate(overheadCostListProvider);
    ref.invalidate(fundListProvider);
    ref.invalidate(fundLedgerProvider);
  }

  Future<List<OverheadAllocationResult>> applyManual({
    required String month,
    required List<({String projectId, int allocatedAmount})> items,
  }) async {
    final result = await ref.read(overheadRepositoryProvider).applyManual(month: month, items: items);
    if (!ref.mounted) return result;
    ref.invalidate(overheadCostListProvider);
    return result;
  }
}
