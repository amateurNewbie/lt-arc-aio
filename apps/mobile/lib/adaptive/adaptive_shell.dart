import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'mobile_shell.dart';
import 'web_shell.dart';

/// LT ARC dùng 2 nhận diện khác nhau cho Web và app di động (không phải cùng
/// 1 theme co giãn theo bề rộng) — xem plan §6.2.
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({super.key});

  @override
  Widget build(BuildContext context) {
    return kIsWeb ? const WebShell() : const MobileShell();
  }
}
