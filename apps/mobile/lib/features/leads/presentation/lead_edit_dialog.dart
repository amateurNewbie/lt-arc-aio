import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../users/application/user_provider.dart';
import '../application/lead_provider.dart';
import '../data/lead_repository.dart';
import '../../../shared/widgets/app_toast.dart';

Future<void> showLeadEditDialog(BuildContext context, Lead lead) {
  return showDialog(context: context, builder: (_) => _LeadEditDialog(lead: lead));
}

class _LeadEditDialog extends ConsumerStatefulWidget {
  const _LeadEditDialog({required this.lead});

  final Lead lead;

  @override
  ConsumerState<_LeadEditDialog> createState() => _LeadEditDialogState();
}

class _LeadEditDialogState extends ConsumerState<_LeadEditDialog> {
  late final _nameController = TextEditingController(text: widget.lead.name);
  late final _phoneController = TextEditingController(text: widget.lead.phone ?? '');
  late final _emailController = TextEditingController(text: widget.lead.email ?? '');
  late final _needController = TextEditingController(text: widget.lead.need ?? '');
  late final _budgetController = TextEditingController(text: widget.lead.budgetEstimate?.toString() ?? '');
  late String? _source = widget.lead.source;
  late String? _ownerId = widget.lead.ownerId;
  /// Trạng thái hiển thị trên popup edit — cập nhật khi chuyển status, không đóng dialog.
  late LeadStatus _status = widget.lead.status;
  bool _savingInfo = false;
  bool _updatingStatus = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _needController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _saveInfo() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showAppToast(context, 'Vui lòng nhập họ tên khách hàng');
      return;
    }
    setState(() => _savingInfo = true);
    // Capture navigator trước await — invalidate list sau update có thể làm context lệch.
    final close = PendingDialogClose.of(context);
    try {
      await ref.read(leadRepositoryProvider).update(
            widget.lead.id,
            name: name,
            phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
            email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
            need: _needController.text.trim().isEmpty ? null : _needController.text.trim(),
            budgetEstimate: int.tryParse(_budgetController.text.trim().replaceAll('.', '')),
            source: _source,
            ownerId: _ownerId,
          );
      close.success('Đã cập nhật thông tin khách hàng tiềm năng');
      ref.invalidate(leadListProvider);
    } on ApiException catch (e) {
      if (mounted) {
        showAppToast(context, e.message, error: true);
        setState(() => _savingInfo = false);
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'Không lưu được: $e', error: true);
        setState(() => _savingInfo = false);
      }
    }
  }

  Future<void> _changeStatus(LeadStatus target) async {
    final note = await _showStatusNoteDialog(context, targetStatus: target);
    if (note == null || !mounted) return;

    final previous = _status;
    // Cập nhật stepper ngay — không chờ API / invalidate list.
    setState(() {
      _status = target;
      _updatingStatus = true;
    });

    try {
      await ref.read(leadRepositoryProvider).updateStatus(
            widget.lead.id,
            target,
            note: note.isEmpty ? null : note,
          );
      // Refresh list sau khi UI dialog đã cập nhật.
      ref.invalidate(leadListProvider);
      if (mounted) {
        showAppToast(context, 'Đã cập nhật trạng thái');
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _status = previous);
        showAppToast(context, e.message, error: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = previous);
        showAppToast(context, 'Không lưu được: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(userListProvider);

    return AlertDialog(
      title: const Text('Sửa khách hàng tiềm năng'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Họ tên khách hàng')),
              const SizedBox(height: 10),
              TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Số điện thoại')),
              const SizedBox(height: 10),
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 10),
              TextField(controller: _needController, decoration: const InputDecoration(labelText: 'Nhu cầu / Loại công trình')),
              const SizedBox(height: 10),
              TextField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Ngân sách dự kiến'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: TextEditingController(text: _source ?? ''),
                decoration: const InputDecoration(labelText: 'Nguồn'),
                onChanged: (v) => _source = v.isEmpty ? null : v,
              ),
              const SizedBox(height: 10),
              usersAsync.when(
                data: (users) => DropdownButtonFormField<String>(
                  initialValue: _ownerId,
                  decoration: const InputDecoration(labelText: 'Người phụ trách'),
                  items: users.map((u) => DropdownMenuItem(value: u.id, child: Text(u.displayName))).toList(),
                  onChanged: (v) => setState(() => _ownerId = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Lỗi tải danh sách: $e'),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 8),
              const Text('Trạng thái', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 10),
              _LeadStatusStepper(
                status: _status,
                updating: _updatingStatus,
                onRequestChange: _changeStatus,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Đóng')),
        FilledButton(
          onPressed: _savingInfo ? null : _saveInfo,
          child: _savingInfo
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Lưu thông tin'),
        ),
      ],
    );
  }
}

/// Hiển thị chuỗi bước tuần tự Mới → Đang tư vấn → Đã báo giá, rồi tới nhánh
/// rẽ Đã chốt/Từ chối — chỉ bước kế tiếp hợp lệ mới bấm chuyển được (FR-2.2).
class _LeadStatusStepper extends StatelessWidget {
  const _LeadStatusStepper({
    required this.status,
    required this.updating,
    required this.onRequestChange,
  });

  final LeadStatus status;
  final bool updating;
  final ValueChanged<LeadStatus> onRequestChange;

  static const _sequence = [LeadStatus.newLead, LeadStatus.consulting, LeadStatus.quoted];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _sequence.indexOf(status);
    final onLinearStep = currentIndex != -1;
    final nextStatuses = nextValidLeadStatuses(status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < _sequence.length; i++) ...[
              _StepChip(
                label: _sequence[i].label,
                state: !onLinearStep
                    ? _StepState.done
                    : i < currentIndex
                        ? _StepState.done
                        : i == currentIndex
                            ? _StepState.current
                            : _StepState.pending,
              ),
              if (i != _sequence.length - 1) const _StepConnector(),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const SizedBox(width: 4),
            const Icon(Icons.subdirectory_arrow_right, size: 16, color: Colors.black45),
            const SizedBox(width: 8),
            _StepChip(
              label: LeadStatus.converted.label,
              state: status == LeadStatus.converted
                  ? _StepState.current
                  : (status == LeadStatus.rejected ? _StepState.disabled : _StepState.pending),
            ),
            const SizedBox(width: 8),
            _StepChip(
              label: LeadStatus.rejected.label,
              state: status == LeadStatus.rejected
                  ? _StepState.current
                  : (status == LeadStatus.converted ? _StepState.disabled : _StepState.pending),
            ),
          ],
        ),
        if (nextStatuses.isNotEmpty) ...[
          const SizedBox(height: 16),
          if (updating)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          Wrap(
            spacing: 8,
            children: [
              for (final target in nextStatuses)
                OutlinedButton(
                  onPressed: updating ? null : () => onRequestChange(target),
                  child: Text('Chuyển sang: ${target.label}'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

enum _StepState { done, current, pending, disabled }

class _StepChip extends StatelessWidget {
  const _StepChip({required this.label, required this.state});

  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (state) {
      _StepState.done => (AppColors.webSuccess.withValues(alpha: 0.15), AppColors.webSuccess),
      _StepState.current => (AppColors.webForeground, Colors.white),
      _StepState.pending => (Colors.transparent, AppColors.webMutedFg),
      _StepState.disabled => (Colors.transparent, Colors.black26),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: state == _StepState.pending ? Border.all(color: AppColors.webBorder) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state == _StepState.done)
            const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.check, size: 12, color: AppColors.webSuccess)),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}

class _StepConnector extends StatelessWidget {
  const _StepConnector();

  @override
  Widget build(BuildContext context) {
    return Container(width: 20, height: 1.5, color: AppColors.webBorder, margin: const EdgeInsets.symmetric(horizontal: 4));
  }
}

/// Trả về nội dung ghi chú nếu xác nhận; `null` nếu huỷ.
/// (Chuỗi rỗng = xác nhận không ghi chú — khác `null`.)
Future<String?> _showStatusNoteDialog(
  BuildContext context, {
  required LeadStatus targetStatus,
}) {
  final noteController = TextEditingController();

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Chuyển trạng thái sang: ${targetStatus.label}'),
      content: SizedBox(
        width: 380,
        child: TextField(
          controller: noteController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Ghi chú',
            hintText: 'Nhập nội dung ghi chú cho lần chuyển trạng thái này...',
            alignLabelWithHint: true,
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Huỷ')),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(noteController.text.trim()),
          child: const Text('Xác nhận'),
        ),
      ],
    ),
  ).whenComplete(noteController.dispose);
}
