import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../auth/application/auth_provider.dart';
import '../../users/data/user_repository.dart';
import '../application/role_permission_provider.dart';
import '../data/permission_grant_repository.dart';
import '../data/role_permission_repository.dart';

bool _canEditRolePermissions(String? role) => role == 'ADMIN' || role == 'DIRECTOR';

const _roles = ['ADMIN', 'DIRECTOR', 'DEPARTMENT_HEAD', 'EMPLOYEE'];

/// Ma trận quyền mặc định 4 role × 6 nhóm FR-1.7 — chỉ Admin/Giám đốc sửa.
class RoleDefaultsTab extends ConsumerStatefulWidget {
  const RoleDefaultsTab({super.key});

  @override
  ConsumerState<RoleDefaultsTab> createState() => _RoleDefaultsTabState();
}

class _RoleDefaultsTabState extends ConsumerState<RoleDefaultsTab> {
  Map<String, Map<String, bool>>? _draft;
  bool _saving = false;
  bool _dirty = false;

  Map<String, Map<String, bool>> _toMatrix(List<RolePermissionEntry> entries) {
    final matrix = {
      for (final role in _roles) role: {for (final g in permissionGroups) g: false},
    };
    for (final e in entries) {
      matrix[e.role]?[e.permissionGroup] = e.enabled;
    }
    return matrix;
  }

  List<RolePermissionEntry> _fromMatrix(Map<String, Map<String, bool>> matrix) {
    return [
      for (final role in _roles)
        for (final group in permissionGroups)
          RolePermissionEntry(
            role: role,
            permissionGroup: group,
            enabled: matrix[role]?[group] ?? false,
          ),
    ];
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(rolePermissionActionsProvider.notifier).save(_fromMatrix(draft));
      if (mounted) {
        setState(() {
          _dirty = false;
          _draft = null;
        });
        showAppToast(context, 'Đã lưu quyền mặc định theo vai trò');
      }
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authProvider).value;
    if (!_canEditRolePermissions(me?.role)) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Chỉ Quản trị và Giám đốc được chỉnh quyền mặc định theo vai trò.'),
        ),
      );
    }

    ref.listen(rolePermissionMatrixProvider, (previous, next) {
      next.whenData((entries) {
        if (!_dirty && mounted) {
          setState(() => _draft = _toMatrix(entries));
        }
      });
    });

    final matrixAsync = ref.watch(rolePermissionMatrixProvider);

    return matrixAsync.when(
      data: (entries) {
        _draft ??= _toMatrix(entries);
        final matrix = _draft!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Bật/tắt 6 nhóm quyền FR-1.7 theo từng vai trò. '
                      'Quyền bổ sung theo từng user nằm ở tab bên cạnh.',
                      style: TextStyle(fontSize: 13, color: AppColors.webMutedFg),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _saving || !_dirty ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Lưu'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(AppColors.webCardBg),
                    columns: [
                      const DataColumn(label: Text('Vai trò')),
                      ...permissionGroups.map(
                        (g) => DataColumn(
                          label: SizedBox(
                            width: 110,
                            child: Text(g.permissionGroupLabel, softWrap: true),
                          ),
                        ),
                      ),
                    ],
                    rows: [
                      for (final role in _roles)
                        DataRow(
                          cells: [
                            DataCell(Text(role.roleLabel, style: const TextStyle(fontWeight: FontWeight.w600))),
                            ...permissionGroups.map((group) {
                              final on = matrix[role]?[group] ?? false;
                              return DataCell(
                                Checkbox(
                                  value: on,
                                  onChanged: (v) {
                                    setState(() {
                                      matrix[role]![group] = v ?? false;
                                      _dirty = true;
                                    });
                                  },
                                ),
                              );
                            }),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi tải ma trận quyền: $e')),
    );
  }
}
