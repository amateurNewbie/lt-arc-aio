import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../debts/presentation/debts_page.dart';
import '../../departments/presentation/departments_page.dart';
import '../../finance/presentation/finance_page.dart';
import '../../hr/presentation/hr_page.dart';
import '../../settings/presentation/settings_page.dart';

/// Menu module chưa có chỗ trên bottom nav (Tài chính, Công nợ...) — đúng
/// concept "topbar menu" của LT-ARC-Mobile-UI_1.html (SRS §2.7.1).
class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.account_balance_outlined),
            title: const Text('Tài chính'),
            subtitle: const Text('P&L, chi phí chung, quỹ & dòng tiền'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FinancePage())),
          ),
          ListTile(
            leading: const Icon(Icons.request_quote_outlined),
            title: const Text('Công nợ'),
            subtitle: const Text('Phải thu · Phải trả'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DebtsPage())),
          ),
          ListTile(
            leading: const Icon(Icons.apartment_outlined),
            title: const Text('Bộ phận'),
            subtitle: const Text('Danh sách bộ phận, Trưởng bộ phận phụ trách'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DepartmentsPage())),
          ),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Nhân sự & Lương'),
            subtitle: const Text('Nhân viên, chức danh lương, số công, trả lương'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HrPage())),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Cài đặt'),
            subtitle: const Text('Tài khoản, người dùng, phân quyền, xem thử vai trò'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Đăng xuất'),
            onTap: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}
