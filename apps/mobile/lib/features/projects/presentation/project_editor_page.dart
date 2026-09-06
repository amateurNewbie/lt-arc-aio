import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/searchable_select.dart';
import '../../../shared/widgets/web_badge.dart';
import '../../auth/application/auth_provider.dart';
import '../../budget/presentation/budget_tab.dart';
import '../../cashbook/application/cashbook_provider.dart';
import '../../cashbook/presentation/expense_tab.dart';
import '../../cashbook/presentation/income_tab.dart';
import '../../debts/application/debt_provider.dart';
import '../../leads/application/lead_provider.dart';
import '../../leads/data/lead_repository.dart';
import '../../reports/application/reports_provider.dart';
import '../../reports/data/reports_repository.dart';
import '../../tasks/application/task_provider.dart';
import '../../tasks/presentation/project_tasks_tab.dart';
import '../../users/application/user_provider.dart';
import '../../users/data/user_repository.dart';
import '../../work_items/application/work_item_provider.dart';
import '../../work_items/presentation/work_items_tab.dart';
import '../application/project_provider.dart';
import '../data/project_repository.dart';
import '../../../shared/widgets/app_toast.dart';

WebBadgeVariant _categoryVariant(ProjectCategory c) => switch (c) {
      ProjectCategory.construction => WebBadgeVariant.warning,
      ProjectCategory.turnkey => WebBadgeVariant.primary,
      ProjectCategory.design => WebBadgeVariant.outline,
    };

List<SearchableOption> _userOptions(List<UserSummary> users) => [
      for (final u in users) SearchableOption(id: u.id, label: u.displayName, searchText: '${u.email} ${u.role}'),
    ];

/// Phase A/B — trang tạo / chi tiết dự án.
/// Create: ẩn KPI, tab khóa đến khi lưu (1A).
/// Phase B: searchable select PM / 2 trưởng BP / NV / KH CONVERTED; lưu PATCH trên detail.
class ProjectEditorPage extends ConsumerStatefulWidget {
  const ProjectEditorPage({super.key, this.projectId, this.seed});

  final String? projectId;
  /// Khi vừa tạo xong — dùng để hiện detail + tabs ngay lập tức.
  final Project? seed;

  bool get isCreate => projectId == null;

  @override
  ConsumerState<ProjectEditorPage> createState() => _ProjectEditorPageState();
}

