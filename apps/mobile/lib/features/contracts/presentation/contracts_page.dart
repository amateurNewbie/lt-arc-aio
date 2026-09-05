import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/web_badge.dart';
import '../../funds/application/fund_provider.dart';
import '../../projects/application/project_provider.dart';
import '../../projects/data/project_repository.dart';
import '../application/contract_provider.dart';
import '../data/contract_repository.dart';
import 'contract_form_sheet.dart';

WebBadgeVariant _statusVariant(ContractStatus s) => switch (s) {
      ContractStatus.active => WebBadgeVariant.secondary,
      ContractStatus.expiringSoon => WebBadgeVariant.warning,
      ContractStatus.liquidated => WebBadgeVariant.outline,
      ContractStatus.settled => WebBadgeVariant.outline,
    };

/// Trang "Hợp đồng" — bám `LT-ARC-Web-UI_1.html` (`data-if="isContracts"`):
/// 4 KPI, bảng hợp đồng toàn công ty, ghi nhận thu tiền theo đợt, chi tiết
/// tiến độ thanh toán của hợp đồng đang chọn.
///
/// Ghi chú trung thực: `Contract.status` luôn là ACTIVE — hệ thống hiện chưa
/// có tác vụ nào tự chuyển Sắp hết hạn/Đã thanh lý/Đã tất toán (không có ở
/// backend), nên cột Trạng thái sẽ luôn hiện "Còn hiệu lực" cho tới khi tính
/// năng đó được xây.
class ContractsPage extends ConsumerStatefulWidget {
  const ContractsPage({super.key});

  @override
  ConsumerState<ContractsPage> createState() => _ContractsPageState();
}

class _ContractsPageState extends ConsumerState<ContractsPage> {
  Contract? _selected;

