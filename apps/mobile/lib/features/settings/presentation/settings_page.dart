import 'package:flutter/material.dart';

import '../../cost_categories/presentation/cost_categories_tab.dart';
import 'account_info_tab.dart';
import 'grants_tab.dart';
import 'role_preview_tab.dart';
import 'security_status_tab.dart';
import 'studio_info_tab.dart';

/// FR-20/1.6/1.7/7 — Cài đặt: Tài khoản | Thông tin chung | Bảo mật | Phân quyền
/// | Danh mục chi phí | Xem thử vai trò — đúng `LT-ARC-Web-UI_1.html` mục Thiết lập.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cài đặt'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Tài khoản'),
              Tab(text: 'Thông tin chung'),
              Tab(text: 'Bảo mật'),
              Tab(text: 'Phân quyền'),
              Tab(text: 'Danh mục chi phí'),
              Tab(text: 'Xem thử vai trò'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [AccountInfoTab(), StudioInfoTab(), SecurityStatusTab(), GrantsTab(), CostCategoriesTab(), RolePreviewTab()],
        ),
      ),
    );
  }
}
