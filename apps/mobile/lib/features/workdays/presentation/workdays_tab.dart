import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../employees/application/employee_provider.dart';
import '../../users/application/user_provider.dart';
import '../application/workdays_provider.dart';
import '../../../shared/widgets/app_toast.dart';

String _monthKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// FR-15 — nhập/khoá số công theo tháng.
class WorkdaysTab extends ConsumerStatefulWidget {
  const WorkdaysTab({super.key});

  @override
  ConsumerState<WorkdaysTab> createState() => _WorkdaysTabState();
}

class _WorkdaysTabState extends ConsumerState<WorkdaysTab> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final Map<String, TextEditingController> _controllers = {};
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
        for (final c in _controllers.values) {
          c.dispose();
        }
        _controllers.clear();
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final entries = {
        for (final entry in _controllers.entries)
          if (double.tryParse(entry.value.text.trim()) != null) entry.key: double.parse(entry.value.text.trim()),
      };
      await ref.read(workdaysActionsProvider.notifier).save(_monthKey(_selectedMonth), entries);
      if (mounted) showAppToast(context, 'Đã lưu số công');
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final month = _monthKey(_selectedMonth);
    final employeesAsync = ref.watch(employeeListProvider);
    final usersAsync = ref.watch(userListProvider);
    final workdaysAsync = ref.watch(workdaysMonthProvider(month));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _saving ? null : _save,
        child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text('Tháng: $month', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 8),
                TextButton(onPressed: _pickMonth, child: const Text('Đổi tháng')),
              ],
            ),
          ),
          Expanded(
            child: employeesAsync.when(
              data: (employees) {
                final usersById = {for (final u in usersAsync.value ?? []) u.id: u};
                final workdaysByEmployee = {for (final w in workdaysAsync.value ?? []) w.employeeId: w};

                if (employees.isEmpty) return const Center(child: Text('Chưa có nhân viên nào'));

                return ListView.separated(
                  itemCount: employees.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final employee = employees[index];
                    final existing = workdaysByEmployee[employee.id];
                    final locked = existing?.lockedAt != null;
                    final controller = _controllers.putIfAbsent(
                      employee.id,
                      () => TextEditingController(text: existing?.actualDays.toString() ?? ''),
                    );

                    return ListTile(
                      title: Text(usersById[employee.userId]?.email ?? employee.userId),
                      subtitle: locked ? const Text('Đã khoá — lương tháng này đã trả', style: TextStyle(color: Colors.orange)) : null,
                      trailing: SizedBox(
                        width: 80,
                        child: TextField(
                          controller: controller,
                          enabled: !locked,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(suffixText: 'công', isDense: true),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Lỗi tải dữ liệu: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
