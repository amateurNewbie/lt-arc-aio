import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../../contracts/data/contract_repository.dart' show MilestoneStatus, milestoneStatusFromJson;

class Receivable {
  const Receivable({
    required this.milestoneId,
    required this.projectId,
    required this.milestoneName,
    required this.amount,
    required this.paidAmount,
    required this.remaining,
    required this.status,
    this.dueDate,
  });

  final String milestoneId;
  final String projectId;
  final String milestoneName;
  final int amount;
  final int paidAmount;
  final int remaining;
  final DateTime? dueDate;
  final MilestoneStatus status;

  factory Receivable.fromJson(Map<String, dynamic> json) => Receivable(
        milestoneId: json['milestone_id'] as String,
        projectId: json['project_id'] as String,
        milestoneName: json['milestone_name'] as String,
        amount: json['amount'] as int,
        paidAmount: json['paid_amount'] as int,
        remaining: json['remaining'] as int,
        dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null,
        status: milestoneStatusFromJson(json['status'] as String),
      );
}

enum PayableStatus { pending, overdue, settled }

const _payableStatusWire = {PayableStatus.pending: 'PENDING', PayableStatus.overdue: 'OVERDUE', PayableStatus.settled: 'SETTLED'};

extension PayableStatusWire on PayableStatus {
  String get label => switch (this) {
        PayableStatus.pending => 'Đúng hạn',
        PayableStatus.overdue => 'Quá hạn',
        PayableStatus.settled => 'Đã tất toán',
      };
}

PayableStatus payableStatusFromJson(String value) => _payableStatusWire.entries.firstWhere((e) => e.value == value).key;

class Payable {
  const Payable({
    required this.id,
    required this.projectId,
    required this.vendorName,
    required this.costCategoryId,
    required this.totalAmount,
    required this.paidAmount,
    required this.status,
    this.dueDate,
  });

  final String id;
  final String projectId;
  final String vendorName;
  final String costCategoryId;
  final int totalAmount;
  final int paidAmount;
  final DateTime? dueDate;
  final PayableStatus status;

  int get remaining => totalAmount - paidAmount;

  factory Payable.fromJson(Map<String, dynamic> json) => Payable(
        id: json['id'] as String,
        projectId: json['project_id'] as String,
        vendorName: json['vendor_name'] as String,
        costCategoryId: json['cost_category_id'] as String,
        totalAmount: json['total_amount'] as int,
        paidAmount: json['paid_amount'] as int,
        dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null,
        status: payableStatusFromJson(json['status'] as String),
      );
}

class DebtRepository {
  DebtRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Receivable>> listReceivables() async {
    try {
      final response = await _apiClient.dio.get('/api/receivables');
      return (response.data as List).map((e) => Receivable.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<Payable>> listPayables() async {
    try {
      final response = await _apiClient.dio.get('/api/payables');
      return (response.data as List).map((e) => Payable.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Payable> createPayable({
    required String projectId,
    required String vendorName,
    required String costCategoryId,
    required int totalAmount,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/payables',
        data: {'project_id': projectId, 'vendor_name': vendorName, 'cost_category_id': costCategoryId, 'total_amount': totalAmount},
      );
      return Payable.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Payable> settlePayable({required String payableId, required int amount, required String fundAccountId}) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/payables/$payableId/settle',
        data: {'amount': amount, 'fund_account_id': fundAccountId},
      );
      return Payable.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
