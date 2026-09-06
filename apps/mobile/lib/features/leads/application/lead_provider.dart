import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../data/lead_repository.dart';

part 'lead_provider.g.dart';

@riverpod
LeadRepository leadRepository(Ref ref) => LeadRepository(ref.watch(apiClientProvider));

@riverpod
class LeadFilter extends _$LeadFilter {
  @override
  ({LeadStatus? status, String? source, String? ownerId, String search}) build() =>
      (status: null, source: null, ownerId: null, search: '');

  void setStatus(LeadStatus? status) => state = (status: status, source: state.source, ownerId: state.ownerId, search: state.search);

  void setSource(String? source) => state = (status: state.status, source: source, ownerId: state.ownerId, search: state.search);

  void setOwner(String? ownerId) => state = (status: state.status, source: state.source, ownerId: ownerId, search: state.search);

  void setSearch(String search) => state = (status: state.status, source: state.source, ownerId: state.ownerId, search: search);
}

@riverpod
Future<List<Lead>> leadList(Ref ref) {
  final filter = ref.watch(leadFilterProvider);
  return ref.watch(leadRepositoryProvider).list(status: filter.status, source: filter.source, ownerId: filter.ownerId, search: filter.search);
}

/// keepAlive: Actions chỉ được `ref.read` từ dialog — autoDispose sẽ dispose
/// giữa `await` API rồi nổ khi `invalidate` (Ref after disposed).
@Riverpod(keepAlive: true)
class LeadActions extends _$LeadActions {
  @override
  void build() {}

  Future<Lead> create({
    required String name,
    String? phone,
    String? email,
    String? need,
    int? budgetEstimate,
    String? source,
    String? note,
    String? ownerId,
  }) async {
    final lead = await ref.read(leadRepositoryProvider).create(
          name: name,
          phone: phone,
          email: email,
          need: need,
          budgetEstimate: budgetEstimate,
          source: source,
          note: note,
          ownerId: ownerId,
        );
    if (!ref.mounted) return lead;
    ref.invalidate(leadListProvider);
    return lead;
  }

  Future<Lead> updateStatus(String leadId, LeadStatus status, {String? note}) async {
    final lead = await ref.read(leadRepositoryProvider).updateStatus(leadId, status, note: note);
    if (!ref.mounted) return lead;
    ref.invalidate(leadListProvider);
    return lead;
  }

  Future<void> update(
    String leadId, {
    String? name,
    String? phone,
    String? email,
    String? need,
    int? budgetEstimate,
    String? source,
    String? ownerId,
  }) async {
    await ref.read(leadRepositoryProvider).update(
          leadId,
          name: name,
          phone: phone,
          email: email,
          need: need,
          budgetEstimate: budgetEstimate,
          source: source,
          ownerId: ownerId,
        );
    if (!ref.mounted) return;
    ref.invalidate(leadListProvider);
  }

  Future<void> delete(String leadId) async {
    await ref.read(leadRepositoryProvider).delete(leadId);
    if (!ref.mounted) return;
    ref.invalidate(leadListProvider);
  }

  Future<String> convertToProject(String leadId, {required String category, required String managerId}) async {
    final projectId = await ref
        .read(leadRepositoryProvider)
        .convertToProject(leadId, category: category, managerId: managerId);
    if (!ref.mounted) return projectId;
    ref.invalidate(leadListProvider);
    return projectId;
  }
}
