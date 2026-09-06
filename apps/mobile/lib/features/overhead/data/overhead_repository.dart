import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/network/api_client.dart';

class OverheadCost {
  const OverheadCost({
    required this.id,
    required this.costCategoryId,
    required this.amount,
    required this.date,
    required this.month,
    this.fundAccountId,
    this.note,
  });

  final String id;
  final String costCategoryId;
  final String? fundAccountId;
  final int amount;
  final DateTime date;
  final String month;
  final String? note;

  factory OverheadCost.fromJson(Map<String, dynamic> json) => OverheadCost(
        id: json['id'] as String,
        costCategoryId: json['cost_category_id'] as String,
        fundAccountId: json['fund_account_id'] as String?,
        amount: json['amount'] as int,
        date: DateTime.parse(json['date'] as String),
        month: json['month'] as String,
        note: json['note'] as String?,
      );
}

class OverheadActiveProject {
  const OverheadActiveProject({
    required this.projectId,
    required this.projectCode,
    required this.projectName,
    required this.status,
  });

  final String projectId;
  final String projectCode;
  final String projectName;
  final String status;

  factory OverheadActiveProject.fromJson(Map<String, dynamic> json) => OverheadActiveProject(
        projectId: json['project_id'].toString(),
        projectCode: json['project_code'] as String? ?? '',
        projectName: json['project_name'] as String? ?? '',
        status: json['status'] as String? ?? '',
      );
}

class OverheadAllocationResult {
  const OverheadAllocationResult({
    required this.projectId,
    required this.allocatedAmount,
    this.revenueShare = 0,
  });

  final String projectId;
  final int allocatedAmount;
  final double revenueShare;

  factory OverheadAllocationResult.fromJson(Map<String, dynamic> json) => OverheadAllocationResult(
        projectId: json['project_id'].toString(),
        allocatedAmount: json['allocated_amount'] as int,
        revenueShare: (json['revenue_share'] as num?)?.toDouble() ?? 0,
      );
}

class OverheadRepository {
  OverheadRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<OverheadCost>> list({String? month}) async {
    try {
      final response = await _apiClient.dio.get('/api/overhead-costs', queryParameters: {if (month != null) 'month': month});
      return (response.data as List).map((e) => OverheadCost.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> declareCost({
    required String costCategoryId,
    required int amount,
    required DateTime date,
    required String month,
    required String fundAccountId,
    String? note,
  }) async {
    try {
      await _apiClient.dio.post(
        '/api/overhead-costs',
        data: {
          'cost_category_id': costCategoryId,
          'amount': amount,
          'date': date.toIso8601String().split('T').first,
          'month': month,
          'fund_account_id': fundAccountId,
          'note': note,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<OverheadActiveProject>> activeProjects() async {
    try {
      final response = await _apiClient.dio.get('/api/overhead-costs/active-projects');
      return (response.data as List)
          .map((e) => OverheadActiveProject.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<OverheadAllocationResult>> applyManual({
    required String month,
    required List<({String projectId, int allocatedAmount})> items,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/overhead-costs/allocate',
        data: {
          'month': month,
          'items': [
            for (final i in items) {'project_id': i.projectId, 'allocated_amount': i.allocatedAmount},
          ],
        },
      );
      return (response.data as List)
          .map((e) => OverheadAllocationResult.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
