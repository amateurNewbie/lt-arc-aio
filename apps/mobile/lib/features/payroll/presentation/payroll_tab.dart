import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/web_badge.dart';
import '../../departments/application/department_provider.dart';
import '../../departments/data/department_repository.dart';
import '../../employees/application/employee_provider.dart';
import '../../employees/data/employee_repository.dart';
import '../../users/application/user_provider.dart';
import '../../users/data/user_repository.dart';
import '../application/payroll_provider.dart';
import '../data/payroll_repository.dart';
import 'payroll_pay_dialog.dart';

String _monthKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// FR-16 — Bảng lương, bám `LT-ARC-Web-UI_1.html` mục "Bảng lương". Không có
/// BHXH/thuế TNCN/thưởng/tăng ca — SRS phase này chủ trương KHÔNG tính (FR-16.7
/// chỉ đặc tả, không triển khai), nên bảng chỉ hiện đúng công thức đang chạy:
/// Thực lãnh = Công thực tế × Đơn giá ngày + Phụ cấp.
class PayrollTab extends ConsumerStatefulWidget {
  const PayrollTab({super.key});

  @override
  ConsumerState<PayrollTab> createState() => _PayrollTabState();
}

class _PayrollTabState extends ConsumerState<PayrollTab> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _running = false;

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) setState(() => _selectedMonth = DateTime(picked.year, picked.month));
  }

  Future<void> _run() async {
    setState(() => _running = true);
    try {
      await ref.read(payrollActionsProvider.notifier).run(_monthKey(_selectedMonth));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final month = _monthKey(_selectedMonth);
    final recordsAsync = ref.watch(payrollMonthProvider(month));
    final employeesAsync = ref.watch(employeeListProvider);
    final usersAsync = ref.watch(userListProvider);
    final departmentsAsync = ref.watch(departmentListProvider);
    final currency = NumberFormat.decimalPattern('vi');

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: recordsAsync.when(
          data: (records) {
            final employeesById = {for (final e in employeesAsync.value ?? const <Employee>[]) e.id: e};
            final usersById = {for (final u in usersAsync.value ?? const <UserSummary>[]) u.id: u};
            final departmentsById = {for (final d in departmentsAsync.value ?? const <Department>[]) d.id: d};

            final totalFund = records.fold<int>(0, (s, r) => s + r.netPay);
            final paidCount = records.where((r) => r.status == PayrollStatus.paid).length;
            final unpaidCount = records.length - paidCount;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _StatCard(icon: Icons.account_balance_wallet_outlined, value: '${currency.format(totalFund)} ₫', label: 'Tổng quỹ lương tháng $month', color: AppColors.gold)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(icon: Icons.people_outline, value: '${records.length}', label: 'Nhân viên nhận lương', color: AppColors.gold)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(icon: Icons.check_circle_outline, value: '$paidCount', label: 'Đã thanh toán', color: AppColors.webSuccess)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(icon: Icons.hourglass_empty, value: '$unpaidCount', label: 'Chưa thanh toán', color: AppColors.webWarning)),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(color: AppColors.webCardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.webBorder)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Bảng lương', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tháng $month — Thực lãnh = Số công thực tế × Đơn giá lương ngày + Phụ cấp.',
                                    style: TextStyle(fontSize: 12, color: AppColors.webMutedFg),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(onPressed: _pickMonth, child: const Text('Đổi tháng')),
                            const SizedBox(width: 4),
                            OutlinedButton.icon(
                              onPressed: _running ? null : _run,
                              icon: _running ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.calculate_outlined, size: 16),
                              label: const Text('Tính lương tháng này'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: () => showPayrollPayDialog(context, month),
                              style: FilledButton.styleFrom(backgroundColor: AppColors.webForeground, foregroundColor: Colors.white),
                              icon: const Icon(Icons.payments_outlined, size: 16),
                              label: const Text('Trả lương'),
                            ),
                          ],
                        ),
                      ),
                      if (records.isEmpty)
                        const Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20), child: Text('Chưa có bản lương tháng này — nhập số công rồi bấm "Tính lương tháng này"'))
                      else
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowHeight: 32,
                              dataRowMinHeight: 40,
                              dataRowMaxHeight: 48,
                              columns: const [
                                DataColumn(label: Text('NHÂN VIÊN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                                DataColumn(label: Text('BỘ PHẬN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                                DataColumn(label: Text('ĐƠN GIÁ NGÀY', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                                DataColumn(label: Text('CÔNG THỰC TẾ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                                DataColumn(label: Text('PHỤ CẤP', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                                DataColumn(label: Text('THỰC LÃNH', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                                DataColumn(label: Text('TRẠNG THÁI', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                              ],
                              rows: [
                                for (final r in records)
                                  DataRow(cells: [
                                    DataCell(Text(usersById[employeesById[r.employeeId]?.userId]?.displayName ?? '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                    DataCell(Text(
                                      departmentsById[usersById[employeesById[r.employeeId]?.userId]?.departmentId]?.name ?? '—',
                                      style: const TextStyle(fontSize: 13),
                                    )),
                                    DataCell(Text('${currency.format(r.dailyRate)} ₫', style: const TextStyle(fontSize: 13))),
                                    DataCell(Text('${r.actualDays}', style: const TextStyle(fontSize: 13))),
                                    DataCell(Text('${currency.format(r.allowanceTotal)} ₫', style: const TextStyle(fontSize: 13))),
                                    DataCell(Text('${currency.format(r.netPay)} ₫', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                                    DataCell(WebBadge(r.status.label, variant: r.status == PayrollStatus.paid ? WebBadgeVariant.outline : WebBadgeVariant.warning)),
                                  ]),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Lỗi tải dữ liệu: $e'),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.value, required this.label, required this.color});

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.webCardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.webBorder)),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(4)),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(label.toUpperCase(), style: TextStyle(fontSize: 10, letterSpacing: 0.3, color: AppColors.webMutedFg)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
