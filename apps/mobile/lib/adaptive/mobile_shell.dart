import 'package:flutter/material.dart';

import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/leads/presentation/leads_page.dart';
import '../features/projects/presentation/projects_page.dart';
import '../features/tasks/presentation/tasks_page.dart';

/// Bottom nav 4 mục — đúng LT-ARC-Mobile-UI_1.html (SRS §2.7.1). Nút "+" nổi
/// giữa mở menu Tạo nhanh và Tài chính/module khác qua topbar là việc của
/// Phase 2+; Phase 1 chỉ có 4 tab chính.
class MobileShell extends StatefulWidget {
  const MobileShell({super.key});

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  int _index = 0;

  static const _pages = [
    DashboardPage(),
    ProjectsPage(),
    TasksPage(),
    LeadsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Tổng quan'),
          NavigationDestination(icon: Icon(Icons.apartment_outlined), label: 'Dự án'),
          NavigationDestination(icon: Icon(Icons.checklist_outlined), label: 'Công việc'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Khách hàng'),
        ],
      ),
    );
  }
}
