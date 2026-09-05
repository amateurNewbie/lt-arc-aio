import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../projects/application/project_provider.dart';
import '../../users/application/user_provider.dart';
import '../../users/data/user_repository.dart';
import '../application/permission_grant_provider.dart';
import '../data/permission_grant_repository.dart';

/// FR-1.7/1.8 — cấp/thu hồi quyền bổ sung theo người dùng.
class GrantsTab extends ConsumerStatefulWidget {
  const GrantsTab({super.key});

  @override
  ConsumerState<GrantsTab> createState() => _GrantsTabState();
}

class _GrantsTabState extends ConsumerState<GrantsTab> {
  UserSummary? _selectedUser;

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(userListProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: usersAsync.when(
            data: (users) => DropdownButtonFormField<UserSummary>(
              initialValue: _selectedUser,
              decoration: const InputDecoration(labelText: 'Chọn người dùng'),
              items: users.map((u) => DropdownMenuItem(value: u, child: Text('${u.email} (${u.role.roleLabel})'))).toList(),
              onChanged: (v) => setState(() => _selectedUser = v),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Lỗi tải danh sách người dùng: $e'),
          ),
        ),
        if (_selectedUser != null) Expanded(child: _UserGrants(user: _selectedUser!)),
      ],
    );
  }
}

class _UserGrants extends ConsumerWidget {
  const _UserGrants({required this.user});

  final UserSummary user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grantsAsync = ref.watch(grantsForUserProvider(user.id));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddGrantSheet(context, ref, user.id),
        child: const Icon(Icons.add_moderator_outlined),
      ),
      body: grantsAsync.when(
        data: (grants) {
          final active = grants.where((g) => g.isActive).toList();
          if (active.isEmpty) return const Center(child: Text('Chưa có quyền bổ sung nào'));
          return ListView.separated(
            itemCount: active.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final grant = active[index];
              return ListTile(
                title: Text(grant.permissionGroup.permissionGroupLabel),
                subtitle: Text(
                  grant.scopeLabel + (grant.expiresAt != null ? ' · Hết hạn ${DateFormat('dd/MM/yyyy').format(grant.expiresAt!)}' : ''),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => ref.read(permissionGrantActionsProvider.notifier).revoke(user.id, grant.id),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi tải dữ liệu: $e')),
      ),
    );
  }

  Future<void> _showAddGrantSheet(BuildContext context, WidgetRef ref, String userId) {
    return showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => _AddGrantSheet(userId: userId));
  }
}

class _AddGrantSheet extends ConsumerStatefulWidget {
  const _AddGrantSheet({required this.userId});

  final String userId;

  @override
  ConsumerState<_AddGrantSheet> createState() => _AddGrantSheetState();
}

class _AddGrantSheetState extends ConsumerState<_AddGrantSheet> {
  String _group = permissionGroups.first;
  bool _allProjects = true;
  final Set<String> _selectedProjectIds = {};
  bool _saving = false;

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await ref.read(permissionGrantActionsProvider.notifier).create(
            widget.userId,
            permissionGroup: _group,
            projectIds: _allProjects ? null : _selectedProjectIds.toList(),
          );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectListProvider());

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cấp quyền bổ sung', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _group,
            decoration: const InputDecoration(labelText: 'Nhóm quyền'),
            items: permissionGroups.map((g) => DropdownMenuItem(value: g, child: Text(g.permissionGroupLabel))).toList(),
            onChanged: (v) => setState(() => _group = v!),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Áp dụng cho toàn bộ dự án'),
            value: _allProjects,
            onChanged: (v) => setState(() => _allProjects = v),
          ),
          if (!_allProjects)
            projectsAsync.when(
              data: (projects) => Wrap(
                spacing: 6,
                children: projects
                    .map((p) => FilterChip(
                          label: Text(p.code),
                          selected: _selectedProjectIds.contains(p.id),
                          onSelected: (sel) => setState(() => sel ? _selectedProjectIds.add(p.id) : _selectedProjectIds.remove(p.id)),
                        ))
                    .toList(),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Lỗi tải dự án: $e'),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Cấp quyền'),
          ),
        ],
      ),
    );
  }
}