class _ProjectEditorPageState extends ConsumerState<ProjectEditorPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  final _nameController = TextEditingController();
  final _clientController = TextEditingController();
  final _typeController = TextEditingController();
  final _areaController = TextEditingController();
  final _budgetController = TextEditingController();

  ProjectCategory _category = ProjectCategory.construction;
  String? _leadId;
  String? _managerId;
  String? _constructionHeadId;
  String? _designHeadId;
  Set<String> _memberIds = {};
  Map<String, ProjectStageProgress> _stages = defaultStageProgressMap();

  bool _saving = false;
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _managerId = ref.read(authProvider).value?.id;
    final seed = widget.seed;
    if (seed != null && widget.projectId != null) {
      _hydrateFrom(seed);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameController.dispose();
    _clientController.dispose();
    _typeController.dispose();
    _areaController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _hydrateFrom(Project project) {
    _nameController.text = project.name;
    _clientController.text = project.client;
    _typeController.text = project.type ?? '';
    _areaController.text = project.area?.toString() ?? '';
    _budgetController.text = project.budget?.toString() ?? '';
    _category = project.category;
    _leadId = project.leadId;
    _managerId = project.managerId;
    _constructionHeadId = project.constructionHeadId;
    _designHeadId = project.designHeadId;
    _memberIds = {...project.memberIds};
    _stages = project.stages;
    _hydrated = true;
  }

  Future<void> _pickDeadline(String stageKey) async {
    final current = _stages[stageKey]?.deadline ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked == null) return;
    setState(() {
      final prev = _stages[stageKey] ?? const ProjectStageProgress(progress: 0);
      _stages = {..._stages, stageKey: ProjectStageProgress(progress: prev.progress, deadline: picked)};
    });
  }

  String? _validate() {
    if (_nameController.text.trim().isEmpty) return 'Vui lòng nhập tên dự án';
    if (_clientController.text.trim().isEmpty) return 'Vui lòng chọn hoặc nhập khách hàng';
    if (_managerId == null) return 'Vui lòng chọn Quản lý dự án';
    return null;
  }

  Future<void> _submitCreate() async {
    if (_saving) return;
    final error = _validate();
    if (error != null) {
      showAppToast(context, error);
      return;
    }

    setState(() => _saving = true);
    try {
      final project = await ref.read(projectActionsProvider.notifier).create(
            name: _nameController.text.trim(),
            client: _clientController.text.trim(),
            category: _category,
            managerId: _managerId!,
            constructionHeadId: _constructionHeadId,
            designHeadId: _designHeadId,
            memberIds: _memberIds.toList(),
            leadId: _leadId,
            type: _typeController.text.trim().isEmpty ? null : _typeController.text.trim(),
            area: double.tryParse(_areaController.text.trim()),
            budget: int.tryParse(_budgetController.text.trim().replaceAll('.', '')),
            stageProgress: _stages,
          );

      // Chuyển detail TRƯỚC mọi thứ khác — đúng yêu cầu: tạo xong → tabs mở.
      if (kIsWeb) {
        ref.read(projectPaneProvider.notifier).showDetail(project.id, seed: project);
      } else if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ProjectEditorPage(projectId: project.id, seed: project)),
        );
      }

      showAppToast(context, 'Đã tạo dự án');
    } on ApiException catch (e) {
      if (mounted) {
        showAppToast(context, e.message, error: true);
        setState(() => _saving = false);
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'Không lưu được: $e', error: true);
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _submitUpdate() async {
    final error = _validate();
    if (error != null) {
      showAppToast(context, error);
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(projectActionsProvider.notifier).update(
            widget.projectId!,
            name: _nameController.text.trim(),
            client: _clientController.text.trim(),
            category: _category,
            managerId: _managerId,
            constructionHeadId: _constructionHeadId,
            designHeadId: _designHeadId,
            memberIds: _memberIds.toList(),
            leadId: _leadId,
            type: _typeController.text.trim().isEmpty ? null : _typeController.text.trim(),
            area: double.tryParse(_areaController.text.trim()),
            budget: int.tryParse(_budgetController.text.trim().replaceAll('.', '')),
            stageProgress: _stages,
            clearOptionalHeads: true,
          );
      if (mounted) {
        showAppToast(context, 'Đã lưu thay đổi dự án');
        setState(() => _saving = false);
      }
    } on ApiException catch (e) {
      if (mounted) {
        showAppToast(context, e.message, error: true);
        setState(() => _saving = false);
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'Không lưu được: $e', error: true);
        setState(() => _saving = false);
      }
    }
  }

  void _goBack() {
    if (kIsWeb) {
      ref.read(projectPaneProvider.notifier).showList();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _onLeadSelected(Lead? lead) {
    setState(() {
      _leadId = lead?.id;
      if (lead != null) {
        _clientController.text = lead.name;
        if (lead.budgetEstimate != null) {
          _budgetController.text = lead.budgetEstimate.toString();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(userListProvider);
    final leadsAsync = ref.watch(leadListProvider);

    if (!widget.isCreate && !_hydrated) {
      final projectAsync = ref.watch(projectDetailProvider(widget.projectId!));
      return projectAsync.when(
        data: (project) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_hydrated) setState(() => _hydrateFrom(project));
          });
          return const Center(child: CircularProgressIndicator());
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi tải dự án: $e')),
      );
    }

    final projectAsync = widget.isCreate ? null : ref.watch(projectDetailProvider(widget.projectId!));
    final project = projectAsync?.asData?.value ?? widget.seed;

    final convertedLeads = (leadsAsync.asData?.value ?? const <Lead>[])
        .where(
          (l) =>
              l.status == LeadStatus.converted &&
              (l.convertedProjectId == null || l.convertedProjectId == widget.projectId),
        )
        .toList();
    final leadOptions = [
      for (final l in convertedLeads)
        SearchableOption(
          id: l.id,
          label: l.name,
          searchText: '${l.phone ?? ''} ${l.email ?? ''}',
        ),
    ];

    return ColoredBox(
      color: kIsWeb ? AppColors.webBackground : Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: widget.isCreate
                ? SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: _editorForm(
                          project: project,
                          usersAsync: usersAsync,
                          leadOptions: leadOptions,
                          convertedLeads: convertedLeads,
                        ),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 5,
                            child: SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 1100),
                                child: _editorForm(
                                  project: project,
                                  usersAsync: usersAsync,
                                  leadOptions: leadOptions,
                                  convertedLeads: convertedLeads,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _ProjectTabs(controller: _tabs, projectId: widget.projectId!),
                          const SizedBox(height: 8),
                          Expanded(
                            flex: 6,
                            child: TabBarView(
                              controller: _tabs,
                              children: [
                                BudgetTab(projectId: widget.projectId!),
                                ProjectTasksTab(projectId: widget.projectId!),
                                WorkItemsTab(projectId: widget.projectId!),
                                IncomeTab(projectId: widget.projectId!),
                                ExpenseTab(projectId: widget.projectId!),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            decoration: BoxDecoration(
              color: kIsWeb ? AppColors.webCardBg : Theme.of(context).scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: AppColors.webBorder.withValues(alpha: 0.85))),
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _saving ? null : (widget.isCreate ? _submitCreate : _submitUpdate),
                style: FilledButton.styleFrom(backgroundColor: AppColors.webForeground, foregroundColor: Colors.white),
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(widget.isCreate ? 'Tạo dự án' : 'Lưu thay đổi'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editorForm({
    required Project? project,
    required AsyncValue<List<UserSummary>> usersAsync,
    required List<SearchableOption> leadOptions,
    required List<Lead> convertedLeads,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _goBack,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back, size: 16),
              SizedBox(width: 6),
              Text('Quay lại danh sách dự án', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _HeaderBlock(
          nameController: _nameController,
          project: project,
          category: _category,
          onCategoryChanged: (c) => setState(() => _category = c),
        ),
        const SizedBox(height: 12),
        usersAsync.when(
          data: (users) {
            final opts = _userOptions(users);
            final byId = {for (final u in users) u.id: u};
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.isCreate)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        if (_constructionHeadId != null && byId[_constructionHeadId] != null)
                          _HeadChip(label: 'Trưởng bộ phận Thi công', user: byId[_constructionHeadId]!),
                        if (_designHeadId != null && byId[_designHeadId] != null)
                          _HeadChip(label: 'Trưởng bộ phận Thiết kế', user: byId[_designHeadId]!),
                        if (_managerId != null && byId[_managerId] != null)
                          _HeadChip(label: 'Quản lý dự án', user: byId[_managerId]!),
                      ],
                    ),
                  ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SearchableSingleSelect(
                      width: 280,
                      label: 'Quản lý dự án',
                      options: opts,
                      valueId: _managerId,
                      allowClear: false,
                      onChanged: (v) => setState(() => _managerId = v),
                    ),
                    SearchableSingleSelect(
                      width: 280,
                      label: 'Trưởng BP Thi công',
                      options: opts,
                      valueId: _constructionHeadId,
                      onChanged: (v) => setState(() => _constructionHeadId = v),
                    ),
                    SearchableSingleSelect(
                      width: 280,
                      label: 'Trưởng BP Thiết kế',
                      options: opts,
                      valueId: _designHeadId,
                      onChanged: (v) => setState(() => _designHeadId = v),
                    ),
                    SearchableMultiSelect(
                      width: 420,
                      label: 'Nhân viên dự án',
                      options: opts,
                      valueIds: _memberIds,
                      onChanged: (ids) => setState(() => _memberIds = ids),
                    ),
                  ],
                ),
              ],
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Lỗi tải users: $e'),
        ),
        const SizedBox(height: 16),
        _InfoBlock(
          clientController: _clientController,
          typeController: _typeController,
          areaController: _areaController,
          budgetController: _budgetController,
          leadId: _leadId,
          leadOptions: leadOptions,
          leads: convertedLeads,
          onLeadSelected: _onLeadSelected,
        ),
        if (!widget.isCreate) ...[
          const SizedBox(height: 16),
          _KpiRow(projectId: widget.projectId!, project: project),
        ],
        const SizedBox(height: 16),
        _StageProgressCard(
          stages: _stages,
          onProgressChanged: (key, value) => setState(() {
            final prev = _stages[key] ?? const ProjectStageProgress(progress: 0);
            _stages = {..._stages, key: ProjectStageProgress(progress: value.round(), deadline: prev.deadline)};
          }),
          onPickDeadline: _pickDeadline,
          onClearDeadline: (key) => setState(() {
            final prev = _stages[key] ?? const ProjectStageProgress(progress: 0);
            _stages = {..._stages, key: ProjectStageProgress(progress: prev.progress)};
          }),
        ),
        if (widget.isCreate) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.webSecondaryBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.webBorder),
            ),
            child: const Text(
              'Các tab Dự toán / Công việc / Hạng mục / Thu / Chi phí sẽ mở sau khi bấm Tạo dự án (lưu hồ sơ trước).',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }
}

class _HeadChip extends StatelessWidget {
  const _HeadChip({required this.label, required this.user});

  final String label;
  final UserSummary user;

  String get _initials {
    final parts = user.displayName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    final s = user.displayName.trim();
    return s.isEmpty ? '?' : s.substring(0, s.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.webSecondaryBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.webBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.webForeground,
            child: Text(_initials, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(fontSize: 13, color: AppColors.webMutedFg)),
          Text(user.displayName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ProjectTabs extends ConsumerWidget {
  const _ProjectTabs({required this.controller, required this.projectId});

  final TabController controller;
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskCount = ref.watch(taskListProvider(projectId: projectId)).asData?.value.length;
    final workItemCount = ref.watch(workItemListProvider(projectId)).asData?.value.length;
    final incomeCount = ref.watch(projectPaymentListProvider(projectId)).asData?.value.length;
    final expenseCount = ref.watch(projectCostListProvider(projectId)).asData?.value.length;
    final cashCount = (incomeCount ?? 0) + (expenseCount ?? 0);

    String labeled(String base, int? n) => n == null ? base : '$base ($n)';

    return TabBar(
      controller: controller,
      isScrollable: true,
      labelColor: AppColors.webForeground,
      tabs: [
        const Tab(text: 'Dự toán'),
        Tab(text: labeled('Công việc', taskCount)),
        Tab(text: labeled('Hạng mục công việc', workItemCount)),
        Tab(text: labeled('Thu', incomeCount)),
        Tab(text: cashCount > 0 ? labeled('Chi phí', expenseCount) : 'Chi phí'),
      ],
    );
  }
}

class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock({
    required this.nameController,
    required this.project,
    required this.category,
    required this.onCategoryChanged,
  });

  final TextEditingController nameController;
  final Project? project;
  final ProjectCategory category;
  final ValueChanged<ProjectCategory> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: nameController,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  hintText: 'Tên dự án',
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            if (project != null) ...[
              WebBadge(project!.status.label, variant: WebBadgeVariant.secondary),
              const SizedBox(width: 6),
              WebBadge(project!.category.label, variant: _categoryVariant(project!.category)),
            ],
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<ProjectCategory>(
            initialValue: category,
            decoration: const InputDecoration(labelText: 'Phân loại', isDense: true),
            items: [for (final c in ProjectCategory.values) DropdownMenuItem(value: c, child: Text(c.label))],
            onChanged: (v) {
              if (v != null) onCategoryChanged(v);
            },
          ),
        ),
        if (project != null) ...[
          const SizedBox(height: 6),
          Text(
            '${project!.code} · ${project!.client}${project!.type != null ? ' · ${project!.type}' : ''}',
            style: TextStyle(fontSize: 13, color: AppColors.webMutedFg),
          ),
        ],
      ],
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.clientController,
    required this.typeController,
    required this.areaController,
    required this.budgetController,
    required this.leadId,
    required this.leadOptions,
    required this.leads,
    required this.onLeadSelected,
  });

  final TextEditingController clientController;
  final TextEditingController typeController;
  final TextEditingController areaController;
  final TextEditingController budgetController;
  final String? leadId;
  final List<SearchableOption> leadOptions;
  final List<Lead> leads;
  final ValueChanged<Lead?> onLeadSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.webCardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.webBorder),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SearchableSingleSelect(
            width: 300,
            label: 'Khách hàng (đã chốt)',
            hint: 'Tìm khách hàng đã chốt...',
            options: leadOptions,
            valueId: leadId,
            onChanged: (id) {
              final lead = leads.where((l) => l.id == id).firstOrNull;
              onLeadSelected(lead);
            },
          ),
          SizedBox(
            width: 220,
            child: TextField(
              controller: clientController,
              decoration: const InputDecoration(labelText: 'Tên khách hàng', isDense: true),
            ),
          ),
          SizedBox(
            width: 180,
            child: TextField(controller: typeController, decoration: const InputDecoration(labelText: 'Loại hình', isDense: true)),
          ),
          SizedBox(
            width: 140,
            child: TextField(
              controller: areaController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Diện tích (m²)', isDense: true),
            ),
          ),
          SizedBox(
            width: 200,
            child: TextField(
              controller: budgetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Ngân sách (₫)',
                hintText: 'Tự điền từ KH — có thể sửa',
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiRow extends ConsumerWidget {
  const _KpiRow({required this.projectId, required this.project});

  final String projectId;
  final Project? project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pnlAsync = ref.watch(profitLossReportProvider);
    final receivablesAsync = ref.watch(receivableListProvider);
    final pnl = (pnlAsync.asData?.value ?? const <ProjectPnl>[]).where((p) => p.projectId == projectId).firstOrNull;
    final receivable = (receivablesAsync.asData?.value ?? const [])
        .where((r) => r.projectId == projectId)
        .fold<int>(0, (s, r) => s + r.remaining);

    Widget card(String label, String value, {Color? valueColor}) => ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 140, maxWidth: 180),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.webCardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.webBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: AppColors.webMutedFg)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: valueColor)),
              ],
            ),
          ),
        );

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        card('Tiến độ', '${project?.progress ?? 0}%'),
        card('Ngân sách', project?.budget != null ? formatCompactVnd(project!.budget!) : '—'),
        card('Đã thu', pnl != null ? formatCompactVnd(pnl.revenue) : '—'),
        card('Tổng chi phí', pnl != null ? formatCompactVnd(pnl.totalCost) : '—'),
        card(
          'Lãi/Lỗ',
          pnl != null ? formatCompactVnd(pnl.profit, showSign: true) : '—',
          valueColor: pnl == null ? null : (pnl.profit >= 0 ? AppColors.webSuccess : AppColors.webDestructive),
        ),
        card('Công nợ phải thu', formatCompactVnd(receivable)),
      ],
    );
  }
}

