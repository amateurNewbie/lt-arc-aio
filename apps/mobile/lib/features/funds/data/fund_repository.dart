import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/network/api_client.dart';

enum FundType { cash, bank }

const _fundTypeWire = {FundType.cash: 'CASH', FundType.bank: 'BANK'};

extension FundTypeWire on FundType {
  String get wire => _fundTypeWire[this]!;
  String get label => this == FundType.cash ? 'Quỹ tiền mặt' : 'Tài khoản ngân hàng';
}

FundType fundTypeFromJson(String value) => _fundTypeWire.entries.firstWhere((e) => e.value == value).key;

class FundAccount {
  const FundAccount({required this.id, required this.name, required this.type, required this.balance});

  final String id;
  final String name;
  final FundType type;
  final int balance;

  factory FundAccount.fromJson(Map<String, dynamic> json) => FundAccount(
        id: json['id'] as String,
        name: json['name'] as String,
        type: fundTypeFromJson(json['type'] as String),
        balance: json['balance'] as int,
      );
}

class CashLedgerEntry {
  const CashLedgerEntry({
    required this.id,
    required this.date,
    required this.description,
    required this.inflow,
    required this.outflow,
    required this.sourceType,
  });

  final String id;
  final DateTime date;
  final String description;
  final int inflow;
  final int outflow;
  final String sourceType;

  factory CashLedgerEntry.fromJson(Map<String, dynamic> json) => CashLedgerEntry(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        description: json['description'] as String,
        inflow: json['inflow'] as int,
        outflow: json['outflow'] as int,
        sourceType: json['source_type'] as String,
      );
}

class FundRepository {
  FundRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<FundAccount>> list() async {
    try {
      final response = await _apiClient.dio.get('/api/funds');
      return (response.data as List).map((e) => FundAccount.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<FundAccount> create({required String name, required FundType type, int balance = 0}) async {
    try {
      final response = await _apiClient.dio.post('/api/funds', data: {'name': name, 'type': type.wire, 'balance': balance});
      return FundAccount.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<CashLedgerEntry>> ledger(String fundId) async {
    try {
      final response = await _apiClient.dio.get('/api/funds/$fundId/ledger');
      return (response.data as List).map((e) => CashLedgerEntry.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
