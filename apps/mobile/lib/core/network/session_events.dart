import 'dart:async';

/// Phát sự kiện khi API trả 401 (token hết hạn / không hợp lệ).
class SessionEvents {
  SessionEvents._();
  static final instance = SessionEvents._();

  final _controller = StreamController<void>.broadcast();
  Stream<void> get unauthorized => _controller.stream;

  void notifyUnauthorized() {
    if (!_controller.isClosed) _controller.add(null);
  }
}
