import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/network/api_client.dart';

enum ProjectCategory { design, construction, turnkey }

const _projectCategoryWire = {
  ProjectCategory.design: 'DESIGN',
  ProjectCategory.construction: 'CONSTRUCTION',
  ProjectCategory.turnkey: 'TURNKEY',
};

extension ProjectCategoryWire on ProjectCategory {
  String get wire => _projectCategoryWire[this]!;

  String get label => switch (this) {
        ProjectCategory.design => 'Thiết kế',
        ProjectCategory.construction => 'Thi công',
        ProjectCategory.turnkey => 'Trọn gói',
      };
}

ProjectCategory projectCategoryFromJson(String value) =>
    _projectCategoryWire.entries.firstWhere((e) => e.value == value).key;

enum ProjectStatus { planning, inProgress, awaitingFeedback, completed }

const _projectStatusWire = {
  ProjectStatus.planning: 'PLANNING',
  ProjectStatus.inProgress: 'IN_PROGRESS',
  ProjectStatus.awaitingFeedback: 'AWAITING_FEEDBACK',
  ProjectStatus.completed: 'COMPLETED',
};

extension ProjectStatusWire on ProjectStatus {
  String get wire => _projectStatusWire[this]!;

  String get label => switch (this) {
        ProjectStatus.planning => 'Lập kế hoạch',
        ProjectStatus.inProgress => 'Đang thực hiện',
        ProjectStatus.awaitingFeedback => 'Chờ phản hồi',
        ProjectStatus.completed => 'Hoàn thành',
      };
}

ProjectStatus projectStatusFromJson(String value) =>
    _projectStatusWire.entries.firstWhere((e) => e.value == value).key;

class Project {
  const Project({
    required this.id,
    required this.code,
    required this.name,
    required this.client,
    required this.category,
    required this.progress,
    required this.status,
    required this.managerId,
    this.type,
    this.area,
    this.budget,
    this.stageProgress,
    this.leadId,
    this.startDate,
    this.dueDate,
  });

  final String id;
  final String code;
  final String name;
  final String client;
  final ProjectCategory category;
  final String? type;
  final double? area;
  final int? budget;
  final int progress;
  final ProjectStatus status;
  final String managerId;
  final Map<String, dynamic>? stageProgress;
  final String? leadId;
  final DateTime? startDate;
  final DateTime? dueDate;

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
        client: json['client'] as String,
        category: projectCategoryFromJson(json['category'] as String),
        type: json['type'] as String?,
        area: (json['area'] as num?)?.toDouble(),
        budget: json['budget'] as int?,
        progress: json['progress'] as int,
        status: projectStatusFromJson(json['status'] as String),
        managerId: json['manager_id'] as String,
        stageProgress: (json['stage_progress'] as Map?)?.cast<String, dynamic>(),
        leadId: json['lead_id'] as String?,
        startDate: json['start_date'] != null ? DateTime.parse(json['start_date'] as String) : null,
        dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null,
      );
}

class ProjectRepository {
  ProjectRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Project>> list({ProjectStatus? status, ProjectCategory? category, String? search}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/projects',
        queryParameters: {
          if (status != null) 'status_filter': status.wire,
          if (category != null) 'category': category.wire,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );
      return (response.data as List).map((e) => Project.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Project> getById(String id) async {
    try {
      final response = await _apiClient.dio.get('/api/projects/$id');
      return Project.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Project> create({
    required String name,
    required String client,
    required ProjectCategory category,
    required String managerId,
    String? type,
    double? area,
    int? budget,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/projects',
        data: {
          'name': name,
          'client': client,
          'category': category.wire,
          'manager_id': managerId,
          'type': type,
          'area': area,
          'budget': budget,
        },
      );
      return Project.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
