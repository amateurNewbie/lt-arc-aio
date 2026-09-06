import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../../projects/data/project_repository.dart' show ProjectCategory;
import '../data/contract_repository.dart';

part 'contract_provider.g.dart';

@riverpod
ContractRepository contractRepository(Ref ref) => ContractRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<Contract>> contractList(Ref ref, String projectId) => ref.watch(contractRepositoryProvider).listByProject(projectId);

@riverpod
Future<List<Contract>> contractListAll(Ref ref) => ref.watch(contractRepositoryProvider).listAll();

/// keepAlive: Actions chỉ được `ref.read` từ dialog — autoDispose sẽ dispose
/// giữa `await` API rồi nổ khi `invalidate` (Ref after disposed).
@Riverpod(keepAlive: true)
class ContractActions extends _$ContractActions {
  @override
  void build() {}

  Future<Contract> create({
    required String projectId,
    required ProjectCategory type,
    required int value,
    required List<MilestoneInput> milestones,
  }) async {
    final contract = await ref.read(contractRepositoryProvider).create(projectId: projectId, type: type, value: value, milestones: milestones);
    if (!ref.mounted) return contract;
    ref.invalidate(contractListProvider);
    ref.invalidate(contractListAllProvider);
    return contract;
  }

  Future<void> collect({required String contractId, required String milestoneId, required int amount, required String fundAccountId, DateTime? date}) async {
    await ref.read(contractRepositoryProvider).collectMilestone(contractId: contractId, milestoneId: milestoneId, amount: amount, fundAccountId: fundAccountId, date: date);
    if (!ref.mounted) return;
    ref.invalidate(contractListProvider);
    ref.invalidate(contractListAllProvider);
  }
}
