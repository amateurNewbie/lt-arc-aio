import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_toast.dart';
import '../application/task_provider.dart';
import '../data/task_repository.dart';

/// Dialog cập nhật tiến độ dành cho nhân viên (assignee).
Future<void> showTaskProgressDialog(BuildContext context, WidgetRef ref, Task task) {
  return showDialog(
    context: context,
    builder: (_) => _TaskProgressDialog(task: task),
  );
}

class _TaskProgressDialog extends ConsumerStatefulWidget {
  const _TaskProgressDialog({required this.task});

  final Task task;

  @override
  ConsumerState<_TaskProgressDialog> createState() => _TaskProgressDialogState();
}

class _TaskProgressDialogState extends ConsumerState<_TaskProgressDialog> {
  late int _progress;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _progress = widget.task.progress;
  }

  String get _hint {
    if (_progress >= 100) return 'Sẽ chuyển sang nhóm Hoàn thành';
    if (_progress > 0) return 'Sẽ chuyển sang nhóm Đang làm';
    return 'Giữ ở nhóm Cần làm';
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final close = PendingDialogClose.of(context);
    try {
      await ref.read(taskActionsProvider.notifier).updateProgress(widget.task.id, _progress);
      close.success('Đã cập nhật tiến độ $_progress%');
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.task.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Cập nhật tiến độ hoàn thành', style: TextStyle(fontSize: 13, color: AppColors.webMutedFg)),
            const SizedBox(height: 16),
            Center(
              child: Text(
                '$_progress%',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
              ),
            ),
            Slider(
              value: _progress.toDouble(),
              max: 100,
              divisions: 20,
              label: '$_progress%',
              onChanged: (v) => setState(() => _progress = v.round()),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in const [0, 25, 50, 75, 100])
                  ChoiceChip(
                    label: Text('$p%'),
                    selected: _progress == p,
                    onSelected: (_) => setState(() => _progress = p),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.webMutedBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_hint, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Huỷ')),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Lưu tiến độ'),
        ),
      ],
    );
  }
}
