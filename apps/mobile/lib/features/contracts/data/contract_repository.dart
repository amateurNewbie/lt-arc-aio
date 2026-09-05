import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../../projects/data/project_repository.dart' as project_data;

enum MilestoneStatus { pending, partiallyPaid, paid, overdue, retained }

const _milestoneStatusWire = {
  MilestoneStatus.pending: 'PENDING',
  MilestoneStatus.partiallyPaid: 'PARTIALLY_PAID',
  MilestoneStatus.paid: 'PAID',
  MilestoneStatus.overdue: 'OVERDUE',
  MilestoneStatus.retained: 'RETAINED',
};

extension MilestoneStatusWire on MilestoneStatus {
  String get label => switch (this) {
        MilestoneStatus.pending => 'Chờ thu',
        MilestoneStatus.partiallyPaid => 'Thu một phần',
        MilestoneStatus.paid => 'Đã thu đủ',
        MilestoneStatus.overdue => 'Quá hạn',
        MilestoneStatus.retained => 'Giữ bảo hành',
      };
}

MilestoneStatus milestoneStatusFromJson(String value) => _milestoneStatusWire.entries.firstWhere((e) => e.value == value).key;

enum ContractStatus { active, expiringSoon, liquidated, settled }

const _contractStatusWire = {
  ContractStatus.active: 'ACTIVE',
  ContractStatus.expiringSoon: 'EXPIRING_SOON',
  ContractStatus.liquidated: 'LIQUIDATED',
  ContractStatus.settled: 'SETTLED',
};

extension ContractStatusWire on ContractStatus {
  String get label => switch (this) {
        ContractStatus.active => 'Còn hiệu lực',
        ContractStatus.expiringSoon => 'Sắp hết hạn',
        ContractStatus.liquidated => 'Đã thanh lý',
        ContractStatus.settled => 'Đã tất toán',
      };
}

ContractStatus contractStatusFromJson(String value) => _contractStatusWire.entries.firstWhere((e) => e.value == value).key;

class ContractMilestone {
  const ContractMilestone({
    required this.id,
    required this.contractId,
    required this.name,
    required this.ratio,
    required this.amount,
    required this.paidAmount,
    required this.status,
    required this.isRetention,
    this.condition,
    this.dueDate,
  });

  final String id;
  final String contractId;
  final String name;
  final String? condition;
  final double ratio;
  final int amount;
  final int paidAmount;
  final DateTime? dueDate;
  final MilestoneStatus status;
  final bool isRetention;

  int get remaining => amount - paidAmount;

  factory ContractMilestone.fromJson(Map<String, dynamic> json) => ContractMilestone(
        id: json['id'] as String,
        contractId: json['contract_id'] as String,
        name: json['name'] as String,
        condition: json['condition'] as String?,
        ratio: (json['ratio'] as num).toDouble(),
        amount: json['amount'] as int,
        paidAmount: json['paid_amount'] as int,
        dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null,
        status: milestoneStatusFromJson(json['status'] as String),
        isRetention: json['is_retention'] as bool,
      );
}

class Contract {
  const Contract({
    required this.id,
    required this.projectId,
    required this.code,
    required this.type,
    required this.value,
    required this.status,
    required this.milestones,
    this.signedDate,
    this.dueDate,
  });

  final String id;
  final String projectId;
  final String code;
  final project_data.ProjectCategory type;
  final int value;
  final ContractStatus status;
  final DateTime? signedDate;
  final DateTime? dueDate;
  final List<ContractMilestone> milestones;

  int get paidAmount => milestones.fold(0, (s, m) => s + m.paidAmount);

  factory Contract.fromJson(Map<String, dynamic> json) => Contract(
        id: json['id'] as String,
        projectId: json['project_id'] as String,
        code: json['code'] as String,
        type: project_data.projectCategoryFromJson(json['type'] as String),
        value: json['value'] as int,
        status: contractStatusFromJson(json['status'] as String),
        signedDate: json['signed_date'] != null ? DateTime.parse(json['signed_date'] as String) : null,
        dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null,
        milestones: (json['milestones'] as List).map((e) => ContractMilestone.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class MilestoneInput {
  const MilestoneInput({required this.name, required this.ratio, this.isRetention = false});
  final String name;
  final double ratio;
  final bool isRetention;

  Map<String, dynamic> toJson() => {'name': name, 'ratio': ratio, 'is_retention': isRetention};
}

class ContractRepository {
  ContractRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Contract>> listByProject(String projectId) async {
    try {
      final response = await _apiClient.dio.get('/api/projects/$projectId/contracts');
      return (response.data as List).map((e) => Contract.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<Contract>> listAll() async {
    try {
      final response = await _apiClient.dio.get('/api/contracts');
      return (response.data as List).map((e) => Contract.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Contract> create({
    required String projectId,
    required project_data.ProjectCategory type,
    required int value,
    required List<MilestoneInput> milestones,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/projects/$projectId/contracts',
        data: {'type': type.wire, 'value': value, 'milestones': milestones.map((m) => m.toJson()).toList()},
      );
      return Contract.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> collectMilestone({
    required String contractId,
    required String milestoneId,
    required int amount,
    required String fundAccountId,
    DateTime? date,
  }) async {
    try {
      await _apiClient.dio.post(
        '/api/contracts/$contractId/milestones/$milestoneId/collect',
        data: {
          'amount': amount,
          'fund_account_id': fundAccountId,
          'date': date?.toIso8601String().split('T').first,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
