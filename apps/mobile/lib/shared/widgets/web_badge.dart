import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Pill nhãn trạng thái — tương ứng `.badge-*` trong LT-ARC-Web-UI_3.html.
/// Đọc màu theo theme hiện tại ([LtArcColors]) — tự đổi sáng/tối theo
/// `webThemeModeProvider`. Chỉ dùng cho Web (Mobile có ngôn ngữ hình ảnh riêng).
enum WebBadgeVariant { primary, secondary, success, warning, destructive, outline, muted }

class WebBadge extends StatelessWidget {
  const WebBadge(this.label, {super.key, this.variant = WebBadgeVariant.outline});

  final String label;
  final WebBadgeVariant variant;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    Gradient? gradient;
    Color bg = Colors.transparent;
    Color fg = c.fg;
    Color? border;

    switch (variant) {
      case WebBadgeVariant.primary:
        gradient = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c.goldBright, c.gold]);
        fg = c.primaryFg;
      case WebBadgeVariant.secondary:
        bg = c.secondary;
        fg = c.secondaryFg;
      case WebBadgeVariant.success:
        bg = c.successSoft;
        fg = c.success;
        border = c.successBorder;
      case WebBadgeVariant.warning:
        bg = c.warningSoft;
        fg = c.warning;
        border = c.warningBorder;
      case WebBadgeVariant.destructive:
        bg = c.destructiveSoft;
        fg = c.destructive;
        border = c.destructiveBorder;
      case WebBadgeVariant.muted:
        bg = c.muted;
        fg = c.mutedFg;
      case WebBadgeVariant.outline:
        fg = c.mutedFg;
        border = c.border;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: gradient == null ? bg : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(6),
        border: border != null ? Border.all(color: border) : null,
      ),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.4)),
    );
  }
}
