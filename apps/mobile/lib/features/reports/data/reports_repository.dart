import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/network/api_client.dart';

class ProjectPnl {
  const ProjectPnl({
    required this.projectId,
    required this.projectCode,
    required this.projectName,
    required this.revenue,
    required this.directCost,
    required this.overheadAllocated,
    required this.totalCost,
    required this.profit,
    required this.marginPercent,
  });

  final String projectId;
  final String projectCode;
  final String projectName;
  final int revenue;
  final int directCost;
  final int overheadAllocated;
  final int totalCost;
  final int profit;
  final double marginPercent;

  factory ProjectPnl.fromJson(Map<String, dynamic> json) => ProjectPnl(
        projectId: json['project_id'] as String,
        projectCode: json['project_code'] as String,
        projectName: json['project_name'] as String,
        revenue: json['revenue'] as int,
        directCost: json['direct_cost'] as int,
        overheadAllocated: json['overhead_allocated'] as int,
        totalCost: json['total_cost'] as int,
        profit: json['profit'] as int,
        marginPercent: (json['margin_percent'] as num).toDouble(),
      );
}

class CashflowReport {
  const CashflowReport({required this.month, required this.openingBalance, required this.totalInflow, required this.totalOutflow, required this.closingBalance});

  final String month;
  final int openingBalance;
  final int totalInflow;
  final int totalOutflow;
  final int closingBalance;

  factory CashflowReport.fromJson(Map<String, dynamic> json) => CashflowReport(
        month: json['month'] as String,
        openingBalance: json['opening_balance'] as int,
        totalInflow: json['total_inflow'] as int,
        totalOutflow: json['total_outflow'] as int,
        closingBalance: json['closing_balance'] as int,
      );
}

class ReportsRepository {
  ReportsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ProjectPnl>> profitLoss() async {
    try {
      final response = await _apiClient.dio.get('/api/reports/profit-loss');
      return (response.data as List).map((e) => ProjectPnl.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<CashflowReport> cashflow({required int year, required int month}) async {
    try {
      final response = await _apiClient.dio.get('/api/reports/cashflow', queryParameters: {'year': year, 'month': month});
      return CashflowReport.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
