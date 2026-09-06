import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/web_badge.dart';
import '../../auth/application/auth_provider.dart';
import '../../projects/application/project_provider.dart';
import '../../projects/data/project_repository.dart';
import '../../users/application/user_provider.dart';
import '../application/lead_provider.dart';
import '../data/lead_repository.dart';
import 'lead_edit_dialog.dart';
import '../../../shared/widgets/app_toast.dart';

const _leadSources = ['Giới thiệu', 'Website', 'Mạng xã hội', 'Khác'];

(WebBadgeVariant, String) _statusBadge(LeadStatus status) => switch (status) {
      LeadStatus.newLead => (WebBadgeVariant.outline, 'Mới'),
      LeadStatus.consulting => (WebBadgeVariant.warning, 'Đang tư vấn'),
      LeadStatus.quoted => (WebBadgeVariant.secondary, 'Đã báo giá'),
      LeadStatus.converted => (WebBadgeVariant.success, 'Đã chốt'),
      LeadStatus.rejected => (WebBadgeVariant.muted, 'Từ chối'),
    };

/// Trang "Khách hàng" bản Web — bám sát `LT-ARC-Web-UI_1.html` (section
/// `data-if="isLeads"`): 4 thẻ KPI, form thêm nhanh dạng lưới 3 cột ngay
/// trên trang (không phải dialog), thanh lọc, bảng danh sách.
class LeadsWebPage extends ConsumerWidget {
  const LeadsWebPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leadsAsync = ref.watch(leadListProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1360),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Khách hàng tiềm năng', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Theo dõi khách hàng tiềm năng từ liên hệ đầu tiên đến khi ký hợp đồng.',
              style: TextStyle(fontSize: 13, color: AppColors.webMutedFg),
            ),
            const SizedBox(height: 20),
            _StatsRow(leadsAsync: leadsAsync),
            const SizedBox(height: 20),
            const _CreateLeadCard(),
            const SizedBox(height: 20),
            const _FilterRow(),
            const SizedBox(height: 20),
            _LeadsTableCard(leadsAsync: leadsAsync),
          ],
        ),
      ),
    );
  }
}

class _WebCard extends StatelessWidget {
  const _WebCard({required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.webCardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.webBorder),
      ),
      padding: padding,
      child: child,
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.leadsAsync});

  final AsyncValue<List<Lead>> leadsAsync;

  @override
  Widget build(BuildContext context) {
    final leads = leadsAsync.value ?? const <Lead>[];
    final total = leads.length;
    final consulting = leads.where((l) => l.status == LeadStatus.consulting).length;
    final quoted = leads.where((l) => l.status == LeadStatus.quoted).length;
    final converted = leads.where((l) => l.status == LeadStatus.converted).length;
    final conversionRate = total == 0 ? 0 : (converted * 100 / total).round();

    return Row(
      children: [
        Expanded(child: _StatCard(icon: Icons.people_outline, iconColor: AppColors.webForeground, iconBgColor: AppColors.gold, value: '$total', label: 'Tổng khách hàng tiềm năng')),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(icon: Icons.mark_chat_unread_outlined, iconColor: AppColors.webWarning, value: '$consulting', label: 'Đang tư vấn')),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(icon: Icons.description_outlined, iconColor: AppColors.webForeground, iconBgColor: AppColors.gold, value: '$quoted', label: 'Đã báo giá')),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.check_circle_outline,
            iconColor: AppColors.webSuccess,
            value: '$conversionRate%',
            valueColor: AppColors.webSuccess,
            label: 'Tỷ lệ chuyển đổi thành khách hàng',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.iconColor, required this.value, required this.label, this.valueColor, Color? iconBgColor})
      : iconBgColor = iconBgColor ?? iconColor;

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return _WebCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBgColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(4)),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: valueColor)),
                const SizedBox(height: 4),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(fontSize: 10.5, letterSpacing: 0.5, color: AppColors.webMutedFg),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4, color: AppColors.webMutedFg));
  }
}

InputDecoration _webInputDecoration({String? hint}) => InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.webBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.webBorder)),
    );

class _CreateLeadCard extends ConsumerStatefulWidget {
  const _CreateLeadCard();

  @override
  ConsumerState<_CreateLeadCard> createState() => _CreateLeadCardState();
}

