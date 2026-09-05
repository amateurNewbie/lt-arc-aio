import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/network/api_client.dart';

enum PayrollStatus { unpaid, paid }

PayrollStatus _payrollStatusFromJson(String value) => value == 'PAID' ? PayrollStatus.paid : PayrollStatus.unpaid;

extension PayrollStatusLabel on PayrollStatus {
  String get label => this == PayrollStatus.paid ? 'Đã trả' : 'Chưa trả';
}

class PayrollRecord {
  const PayrollRecord({
    required this.id,
    required this.employeeId,
    required this.month,
    required this.dailyRate,
    required this.actualDays,
    required this.dayWage,
    required this.allowances,
    required this.netPay,
    required this.status,
  });

  final String id;
  final String employeeId;
  final String month;
  final int dailyRate;
  final double actualDays;
  final int dayWage;
  final List<Map<String, dynamic>> allowances;
  final int netPay;
  final PayrollStatus status;

  /// Tổng phụ cấp = Thực lãnh − Lương theo công (đúng công thức FR-16.1).
  int get allowanceTotal => netPay - dayWage;

  factory PayrollRecord.fromJson(Map<String, dynamic> json) => PayrollRecord(
        id: json['id'] as String,
        employeeId: json['employee_id'] as String,
        month: json['month'] as String,
        dailyRate: json['daily_rate'] as int,
        actualDays: (json['actual_days'] as num).toDouble(),
        dayWage: json['day_wage'] as int,
        allowances: (json['allowances'] as List).cast<Map<String, dynamic>>(),
        netPay: json['net_pay'] as int,
        status: _payrollStatusFromJson(json['status'] as String),
      );
}

/// Gọi `/api/payroll` — FR-16.
class PayrollRepository {
  PayrollRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<PayrollRecord>> listMonth(String month) async {
    try {
      final response = await _apiClient.dio.get('/api/payroll', queryParameters: {'month': month});
      return (response.data as List).map((e) => PayrollRecord.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<PayrollRecord>> run(String month) async {
    try {
      final response = await _apiClient.dio.post('/api/payroll/run', data: {'month': month});
      return (response.data as List).map((e) => PayrollRecord.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<PayrollRecord>> pay(String month, {required String fundAccountId}) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/payroll/pay',
        queryParameters: {'month': month},
        data: {'fund_account_id': fundAccountId},
      );
      return (response.data as List).map((e) => PayrollRecord.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
