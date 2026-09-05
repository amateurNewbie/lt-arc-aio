import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/network/api_client.dart';

enum WorkItemStatus { notStarted, inProgress, done }

const _workItemStatusWire = {
  WorkItemStatus.notStarted: 'NOT_STARTED',
  WorkItemStatus.inProgress: 'IN_PROGRESS',
  WorkItemStatus.done: 'DONE',
};

extension WorkItemStatusWire on WorkItemStatus {
  String get wire => _workItemStatusWire[this]!;

  String get label => switch (this) {
        WorkItemStatus.notStarted => 'Chưa bắt đầu',
        WorkItemStatus.inProgress => 'Đang thi công',
        WorkItemStatus.done => 'Hoàn thành',
      };
}

WorkItemStatus workItemStatusFromJson(String value) => _workItemStatusWire.entries.firstWhere((e) => e.value == value).key;

class WorkItem {
  const WorkItem({
    required this.id,
    required this.projectId,
    required this.departmentId,
    required this.name,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
    required this.progress,
    required this.status,
  });

  final String id;
  final String projectId;
  final String departmentId;
  final String name;
  final String unit;
  final double quantity;
  final int unitPrice;
  final int amount;
  final int progress;
  final WorkItemStatus status;

  factory WorkItem.fromJson(Map<String, dynamic> json) => WorkItem(
        id: json['id'] as String,
        projectId: json['project_id'] as String,
        departmentId: json['department_id'] as String,
        name: json['name'] as String,
        unit: json['unit'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        unitPrice: json['unit_price'] as int,
        amount: json['amount'] as int,
        progress: json['progress'] as int,
        status: workItemStatusFromJson(json['status'] as String),
      );
}

/// Gọi `/api/projects/{project_id}/work-items` — FR-5.5.
class WorkItemRepository {
  WorkItemRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<WorkItem>> list(String projectId) async {
    try {
      final response = await _apiClient.dio.get('/api/projects/$projectId/work-items');
      return (response.data as List).map((e) => WorkItem.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<WorkItem> create({
    required String projectId,
    required String departmentId,
    required String name,
    required String unit,
    required double quantity,
    required int unitPrice,
  }) async {
    try {
      final response = await _apiClient.dio.post('/api/projects/$projectId/work-items', data: {
        'project_id': projectId,
        'department_id': departmentId,
        'name': name,
        'unit': unit,
        'quantity': quantity,
        'unit_price': unitPrice,
      });
      return WorkItem.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<WorkItem> updateProgress(String projectId, String workItemId, int progress) async {
    try {
      final response = await _apiClient.dio.patch('/api/projects/$projectId/work-items/$workItemId', data: {'progress': progress});
      return WorkItem.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
