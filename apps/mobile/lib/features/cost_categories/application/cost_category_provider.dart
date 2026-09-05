import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../data/cost_category_repository.dart';

part 'cost_category_provider.g.dart';

@riverpod
CostCategoryRepository costCategoryRepository(Ref ref) => CostCategoryRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<CostCategory>> costCategoryList(Ref ref, {CostCategoryScope? scope}) =>
    ref.watch(costCategoryRepositoryProvider).list(scope: scope);

@riverpod
class CostCategoryActions extends _$CostCategoryActions {
  @override
  void build() {}

  Future<void> create({required String name, required CostCategoryScope scope, String? description}) async {
    await ref.read(costCategoryRepositoryProvider).create(name: name, scope: scope, description: description);
    ref.invalidate(costCategoryListProvider);
  }

  Future<void> setActive(String id, bool active) async {
    await ref.read(costCategoryRepositoryProvider).update(id, active: active);
    ref.invalidate(costCategoryListProvider);
  }
}
