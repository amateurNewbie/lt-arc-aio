import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/web_badge.dart';
import '../../users/data/user_repository.dart';
import '../application/role_preview_provider.dart';

const _previewableRoles = ['DIRECTOR', 'DEPARTMENT_HEAD', 'EMPLOYEE'];

const _roleSummary = [
  (label: 'Admin', variant: WebBadgeVariant.primary, desc: 'Toàn quyền hệ thống, quản lý tài khoản và cấu hình chung.'),
  (label: 'Giám đốc', variant: WebBadgeVariant.secondary, desc: 'Toàn quyền nghiệp vụ: dự án, dự toán, hợp đồng, thu chi, công nợ, quỹ, bảng lương.'),
  (label: 'Trưởng bộ phận', variant: WebBadgeVariant.warning, desc: 'Giao việc, chia đầu việc, ghi nhận thu chi trong dự án phụ trách.'),
  (label: 'Nhân viên', variant: WebBadgeVariant.outline, desc: 'Xem việc được giao, cập nhật % tiến độ của bản thân.'),
];

/// FR-1.6 — xem thử giao diện/dữ liệu như vai trò khác, chỉ đọc.
class RolePreviewTab extends ConsumerStatefulWidget {
  const RolePreviewTab({super.key});

  @override
  ConsumerState<RolePreviewTab> createState() => _RolePreviewTabState();
}

class _RolePreviewTabState extends ConsumerState<RolePreviewTab> {
  String _role = _previewableRoles.first;
  bool _activating = false;

  Future<void> _activate() async {
    setState(() => _activating = true);
    try {
      await ref.read(rolePreviewProvider.notifier).activate(_role);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đang xem thử vai trò: ${_role.roleLabel}')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _activating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(rolePreviewProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Xem thử vai trò khác', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('Xem giao diện và dữ liệu như một vai trò khác — chỉ đọc, không thể lưu/sửa/xoá khi đang xem thử.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          if (preview != null)
            Card(
              color: Colors.amber.shade50,
              child: ListTile(
                leading: const Icon(Icons.visibility_outlined, color: Colors.orange),
                title: Text('Đang xem thử: ${preview.role.roleLabel}'),
                subtitle: const Text('Điều hướng cả ứng dụng để xem giao diện dưới vai trò này'),
                trailing: FilledButton.tonal(onPressed: () => ref.read(rolePreviewProvider.notifier).exit(), child: const Text('Thoát')),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _role,
                    decoration: const InputDecoration(labelText: 'Vai trò muốn xem thử'),
                    items: _previewableRoles.map((r) => DropdownMenuItem(value: r, child: Text(r.roleLabel))).toList(),
                    onChanged: (v) => setState(() => _role = v!),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _activating ? null : _activate,
                  child: _activating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Bắt đầu'),
                ),
              ],
            ),
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 12),
          const Text('Vai trò & phân quyền', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'Tóm tắt nhanh 4 cấp vai trò trong hệ thống — Trưởng bộ phận chỉ thấy dữ liệu tài chính của dự án mình phụ trách.',
            style: TextStyle(fontSize: 13, color: AppColors.webMutedFg),
          ),
          const SizedBox(height: 12),
          for (final r in _roleSummary)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 130, child: WebBadge(r.label, variant: r.variant)),
                  Expanded(child: Text(r.desc, style: const TextStyle(fontSize: 13))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
