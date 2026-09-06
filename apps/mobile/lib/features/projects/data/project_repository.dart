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

/// FR-3.4 — 5 giai đoạn tiến độ (khớp HTML + BRD).
const projectStageKeys = [
  'design',
  'permit',
  'rough_construction',
  'interior_finish',
  'handover',
];

const projectStageLabels = {
  'design': 'Thiết kế',
  'permit': 'Xin phép xây dựng',
  'rough_construction': 'Thi công phần thô',
  'interior_finish': 'Hoàn thiện nội thất',
  'handover': 'Nghiệm thu & bàn giao',
};

class ProjectStageProgress {
  const ProjectStageProgress({required this.progress, this.deadline});

  final int progress;
  final DateTime? deadline;

  Map<String, dynamic> toJson() => {
        'progress': progress,
        'deadline': deadline?.toIso8601String().split('T').first,
      };

  factory ProjectStageProgress.fromJson(dynamic raw) {
    if (raw is Map) {
      final map = raw.cast<String, dynamic>();
      final deadlineRaw = map['deadline'];
      return ProjectStageProgress(
        progress: (map['progress'] as num?)?.toInt() ?? 0,
        deadline: deadlineRaw is String && deadlineRaw.isNotEmpty ? DateTime.tryParse(deadlineRaw) : null,
      );
    }
    if (raw is num) return ProjectStageProgress(progress: raw.toInt());
    return const ProjectStageProgress(progress: 0);
  }
}

Map<String, ProjectStageProgress> defaultStageProgressMap() => {
      for (final key in projectStageKeys) key: const ProjectStageProgress(progress: 0),
    };

Map<String, ProjectStageProgress> stageProgressFromJson(Map<String, dynamic>? raw) {
  final result = defaultStageProgressMap();
  if (raw == null) return result;
  for (final key in projectStageKeys) {
    if (raw.containsKey(key)) result[key] = ProjectStageProgress.fromJson(raw[key]);
  }
  return result;
}

Map<String, dynamic> stageProgressToJson(Map<String, ProjectStageProgress> stages) => {
      for (final e in stages.entries) e.key: e.value.toJson(),
    };

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
    this.constructionHeadId,
    this.designHeadId,
    this.memberIds = const [],
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
  final String? constructionHeadId;
  final String? designHeadId;
  final List<String> memberIds;
  final Map<String, dynamic>? stageProgress;
  final String? leadId;
  final DateTime? startDate;
  final DateTime? dueDate;

  Map<String, ProjectStageProgress> get stages => stageProgressFromJson(stageProgress);

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'].toString(),
        code: json['code'] as String,
        name: json['name'] as String,
        client: json['client'] as String,
        category: projectCategoryFromJson(json['category'] as String),
        type: json['type'] as String?,
        area: (json['area'] as num?)?.toDouble(),
        budget: (json['budget'] as num?)?.toInt(),
        progress: (json['progress'] as num?)?.toInt() ?? 0,
        status: projectStatusFromJson(json['status'] as String),
        managerId: json['manager_id'].toString(),
        constructionHeadId: json['construction_head_id']?.toString(),
        designHeadId: json['design_head_id']?.toString(),
        memberIds: (json['member_ids'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        stageProgress: (json['stage_progress'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)),
        leadId: json['lead_id']?.toString(),
        startDate: json['start_date'] != null ? DateTime.tryParse(json['start_date'].toString()) : null,
        dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date'].toString()) : null,
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
      return (response.data as List)
          .map((e) => Project.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Project> getById(String id) async {
    try {
      final response = await _apiClient.dio.get('/api/projects/$id');
      return Project.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Project> create({
    required String name,
    required String client,
    required ProjectCategory category,
    required String managerId,
    String? constructionHeadId,
    String? designHeadId,
    List<String> memberIds = const [],
    String? leadId,
    String? type,
    double? area,
    int? budget,
    Map<String, ProjectStageProgress>? stageProgress,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/projects',
        data: {
          'name': name,
          'client': client,
          'category': category.wire,
          'manager_id': managerId,
          if (constructionHeadId != null) 'construction_head_id': constructionHeadId,
          if (designHeadId != null) 'design_head_id': designHeadId,
          'member_ids': memberIds,
          if (leadId != null) 'lead_id': leadId,
          if (type != null) 'type': type,
          if (area != null) 'area': area,
          if (budget != null) 'budget': budget,
          if (stageProgress != null) 'stage_progress': stageProgressToJson(stageProgress),
        },
      );
      return Project.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Project> update(
    String projectId, {
    String? name,
    String? client,
    ProjectCategory? category,
    String? managerId,
    String? constructionHeadId,
    String? designHeadId,
    List<String>? memberIds,
    String? leadId,
    String? type,
    double? area,
    int? budget,
    ProjectStatus? status,
    Map<String, ProjectStageProgress>? stageProgress,
    bool clearOptionalHeads = false,
  }) async {
    try {
      final response = await _apiClient.dio.patch(
        '/api/projects/$projectId',
        data: {
          if (name != null) 'name': name,
          if (client != null) 'client': client,
          if (category != null) 'category': category.wire,
          if (managerId != null) 'manager_id': managerId,
          if (clearOptionalHeads || constructionHeadId != null) 'construction_head_id': constructionHeadId,
          if (clearOptionalHeads || designHeadId != null) 'design_head_id': designHeadId,
          if (memberIds != null) 'member_ids': memberIds,
          if (clearOptionalHeads || leadId != null) 'lead_id': leadId,
          if (type != null) 'type': type,
          if (area != null) 'area': area,
          if (budget != null) 'budget': budget,
          if (status != null) 'status': status.wire,
          if (stageProgress != null) 'stage_progress': stageProgressToJson(stageProgress),
        },
      );
      return Project.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
