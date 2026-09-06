import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../data/workdays_repository.dart';

part 'workdays_provider.g.dart';

@riverpod
WorkdaysRepository workdaysRepository(Ref ref) => WorkdaysRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<MonthlyWorkDays>> workdaysMonth(Ref ref, String month) => ref.watch(workdaysRepositoryProvider).listMonth(month);

/// keepAlive: Actions chỉ được `ref.read` từ dialog — autoDispose sẽ dispose
/// giữa `await` API rồi nổ khi `invalidate` (Ref after disposed).
@Riverpod(keepAlive: true)
class WorkdaysActions extends _$WorkdaysActions {
  @override
  void build() {}

  Future<void> save(String month, Map<String, double> entriesByEmployeeId) async {
    await ref.read(workdaysRepositoryProvider).upsert(month, entriesByEmployeeId);
    if (!ref.mounted) return;
    ref.invalidate(workdaysMonthProvider);
  }
}