  Future<void> _pickProjectAndCreate(BuildContext context, List<Project> projects) async {
    final projectId = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Chọn dự án để tạo hợp đồng'),
        children: [
          for (final p in projects)
            SimpleDialogOption(onPressed: () => Navigator.of(context).pop(p.id), child: Text('${p.name} (${p.code})')),
        ],
      ),
    );
    if (projectId != null && context.mounted) {
      await showContractFormSheet(context, projectId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contractsAsync = ref.watch(contractListAllProvider);
    final projectsAsync = ref.watch(projectListProvider());
    final currency = NumberFormat.decimalPattern('vi');
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1360),
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
                        Text('Hợp đồng', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('Theo dõi hợp đồng ký với khách hàng theo từng dự án.', style: TextStyle(fontSize: 13, color: AppColors.webMutedFg)),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _pickProjectAndCreate(context, projectsAsync.value ?? const []),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.webForeground, foregroundColor: Colors.white),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Tạo hợp đồng'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              contractsAsync.when(
                data: (contracts) {
                  final projectsById = {for (final p in projectsAsync.value ?? const <Project>[]) p.id: p};
                  final total = contracts.length;
                  final active = contracts.where((c) => c.status == ContractStatus.active).length;
                  final expiring = contracts.where((c) => c.status == ContractStatus.expiringSoon).length;
                  final totalValue = contracts.fold<int>(0, (s, c) => s + c.value);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _StatCard(icon: Icons.description_outlined, color: AppColors.gold, value: '$total', label: 'Tổng hợp đồng')),
                          const SizedBox(width: 12),
                          Expanded(child: _StatCard(icon: Icons.check_circle_outline, color: AppColors.webSuccess, value: '$active', label: 'Còn hiệu lực')),
                          const SizedBox(width: 12),
                          Expanded(child: _StatCard(icon: Icons.access_time, color: AppColors.webWarning, value: '$expiring', label: 'Sắp hết hạn')),
                          const SizedBox(width: 12),
                          Expanded(child: _StatCard(icon: Icons.account_balance_outlined, color: AppColors.webMutedFg, value: '${currency.format(totalValue)} ₫', label: 'Tổng giá trị hợp đồng')),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (contracts.isEmpty)
                        const Text('Chưa có hợp đồng nào')
                      else
                        Container(
                          decoration: BoxDecoration(color: AppColors.webCardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.webBorder)),
                          padding: const EdgeInsets.all(16),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowHeight: 32,
                              dataRowMinHeight: 40,
                              dataRowMaxHeight: 48,
                              columns: const [
                                DataColumn(label: Text('MÃ HĐ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                                DataColumn(label: Text('DỰ ÁN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                                DataColumn(label: Text('KHÁCH HÀNG', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                                DataColumn(label: Text('GIÁ TRỊ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                                DataColumn(label: Text('NGÀY KÝ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                                DataColumn(label: Text('HẠN BÀN GIAO', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                                DataColumn(label: Text('TIẾN ĐỘ THANH TOÁN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                                DataColumn(label: Text('TRẠNG THÁI', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                              ],
                              rows: [
                                for (final c in contracts)
                                  DataRow(
                                    selected: _selected?.id == c.id,
                                    onSelectChanged: (_) => setState(() => _selected = c),
                                    cells: [
                                      DataCell(Text(c.code, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                      DataCell(Text(projectsById[c.projectId]?.name ?? '—', style: const TextStyle(fontSize: 13))),
                                      DataCell(Text(projectsById[c.projectId]?.client ?? '—', style: const TextStyle(fontSize: 13))),
                                      DataCell(Text('${currency.format(c.value)} ₫', style: const TextStyle(fontSize: 13))),
                                      DataCell(Text(c.signedDate != null ? dateFormat.format(c.signedDate!) : '—', style: const TextStyle(fontSize: 13))),
                                      DataCell(Text(c.dueDate != null ? dateFormat.format(c.dueDate!) : '—', style: const TextStyle(fontSize: 13))),
                                      DataCell(Text(
                                        c.value > 0 ? '${(c.paidAmount * 100 / c.value).toStringAsFixed(0)}%' : '—',
                                        style: const TextStyle(fontSize: 13),
                                      )),
                                      DataCell(WebBadge(c.status.label, variant: _statusVariant(c.status))),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      if (_selected != null) ...[
                        _CollectMilestoneCard(contract: _selected!),
                        const SizedBox(height: 20),
                        _MilestoneScheduleCard(contract: _selected!, project: projectsById[_selected!.projectId]),
                      ],
                    ],
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

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.color, required this.value, required this.label});

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.webCardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.webBorder)),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(4)),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(label.toUpperCase(), style: TextStyle(fontSize: 10, letterSpacing: 0.3, color: AppColors.webMutedFg)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectMilestoneCard extends ConsumerStatefulWidget {
  const _CollectMilestoneCard({required this.contract});

  final Contract contract;

  @override
  ConsumerState<_CollectMilestoneCard> createState() => _CollectMilestoneCardState();
}

class _CollectMilestoneCardState extends ConsumerState<_CollectMilestoneCard> {
  String? _milestoneId;
  final _amountController = TextEditingController();
  String? _fundAccountId;
  final DateTime _date = DateTime.now();
  bool _saving = false;

  Future<void> _submit() async {
    final amount = int.tryParse(_amountController.text.trim());
    if (_milestoneId == null || amount == null || _fundAccountId == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(contractActionsProvider.notifier).collect(
            contractId: widget.contract.id,
            milestoneId: _milestoneId!,
            amount: amount,
            fundAccountId: _fundAccountId!,
            date: _date,
          );
      if (mounted) {
        _amountController.clear();
        setState(() {
          _milestoneId = null;
          _fundAccountId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu khoản thu')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fundsAsync = ref.watch(fundListProvider);
    final pending = widget.contract.milestones.where((m) => m.remaining > 0).toList();

    return Container(
      decoration: BoxDecoration(color: AppColors.webCardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.webBorder)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ghi nhận thu tiền theo đợt — ${widget.contract.code}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Hệ thống tự cập nhật công nợ phải thu và tạo bút toán trong Sổ quỹ.', style: TextStyle(fontSize: 12, color: AppColors.webMutedFg)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _milestoneId,
                  decoration: const InputDecoration(labelText: 'Đợt thanh toán', isDense: true),
                  items: pending.map((m) => DropdownMenuItem(value: m.id, child: Text('${m.name} (còn ${m.remaining} ₫)', overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setState(() => _milestoneId = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Số tiền thu', isDense: true))),
              const SizedBox(width: 10),
              Expanded(
                child: fundsAsync.when(
                  data: (funds) => DropdownButtonFormField<String>(
                    initialValue: _fundAccountId,
                    decoration: const InputDecoration(labelText: 'Quỹ nhận', isDense: true),
                    items: funds.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name))).toList(),
                    onChanged: (v) => setState(() => _fundAccountId = v),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Lỗi: $e'),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(backgroundColor: AppColors.webForeground, foregroundColor: Colors.white),
                child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Lưu khoản thu'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MilestoneScheduleCard extends StatelessWidget {
  const _MilestoneScheduleCard({required this.contract, required this.project});

  final Contract contract;
  final Project? project;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.decimalPattern('vi');
    final dateFormat = DateFormat('dd/MM/yyyy');
    final totalPaid = contract.milestones.fold<int>(0, (s, m) => s + m.paidAmount);

    return Container(
      decoration: BoxDecoration(color: AppColors.webCardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.webBorder)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tiến độ thanh toán — ${contract.code}${project != null ? ' — ${project!.name}' : ''}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 32,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 48,
              columns: const [
                DataColumn(label: Text('ĐỢT', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('ĐIỀU KIỆN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('TỶ LỆ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('GIÁ TRỊ ĐỢT', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('ĐÃ THU', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('CÒN LẠI', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('HẠN THU', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('TRẠNG THÁI', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
              ],
              rows: [
                for (final m in contract.milestones)
                  DataRow(cells: [
                    DataCell(Text(m.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                    DataCell(Text(m.condition ?? '—', style: const TextStyle(fontSize: 13))),
                    DataCell(Text('${m.ratio}%', style: const TextStyle(fontSize: 13))),
                    DataCell(Text('${currency.format(m.amount)} ₫', style: const TextStyle(fontSize: 13))),
                    DataCell(Text('${currency.format(m.paidAmount)} ₫', style: const TextStyle(fontSize: 13))),
                    DataCell(Text('${currency.format(m.remaining)} ₫', style: TextStyle(fontSize: 13, fontWeight: m.remaining > 0 ? FontWeight.w500 : FontWeight.normal))),
                    DataCell(Text(m.dueDate != null ? dateFormat.format(m.dueDate!) : '—', style: const TextStyle(fontSize: 13))),
                    DataCell(WebBadge(m.status.label, variant: m.status == MilestoneStatus.paid ? WebBadgeVariant.secondary : (m.status == MilestoneStatus.overdue ? WebBadgeVariant.destructive : WebBadgeVariant.outline))),
                  ]),
              ],
            ),
          ),
          const Divider(),
          Text('Đã thu ${contract.value > 0 ? (totalPaid * 100 / contract.value).toStringAsFixed(0) : 0}% giá trị hợp đồng', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
