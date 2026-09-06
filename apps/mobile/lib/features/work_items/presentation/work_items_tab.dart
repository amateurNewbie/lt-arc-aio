import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_toast.dart';
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

/// FR-5.5 — tab Hạng mục công việc: bảng + popup thêm (bám HTML / Phase D).
class WorkItemsTab extends ConsumerWidget {
  const WorkItemsTab({super.key, required this.projectId});

  final String projectId;

  Future<void> _editProgress(BuildContext context, WidgetRef ref, WorkItem item) async {
    var progress = item.progress;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(item.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(value: progress.toDouble(), max: 100, divisions: 20, label: '$progress%', onChanged: (v) => setState(() => progress = v.round())),
              Text('$progress%'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Huỷ')),
            FilledButton(
              onPressed: () async {
                final close = PendingDialogClose.of(ctx);
                await ref.read(workItemActionsProvider.notifier).updateProgress(projectId, item.id, progress);
                close.success('Đã cập nhật tiến độ');
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  Text(
                    'Bóc tách khối lượng, đơn giá và theo dõi tiến độ theo từng hạng mục.',
                    style: TextStyle(fontSize: 12, color: AppColors.webMutedFg),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => showWorkItemDialog(context, projectId),
              style: FilledButton.styleFrom(backgroundColor: AppColors.webForeground, foregroundColor: Colors.white),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Thêm hạng mục'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: itemsAsync.when(
            data: (items) {
              if (items.isEmpty) return const Center(child: Text('Chưa có hạng mục công việc nào'));
              final departmentsById = {for (final d in departmentsAsync.value ?? const <Department>[]) d.id: d};
              final total = items.fold<int>(0, (s, i) => s + i.amount);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Tổng thành tiền: ${currency.format(total)} ₫', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 40,
                          dataRowMinHeight: 44,
                          dataRowMaxHeight: 52,
                          columns: const [
                            DataColumn(label: Text('Hạng mục')),
                            DataColumn(label: Text('Bộ phận')),
                            DataColumn(label: Text('Khối lượng')),
                            DataColumn(label: Text('Đơn giá'), numeric: true),
                            DataColumn(label: Text('Thành tiền'), numeric: true),
                            DataColumn(label: Text('Tiến độ')),
                            DataColumn(label: Text('Trạng thái')),
                          ],
                          rows: [
                            for (final item in items)
                              DataRow(
                                cells: [
                                  DataCell(
                                    InkWell(
                                      onTap: () => _editProgress(context, ref, item),
                                      child: Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                    ),
                                  ),
                                  DataCell(Text(departmentsById[item.departmentId]?.name ?? '—', style: const TextStyle(fontSize: 13))),
                                  DataCell(Text('${item.quantity} ${item.unit}', style: const TextStyle(fontSize: 13))),
                                  DataCell(Text('${currency.format(item.unitPrice)} ₫', style: const TextStyle(fontSize: 13))),
                                  DataCell(Text('${currency.format(item.amount)} ₫', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 70,
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
                                        const SizedBox(width: 6),
                                        Text('${item.progress}%', style: const TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  DataCell(WebBadge(item.status.label, variant: _statusVariant(item.status))),
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
            error: (e, _) => Center(child: Text('Lỗi tải dữ liệu: $e')),
          ),
        ),
      ],
    );
  }
}
