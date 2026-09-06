import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../data/budget_repository.dart';

part 'budget_provider.g.dart';

@riverpod
BudgetRepository budgetRepository(Ref ref) => BudgetRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<BudgetEstimate>> budgetList(Ref ref, String projectId) => ref.watch(budgetRepositoryProvider).list(projectId);

/// keepAlive: Actions chỉ được `ref.read` từ dialog — autoDispose sẽ dispose
/// giữa `await` API rồi nổ khi `invalidate` (Ref after disposed).
@Riverpod(keepAlive: true)
class BudgetActions extends _$BudgetActions {
  @override
  void build() {}

  Future<BudgetEstimate> create(String projectId, List<BudgetLineInput> lines) async {
    final budget = await ref.read(budgetRepositoryProvider).create(projectId, lines);
    if (!ref.mounted) return budget;
    ref.invalidate(budgetListProvider);
    return budget;
  }

  Future<BudgetEstimate> addLine(String projectId, BudgetLineInput line) async {
    final budget = await ref.read(budgetRepositoryProvider).addLine(projectId, line);
    if (!ref.mounted) return budget;
    ref.invalidate(budgetListProvider);
    return budget;
  }

  Future<BudgetEstimate> submit(String projectId, String budgetId) async {
    final budget = await ref.read(budgetRepositoryProvider).submit(projectId, budgetId);
    if (!ref.mounted) return budget;
    ref.invalidate(budgetListProvider);
    return budget;
  }

  Future<BudgetEstimate> approve(String projectId, String budgetId) async {
    final budget = await ref.read(budgetRepositoryProvider).approve(projectId, budgetId);
    if (!ref.mounted) return budget;
    ref.invalidate(budgetListProvider);
    return budget;
  }
}
