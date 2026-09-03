import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/lead_provider.dart';
import '../data/lead_repository.dart';
import 'lead_form_sheet.dart';

class LeadsPage extends ConsumerWidget {
  const LeadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leadsAsync = ref.watch(leadListProvider);
    final filter = ref.watch(leadFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Khách hàng tiềm năng')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showLeadFormSheet(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Tất cả'),
                    selected: filter.status == null,
                    onSelected: (_) => ref.read(leadFilterProvider.notifier).setStatus(null),
                  ),
                  const SizedBox(width: 8),
                  for (final status in LeadStatus.values) ...[
                    ChoiceChip(
                      label: Text(status.label),
                      selected: filter.status == status,
                      onSelected: (_) => ref.read(leadFilterProvider.notifier).setStatus(status),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: leadsAsync.when(
              data: (leads) {
                if (leads.isEmpty) {
                  return const Center(child: Text('Chưa có khách hàng tiềm năng nào'));
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(leadListProvider.future),
                  child: ListView.separated(
                    itemCount: leads.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final lead = leads[index];
                      return ListTile(
                        title: Text(lead.name),
                        subtitle: Text([if (lead.phone != null) lead.phone!, if (lead.need != null) lead.need!].join(' · ')),
                        trailing: Chip(label: Text(lead.status.label)),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Lỗi tải dữ liệu: $error')),
            ),
          ),
        ],
      ),
    );
  }
}
