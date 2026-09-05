import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/web_badge.dart';
import '../../departments/application/department_provider.dart';
import '../../departments/data/department_repository.dart';
import '../../users/application/user_provider.dart';
import '../../users/data/user_repository.dart';
import '../application/employee_provider.dart';
import 'employee_create_sheet.dart';
import 'employee_pay_sheet.dart';

const _statusLabels = {'ACTIVE': 'Đang hoạt động', 'ON_LEAVE': 'Tạm nghỉ'};

/// FR-14 — Danh sách nhân sự, bám `LT-ARC-Web-UI_1.html` mục "Danh sách nhân sự".
class EmployeesTab extends ConsumerWidget {
  const EmployeesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeeListProvider);
    final usersAsync = ref.watch(userListProvider);
    final departmentsAsync = ref.watch(departmentListProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => showEmployeeCreateSheet(context, existing: employeesAsync.value ?? []),
        child: const Icon(Icons.person_add_alt),
      ),
      body: employeesAsync.when(
        data: (employees) {
          if (employees.isEmpty) return const Center(child: Text('Chưa có hồ sơ nhân sự nào'));
          final usersById = {for (final u in usersAsync.value ?? const <UserSummary>[]) u.id: u};
          final departmentsById = {for (final d in departmentsAsync.value ?? const <Department>[]) d.id: d};

          final active = employees.where((e) => e.status == 'ACTIVE').length;
          final onLeave = employees.length - active;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _StatCard(icon: Icons.badge_outlined, value: '${employees.length}', label: 'Tổng nhân viên', color: AppColors.gold)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(icon: Icons.check_circle_outline, value: '$active', label: 'Đang hoạt động', color: AppColors.webSuccess)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(icon: Icons.pause_circle_outline, value: '$onLeave', label: 'Tạm nghỉ', color: AppColors.webMutedFg)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(icon: Icons.apartment_outlined, value: '${departmentsById.length}', label: 'Bộ phận', color: AppColors.webWarning)),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(color: AppColors.webCardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.webBorder)),
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 32,
                      dataRowMinHeight: 40,
                      dataRowMaxHeight: 48,
                      columns: const [
                        DataColumn(label: Text('TÊN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('EMAIL', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('SĐT', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('VAI TRÒ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('BỘ PHẬN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('NGÀY VÀO LÀM', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('TRẠNG THÁI', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                      ],
                      rows: [
                        for (final e in employees)
                          DataRow(
                            onSelectChanged: (_) => showEmployeePaySheet(context, e),
                            cells: [
                              DataCell(Text(usersById[e.userId]?.displayName ?? '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                              DataCell(Text(usersById[e.userId]?.email ?? '—', style: TextStyle(fontSize: 13, color: AppColors.webMutedFg))),
                              DataCell(Text(e.phone ?? '—', style: const TextStyle(fontSize: 13))),
                              DataCell(WebBadge((usersById[e.userId]?.role ?? '').roleLabel, variant: WebBadgeVariant.outline)),
                              DataCell(Text(usersById[e.userId]?.departmentId != null ? (departmentsById[usersById[e.userId]!.departmentId]?.name ?? '—') : '—', style: const TextStyle(fontSize: 13))),
                              DataCell(Text(e.hireDate != null ? DateFormat('dd/MM/yyyy').format(e.hireDate!) : '—', style: const TextStyle(fontSize: 13))),
                              DataCell(WebBadge(_statusLabels[e.status] ?? e.status, variant: e.status == 'ACTIVE' ? WebBadgeVariant.outline : WebBadgeVariant.muted)),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi tải dữ liệu: $e')),
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
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(label.toUpperCase(), style: TextStyle(fontSize: 10.5, letterSpacing: 0.5, color: AppColors.webMutedFg)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
