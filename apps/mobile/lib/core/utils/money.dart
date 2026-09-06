import 'package:intl/intl.dart';

/// Rút gọn số tiền kiểu HTML mock (680tr ₫ / 1.5 tỷ ₫).
String formatCompactVnd(int amount, {bool showSign = false}) {
  final sign = amount < 0 ? '-' : (showSign && amount > 0 ? '+' : '');
  final abs = amount.abs();
  if (abs >= 1000000000) {
    final ty = abs / 1000000000;
    final body = ty == ty.roundToDouble() ? '${ty.toInt()}' : ty.toStringAsFixed(1);
    return '$sign$body tỷ ₫';
  }
  if (abs >= 1000000) {
    final tr = abs / 1000000;
    final body = tr == tr.roundToDouble() ? '${tr.toInt()}' : tr.toStringAsFixed(0);
    return '$sign${body}tr ₫';
  }
  return '$sign${NumberFormat.decimalPattern('vi').format(abs)} ₫';
}
