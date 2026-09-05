import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../projects/data/project_repository.dart';
import '../application/contract_provider.dart';
import '../data/contract_repository.dart';

Future<void> showContractFormSheet(BuildContext context, String projectId) {
  return showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => _ContractFormSheet(projectId: projectId));
}

class _DraftMilestone {
  _DraftMilestone({this.name = '', this.ratio = 0});
  String name;
  double ratio;
  bool isRetention = false;
}

class _ContractFormSheet extends ConsumerStatefulWidget {
  const _ContractFormSheet({required this.projectId});
  final String projectId;

  @override
  ConsumerState<_ContractFormSheet> createState() => _ContractFormSheetState();
}

class _ContractFormSheetState extends ConsumerState<_ContractFormSheet> {
  final _valueController = TextEditingController();
  ProjectCategory _type = ProjectCategory.construction;
  final List<_DraftMilestone> _milestones = [_DraftMilestone(name: 'Đợt 1', ratio: 50), _DraftMilestone(name: 'Đợt 2', ratio: 50)];
  bool _saving = false;

  double get _totalRatio => _milestones.fold(0, (sum, m) => sum + m.ratio);

  Future<void> _submit() async {
    final value = int.tryParse(_valueController.text) ?? 0;
    if (value <= 0 || (_totalRatio - 100).abs() > 0.01) return;

    setState(() => _saving = true);
    try {
      await ref.read(contractActionsProvider.notifier).create(
            projectId: widget.projectId,
            type: _type,
            value: value,
            milestones: _milestones.map((m) => MilestoneInput(name: m.name, ratio: m.ratio, isRetention: m.isRetention)).toList(),
          );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tạo hợp đồng', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            DropdownButtonFormField<ProjectCategory>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Loại hợp đồng'),
              items: [for (final c in ProjectCategory.values) DropdownMenuItem(value: c, child: Text(c.label))],
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _valueController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Giá trị hợp đồng (₫)'),
            ),
            const SizedBox(height: 12),
            Text('Đợt thanh toán (tổng phải = 100%, hiện tại ${_totalRatio.toStringAsFixed(0)}%)',
                style: Theme.of(context).textTheme.labelMedium),
            for (var i = 0; i < _milestones.length; i++) _milestoneRow(i),
            TextButton.icon(
              onPressed: () => setState(() => _milestones.add(_DraftMilestone(name: 'Đợt ${_milestones.length + 1}'))),
              icon: const Icon(Icons.add),
              label: const Text('Thêm đợt'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Tạo hợp đồng'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _milestoneRow(int index) {
    final m = _milestones[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: m.name,
              decoration: const InputDecoration(labelText: 'Tên đợt'),
              onChanged: (v) => m.name = v,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              initialValue: m.ratio == 0 ? '' : m.ratio.toStringAsFixed(0),
              decoration: const InputDecoration(labelText: '%'),
              keyboardType: TextInputType.number,
              onChanged: (v) => setState(() => m.ratio = double.tryParse(v) ?? 0),
            ),
          ),
          Checkbox(value: m.isRetention, onChanged: (v) => setState(() => m.isRetention = v ?? false)),
          const Text('BH', style: TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