class _CreateLeadCardState extends ConsumerState<_CreateLeadCard> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _needController = TextEditingController();
  final _budgetController = TextEditingController();
  final _noteController = TextEditingController();
  String? _source;
  String? _ownerId;
  bool _saving = false;
  /// Đổi key để DropdownButtonFormField rebuild lại sau khi clear form.
  int _formEpoch = 0;

  @override
  void initState() {
    super.initState();
    // FR-2.1 — mặc định người phụ trách là người tạo, vẫn cho chọn người khác.
    _ownerId = ref.read(authProvider).value?.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _needController.dispose();
    _budgetController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _nameController.clear();
    _phoneController.clear();
    _emailController.clear();
    _needController.clear();
    _budgetController.clear();
    _noteController.clear();
    setState(() {
      _source = null;
      _ownerId = ref.read(authProvider).value?.id;
      _formEpoch++;
    });
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showAppToast(context, 'Vui lòng nhập họ tên khách hàng');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(leadRepositoryProvider).create(
            name: name,
            phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
            email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
            need: _needController.text.trim().isEmpty ? null : _needController.text.trim(),
            budgetEstimate: int.tryParse(_budgetController.text.trim().replaceAll('.', '')),
            source: _source,
            note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
            ownerId: _ownerId,
          );
      if (!mounted) return;
      _clearForm();
      showAppToast(context, 'Đã lưu khách hàng tiềm năng');
      // Gọi lại API danh sách — lead mới nhất lên đầu (order created_at desc).
      await ref.refresh(leadListProvider.future);
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message, error: true);
    } catch (e) {
      if (mounted) showAppToast(context, 'Không lưu được: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(userListProvider);

    return _WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Thêm khách hàng tiềm năng mới', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'Nhập thông tin ngay khi có liên hệ mới, phân công người phụ trách tư vấn.',
            style: TextStyle(fontSize: 13, color: AppColors.webMutedFg),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _field('Họ tên khách hàng', TextField(controller: _nameController, decoration: _webInputDecoration(hint: 'VD: Anh Hoàng Minh')))),
              const SizedBox(width: 12),
              Expanded(child: _field('Số điện thoại', TextField(controller: _phoneController, decoration: _webInputDecoration(hint: '09xx xxx xxx')))),
              const SizedBox(width: 12),
              Expanded(child: _field('Email', TextField(controller: _emailController, decoration: _webInputDecoration(hint: 'email@vidu.com')))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _field('Nhu cầu / Loại công trình', TextField(controller: _needController, decoration: _webInputDecoration(hint: 'VD: Nhà phố')))),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  'Ngân sách dự kiến',
                  TextField(
                    controller: _budgetController,
                    keyboardType: TextInputType.number,
                    decoration: _webInputDecoration(hint: '0 ₫'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  'Nguồn',
                  DropdownButtonFormField<String>(
                    key: ValueKey('lead-source-$_formEpoch'),
                    initialValue: _source,
                    decoration: _webInputDecoration(),
                    hint: const Text('Chọn nguồn', style: TextStyle(fontSize: 13)),
                    items: _leadSources.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (v) => setState(() => _source = v),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field(
                  'Người phụ trách',
                  usersAsync.when(
                    data: (users) => DropdownButtonFormField<String>(
                      key: ValueKey('lead-owner-$_formEpoch'),
                      initialValue: _ownerId,
                      decoration: _webInputDecoration(),
                      hint: const Text('Chọn người phụ trách', style: TextStyle(fontSize: 13)),
                      items: users.map((u) => DropdownMenuItem(value: u.id, child: Text(u.displayName, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (v) => setState(() => _ownerId = v),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Lỗi tải danh sách: $e'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _field('Ghi chú', TextField(controller: _noteController, decoration: _webInputDecoration(hint: 'VD: Khách quan tâm phong cách hiện đại...'))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: AppColors.webForeground, foregroundColor: Colors.white),
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Lưu khách hàng tiềm năng'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, Widget input) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        input,
      ],
    );
  }
}

class _FilterRow extends ConsumerWidget {
  const _FilterRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(leadFilterProvider);
    final usersAsync = ref.watch(userListProvider);

    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: _webInputDecoration(hint: 'Tìm theo tên hoặc số điện thoại...').copyWith(prefixIcon: const Icon(Icons.search, size: 18)),
            onChanged: (v) => ref.read(leadFilterProvider.notifier).setSearch(v),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<LeadStatus?>(
            initialValue: filter.status,
            decoration: _webInputDecoration(),
            items: [
              const DropdownMenuItem(value: null, child: Text('Trạng thái: Tất cả', style: TextStyle(fontSize: 13))),
              for (final s in LeadStatus.values) DropdownMenuItem(value: s, child: Text(s.label, style: const TextStyle(fontSize: 13))),
            ],
            onChanged: (v) => ref.read(leadFilterProvider.notifier).setStatus(v),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String?>(
            initialValue: filter.source,
            decoration: _webInputDecoration(),
            items: [
              const DropdownMenuItem(value: null, child: Text('Nguồn: Tất cả', style: TextStyle(fontSize: 13))),
              for (final s in _leadSources) DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))),
            ],
            onChanged: (v) => ref.read(leadFilterProvider.notifier).setSource(v),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 210,
          child: usersAsync.when(
            data: (users) => DropdownButtonFormField<String?>(
              initialValue: filter.ownerId,
              decoration: _webInputDecoration(),
              items: [
                const DropdownMenuItem(value: null, child: Text('Người phụ trách: Tất cả', style: TextStyle(fontSize: 13))),
                for (final u in users) DropdownMenuItem(value: u.id, child: Text(u.displayName, style: const TextStyle(fontSize: 13))),
              ],
              onChanged: (v) => ref.read(leadFilterProvider.notifier).setOwner(v),
            ),
            loading: () => const SizedBox(height: 36),
            error: (e, _) => const SizedBox(height: 36),
          ),
        ),
      ],
    );
  }
}

class _LeadsTableCard extends ConsumerWidget {
  const _LeadsTableCard({required this.leadsAsync});

  final AsyncValue<List<Lead>> leadsAsync;

  static const _headerStyle = TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 0.5);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(userListProvider);
    final projectsAsync = ref.watch(projectListProvider());
    final currency = NumberFormat.decimalPattern('vi');
    final dateFormat = DateFormat('dd/MM/yyyy');

    return _WebCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Danh sách khách hàng tiềm năng', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          leadsAsync.when(
            data: (leads) {
              if (leads.isEmpty) {
                return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('Chưa có khách hàng tiềm năng nào')));
              }
              final usersById = {for (final u in usersAsync.value ?? const []) u.id: u};
              final projectsById = <String, Project>{for (final p in projectsAsync.value ?? const <Project>[]) p.id: p};

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 34,
                  dataRowMinHeight: 44,
                  dataRowMaxHeight: 52,
                  columnSpacing: 20,
                  dividerThickness: 0.6,
                  columns: const [
                    DataColumn(label: Text('TÊN', style: _headerStyle)),
                    DataColumn(label: Text('SĐT', style: _headerStyle)),
                    DataColumn(label: Text('NHU CẦU', style: _headerStyle)),
                    DataColumn(label: Text('NGÂN SÁCH DỰ KIẾN', style: _headerStyle)),
                    DataColumn(label: Text('NGUỒN', style: _headerStyle)),
                    DataColumn(label: Text('NGƯỜI PHỤ TRÁCH', style: _headerStyle)),
                    DataColumn(label: Text('TRẠNG THÁI', style: _headerStyle)),
                    DataColumn(label: Text('NGÀY TẠO', style: _headerStyle)),
                    DataColumn(label: Text('THAO TÁC', style: _headerStyle)),
                  ],
                  rows: [
                    for (final lead in leads)
                      DataRow(
                        cells: [
                          for (final cell in [
                            Text(lead.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                            Text(lead.phone ?? '—', style: const TextStyle(fontSize: 13)),
                            Text(lead.need ?? '—', style: const TextStyle(fontSize: 13)),
                            Text(lead.budgetEstimate != null ? '${currency.format(lead.budgetEstimate)} ₫' : '—', style: const TextStyle(fontSize: 13)),
                            lead.source != null ? WebBadge(lead.source!, variant: WebBadgeVariant.outline) : const Text('—'),
                            Text(usersById[lead.ownerId]?.displayName ?? '—', style: const TextStyle(fontSize: 13)),
                            _statusCell(lead, projectsById),
                            Text(dateFormat.format(lead.createdAt.toLocal()), style: const TextStyle(fontSize: 13)),
                            _actionsCell(context, ref, lead),
                          ])
                            DataCell(lead.status == LeadStatus.rejected ? Opacity(opacity: 0.7, child: cell) : cell),
                        ],
                      ),
                  ],
                ),
              );
            },
            loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Text('Lỗi tải dữ liệu: $e')),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _statusCell(Lead lead, Map<String, Project> projectsById) {
    final (variant, label) = _statusBadge(lead.status);
    if (lead.status == LeadStatus.converted && lead.convertedProjectId != null) {
      final code = projectsById[lead.convertedProjectId]?.code;
      return WebBadge('$label${code != null ? ' → $code' : ''}', variant: variant);
    }
    return WebBadge(label, variant: variant);
  }

  Widget _actionsCell(BuildContext context, WidgetRef ref, Lead lead) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18),
          tooltip: 'Sửa',
          onPressed: () => showLeadEditDialog(context, lead),
        ),
        IconButton(
          icon: Icon(Icons.delete_outline, size: 18, color: AppColors.webDestructive),
          tooltip: 'Xoá',
          onPressed: () => _confirmDelete(context, ref, lead),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Lead lead) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xoá khách hàng tiềm năng?'),
        content: Text('Bạn có chắc muốn xoá "${lead.name}"? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Huỷ')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.webDestructive),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(leadActionsProvider.notifier).delete(lead.id);
      if (context.mounted) {
        showAppToast(context, 'Đã xoá khách hàng tiềm năng');
      }
    } on ApiException catch (e) {
      if (context.mounted) showAppToast(context, e.message, error: true);
    }
  }
}
