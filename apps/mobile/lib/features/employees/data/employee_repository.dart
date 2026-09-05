import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../../pay_profiles/data/pay_profile_repository.dart';

class Employee {
  const Employee({
    required this.id,
    required this.userId,
    required this.phone,
    required this.hireDate,
    required this.status,
    required this.payProfileId,
    this.dailyRateOverride,
    this.allowanceOverrides,
  });

  final String id;
  final String userId;
  final String? phone;
  final DateTime? hireDate;
  final String status;
  final String? payProfileId;
  final int? dailyRateOverride;
  final List<Allowance>? allowanceOverrides;

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        phone: json['phone'] as String?,
        hireDate: json['hire_date'] != null ? DateTime.parse(json['hire_date'] as String) : null,
        status: json['status'] as String,
        payProfileId: json['pay_profile_id'] as String?,
        dailyRateOverride: json['daily_rate_override'] as int?,
        allowanceOverrides:
            (json['allowance_overrides'] as List?)?.map((a) => Allowance.fromJson(a as Map<String, dynamic>)).toList(),
      );
}

/// Gọi `/api/employees` — FR-14.
class EmployeeRepository {
  EmployeeRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Employee>> list() async {
    try {
      final response = await _apiClient.dio.get('/api/employees');
      return (response.data as List).map((e) => Employee.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Employee> create({required String userId, String? phone, DateTime? hireDate, String? payProfileId}) async {
    try {
      final response = await _apiClient.dio.post('/api/employees', data: {
        'user_id': userId,
        'phone': phone,
        'hire_date': hireDate?.toIso8601String().substring(0, 10),
        'pay_profile_id': payProfileId,
      });
      return Employee.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Employee> updatePay(String employeeId, {String? payProfileId, int? dailyRateOverride, List<Allowance>? allowanceOverrides}) async {
    try {
      final response = await _apiClient.dio.patch('/api/employees/$employeeId/pay', data: {
        'pay_profile_id': payProfileId,
        'daily_rate_override': dailyRateOverride,
        'allowance_overrides': allowanceOverrides?.map((a) => a.toJson()).toList(),
      });
      return Employee.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
