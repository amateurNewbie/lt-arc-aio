import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Toast góc trên phải — dùng thay cho [SnackBar] mặc định (bottom).
void showAppToast(
  BuildContext context,
  String message, {
  bool error = false,
  Duration duration = const Duration(seconds: 3),
}) {
  if (!context.mounted) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  AppToast.show(overlay, message, error: error, duration: duration);
}

/// Hiện toast trên [overlay] (an toàn sau khi pop dialog).
void showAppToastOn(
  OverlayState overlay,
  String message, {
  bool error = false,
  Duration duration = const Duration(seconds: 3),
}) {
  AppToast.show(overlay, message, error: error, duration: duration);
}

/// Capture [Navigator]/[Overlay] **trước** `await` lưu — tránh mất route sau async gap
/// (invalidate Riverpod / rebuild) khiến popup không đóng dù lưu thành công.
class PendingDialogClose {
  PendingDialogClose._(this._navigator, this._overlay);

  factory PendingDialogClose.of(BuildContext context) {
    return PendingDialogClose._(
      Navigator.of(context, rootNavigator: true),
      Overlay.maybeOf(context, rootOverlay: true),
    );
  }

  final NavigatorState _navigator;
  final OverlayState? _overlay;

  /// Đóng dialog/sheet rồi toast (thành công hoặc lỗi).
  void popThenToast(String message, {bool error = false}) {
    if (_navigator.canPop()) {
      _navigator.pop();
    }
    final overlay = _overlay;
    if (overlay == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppToast.show(overlay, message, error: error);
    });
  }

  /// Đóng dialog/sheet rồi toast thành công (góc trên phải).
  void success(String message) => popThenToast(message);
}

/// Đóng dialog/sheet hiện tại rồi toast góc trên phải.
///
/// Ưu tiên [PendingDialogClose.of] trước `await` rồi gọi [PendingDialogClose.success].
void popDialogAndToast(BuildContext context, String message, {bool error = false}) {
  if (!context.mounted) return;
  PendingDialogClose.of(context).popThenToast(message, error: error);
}

class AppToast {
  AppToast._();

  static OverlayEntry? _current;
  static Timer? _timer;

  static void show(
    OverlayState overlay,
    String message, {
    bool error = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    dismiss();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        final top = MediaQuery.paddingOf(ctx).top + 16;
        return Positioned(
          top: top,
          right: 16,
          child: _ToastCard(
            message: message,
            error: error,
            onClose: dismiss,
          ),
        );
      },
    );
    _current = entry;
    overlay.insert(entry);
    _timer = Timer(duration, dismiss);
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _current?.remove();
    _current = null;
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({required this.message, required this.error, required this.onClose});

  final String message;
  final bool error;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final bg = error ? AppColors.webDestructive : AppColors.webForeground;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      color: bg,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 240, maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(error ? Icons.error_outline : Icons.check_circle_outline, size: 18, color: Colors.white),
              const SizedBox(width: 10),
              Flexible(
                child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.3)),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onClose,
                child: const Icon(Icons.close, size: 16, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
