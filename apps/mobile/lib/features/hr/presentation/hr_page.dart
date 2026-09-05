import 'package:flutter/material.dart';

import '../../employees/presentation/employees_tab.dart';
import '../../pay_profiles/presentation/pay_profiles_tab.dart';
import '../../payroll/presentation/payroll_tab.dart';
import '../../workdays/presentation/workdays_tab.dart';

/// FR-14/15/16 — Nhân sự & Lương: Nhân viên | Chức danh lương | Số công | Trả lương.
class HrPage extends StatelessWidget {
  const HrPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Nhân sự & Lương'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [Tab(text: 'Nhân viên'), Tab(text: 'Chức danh lương'), Tab(text: 'Số công'), Tab(text: 'Lương')],
          ),
        ),
        body: const TabBarView(
          children: [EmployeesTab(), PayProfilesTab(), WorkdaysTab(), PayrollTab()],
        ),
      ),
    );
  }
}
