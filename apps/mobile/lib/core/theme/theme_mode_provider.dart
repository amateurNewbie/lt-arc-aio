import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/secure_storage.dart';

part 'theme_mode_provider.g.dart';

/// FR-theme — sáng/tối cho các trang Web đã migrate sang [LtArcColors]
/// (xem kế hoạch 4 giai đoạn). Mặc định SÁNG trong lúc migrate dở: bật tối
/// lúc này sẽ làm ~33 trang Web chưa migrate (còn dùng `AppColors.web*` tĩnh)
/// hiển thị sai màu. Đổi mặc định sang tối sau khi Giai đoạn 3 hoàn tất.
@Riverpod(keepAlive: true)
class WebThemeMode extends _$WebThemeMode {
  @override
  ThemeMode build() {
    _restore();
    return ThemeMode.light;
  }

  Future<void> _restore() async {
    final saved = await SecureStorage.readThemeMode();
    if (saved == 'dark' && ref.mounted) state = ThemeMode.dark;
  }

  Future<void> toggle() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    await SecureStorage.saveThemeMode(next == ThemeMode.dark ? 'dark' : 'light');
  }
}
