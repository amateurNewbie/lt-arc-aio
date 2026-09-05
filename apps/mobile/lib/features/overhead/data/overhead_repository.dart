import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/network/api_client.dart';

enum AllocationBasis { revenue, equal }

const _basisWire = {AllocationBasis.revenue: 'REVENUE', AllocationBasis.equal: 'EQUAL'};

extension AllocationBasisWire on AllocationBasis {
  String get wire => _basisWire[this]!;
  String get label => this == AllocationBasis.revenue ? 'Theo doanh thu' : 'Chia đều';
}

class OverheadAllocationPreview {
  const OverheadAllocationPreview({required this.projectId, required this.projectCode, required this.revenueShare, required this.allocatedAmount});
  final String projectId;
  final String projectCode;
  final double revenueShare;
  final int allocatedAmount;

  factory OverheadAllocationPreview.fromJson(Map<String, dynamic> json) => OverheadAllocationPreview(
        projectId: json['project_id'] as String,
        projectCode: json['project_code'] as String,
        revenueShare: (json['revenue_share'] as num).toDouble(),
        allocatedAmount: json['allocated_amount'] as int,
      );
}

class OverheadCost {
  const OverheadCost({required this.id, required this.costCategoryId, required this.amount, required this.date, required this.month, this.note});

  final String id;
  final String costCategoryId;
  final int amount;
  final DateTime date;
  final String month;
  final String? note;

  factory OverheadCost.fromJson(Map<String, dynamic> json) => OverheadCost(
        id: json['id'] as String,
        costCategoryId: json['cost_category_id'] as String,
        amount: json['amount'] as int,
        date: DateTime.parse(json['date'] as String),
        month: json['month'] as String,
        note: json['note'] as String?,
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

  Future<void> declareCost({required String costCategoryId, required int amount, required DateTime date, required String month, String? note}) async {
    try {
      await _apiClient.dio.post(
        '/api/overhead-costs',
        data: {
          'cost_category_id': costCategoryId,
          'amount': amount,
          'date': date.toIso8601String().split('T').first,
          'month': month,
          'note': note,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<OverheadAllocationPreview>> preview({required String month, required AllocationBasis basis}) async {
    try {
      final response = await _apiClient.dio.post('/api/overhead-costs/allocate/preview', data: {'month': month, 'basis': basis.wire});
      return (response.data as List).map((e) => OverheadAllocationPreview.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<OverheadAllocationPreview>> apply({required String month, required AllocationBasis basis}) async {
    try {
      final response = await _apiClient.dio.post('/api/overhead-costs/allocate', data: {'month': month, 'basis': basis.wire});
      return (response.data as List)
          .map((e) => OverheadAllocationPreview(
                projectId: e['project_id'] as String,
                projectCode: '',
                revenueShare: (e['revenue_share'] as num).toDouble(),
                allocatedAmount: e['allocated_amount'] as int,
              ))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
