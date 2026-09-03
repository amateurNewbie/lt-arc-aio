import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/leads/presentation/leads_page.dart';
import '../features/projects/presentation/projects_page.dart';
import '../features/tasks/presentation/tasks_page.dart';

/// Sidebar — đúng LT-ARC-Web-UI_1.html (SRS §2.7.1). Phase 1 mới có nhóm
/// "Điều hành"; Tài chính/Tổ chức/Hệ thống thêm ở Phase 2+.
class WebShell extends StatefulWidget {
  const WebShell({super.key});

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  int _index = 0;

  static const _pages = [
    DashboardPage(),
    ProjectsPage(),
    TasksPage(),
    LeadsPage(),
  ];

  static const _navItems = [
    (icon: Icons.dashboard_outlined, label: 'Tổng quan'),
    (icon: Icons.apartment_outlined, label: 'Dự án'),
    (icon: Icons.checklist_outlined, label: 'Công việc'),
    (icon: Icons.people_outline, label: 'Khách hàng'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 240,
            color: AppColors.webSidebar,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Text(
                    'LT ARC',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ĐIỀU HÀNH',
                  style: TextStyle(color: AppColors.webSidebarText.withValues(alpha: 0.6), fontSize: 10, letterSpacing: 1),
                ),
                for (var i = 0; i < _navItems.length; i++)
                  _SidebarItem(
                    icon: _navItems[i].icon,
                    label: _navItems[i].label,
                    selected: _index == i,
                    onTap: () => setState(() => _index = i),
                  ),
              ],
            ),
          ),
          Expanded(child: IndexedStack(index: _index, children: _pages)),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.webSidebar.withValues(alpha: 0.6) : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: selected ? AppColors.gold : AppColors.webSidebarText),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.webSidebarText,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
