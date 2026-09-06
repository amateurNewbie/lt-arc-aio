import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/network/api_client.dart';

enum TaskStatus { todo, doing, done }

const _taskStatusWire = {
  TaskStatus.todo: 'TODO',
  TaskStatus.doing: 'DOING',
  TaskStatus.done: 'DONE',
};

extension TaskStatusWire on TaskStatus {
  String get wire => _taskStatusWire[this]!;

  String get label => switch (this) {
        TaskStatus.todo => 'Cần làm',
        TaskStatus.doing => 'Đang làm',
        TaskStatus.done => 'Đã hoàn thành',
      };
}

TaskStatus taskStatusFromJson(String value) => _taskStatusWire.entries.firstWhere((e) => e.value == value).key;

enum TaskPriority { low, medium, high }

const _taskPriorityWire = {
  TaskPriority.low: 'LOW',
  TaskPriority.medium: 'MEDIUM',
  TaskPriority.high: 'HIGH',
};

extension TaskPriorityWire on TaskPriority {
  String get wire => _taskPriorityWire[this]!;

  String get label => switch (this) {
        TaskPriority.low => 'Thấp',
        TaskPriority.medium => 'Trung bình',
        TaskPriority.high => 'Cao',
      };
}

TaskPriority taskPriorityFromJson(String value) => _taskPriorityWire.entries.firstWhere((e) => e.value == value).key;

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.projectId,
    required this.departmentId,
    required this.priority,
    required this.status,
    required this.progress,
    required this.isOverdue,
    this.description,
    this.parentTaskId,
    this.dueDate,
    this.assigneeId,
  });

  final String id;
  final String title;
  final String? description;
  final String projectId;
  final String departmentId;
  final String? parentTaskId;
  final DateTime? dueDate;
  final TaskPriority priority;
  final TaskStatus status;
  final int progress;
  final String? assigneeId;
  final bool isOverdue;

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        projectId: json['project_id'] as String,
        departmentId: json['department_id'] as String,
        parentTaskId: json['parent_task_id'] as String?,
        dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null,
        priority: taskPriorityFromJson(json['priority'] as String),
        status: taskStatusFromJson(json['status'] as String),
        progress: json['progress'] as int,
        assigneeId: json['assignee_id'] as String?,
        isOverdue: json['is_overdue'] as bool? ?? false,
      );
}

class TaskRepository {
  TaskRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Task>> list({String? projectId, String? departmentId, String? assigneeId}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/tasks',
        queryParameters: {
          'project_id': ?projectId,
          'department_id': ?departmentId,
          'assignee_id': ?assigneeId,
        },
      );
      return (response.data as List).map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Task> create({
    required String title,
    required String projectId,
    required String departmentId,
    String? parentTaskId,
    String? assigneeId,
    DateTime? dueDate,
    TaskPriority priority = TaskPriority.medium,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/tasks',
        data: {
          'title': title,
          'project_id': projectId,
          'department_id': departmentId,
          'parent_task_id': ?parentTaskId,
          'assignee_id': ?assigneeId,
          if (dueDate != null) 'due_date': dueDate.toIso8601String().split('T').first,
          'priority': priority.wire,
        },
      );
      return Task.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Task> updateProgress(String taskId, int progress) async {
    try {
      final response = await _apiClient.dio.patch('/api/tasks/$taskId', data: {'progress': progress});
      return Task.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
