import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/web_badge.dart';
import '../application/cost_category_provider.dart';
import '../data/cost_category_repository.dart';

InputDecoration _fieldDecoration({String? hint}) => InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.webBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.webBorder)),
    );

/// FR-7 — Danh mục hạng mục chi phí, dùng chung cho Dự toán/Chi phí dự án/Chi
/// phí chung công ty. Bám `LT-ARC-Web-UI_1.html` mục "Danh mục hạng mục chi phí".
class CostCategoriesTab extends ConsumerStatefulWidget {
  const CostCategoriesTab({super.key});

  @override
  ConsumerState<CostCategoriesTab> createState() => _CostCategoriesTabState();
}

class _CostCategoriesTabState extends ConsumerState<CostCategoriesTab> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  CostCategoryScope _scope = CostCategoryScope.project;
  bool _saving = false;

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(costCategoryActionsProvider.notifier).create(
            name: name,
            scope: _scope,
            description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
          );
      if (mounted) {
        _nameController.clear();
        _descController.clear();
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(costCategoryListProvider());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Thêm danh mục hạng mục chi phí', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: TextField(controller: _nameController, decoration: _fieldDecoration(hint: 'VD: Vận chuyển'))),
              const SizedBox(width: 12),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<CostCategoryScope>(
                  initialValue: _scope,
                  decoration: _fieldDecoration(),
                  items: const [
                    DropdownMenuItem(value: CostCategoryScope.project, child: Text('Chi phí dự án', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: CostCategoryScope.company, child: Text('Chi phí chung công ty', style: TextStyle(fontSize: 13))),
                  ],
                  onChanged: (v) => setState(() => _scope = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _descController, decoration: _fieldDecoration(hint: 'VD: Chi phí vận chuyển vật tư, thiết bị'))),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: AppColors.webForeground, foregroundColor: Colors.white),
              child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Thêm danh mục'),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          categoriesAsync.when(
            data: (categories) {
              if (categories.isEmpty) return const Text('Chưa có danh mục nào');
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 32,
                  dataRowMinHeight: 40,
                  dataRowMaxHeight: 48,
                  columns: const [
                    DataColumn(label: Text('TÊN DANH MỤC', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('PHẠM VI', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('MÔ TẢ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('TRẠNG THÁI', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('THAO TÁC', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                  ],
                  rows: [
                    for (final c in categories)
                      DataRow(cells: [
                        DataCell(Text(c.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                        DataCell(WebBadge(c.scope == CostCategoryScope.project ? 'Dự án' : 'Công ty', variant: WebBadgeVariant.outline)),
                        DataCell(Text(c.description ?? '—', style: TextStyle(fontSize: 13, color: AppColors.webMutedFg))),
                        DataCell(WebBadge(c.active ? 'Đang dùng' : 'Ngừng dùng', variant: c.active ? WebBadgeVariant.secondary : WebBadgeVariant.muted)),
                        DataCell(TextButton(
                          onPressed: () => ref.read(costCategoryActionsProvider.notifier).setActive(c.id, !c.active),
                          child: Text(c.active ? 'Ngừng dùng' : 'Dùng lại', style: const TextStyle(fontSize: 12)),
                        )),
                      ]),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Lỗi tải dữ liệu: $e'),
          ),
        ],
      ),
    );
  }
}
