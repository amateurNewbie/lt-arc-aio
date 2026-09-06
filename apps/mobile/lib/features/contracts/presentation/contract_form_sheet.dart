import 'package:flutter/material.dart';

import 'contract_create_form.dart';

/// Dialog tạo HĐ từ tab chi tiết dự án — dùng chung form HTML mock.
Future<void> showContractFormSheet(BuildContext context, String projectId) {
  return showDialog(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 720),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: ContractCreateForm(
              fixedProjectId: projectId,
              onCancel: () => Navigator.of(ctx).pop(),
              onCreated: (_) => Navigator.of(ctx).pop(),
            ),
          ),
        ),
      ),
    ),
  );
}
