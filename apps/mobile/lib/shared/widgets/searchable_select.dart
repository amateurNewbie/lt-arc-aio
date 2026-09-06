import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Item chọn được — id + nhãn hiển thị (tìm theo [label] và [searchText]).
class SearchableOption {
  const SearchableOption({required this.id, required this.label, this.searchText});

  final String id;
  final String label;
  final String? searchText;

  String get haystack => '${label.toLowerCase()} ${(searchText ?? '').toLowerCase()}';
}

InputDecoration _fieldDecoration({required String label, String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.webBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.webBorder)),
      filled: true,
      fillColor: Colors.white,
    );

/// Select 1 giá trị, tìm theo tên trong popup.
class SearchableSingleSelect extends StatelessWidget {
  const SearchableSingleSelect({
    super.key,
    required this.label,
    required this.options,
    required this.valueId,
    required this.onChanged,
    this.hint = 'Tìm theo tên...',
    this.allowClear = true,
    this.width,
  });

  final String label;
  final List<SearchableOption> options;
  final String? valueId;
  final ValueChanged<String?> onChanged;
  final String hint;
  final bool allowClear;
  final double? width;

  String get _display {
    if (valueId == null) return '';
    return options.where((o) => o.id == valueId).map((o) => o.label).firstOrNull ?? '';
  }

  Future<void> _open(BuildContext context) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => _SearchPickDialog(
        title: label,
        options: options,
        selectedId: valueId,
        hint: hint,
        allowClear: allowClear,
        multi: false,
      ),
    );
    if (!context.mounted) return;
    if (selected == null || selected == _SearchPickDialog.cancelled) return;
    if (selected == _SearchPickDialog.clearToken) {
      onChanged(null);
      return;
    }
    onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final child = InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(6),
      child: InputDecorator(
        decoration: _fieldDecoration(label: label, hint: hint).copyWith(
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (allowClear && valueId != null)
                IconButton(
                  tooltip: 'Xoá chọn',
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onChanged(null),
                ),
              const Icon(Icons.search, size: 18),
              const SizedBox(width: 8),
            ],
          ),
        ),
        child: Text(
          _display.isEmpty ? hint : _display,
          style: TextStyle(
            fontSize: 13,
            color: _display.isEmpty ? AppColors.webMutedFg : AppColors.webForeground,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
    return width == null ? child : SizedBox(width: width, child: child);
  }
}

/// Select nhiều giá trị, tìm theo tên; hiển thị chip đã chọn.
class SearchableMultiSelect extends StatelessWidget {
  const SearchableMultiSelect({
    super.key,
    required this.label,
    required this.options,
    required this.valueIds,
    required this.onChanged,
    this.hint = 'Tìm và chọn nhân viên...',
    this.width,
  });

  final String label;
  final List<SearchableOption> options;
  final Set<String> valueIds;
  final ValueChanged<Set<String>> onChanged;
  final String hint;
  final double? width;

  Future<void> _open(BuildContext context) async {
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => _SearchPickDialog(
        title: label,
        options: options,
        selectedIds: valueIds,
        hint: hint,
        multi: true,
      ),
    );
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final selectedOptions = options.where((o) => valueIds.contains(o.id)).toList();
    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(6),
          child: InputDecorator(
            decoration: _fieldDecoration(label: label, hint: hint).copyWith(
              suffixIcon: const Icon(Icons.person_search_outlined, size: 18),
            ),
            child: Text(
              selectedOptions.isEmpty ? hint : '${selectedOptions.length} người đã chọn — bấm để sửa',
              style: TextStyle(
                fontSize: 13,
                color: selectedOptions.isEmpty ? AppColors.webMutedFg : AppColors.webForeground,
              ),
            ),
          ),
        ),
        if (selectedOptions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final o in selectedOptions)
                InputChip(
                  label: Text(o.label, style: const TextStyle(fontSize: 12)),
                  onDeleted: () {
                    final next = {...valueIds}..remove(o.id);
                    onChanged(next);
                  },
                ),
            ],
          ),
        ],
      ],
    );
    return width == null ? child : SizedBox(width: width, child: child);
  }
}

class _SearchPickDialog extends StatefulWidget {
  const _SearchPickDialog({
    required this.title,
    required this.options,
    required this.hint,
    required this.multi,
    this.selectedId,
    this.selectedIds,
    this.allowClear = false,
  });

  static const cancelled = '__cancelled__';
  static const clearToken = '__clear__';

  final String title;
  final List<SearchableOption> options;
  final String hint;
  final bool multi;
  final String? selectedId;
  final Set<String>? selectedIds;
  final bool allowClear;

  @override
  State<_SearchPickDialog> createState() => _SearchPickDialogState();
}

class _SearchPickDialogState extends State<_SearchPickDialog> {
  final _query = TextEditingController();
  late Set<String> _picked;

  @override
  void initState() {
    super.initState();
    _picked = {...?widget.selectedIds};
    if (!widget.multi && widget.selectedId != null) {
      _picked = {widget.selectedId!};
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<SearchableOption> get _filtered {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return widget.options.where((o) => o.haystack.contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.hint,
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('Không tìm thấy', style: TextStyle(color: AppColors.webMutedFg)))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final opt = filtered[index];
                        final selected = _picked.contains(opt.id);
                        if (widget.multi) {
                          return CheckboxListTile(
                            dense: true,
                            value: selected,
                            title: Text(opt.label, style: const TextStyle(fontSize: 13)),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _picked.add(opt.id);
                              } else {
                                _picked.remove(opt.id);
                              }
                            }),
                          );
                        }
                        return ListTile(
                          dense: true,
                          selected: selected,
                          title: Text(opt.label, style: const TextStyle(fontSize: 13)),
                          trailing: selected ? const Icon(Icons.check, size: 18) : null,
                          onTap: () => Navigator.of(context).pop(opt.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        if (!widget.multi && widget.allowClear)
          TextButton(
            onPressed: () => Navigator.of(context).pop(_SearchPickDialog.clearToken),
            child: const Text('Bỏ chọn'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(widget.multi ? null : _SearchPickDialog.cancelled),
          child: const Text('Huỷ'),
        ),
        if (widget.multi)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(Set<String>.from(_picked)),
            child: const Text('Xác nhận'),
          ),
      ],
    );
  }
}
