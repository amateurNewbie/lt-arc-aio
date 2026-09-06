import 'package:flutter/material.dart';

import '../../cost_categories/presentation/cost_categories_tab.dart';
import 'account_info_tab.dart';
import 'funds_settings_tab.dart';
import 'permissions_hub_tab.dart';
import 'role_preview_tab.dart';
import 'security_status_tab.dart';
import 'stage_templates_tab.dart';
import 'studio_info_tab.dart';
import 'users_tab.dart';

/// FR-20/1.3/1.6/1.7/7 — Cài đặt: Tài khoản | Người dùng | Thông tin chung | Bảo mật
/// | Phân quyền | Danh mục chi phí | Quỹ & tiền mặt | Giai đoạn dự án | Xem thử vai trò.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 9,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cài đặt'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Tài khoản'),
              Tab(text: 'Người dùng'),
              Tab(text: 'Thông tin chung'),
              Tab(text: 'Bảo mật'),
              Tab(text: 'Phân quyền'),
              Tab(text: 'Danh mục chi phí'),
              Tab(text: 'Quỹ & tiền mặt'),
              Tab(text: 'Giai đoạn dự án'),
              Tab(text: 'Xem thử vai trò'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AccountInfoTab(),
            UsersTab(),
            StudioInfoTab(),
            SecurityStatusTab(),
            PermissionsHubTab(),
            CostCategoriesTab(),
            FundsSettingsTab(),
            StageTemplatesTab(),
            RolePreviewTab(),
          ],
        ),
      ),
    );
  }
}
