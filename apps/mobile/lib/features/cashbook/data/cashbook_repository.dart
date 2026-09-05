import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/network/api_client.dart';

class ProjectCost {
  const ProjectCost({
    required this.id,
    required this.projectId,
    required this.costCategoryId,
    required this.amount,
    required this.date,
    this.note,
  });

  final String id;
  final String projectId;
  final String costCategoryId;
  final int amount;
  final DateTime date;
  final String? note;

  factory ProjectCost.fromJson(Map<String, dynamic> json) => ProjectCost(
        id: json['id'] as String,
        projectId: json['project_id'] as String,
        costCategoryId: json['cost_category_id'] as String,
        amount: json['amount'] as int,
        date: DateTime.parse(json['date'] as String),
        note: json['note'] as String?,
      );
}

class Payment {
  const Payment({required this.id, required this.projectId, required this.amount, required this.date});

  final String id;
  final String projectId;
  final int amount;
  final DateTime date;

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: json['id'] as String,
        projectId: json['project_id'] as String,
        amount: json['amount'] as int,
        date: DateTime.parse(json['date'] as String),
      );
}

/// Một dòng sổ Thu&Chi hợp nhất để hiển thị (FR-6.4) — gộp từ 2 nguồn dữ liệu
/// khác nhau ở backend (ProjectCost = Chi, Payment = Thu).
class CashbookEntry {
  const CashbookEntry({required this.id, required this.isInflow, required this.amount, required this.date, this.note});
  final String id;
  final bool isInflow;
  final int amount;
  final DateTime date;
  final String? note;
}

class DuplicateCostWarning {
  const DuplicateCostWarning({required this.existingCostId, required this.existingAmount, required this.existingDate});
  final String existingCostId;
  final int existingAmount;
  final DateTime existingDate;
}

class CashbookRepository {
  CashbookRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ProjectCost>> listCosts(String projectId) async {
    try {
      final response = await _apiClient.dio.get('/api/projects/$projectId/costs');
      return (response.data as List).map((e) => ProjectCost.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<Payment>> listPayments(String projectId) async {
    try {
      final response = await _apiClient.dio.get('/api/payments', queryParameters: {'project_id': projectId});
      return (response.data as List).map((e) => Payment.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Trả về [ProjectCost] khi lưu thành công, hoặc [DuplicateCostWarning] khi
  /// nghi trùng và caller cần hỏi lại người dùng trước khi gọi lại với
  /// `confirmDuplicate: true` (FR-6.6).
  Future<Object> createCost({
    required String projectId,
    required String costCategoryId,
    required int amount,
    required DateTime date,
    String? note,
    bool confirmDuplicate = false,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/projects/$projectId/costs',
        data: {
          'cost_category_id': costCategoryId,
          'amount': amount,
          'date': date.toIso8601String().split('T').first,
          'note': note,
          'confirm_duplicate': confirmDuplicate,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['duplicate_warning'] == true) {
        return DuplicateCostWarning(
          existingCostId: data['existing_cost_id'] as String,
          existingAmount: data['existing_amount'] as int,
          existingDate: DateTime.parse(data['existing_date'] as String),
        );
      }
      return ProjectCost.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
