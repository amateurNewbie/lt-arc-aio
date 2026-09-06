import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../data/debt_repository.dart';

part 'debt_provider.g.dart';

@riverpod
DebtRepository debtRepository(Ref ref) => DebtRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<Receivable>> receivableList(Ref ref) => ref.watch(debtRepositoryProvider).listReceivables();

@riverpod
Future<List<Payable>> payableList(Ref ref) => ref.watch(debtRepositoryProvider).listPayables();

/// keepAlive: Actions chỉ được `ref.read` từ dialog — autoDispose sẽ dispose
/// giữa `await` API rồi nổ khi `invalidate` (Ref after disposed).
@Riverpod(keepAlive: true)
class DebtActions extends _$DebtActions {
  @override
  void build() {}

  Future<Payable> createPayable({required String projectId, required String vendorName, required String costCategoryId, required int totalAmount}) async {
    final payable = await ref.read(debtRepositoryProvider).createPayable(
          projectId: projectId,
          vendorName: vendorName,
          costCategoryId: costCategoryId,
          totalAmount: totalAmount,
        );
    if (!ref.mounted) return payable;
    ref.invalidate(payableListProvider);
    return payable;
  }

  Future<Payable> settlePayable({required String payableId, required int amount, required String fundAccountId}) async {
    final payable = await ref.read(debtRepositoryProvider).settlePayable(payableId: payableId, amount: amount, fundAccountId: fundAccountId);
    if (!ref.mounted) return payable;
    ref.invalidate(payableListProvider);
    return payable;
  }
}
