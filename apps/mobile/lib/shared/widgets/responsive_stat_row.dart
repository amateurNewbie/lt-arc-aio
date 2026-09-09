import 'package:flutter/material.dart';

/// Xếp các thẻ KPI (`_StatCard`...) thành 1 hàng co giãn đều khi đủ rộng
/// (Web), tự chia 2 cột khi màn hình hẹp (Mobile) — tránh chữ bị vỡ từng ký
/// tự khi 4+ thẻ bị ép co lại `Expanded` trong 1 hàng quá hẹp. Dùng cho các
/// trang dùng chung layout Web/Mobile (không tách riêng `_web_page.dart`),
/// vd. Tài chính, Công nợ, Nhân sự, Hợp đồng.
class ResponsiveStatRow extends StatelessWidget {
  const ResponsiveStatRow({super.key, required this.children, this.breakpoint = 700, this.spacing = 12});

  final List<Widget> children;
  final double breakpoint;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= breakpoint) {
          return Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(width: spacing),
                Expanded(child: children[i]),
              ],
            ],
          );
        }

        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += 2) {
          final hasSecond = i + 1 < children.length;
          if (i > 0) rows.add(SizedBox(height: spacing));
          rows.add(
            Row(
              children: [
                Expanded(child: children[i]),
                if (hasSecond) ...[SizedBox(width: spacing), Expanded(child: children[i + 1])],
              ],
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}
