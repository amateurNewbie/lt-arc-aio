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
}) =>
    ref.watch(reportsRepositoryProvider).profitLoss(
          category: category,
          projectId: projectId,
          dateFrom: dateFrom,
          dateTo: dateTo,
        );

@riverpod
Future<CashflowReport> cashflowReport(Ref ref, {required int year, required int month}) =>
    ref.watch(reportsRepositoryProvider).cashflow(year: year, month: month);
