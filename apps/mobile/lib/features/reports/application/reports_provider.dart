import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import '../data/reports_repository.dart';

part 'reports_provider.g.dart';

@riverpod
ReportsRepository reportsRepository(Ref ref) => ReportsRepository(ref.watch(apiClientProvider));

@riverpod
Future<List<ProjectPnl>> profitLossReport(
  Ref ref, {
  String? category,
  String? projectId,
  DateTime? dateFrom,
  DateTime? dateTo,
}) async {
  // GET /api/reports/profit-loss chỉ ADMIN/DIRECTOR gọi được — trang Dự án
  // (nơi gọi provider này để hiện lãi/lỗ tạm tính) vẫn mở cho mọi role, nên
  // không thể để cả trang lỗi chỉ vì báo cáo tài chính bị chặn.
  final role = ref.watch(authProvider).value?.role;
  if (role != 'ADMIN' && role != 'DIRECTOR') return const [];
  return ref.watch(reportsRepositoryProvider).profitLoss(
        category: category,
        projectId: projectId,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
}

@riverpod
Future<CashflowReport> cashflowReport(Ref ref, {required int year, required int month}) =>
    ref.watch(reportsRepositoryProvider).cashflow(year: year, month: month);
