import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/application/auth_provider.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/debts/presentation/debts_page.dart';
import '../features/contracts/presentation/contracts_page.dart';
import '../features/departments/presentation/departments_page.dart';
import '../features/finance/presentation/finance_page.dart';
import '../features/hr/presentation/hr_page.dart';
import '../features/leads/presentation/leads_page.dart';
import '../features/projects/application/project_provider.dart';
import '../features/projects/presentation/projects_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/tasks/presentation/tasks_page.dart';
import '../features/users/data/user_repository.dart';

/// Sidebar — đúng LT-ARC-Web-UI_1.html (SRS §2.7.1). Nhóm "Điều hành" (Phase 1)
/// + "Tài chính" (Phase 2); Tổ chức/Hệ thống thêm ở Phase 3+.
class WebShell extends ConsumerStatefulWidget {
  const WebShell({super.key});

  @override
  ConsumerState<WebShell> createState() => _WebShellState();
}

class _NavItem {
  const _NavItem(this.icon, this.label, this.page);
  final IconData icon;
  final String label;
  final Widget page;
}

class _WebShellState extends ConsumerState<WebShell> {
  int _index = 0;

  /// Index của mục "Dự án" trong `_allItems`.
  static const _projectsIndex = 1;

  static const _dieuHanh = [
    _NavItem(Icons.dashboard_outlined, 'Tổng quan', DashboardPage()),
    _NavItem(Icons.apartment_outlined, 'Dự án', ProjectsPage()),
    _NavItem(Icons.checklist_outlined, 'Công việc', TasksPage()),
    _NavItem(Icons.people_outline, 'Khách hàng', LeadsPage()),
  ];

  static const _taiChinhAll = [
    _NavItem(Icons.account_balance_outlined, 'Tài chính', FinancePage()),
    _NavItem(Icons.description_outlined, 'Hợp đồng', ContractsPage()),
    _NavItem(Icons.request_quote_outlined, 'Công nợ', DebtsPage()),
  ];

  static const _toChucAll = [
    _NavItem(Icons.apartment_outlined, 'Bộ phận', DepartmentsPage()),
    _NavItem(Icons.badge_outlined, 'Nhân sự & Lương', HrPage()),
  ];

  static const _heThong = [
    _NavItem(Icons.settings_outlined, 'Cài đặt', SettingsPage()),
  ];

  /// FR-1 — chỉ hiện mục sidebar mà role hiện tại thực sự gọi được API đứng
  /// sau nó; ẩn "Tài chính" (report P&L/cashflow: ADMIN/DIRECTOR) và "Công nợ"
  /// (ADMIN/DIRECTOR/DEPARTMENT_HEAD) cho Nhân viên. "Hợp đồng" mở cho mọi role
  /// (GET /api/contracts không giới hạn).
  static List<_NavItem> _taiChinhFor(String? role) => [
        if (role == 'ADMIN' || role == 'DIRECTOR') _taiChinhAll[0],
        _taiChinhAll[1],
        if (role == 'ADMIN' || role == 'DIRECTOR' || role == 'DEPARTMENT_HEAD') _taiChinhAll[2],
      ];

  /// "Bộ phận"/"Nhân sự & Lương" đều yêu cầu ADMIN/DIRECTOR/DEPARTMENT_HEAD ở
  /// backend — Nhân viên không thấy 2 mục này nữa.
  static List<_NavItem> _toChucFor(String? role) =>
      (role == 'ADMIN' || role == 'DIRECTOR' || role == 'DEPARTMENT_HEAD') ? _toChucAll : const [];

  void _select(int index) {
    if (index == _projectsIndex) {
      ref.read(projectPaneProvider.notifier).showList();
    }
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    final taiChinh = _taiChinhFor(user?.role);
    final toChuc = _toChucFor(user?.role);
    final allItems = [..._dieuHanh, ...taiChinh, ...toChuc, ..._heThong];
    if (_index >= allItems.length) _index = 0;

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
                if (taiChinh.isNotEmpty) ...[
                  _groupLabel('TÀI CHÍNH'),
                  for (var i = 0; i < taiChinh.length; i++) _item(_dieuHanh.length + i, taiChinh[i]),
                ],
                if (toChuc.isNotEmpty) ...[
                  _groupLabel('TỔ CHỨC'),
                  for (var i = 0; i < toChuc.length; i++) _item(_dieuHanh.length + taiChinh.length + i, toChuc[i]),
                ],
                _groupLabel('HỆ THỐNG'),
                for (var i = 0; i < _heThong.length; i++) _item(_dieuHanh.length + taiChinh.length + toChuc.length + i, _heThong[i]),
                const Spacer(),
                if (user != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      '${user.displayName}\n${user.role.roleLabel}',
                      style: TextStyle(color: AppColors.webSidebarText.withValues(alpha: 0.75), fontSize: 11, height: 1.35),
                    ),
                  ),
                _SidebarItem(
                  icon: Icons.logout,
                  label: 'Đăng xuất',
                  selected: false,
                  onTap: () => ref.read(authProvider.notifier).logout(),
                ),
              ],
            ),
          ),
          Expanded(child: IndexedStack(index: _index, children: [for (final item in allItems) item.page])),
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
        onTap: () => _select(index),
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
