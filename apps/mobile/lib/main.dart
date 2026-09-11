import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Web chưa cấu hình Firebase (VAPID key) — push chỉ dành cho Android/iOS
  // (xem `push_notification_provider.dart`). Lỗi init (native chưa wiring
  // xong ở Phase 4/5) không được chặn app khởi động.
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
    } catch (_) {}
  }

  runApp(const ProviderScope(child: App()));
}
