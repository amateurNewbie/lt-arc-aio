import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Pill nhãn trạng thái — tương ứng `.badge-*` trong LT-ARC-Web-UI_1.html.
/// Dùng cho mọi trang Web cần hiển thị trạng thái/tag (không dùng cho Mobile,
/// vốn có ngôn ngữ hình ảnh riêng theo LT-ARC-Mobile-UI_1.html).
enum WebBadgeVariant { primary, secondary, success, warning, destructive, outline, muted }

class WebBadge extends StatelessWidget {
  const WebBadge(this.label, {super.key, this.variant = WebBadgeVariant.outline});

  final String label;
  final WebBadgeVariant variant;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Color? border) = switch (variant) {
      WebBadgeVariant.primary => (AppColors.webForeground, Colors.white, null),
      WebBadgeVariant.secondary => (AppColors.webSecondaryBg, AppColors.webSecondaryFg, null),
      WebBadgeVariant.success => (AppColors.webSuccess, Colors.white, null),
      WebBadgeVariant.warning => (AppColors.webWarning, AppColors.webWarningFg, null),
      WebBadgeVariant.destructive => (AppColors.webDestructive, Colors.white, null),
      WebBadgeVariant.muted => (AppColors.webMutedBg, AppColors.webMutedFg, null),
      WebBadgeVariant.outline => (Colors.transparent, AppColors.webForeground, AppColors.webBorder),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: border != null ? Border.all(color: border) : null,
      ),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.4)),
    );
  }
}
