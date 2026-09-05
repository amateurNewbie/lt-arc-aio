import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/network/api_client.dart';

class Allowance {
  const Allowance({required this.name, required this.amount, this.taxable = true, this.taxFreeCap});

  final String name;
  final int amount;
  final bool taxable;
  final int? taxFreeCap;

  factory Allowance.fromJson(Map<String, dynamic> json) => Allowance(
        name: json['name'] as String,
        amount: json['amount'] as int,
        taxable: json['taxable'] as bool? ?? true,
        taxFreeCap: json['tax_free_cap'] as int?,
      );

  Map<String, dynamic> toJson() => {'name': name, 'amount': amount, 'taxable': taxable, 'tax_free_cap': taxFreeCap};
}

class PayProfile {
  const PayProfile({required this.id, required this.roleTitle, required this.dailyRate, required this.allowances, required this.active});

  final String id;
  final String roleTitle;
  final int dailyRate;
  final List<Allowance> allowances;
  final bool active;

  factory PayProfile.fromJson(Map<String, dynamic> json) => PayProfile(
        id: json['id'] as String,
        roleTitle: json['role_title'] as String,
        dailyRate: json['daily_rate'] as int,
        allowances: (json['allowances'] as List).map((e) => Allowance.fromJson(e as Map<String, dynamic>)).toList(),
        active: json['active'] as bool,
      );
}

/// Gọi `/api/pay-profiles` — FR-16.5.
class PayProfileRepository {
  PayProfileRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<PayProfile>> list() async {
    try {
      final response = await _apiClient.dio.get('/api/pay-profiles');
      return (response.data as List).map((e) => PayProfile.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<PayProfile> create({required String roleTitle, required int dailyRate, required List<Allowance> allowances}) async {
    try {
      final response = await _apiClient.dio.post('/api/pay-profiles', data: {
        'role_title': roleTitle,
        'daily_rate': dailyRate,
        'allowances': allowances.map((a) => a.toJson()).toList(),
      });
      return PayProfile.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<PayProfile> update(String id, {int? dailyRate, List<Allowance>? allowances, bool? active}) async {
    try {
      final response = await _apiClient.dio.patch('/api/pay-profiles/$id', data: {
        if (dailyRate != null) 'daily_rate': dailyRate,
        if (allowances != null) 'allowances': allowances.map((a) => a.toJson()).toList(),
        if (active != null) 'active': active,
      });
      return PayProfile.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