class _StageProgressCard extends StatelessWidget {
  const _StageProgressCard({
    required this.stages,
    required this.onProgressChanged,
    required this.onPickDeadline,
    required this.onClearDeadline,
  });

  final Map<String, ProjectStageProgress> stages;
  final void Function(String key, double value) onProgressChanged;
  final ValueChanged<String> onPickDeadline;
  final ValueChanged<String> onClearDeadline;

  bool _isOverdue(ProjectStageProgress stage) {
    if (stage.deadline == null || stage.progress >= 100) return false;
    final today = DateTime.now();
    final d = DateTime(stage.deadline!.year, stage.deadline!.month, stage.deadline!.day);
    final t = DateTime(today.year, today.month, today.day);
    return d.isBefore(t);
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.webCardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.webBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tiến độ theo giai đoạn', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'Theo dõi chi tiết tiến độ thi công & thiết kế của dự án.',
            style: TextStyle(fontSize: 12, color: AppColors.webMutedFg),
          ),
          const SizedBox(height: 16),
          for (final key in projectStageKeys) ...[
            Builder(
              builder: (context) {
                final stage = stages[key] ?? const ProjectStageProgress(progress: 0);
                final overdue = _isOverdue(stage);
                final barColor = stage.progress >= 100
                    ? AppColors.webSuccess
                    : (overdue ? AppColors.webDestructive : AppColors.gold);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              projectStageLabels[key] ?? key,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                          Text(
                            overdue ? '${stage.progress}% · trễ kế hoạch' : '${stage.progress}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: overdue ? AppColors.webDestructive : AppColors.webMutedFg,
                              fontWeight: overdue ? FontWeight.w600 : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => onPickDeadline(key),
                            icon: const Icon(Icons.event, size: 16),
                            label: Text(
                              stage.deadline != null ? dateFmt.format(stage.deadline!) : 'Deadline',
                              style: TextStyle(
                                fontSize: 12,
                                color: overdue ? AppColors.webDestructive : null,
                              ),
                            ),
                          ),
                          if (stage.deadline != null)
                            IconButton(
                              tooltip: 'Xoá deadline',
                              onPressed: () => onClearDeadline(key),
                              icon: const Icon(Icons.clear, size: 16),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: stage.progress / 100,
                          minHeight: 8,
                          backgroundColor: AppColors.webMutedBg,
                          color: barColor,
                        ),
                      ),
                      Slider(
                        value: stage.progress.toDouble().clamp(0, 100),
                        max: 100,
                        divisions: 20,
                        label: '${stage.progress}%',
                        activeColor: barColor,
                        onChanged: (v) => onProgressChanged(key, v),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
