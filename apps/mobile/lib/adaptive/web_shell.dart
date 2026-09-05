import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/debts/presentation/debts_page.dart';
import '../features/contracts/presentation/contracts_page.dart';
import '../features/departments/presentation/departments_page.dart';
import '../features/finance/presentation/finance_page.dart';
import '../features/hr/presentation/hr_page.dart';
import '../features/leads/presentation/leads_page.dart';
import '../features/projects/presentation/projects_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/tasks/presentation/tasks_page.dart';

/// Sidebar — đúng LT-ARC-Web-UI_1.html (SRS §2.7.1). Nhóm "Điều hành" (Phase 1)
/// + "Tài chính" (Phase 2); Tổ chức/Hệ thống thêm ở Phase 3+.
class WebShell extends StatefulWidget {
  const WebShell({super.key});

  @override
  State<WebShell> createState() => _WebShellState();
}

class _NavItem {
  const _NavItem(this.icon, this.label, this.page);
  final IconData icon;
  final String label;
  final Widget page;
}

class _WebShellState extends State<WebShell> {
  int _index = 0;

  static const _dieuHanh = [
    _NavItem(Icons.dashboard_outlined, 'Tổng quan', DashboardPage()),
    _NavItem(Icons.apartment_outlined, 'Dự án', ProjectsPage()),
    _NavItem(Icons.checklist_outlined, 'Công việc', TasksPage()),
    _NavItem(Icons.people_outline, 'Khách hàng', LeadsPage()),
  ];

  static const _taiChinh = [
    _NavItem(Icons.account_balance_outlined, 'Tài chính', FinancePage()),
    _NavItem(Icons.description_outlined, 'Hợp đồng', ContractsPage()),
    _NavItem(Icons.request_quote_outlined, 'Công nợ', DebtsPage()),
  ];

  static const _toChuc = [
    _NavItem(Icons.apartment_outlined, 'Bộ phận', DepartmentsPage()),
    _NavItem(Icons.badge_outlined, 'Nhân sự & Lương', HrPage()),
  ];

  static const _heThong = [
    _NavItem(Icons.settings_outlined, 'Cài đặt', SettingsPage()),
  ];

  static const _allItems = [..._dieuHanh, ..._taiChinh, ..._toChuc, ..._heThong];

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
                  child: Text('LT ARC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                ),
                _groupLabel('ĐIỀU HÀNH'),
                for (var i = 0; i < _dieuHanh.length; i++) _item(i, _dieuHanh[i]),
                _groupLabel('TÀI CHÍNH'),
                for (var i = 0; i < _taiChinh.length; i++) _item(_dieuHanh.length + i, _taiChinh[i]),
                _groupLabel('TỔ CHỨC'),
                for (var i = 0; i < _toChuc.length; i++) _item(_dieuHanh.length + _taiChinh.length + i, _toChuc[i]),
                _groupLabel('HỆ THỐNG'),
                for (var i = 0; i < _heThong.length; i++) _item(_dieuHanh.length + _taiChinh.length + _toChuc.length + i, _heThong[i]),
              ],
            ),
          ),
          Expanded(child: IndexedStack(index: _index, children: [for (final item in _allItems) item.page])),
        ],
      ),
    );
  }

  Widget _groupLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 2, top: 14, bottom: 5),
        child: Text(text, style: TextStyle(color: AppColors.webSidebarText.withValues(alpha: 0.6), fontSize: 10, letterSpacing: 1)),
      );

  Widget _item(int index, _NavItem item) => _SidebarItem(
        icon: item.icon,
        label: item.label,
        selected: _index == index,
        onTap: () => setState(() => _index = index),
      );
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
