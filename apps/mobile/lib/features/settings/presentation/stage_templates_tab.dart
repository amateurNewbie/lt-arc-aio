import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/web_badge.dart';
import '../application/stage_template_provider.dart';
import '../data/stage_template_repository.dart';

InputDecoration _fieldDecoration({String? label, String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.webBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.webBorder)),
    );

/// Cài đặt mẫu giai đoạn dự án — list / thêm / sửa tên / xoá hoặc ngừng dùng.
class StageTemplatesTab extends ConsumerStatefulWidget {
  const StageTemplatesTab({super.key});

  @override
  ConsumerState<StageTemplatesTab> createState() => _StageTemplatesTabState();
}

class _StageTemplatesTabState extends ConsumerState<StageTemplatesTab> {
  final _nameController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(stageTemplateActionsProvider.notifier).create(name: name);
      if (mounted) {
        _nameController.clear();
        showAppToast(context, 'Đã thêm giai đoạn');
      }
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editName(StageTemplate template) async {
    final controller = TextEditingController(text: template.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sửa tên giai đoạn'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: _fieldDecoration(label: 'Tên giai đoạn'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Huỷ')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty || result == template.name) return;
    try {
      await ref.read(stageTemplateActionsProvider.notifier).update(template.id, name: result);
      if (mounted) showAppToast(context, 'Đã cập nhật tên');
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message, error: true);
    }
  }

  Future<void> _confirmDelete(StageTemplate template) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá giai đoạn?'),
        content: Text('Xoá «${template.name}» khỏi danh sách mẫu?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Huỷ')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.webDestructive),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(stageTemplateActionsProvider.notifier).delete(template.id);
      if (mounted) showAppToast(context, 'Đã xoá giai đoạn');
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(stageTemplateListProvider());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Thêm giai đoạn dự án', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  decoration: _fieldDecoration(label: 'Tên giai đoạn', hint: 'VD: Thiết kế nội thất'),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(backgroundColor: AppColors.webForeground, foregroundColor: Colors.white),
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Thêm'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          templatesAsync.when(
            data: (templates) {
              if (templates.isEmpty) return const Text('Chưa có mẫu giai đoạn nào');
              return Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.webCardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.webBorder),
                ),
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 36,
                    dataRowMinHeight: 44,
                    dataRowMaxHeight: 56,
                    columns: const [
                      DataColumn(label: Text('TÊN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('KEY', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('THỨ TỰ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('TRẠNG THÁI', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('THAO TÁC', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                    ],
                    rows: [
                      for (final t in templates)
                        DataRow(
                          cells: [
                            DataCell(Text(t.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                            DataCell(Text(t.key, style: TextStyle(fontSize: 12, color: AppColors.webMutedFg))),
                            DataCell(Text('${t.sortOrder}', style: const TextStyle(fontSize: 13))),
                            DataCell(
                              WebBadge(
                                t.active ? 'Đang dùng' : 'Ngừng dùng',
                                variant: t.active ? WebBadgeVariant.secondary : WebBadgeVariant.muted,
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      minimumSize: Size.zero,
                                    ),
                                    onPressed: () => _editName(t),
                                    child: const Text('Sửa', style: TextStyle(fontSize: 12)),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      minimumSize: Size.zero,
                                    ),
                                    onPressed: () => ref.read(stageTemplateActionsProvider.notifier).update(t.id, active: !t.active),
                                    child: Text(t.active ? 'Ngừng dùng' : 'Dùng lại', style: const TextStyle(fontSize: 12)),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      minimumSize: Size.zero,
                                      foregroundColor: AppColors.webDestructive,
                                    ),
                                    onPressed: () => _confirmDelete(t),
                                    child: const Text('Xoá', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: SizedBox(height: 36, width: 36, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Text('Lỗi tải dữ liệu: $e'),
          ),
        ],
      ),
    );
  }
}
