import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/pay_profile_provider.dart';
import 'pay_profile_form_sheet.dart';

/// FR-16.5 — chức danh lương (đơn giá ngày + phụ cấp mặc định).
class PayProfilesTab extends ConsumerWidget {
  const PayProfilesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(payProfileListProvider);
    final currency = NumberFormat.decimalPattern('vi');

    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: () => showPayProfileFormSheet(context), child: const Icon(Icons.add)),
      body: profilesAsync.when(
        data: (profiles) {
          if (profiles.isEmpty) return const Center(child: Text('Chưa có chức danh lương nào'));
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: profiles.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final profile = profiles[index];
              return Card(
                child: ListTile(
                  title: Text(profile.roleTitle, style: TextStyle(color: profile.active ? null : Theme.of(context).disabledColor)),
                  subtitle: Text('${profile.allowances.length} phụ cấp${profile.active ? '' : ' · Đã ẩn'}'),
                  trailing: Text('${currency.format(profile.dailyRate)} ₫/ngày', style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => showPayProfileFormSheet(context, profile: profile),
                  onLongPress: () => ref.read(payProfileActionsProvider.notifier).update(profile.id, active: !profile.active),
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
