import 'package:flutter/material.dart';

import 'grants_tab.dart';
import 'role_defaults_tab.dart';

/// Phân quyền: (1) mặc định theo 4 role (2) bổ sung theo từng user — FR-1.7/1.8.
class PermissionsHubTab extends StatelessWidget {
  const PermissionsHubTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Theo vai trò'),
              Tab(text: 'Bổ sung theo user'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                RoleDefaultsTab(),
                GrantsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
