import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../application/settings_provider.dart';
import '../data/settings_repository.dart';

/// FR-20.1/20.2 — thông tin chung studio + cấu hình số ngày nhắc (FR-19.2/FR-8.4).
class StudioInfoTab extends ConsumerStatefulWidget {
  const StudioInfoTab({super.key});

  @override
  ConsumerState<StudioInfoTab> createState() => _StudioInfoTabState();
}

class _StudioInfoTabState extends ConsumerState<StudioInfoTab> {
  CompanySettings? _loaded;
  late final _nameController = TextEditingController();
  late final _ownerController = TextEditingController();
  late final _phoneController = TextEditingController();
  late final _emailController = TextEditingController();
  late final _taskReminderController = TextEditingController();
  late final _debtReminderController = TextEditingController();
  late final _overheadReminderController = TextEditingController();
  bool _saving = false;

  void _populate(CompanySettings s) {
    if (_loaded?.id == s.id) return;
    _loaded = s;
    _nameController.text = s.name;
    _ownerController.text = s.owner ?? '';
    _phoneController.text = s.phone ?? '';
    _emailController.text = s.email ?? '';
    _taskReminderController.text = '${s.taskReminderDays}';
    _debtReminderController.text = '${s.debtReminderDays}';
    _overheadReminderController.text = '${s.overheadReminderDay}';
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await ref.read(settingsActionsProvider.notifier).update({
        'name': _nameController.text.trim(),
        'owner': _ownerController.text.trim().isEmpty ? null : _ownerController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        'task_reminder_days': int.tryParse(_taskReminderController.text.trim()),
        'debt_reminder_days': int.tryParse(_debtReminderController.text.trim()),
        'overhead_reminder_day': int.tryParse(_overheadReminderController.text.trim()),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(companySettingsProvider);

    return settingsAsync.when(
      data: (s) {
        _populate(s);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Thông tin studio', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Tên studio')),
              const SizedBox(height: 12),
              TextField(controller: _ownerController, decoration: const InputDecoration(labelText: 'Chủ sở hữu')),
              const SizedBox(height: 12),
              TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Số điện thoại')),
              const SizedBox(height: 12),
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 24),
              Text('Cấu hình nhắc việc', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: _taskReminderController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Nhắc công việc trước (ngày)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _debtReminderController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Nhắc công nợ sắp đến hạn trước (ngày)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _overheadReminderController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Nhắc phân bổ chi phí chung — ngày trong tháng'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Lưu'),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi tải dữ liệu: $e')),
    );
  }
}
