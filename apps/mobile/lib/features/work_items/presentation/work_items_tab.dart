import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/web_badge.dart';
import '../../departments/application/department_provider.dart';
import '../../departments/data/department_repository.dart';
import '../application/work_item_provider.dart';
import '../data/work_item_repository.dart';
import 'work_item_form_sheet.dart';

WebBadgeVariant _statusVariant(WorkItemStatus s) => switch (s) {
      WorkItemStatus.done => WebBadgeVariant.secondary,
      WorkItemStatus.inProgress => WebBadgeVariant.warning,
      WorkItemStatus.notStarted => WebBadgeVariant.outline,
    };

/// FR-5.5 — "Hạng mục công việc": bóc tách khối lượng/đơn giá theo bộ phận,
/// bám `LT-ARC-Web-UI_1.html` mục "Khai báo hạng mục công việc".
class WorkItemsTab extends ConsumerWidget {
  const WorkItemsTab({super.key, required this.projectId});

  final String projectId;

  Future<void> _editProgress(BuildContext context, WidgetRef ref, WorkItem item) async {
    var progress = item.progress;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(item.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(value: progress.toDouble(), min: 0, max: 100, divisions: 20, label: '$progress%', onChanged: (v) => setState(() => progress = v.round())),
              Text('$progress%'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Huỷ')),
            FilledButton(
              onPressed: () async {
                await ref.read(workItemActionsProvider.notifier).updateProgress(projectId, item.id, progress);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Cập nhật'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(workItemListProvider(projectId));
    final departmentsAsync = ref.watch(departmentListProvider);
    final currency = NumberFormat.decimalPattern('vi');

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(color: AppColors.webCardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.webBorder)),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Khai báo hạng mục công việc', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('Bóc tách khối lượng, đơn giá và theo dõi tiến độ theo từng hạng mục của dự án.', style: TextStyle(fontSize: 12, color: AppColors.webMutedFg)),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(onPressed: () => showWorkItemFormSheet(context, projectId), icon: const Icon(Icons.add, size: 16), label: const Text('Thêm hạng mục')),
                ],
              ),
              const SizedBox(height: 16),
              itemsAsync.when(
                data: (items) {
                  if (items.isEmpty) return const Text('Chưa có hạng mục công việc nào');
                  final departmentsById = {for (final d in departmentsAsync.value ?? const <Department>[]) d.id: d};
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 32,
                      dataRowMinHeight: 40,
                      dataRowMaxHeight: 48,
                      columns: const [
                        DataColumn(label: Text('HẠNG MỤC', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('BỘ PHẬN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('KHỐI LƯỢNG', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('ĐƠN GIÁ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('THÀNH TIỀN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('TIẾN ĐỘ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('TRẠNG THÁI', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                      ],
                      rows: [
                        for (final item in items)
                          DataRow(
                            onSelectChanged: (_) => _editProgress(context, ref, item),
                            cells: [
                              DataCell(Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                              DataCell(Text(departmentsById[item.departmentId]?.name ?? '—', style: const TextStyle(fontSize: 13))),
                              DataCell(Text('${item.quantity} ${item.unit}', style: const TextStyle(fontSize: 13))),
                              DataCell(Text('${currency.format(item.unitPrice)} ₫', style: const TextStyle(fontSize: 13))),
                              DataCell(Text('${currency.format(item.amount)} ₫', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 60,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: LinearProgressIndicator(
                                          value: item.progress / 100,
                                          minHeight: 6,
                                          backgroundColor: AppColors.webMutedBg,
                                          color: item.progress == 100 ? AppColors.webSuccess : AppColors.gold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('${item.progress}%', style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                              DataCell(WebBadge(item.status.label, variant: _statusVariant(item.status))),
                            ],
                          ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Lỗi tải dữ liệu: $e'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
