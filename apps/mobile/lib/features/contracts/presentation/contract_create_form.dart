import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../auth/application/auth_provider.dart';
import '../../projects/application/project_provider.dart';
import '../../projects/data/project_repository.dart';
import '../application/contract_provider.dart';
import '../data/contract_repository.dart';

class _MilestoneDraft {
  _MilestoneDraft({
    this.name = '',
    this.condition = '',
    this.ratio = 0,
    this.dueDate,
    this.isRetention = false,
  });

  String name;
  String condition;
  double ratio;
  DateTime? dueDate;
  bool isRetention;

  _MilestoneDraft copy() => _MilestoneDraft(
        name: name,
        condition: condition,
        ratio: ratio,
        dueDate: dueDate,
        isRetention: isRetention,
      );
}

List<_MilestoneDraft> _designTemplate() => [
      _MilestoneDraft(name: 'Đợt 1', condition: 'Ngay sau khi ký hợp đồng', ratio: 50),
      _MilestoneDraft(name: 'Đợt 2', condition: 'Bàn giao hồ sơ thiết kế hoàn chỉnh', ratio: 50),
    ];

List<_MilestoneDraft> _buildTemplate() => [
      _MilestoneDraft(name: 'Đợt 1', condition: 'Tạm ứng khi ký hợp đồng', ratio: 30),
      _MilestoneDraft(name: 'Đợt 2', condition: 'Nghiệm thu xong phần móng & kết cấu thô', ratio: 32),
      _MilestoneDraft(name: 'Đợt 3', condition: 'Nghiệm thu xong phần hoàn thiện', ratio: 25),
      _MilestoneDraft(name: 'Đợt 4', condition: 'Nghiệm thu bàn giao đưa vào sử dụng', ratio: 8),
      _MilestoneDraft(
        name: 'Bảo hành',
        condition: 'Giữ lại, hoàn trả sau 12 tháng bảo hành',
        ratio: 5,
        isRetention: true,
      ),
    ];

List<_MilestoneDraft> _templateFor(ProjectCategory type) =>
    type == ProjectCategory.design ? _designTemplate() : _buildTemplate();

String _previewCode(Project project) => 'HD-${project.code.replaceFirst(RegExp(r'^LT-'), '')}';

InputDecoration _fieldDecoration({String? label, String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.webBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.webBorder)),
    );

/// Form khai báo HĐ mới — bám `LT-ARC-Web-UI_2.html` (#wcFormCard).
/// Chọn dự án → bind loại (category) + giá trị (budget), vẫn cho sửa.
class ContractCreateForm extends ConsumerStatefulWidget {
  const ContractCreateForm({
    super.key,
    this.fixedProjectId,
    this.onCancel,
    this.onCreated,
  });

  /// Khi tạo từ tab chi tiết DA — khoá select dự án.
  final String? fixedProjectId;
  final VoidCallback? onCancel;
  final ValueChanged<Contract>? onCreated;

  @override
  ConsumerState<ContractCreateForm> createState() => _ContractCreateFormState();
}

class _ContractCreateFormState extends ConsumerState<ContractCreateForm> {
  String? _projectId;
  ProjectCategory? _type;
  final _valueController = TextEditingController();
  final _codeController = TextEditingController();
  DateTime _signedDate = DateTime.now();
  DateTime? _dueDate;
  final List<_MilestoneDraft> _milestones = [];
  bool _saving = false;
  String? _warn;

  final _currency = NumberFormat.decimalPattern('vi');

