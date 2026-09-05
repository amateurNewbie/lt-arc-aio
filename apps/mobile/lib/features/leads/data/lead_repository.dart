import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/network/api_client.dart';

enum LeadStatus { newLead, consulting, quoted, converted, rejected }

/// Ánh xạ 1-1 với `LeadStatus` (Python `StrEnum`) ở backend — SCREAMING_CASE.
const _leadStatusWire = {
  LeadStatus.newLead: 'NEW',
  LeadStatus.consulting: 'CONSULTING',
  LeadStatus.quoted: 'QUOTED',
  LeadStatus.converted: 'CONVERTED',
  LeadStatus.rejected: 'REJECTED',
};

extension LeadStatusWire on LeadStatus {
  String get wire => _leadStatusWire[this]!;

  String get label => switch (this) {
        LeadStatus.newLead => 'Mới',
        LeadStatus.consulting => 'Đang tư vấn',
        LeadStatus.quoted => 'Đã báo giá',
        LeadStatus.converted => 'Đã chốt',
        LeadStatus.rejected => 'Từ chối',
      };
}

LeadStatus leadStatusFromJson(String value) =>
    _leadStatusWire.entries.firstWhere((e) => e.value == value).key;

class Lead {
  const Lead({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.status,
    required this.createdAt,
    this.phone,
    this.email,
    this.need,
    this.budgetEstimate,
    this.source,
    this.note,
    this.convertedProjectId,
  });

  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? need;
  final int? budgetEstimate;
  final String? source;
  final String? note;
  final String ownerId;
  final LeadStatus status;
  final String? convertedProjectId;
  final DateTime createdAt;

  factory Lead.fromJson(Map<String, dynamic> json) => Lead(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        need: json['need'] as String?,
        budgetEstimate: json['budget_estimate'] as int?,
        source: json['source'] as String?,
        note: json['note'] as String?,
        ownerId: json['owner_id'] as String,
        status: leadStatusFromJson(json['status'] as String),
        convertedProjectId: json['converted_project_id'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class LeadRepository {
  LeadRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Lead>> list({LeadStatus? status, String? source, String? ownerId, String? search}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/leads',
        queryParameters: {
          if (status != null) 'status_filter': status.wire,
          if (source != null) 'source': source,
          if (ownerId != null) 'owner_id': ownerId,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );
      return (response.data as List).map((e) => Lead.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Lead> create({
    required String name,
    String? phone,
    String? email,
    String? need,
    int? budgetEstimate,
    String? source,
    String? note,
    String? ownerId,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/leads',
        data: {
          'name': name,
          'phone': phone,
          'email': email,
          'need': need,
          'budget_estimate': budgetEstimate,
          'source': source,
          'note': note,
          'owner_id': ownerId,
        },
      );
      return Lead.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Lead> updateStatus(String leadId, LeadStatus status) async {
    try {
      final response = await _apiClient.dio.patch('/api/leads/$leadId', data: {'status': status.wire});
      return Lead.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<String> convertToProject(
    String leadId, {
    required String category,
    required String managerId,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/leads/$leadId/convert',
        data: {'category': category, 'manager_id': managerId},
      );
      return (response.data['project'] as Map<String, dynamic>)['id'] as String;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
