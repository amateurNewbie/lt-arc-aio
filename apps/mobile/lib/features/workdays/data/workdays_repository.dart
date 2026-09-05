import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/network/api_client.dart';

class MonthlyWorkDays {
  const MonthlyWorkDays({required this.id, required this.employeeId, required this.month, required this.actualDays, required this.lockedAt, required this.isOverDaysInMonth});

  final String id;
  final String employeeId;
  final String month;
  final double actualDays;
  final DateTime? lockedAt;
  final bool isOverDaysInMonth;

  factory MonthlyWorkDays.fromJson(Map<String, dynamic> json) => MonthlyWorkDays(
        id: json['id'] as String,
        employeeId: json['employee_id'] as String,
        month: json['month'] as String,
        actualDays: (json['actual_days'] as num).toDouble(),
        lockedAt: json['locked_at'] != null ? DateTime.parse(json['locked_at'] as String) : null,
        isOverDaysInMonth: json['is_over_days_in_month'] as bool? ?? false,
      );
}

/// Gọi `/api/workdays/{month}` — FR-15.
class WorkdaysRepository {
  WorkdaysRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<MonthlyWorkDays>> listMonth(String month) async {
    try {
      final response = await _apiClient.dio.get('/api/workdays/$month');
      return (response.data as List).map((e) => MonthlyWorkDays.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<MonthlyWorkDays>> upsert(String month, Map<String, double> entriesByEmployeeId) async {
    try {
      final response = await _apiClient.dio.put('/api/workdays/$month', data: {
        'entries': entriesByEmployeeId.entries.map((e) => {'employee_id': e.key, 'actual_days': e.value}).toList(),
      });
      return (response.data as List).map((e) => MonthlyWorkDays.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
