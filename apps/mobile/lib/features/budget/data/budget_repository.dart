import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/network/api_client.dart';

enum BudgetStatus { draft, pending, approved }

const _statusWire = {BudgetStatus.draft: 'DRAFT', BudgetStatus.pending: 'PENDING', BudgetStatus.approved: 'APPROVED'};

extension BudgetStatusWire on BudgetStatus {
  String get label => switch (this) {
        BudgetStatus.draft => 'Nháp',
        BudgetStatus.pending => 'Chờ duyệt',
        BudgetStatus.approved => 'Đã duyệt',
      };
}

BudgetStatus budgetStatusFromJson(String value) => _statusWire.entries.firstWhere((e) => e.value == value).key;

class BudgetLine {
  const BudgetLine({
    required this.id,
    required this.costCategoryId,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
    this.description,
  });

  final String id;
  final String costCategoryId;
  final String? description;
  final String unit;
  final double quantity;
  final int unitPrice;
  final int amount;

  factory BudgetLine.fromJson(Map<String, dynamic> json) => BudgetLine(
        id: json['id'] as String,
        costCategoryId: json['cost_category_id'] as String,
        description: json['description'] as String?,
        unit: json['unit'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        unitPrice: json['unit_price'] as int,
        amount: json['amount'] as int,
      );
}

class BudgetEstimate {
  const BudgetEstimate({
    required this.id,
    required this.projectId,
    required this.version,
    required this.status,
    required this.total,
    required this.lines,
    this.approvedById,
  });

  final String id;
  final String projectId;
  final int version;
  final BudgetStatus status;
  final String? approvedById;
  final int total;
  final List<BudgetLine> lines;

  factory BudgetEstimate.fromJson(Map<String, dynamic> json) => BudgetEstimate(
        id: json['id'] as String,
        projectId: json['project_id'] as String,
        version: json['version'] as int,
        status: budgetStatusFromJson(json['status'] as String),
        approvedById: json['approved_by_id'] as String?,
        total: json['total'] as int,
        lines: (json['lines'] as List).map((e) => BudgetLine.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class BudgetLineInput {
  const BudgetLineInput({required this.costCategoryId, required this.unit, required this.quantity, required this.unitPrice});

  final String costCategoryId;
  final String unit;
  final double quantity;
  final int unitPrice;

  Map<String, dynamic> toJson() => {
        'cost_category_id': costCategoryId,
        'unit': unit,
        'quantity': quantity,
        'unit_price': unitPrice,
      };
}

class BudgetRepository {
  BudgetRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<BudgetEstimate>> list(String projectId) async {
    try {
      final response = await _apiClient.dio.get('/api/projects/$projectId/budget');
      return (response.data as List).map((e) => BudgetEstimate.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<BudgetEstimate> create(String projectId, List<BudgetLineInput> lines) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/projects/$projectId/budget',
        data: {'lines': lines.map((l) => l.toJson()).toList()},
      );
      return BudgetEstimate.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<BudgetEstimate> submit(String projectId, String budgetId) async {
    try {
      final response = await _apiClient.dio.post('/api/projects/$projectId/budget/$budgetId/submit');
      return BudgetEstimate.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<BudgetEstimate> approve(String projectId, String budgetId) async {
    try {
      final response = await _apiClient.dio.post('/api/projects/$projectId/budget/$budgetId/approve');
      return BudgetEstimate.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