  @override
  void initState() {
    super.initState();
    _projectId = widget.fixedProjectId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_projectId != null) _bindProject(_projectId!);
    });
  }

  @override
  void dispose() {
    _valueController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  int get _value {
    final digits = _valueController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  double get _totalRatio => _milestones.fold(0.0, (s, m) => s + m.ratio);

  int _amountFor(double ratio) => (_value * ratio / 100).round();

  void _formatValueField() {
    final v = _value;
    _valueController.value = TextEditingValue(
      text: v > 0 ? _currency.format(v) : '',
      selection: TextSelection.collapsed(offset: v > 0 ? _currency.format(v).length : 0),
    );
  }

  void _bindProject(String projectId) {
    final projects = ref.read(projectListProvider()).value ?? const <Project>[];
    Project? project;
    for (final p in projects) {
      if (p.id == projectId) {
        project = p;
        break;
      }
    }
    if (project == null) {
      setState(() => _projectId = projectId);
      return;
    }

    setState(() {
      _projectId = project!.id;
      _type = project.category;
      _dueDate = project.dueDate;
      _codeController.text = _previewCode(project);
      if (project.budget != null && project.budget! > 0) {
        _valueController.text = _currency.format(project.budget!);
      } else {
        _valueController.clear();
      }
      _milestones
        ..clear()
        ..addAll(_templateFor(project.category).map((m) => m.copy()));
      _warn = null;
    });
  }

  void _onTypeChanged(ProjectCategory? type) {
    if (type == null) return;
    setState(() {
      _type = type;
      if (_milestones.isEmpty) {
        _milestones.addAll(_templateFor(type).map((m) => m.copy()));
      }
      _warn = null;
    });
  }

  void _applyTemplate(String kind) {
    setState(() {
      _milestones
        ..clear()
        ..addAll((kind == 'design' ? _designTemplate() : _buildTemplate()).map((m) => m.copy()));
      if (kind == 'design') {
        _type = ProjectCategory.design;
      } else if (_type != ProjectCategory.construction && _type != ProjectCategory.turnkey) {
        _type = ProjectCategory.construction;
      }
      _warn = null;
    });
  }

  Future<void> _pickDate({required bool signed}) async {
    final initial = signed ? _signedDate : (_dueDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked == null) return;
    setState(() {
      if (signed) {
        _signedDate = picked;
      } else {
        _dueDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (_projectId == null) {
      setState(() => _warn = 'Vui lòng chọn dự án liên kết.');
      return;
    }
    if (_type == null) {
      setState(() => _warn = 'Vui lòng chọn loại hợp đồng.');
      return;
    }
    if (_value <= 0) {
      setState(() => _warn = 'Vui lòng nhập giá trị hợp đồng.');
      return;
    }
    if (_milestones.isEmpty) {
      setState(() => _warn = 'Vui lòng thêm ít nhất một đợt thanh toán.');
      return;
    }
    if (_milestones.any((m) => m.name.trim().isEmpty || m.ratio <= 0)) {
      setState(() => _warn = 'Mỗi đợt cần có tên và tỷ lệ (%) lớn hơn 0.');
      return;
    }
    if ((_totalRatio - 100).abs() > 0.5) {
      setState(() => _warn = 'Tổng tỷ lệ các đợt phải bằng 100% (hiện tại: ${_totalRatio.toStringAsFixed(1)}%).');
      return;
    }

    setState(() {
      _saving = true;
      _warn = null;
    });
    try {
      final contract = await ref.read(contractActionsProvider.notifier).create(
            projectId: _projectId!,
            type: _type!,
            value: _value,
            signedDate: _signedDate,
            dueDate: _dueDate,
            milestones: [
              for (final m in _milestones)
                MilestoneInput(
                  name: m.name.trim(),
                  ratio: m.ratio,
                  condition: m.condition.trim().isEmpty ? null : m.condition.trim(),
                  dueDate: m.dueDate,
                  isRetention: m.isRetention || m.name.toLowerCase().contains('bảo hành'),
                ),
            ],
          );
      if (!mounted) return;
      showAppToast(context, 'Đã lưu hợp đồng ${contract.code}');
      widget.onCreated?.call(contract);
    } on ApiException catch (e) {
      if (mounted) setState(() => _warn = e.message);
    } catch (e) {
      if (mounted) setState(() => _warn = 'Không lưu được: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectListProvider());
    final role = ref.watch(authProvider).value?.role;
    final canCreate = role == 'ADMIN' || role == 'DIRECTOR';

    if (!canCreate) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.webCardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.webBorder),
        ),
        child: const Text('Chỉ Quản trị và Giám đốc được tạo hợp đồng.'),
      );
    }

    final ratioOk = (_totalRatio - 100).abs() < 0.5;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.webCardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.webBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Khai báo hợp đồng mới', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'Nhập thông tin hợp đồng và khai báo các đợt thanh toán — tổng tỷ lệ các đợt phải bằng 100% trước khi lưu.',
            style: TextStyle(fontSize: 12.5, color: AppColors.webMutedFg),
          ),
          const SizedBox(height: 16),
          projectsAsync.when(
            data: (projects) => LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                final fields = [
                  _projectField(projects),
                  TextField(
                    controller: _codeController,
                    readOnly: true,
                    decoration: _fieldDecoration(label: 'Mã hợp đồng', hint: 'Tự sinh theo dự án khi lưu'),
                  ),
                  DropdownButtonFormField<ProjectCategory?>(
                    key: ValueKey(_type),
                    initialValue: _type,
                    isExpanded: true,
                    decoration: _fieldDecoration(label: 'Loại hợp đồng'),
                    items: [
                      const DropdownMenuItem<ProjectCategory?>(value: null, child: Text('— Chọn loại —')),
                      for (final c in ProjectCategory.values)
                        DropdownMenuItem<ProjectCategory?>(value: c, child: Text(c.label, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: _onTypeChanged,
                  ),
                  TextField(
                    controller: _valueController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    decoration: _fieldDecoration(label: 'Giá trị hợp đồng (₫)', hint: 'VD: 2.000.000.000'),
                    onChanged: (_) {
                      _formatValueField();
                      setState(() {});
                    },
                  ),
                  InkWell(
                    onTap: () => _pickDate(signed: true),
                    child: InputDecorator(
                      decoration: _fieldDecoration(label: 'Ngày ký'),
                      child: Text(DateFormat('dd/MM/yyyy').format(_signedDate), style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                  InkWell(
                    onTap: () => _pickDate(signed: false),
                    child: InputDecorator(
                      decoration: _fieldDecoration(label: 'Hạn bàn giao dự kiến'),
                      child: Text(
                        _dueDate == null ? '—' : DateFormat('dd/MM/yyyy').format(_dueDate!),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ];

                if (wide) {
                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < 4; i++) ...[
                            if (i > 0) const SizedBox(width: 12),
                            Expanded(child: fields[i]),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: fields[4]),
                          const SizedBox(width: 12),
                          Expanded(child: fields[5]),
                          const SizedBox(width: 12),
                          const Expanded(child: SizedBox()),
                          const SizedBox(width: 12),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    for (final f in fields) ...[f, const SizedBox(height: 10)],
                  ],
                );
              },
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Lỗi tải dự án: $e'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => _applyTemplate('design'),
                style: OutlinedButton.styleFrom(backgroundColor: AppColors.webSecondaryBg, foregroundColor: AppColors.webSecondaryFg),
                child: const Text('Mẫu Thiết kế 50/50'),
              ),
              OutlinedButton(
                onPressed: () => _applyTemplate('build'),
                style: OutlinedButton.styleFrom(backgroundColor: AppColors.webSecondaryBg, foregroundColor: AppColors.webSecondaryFg),
                child: const Text('Mẫu Thi công (giữ 5% bảo hành)'),
              ),
              OutlinedButton(
                onPressed: () => setState(() => _milestones.add(_MilestoneDraft(name: 'Đợt ${_milestones.length + 1}'))),
                child: const Text('+ Thêm đợt'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _milestonesTable(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Tổng tỷ lệ: ', style: TextStyle(fontSize: 13, color: AppColors.webMutedFg)),
              Text(
                '${_totalRatio.toStringAsFixed(_totalRatio == _totalRatio.roundToDouble() ? 0 : 1)}%',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ratioOk ? AppColors.webSuccess : AppColors.webDestructive),
              ),
              const SizedBox(width: 24),
              Text('Tổng tiền phân bổ: ', style: TextStyle(fontSize: 13, color: AppColors.webMutedFg)),
              Text('${_currency.format(_amountFor(_totalRatio))} ₫', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          if (_warn != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.webDestructive.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.webDestructive.withValues(alpha: 0.25)),
              ),
              child: Text(_warn!, style: const TextStyle(fontSize: 12.5, color: AppColors.webDestructive)),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(onPressed: _saving ? null : widget.onCancel, child: const Text('Huỷ')),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(backgroundColor: AppColors.webForeground, foregroundColor: Colors.white),
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Lưu hợp đồng'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _projectField(List<Project> projects) {
    if (widget.fixedProjectId != null) {
      Project? p;
      for (final x in projects) {
        if (x.id == widget.fixedProjectId) p = x;
      }
      return InputDecorator(
        decoration: _fieldDecoration(label: 'Dự án liên kết'),
        child: Text(p == null ? '—' : '${p.name} · ${p.code}', style: const TextStyle(fontSize: 13)),
      );
    }

    return DropdownButtonFormField<String?>(
      key: ValueKey(_projectId),
      initialValue: _projectId,
      isExpanded: true,
      decoration: _fieldDecoration(label: 'Dự án liên kết'),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('— Chọn dự án —', overflow: TextOverflow.ellipsis)),
        for (final p in projects)
          DropdownMenuItem<String?>(
            value: p.id,
            child: Text('${p.name} · ${p.code}', overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (id) {
        if (id == null) {
          setState(() {
            _projectId = null;
            _codeController.clear();
          });
          return;
        }
        _bindProject(id);
      },
    );
  }

  Widget _milestonesTable() {
    if (_milestones.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        child: Text(
          'Chưa có đợt thanh toán — chọn mẫu ở trên hoặc bấm "+ Thêm đợt".',
          style: TextStyle(fontSize: 13, color: AppColors.webMutedFg),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 48,
        dataRowMaxHeight: 56,
        columns: const [
          DataColumn(label: Text('Tên đợt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('Điều kiện / mô tả nghiệm thu', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('Tỷ lệ (%)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('Số tiền', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('Ngày dự kiến', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('')),
        ],
        rows: [
          for (var i = 0; i < _milestones.length; i++)
            DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 120,
                    child: TextFormField(
                      initialValue: _milestones[i].name,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                      onChanged: (v) => _milestones[i].name = v,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 280,
                    child: TextFormField(
                      initialValue: _milestones[i].condition,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                      onChanged: (v) => _milestones[i].condition = v,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 72,
                    child: TextFormField(
                      initialValue: _milestones[i].ratio == 0 ? '' : _milestones[i].ratio.toStringAsFixed(0),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                      onChanged: (v) => setState(() => _milestones[i].ratio = double.tryParse(v) ?? 0),
                    ),
                  ),
                ),
                DataCell(Text('${_currency.format(_amountFor(_milestones[i].ratio))} ₫', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                DataCell(
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _milestones[i].dueDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2040),
                      );
                      if (picked != null) setState(() => _milestones[i].dueDate = picked);
                    },
                    child: Text(
                      _milestones[i].dueDate == null ? '—' : DateFormat('dd/MM/yyyy').format(_milestones[i].dueDate!),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: AppColors.webDestructive),
                    onPressed: () => setState(() => _milestones.removeAt(i)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
