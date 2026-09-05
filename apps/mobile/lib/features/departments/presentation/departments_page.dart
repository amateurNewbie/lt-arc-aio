import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/web_badge.dart';
import '../../employees/application/employee_provider.dart';
import '../../employees/data/employee_repository.dart';
import '../../users/application/user_provider.dart';
import '../../users/data/user_repository.dart';
import '../application/department_provider.dart';
import '../data/department_repository.dart';
import 'department_form_dialog.dart';

const _statusLabels = {'ACTIVE': 'Đang hoạt động', 'ON_LEAVE': 'Tạm nghỉ'};

/// Trang "Bộ phận" — bám `LT-ARC-Web-UI_1.html` (`data-if="isDepartments"`):
/// thẻ tổng quan mỗi bộ phận (số nhân viên/việc đang làm/tiến độ trung bình —
/// tính thật từ backend, không dùng số liệu tĩnh) + bảng Trưởng bộ phận.
class DepartmentsPage extends ConsumerWidget {
  const DepartmentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departmentsAsync = ref.watch(departmentListProvider);
    final usersAsync = ref.watch(userListProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1360),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bộ phận', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('Quản lý bộ phận, Trưởng bộ phận phụ trách và nhân sự.', style: TextStyle(fontSize: 13, color: AppColors.webMutedFg)),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => showDepartmentFormDialog(context),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.webForeground, foregroundColor: Colors.white),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Tạo bộ phận'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              departmentsAsync.when(
                data: (departments) {
                  final usersById = {for (final u in usersAsync.value ?? const <UserSummary>[]) u.id: u};
                  if (departments.isEmpty) return const Text('Chưa có bộ phận nào');

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          for (final d in departments)
                            SizedBox(
                              width: 420,
                              child: _DepartmentCard(department: d, headName: d.headUserId != null ? usersById[d.headUserId]?.displayName : null),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _HeadsTableCard(departments: departments, usersById: usersById),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Lỗi tải dữ liệu: $e'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({required this.department, required this.headName});

  final Department department;
  final String? headName;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.webCardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.webBorder)),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(department.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: AppColors.webSecondaryBg,
                child: Text(
                  headName != null && headName!.isNotEmpty ? headName!.trim().split(' ').last.substring(0, 1).toUpperCase() : '—',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.webSecondaryFg),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 13),
                    children: [
                      const TextSpan(text: 'Trưởng bộ phận: '),
                      TextSpan(text: headName ?? 'Chưa gán', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('${department.employeeCount} nhân viên', style: TextStyle(fontSize: 12, color: AppColors.webMutedFg)),
              const SizedBox(width: 16),
              Text('${department.activeTaskCount} việc đang làm', style: TextStyle(fontSize: 12, color: AppColors.webMutedFg)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: department.avgTaskProgress / 100, minHeight: 6, backgroundColor: AppColors.webMutedBg, color: AppColors.gold),
          ),
          const SizedBox(height: 6),
          Text('Tiến độ trung bình ${department.avgTaskProgress.toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, color: AppColors.webMutedFg)),
        ],
      ),
    );
  }
}

class _HeadsTableCard extends ConsumerWidget {
  const _HeadsTableCard({required this.departments, required this.usersById});

  final List<Department> departments;
  final Map<String, UserSummary> usersById;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeeListProvider);
    final statusByUserId = {for (final e in employeesAsync.value ?? const <Employee>[]) e.userId: e.status};
    final heads = departments.where((d) => d.headUserId != null && usersById.containsKey(d.headUserId)).toList();

    return Container(
      decoration: BoxDecoration(color: AppColors.webCardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.webBorder)),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nhân sự theo bộ phận', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (heads.isEmpty)
            const Text('Chưa có Trưởng bộ phận nào được gán')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 32,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 48,
                columns: const [
                  DataColumn(label: Text('TÊN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('VAI TRÒ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('BỘ PHẬN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('TRẠNG THÁI', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                ],
                rows: [
                  for (final d in heads)
                    DataRow(cells: [
                      DataCell(Text(usersById[d.headUserId]!.displayName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                      const DataCell(WebBadge('Trưởng bộ phận', variant: WebBadgeVariant.warning)),
                      DataCell(Text(d.name, style: const TextStyle(fontSize: 13))),
                      DataCell(WebBadge(_statusLabels[statusByUserId[d.headUserId]] ?? 'Đang hoạt động', variant: WebBadgeVariant.outline)),
                    ]),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
