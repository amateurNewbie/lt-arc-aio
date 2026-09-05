import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../data/cashbook_repository.dart';

part 'cashbook_provider.g.dart';

@riverpod
CashbookRepository cashbookRepository(Ref ref) => CashbookRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<CashbookEntry>> cashbookEntries(Ref ref, String projectId) async {
  final repo = ref.watch(cashbookRepositoryProvider);
  final costs = await repo.listCosts(projectId);
  final payments = await repo.listPayments(projectId);

  final entries = [
    ...costs.map((c) => CashbookEntry(id: c.id, isInflow: false, amount: c.amount, date: c.date, note: c.note)),
    ...payments.map((p) => CashbookEntry(id: p.id, isInflow: true, amount: p.amount, date: p.date)),
  ];
  entries.sort((a, b) => b.date.compareTo(a.date));
  return entries;
}

@riverpod
class CashbookActions extends _$CashbookActions {
  @override
  void build() {}

  /// Trả về `null` khi lưu thành công, hoặc [DuplicateCostWarning] khi cần
  /// hỏi lại người dùng (FR-6.6).
  Future<DuplicateCostWarning?> createCost({
    required String projectId,
    required String costCategoryId,
    required int amount,
    required DateTime date,
    String? note,
    bool confirmDuplicate = false,
  }) async {
    final result = await ref.read(cashbookRepositoryProvider).createCost(
          projectId: projectId,
          costCategoryId: costCategoryId,
          amount: amount,
          date: date,
          note: note,
          confirmDuplicate: confirmDuplicate,
        );
    if (result is DuplicateCostWarning) return result;
    ref.invalidate(cashbookEntriesProvider);
    return null;
  }
}
