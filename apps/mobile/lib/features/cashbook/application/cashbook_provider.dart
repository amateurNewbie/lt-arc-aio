import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../../contracts/application/contract_provider.dart';
import '../../funds/application/fund_provider.dart';
import '../data/cashbook_repository.dart';

part 'cashbook_provider.g.dart';

@riverpod
CashbookRepository cashbookRepository(Ref ref) => CashbookRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<ProjectCost>> projectCostList(Ref ref, String projectId) =>
    ref.watch(cashbookRepositoryProvider).listCosts(projectId);

@riverpod
Future<List<Payment>> projectPaymentList(Ref ref, String projectId) =>
    ref.watch(cashbookRepositoryProvider).listPayments(projectId);

/// keepAlive: Actions chỉ được `ref.read` từ dialog — autoDispose sẽ dispose
/// giữa `await` API rồi nổ khi `invalidate` (Ref after disposed).
@Riverpod(keepAlive: true)
class CashbookActions extends _$CashbookActions {
  @override
  void build() {}

  /// Trả về `null` khi lưu thành công, hoặc [DuplicateCostWarning] khi cần hỏi lại (FR-6.6).
  Future<DuplicateCostWarning?> createCost({
    required String projectId,
    required String costCategoryId,
    required int amount,
    required DateTime date,
    String? workItemId,
    String? fundAccountId,
    String? note,
    bool confirmDuplicate = false,
  }) async {
    final result = await ref.read(cashbookRepositoryProvider).createCost(
          projectId: projectId,
          costCategoryId: costCategoryId,
          amount: amount,
          date: date,
          workItemId: workItemId,
          fundAccountId: fundAccountId,
          note: note,
          confirmDuplicate: confirmDuplicate,
        );
    if (result is DuplicateCostWarning) return result;
    if (!ref.mounted) return null;
    ref.invalidate(projectCostListProvider(projectId));
    ref.invalidate(fundListProvider);
    return null;
  }

  Future<void> collectPayment({
    required String projectId,
    required String contractId,
    required String milestoneId,
    required int amount,
    required String fundAccountId,
    DateTime? date,
  }) async {
    await ref.read(contractActionsProvider.notifier).collect(
          contractId: contractId,
          milestoneId: milestoneId,
          amount: amount,
          fundAccountId: fundAccountId,
          date: date,
        );
    if (!ref.mounted) return;
    ref.invalidate(projectPaymentListProvider(projectId));
    ref.invalidate(contractListProvider(projectId));
    ref.invalidate(fundListProvider);
  }
}
