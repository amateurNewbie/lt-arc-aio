import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/download/file_downloader.dart';
import '../application/file_provider.dart';
import '../data/file_repository.dart';
import '../../../shared/widgets/app_toast.dart';

/// FR-17 — tệp đính kèm theo dự án (tải lên/xuống/xoá).
class FilesTab extends ConsumerWidget {
  const FilesTab({super.key, required this.projectId});

  final String projectId;

  Future<void> _upload(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final picked = result?.files.single;
    if (picked == null || picked.bytes == null) return;
    try {
      await ref.read(fileActionsProvider.notifier).upload(projectId, filename: picked.name, bytes: picked.bytes!);
    } on ApiException catch (e) {
      if (context.mounted) showAppToast(context, e.message, error: true);
    }
  }

  Future<void> _download(BuildContext context, WidgetRef ref, FileAsset file) async {
    try {
      final bytes = await ref.read(fileActionsProvider.notifier).download(file.id);
      await saveBytesToFile(fileName: file.name, bytes: bytes);
    } on ApiException catch (e) {
      if (context.mounted) showAppToast(context, e.message, error: true);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, FileAsset file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xoá tệp?'),
        content: Text('Xoá "${file.name}"? Không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Xoá')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(fileActionsProvider.notifier).delete(projectId, file.id);
    } on ApiException catch (e) {
      if (context.mounted) showAppToast(context, e.message, error: true);
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesAsync = ref.watch(projectFilesProvider(projectId));

    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: () => _upload(context, ref), child: const Icon(Icons.upload_file_outlined)),
      body: filesAsync.when(
        data: (files) {
          if (files.isEmpty) return const Center(child: Text('Chưa có tệp đính kèm nào'));
          return ListView.separated(
            itemCount: files.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final file = files[index];
              return ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: Text(file.name),
                subtitle: Text('${_formatSize(file.sizeBytes)} · ${DateFormat('dd/MM/yyyy HH:mm').format(file.createdAt.toLocal())}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.download_outlined), onPressed: () => _download(context, ref, file)),
                    IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(context, ref, file)),
                  ],
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
}
