import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/network/api_client.dart';

class CompanySettings {
  const CompanySettings({
    required this.id,
    required this.name,
    required this.owner,
    required this.phone,
    required this.email,
    required this.currency,
    required this.unit,
    required this.taskReminderDays,
    required this.debtReminderDays,
    required this.overheadReminderDay,
  });

  final String id;
  final String name;
  final String? owner;
  final String? phone;
  final String? email;
  final String currency;
  final String unit;
  final int taskReminderDays;
  final int debtReminderDays;
  final int overheadReminderDay;

  factory CompanySettings.fromJson(Map<String, dynamic> json) => CompanySettings(
        id: json['id'] as String,
        name: json['name'] as String,
        owner: json['owner'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        currency: json['currency'] as String,
        unit: json['unit'] as String,
        taskReminderDays: json['task_reminder_days'] as int,
        debtReminderDays: json['debt_reminder_days'] as int,
        overheadReminderDay: json['overhead_reminder_day'] as int,
      );
}

class SecurityStatusItem {
  const SecurityStatusItem({required this.name, required this.active});

  final String name;
  final bool active;

  factory SecurityStatusItem.fromJson(Map<String, dynamic> json) => SecurityStatusItem(name: json['name'] as String, active: json['active'] as bool);
}

/// Gọi `/api/settings` — FR-20.
class SettingsRepository {
  SettingsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<CompanySettings> get() async {
    try {
      final response = await _apiClient.dio.get('/api/settings');
      return CompanySettings.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<CompanySettings> update(Map<String, dynamic> updates) async {
    try {
      final response = await _apiClient.dio.patch('/api/settings', data: updates);
      return CompanySettings.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<SecurityStatusItem>> securityStatus() async {
    try {
      final response = await _apiClient.dio.get('/api/settings/security-status');
      return (response.data as List).map((e) => SecurityStatusItem.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// FR-1.6 — trả về access token chỉ đọc, mang vai trò xem thử.
  Future<String> previewRole(String role) async {
    try {
      final response = await _apiClient.dio.post('/api/auth/preview-role', data: {'role': role});
      return response.data['access_token'] as String;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
