import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_provider.dart';
import 'notification_provider.dart';

part 'push_notification_provider.g.dart';

const _androidChannel = AndroidNotificationChannel(
  'default_channel',
  'Thông báo chung',
  description: 'Thông báo real-time từ LT ARC',
  importance: Importance.high,
);

final _localNotifications = FlutterLocalNotificationsPlugin();

/// Chạy trong isolate riêng khi app ở background/terminated — isolate này
/// không kế thừa Firebase đã init ở isolate chính nên phải tự khởi tạo lại.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> _showLocalNotification(RemoteMessage message) async {
  final notification = message.notification;
  if (notification == null) return;
  await _localNotifications.show(
    notification.hashCode,
    notification.title,
    notification.body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannel.id,
        _androidChannel.name,
        channelDescription: _androidChannel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    ),
  );
}

/// FCM cho Android/iOS. Không chạy trên Web (Firebase Web/VAPID key nằm
/// ngoài phạm vi hiện tại). Được khởi tạo 1 lần khi app mở qua
/// `ref.watch(pushNotificationsProvider)` trong `App.build` — tự đăng ký
/// token khi đăng nhập, tự bỏ qua nếu native chưa wiring xong (Phase 4).
@Riverpod(keepAlive: true)
class PushNotifications extends _$PushNotifications {
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;
  StreamSubscription<String>? _tokenRefreshSub;

  @override
  void build() {
    if (kIsWeb) return;

    ref.onDispose(() {
      _foregroundSub?.cancel();
      _openedAppSub?.cancel();
      _tokenRefreshSub?.cancel();
    });

    unawaited(_init());

    ref.listen(authProvider, (previous, next) {
      final wasLoggedIn = previous?.value != null;
      final isLoggedIn = next.value != null;
      if (isLoggedIn && !wasLoggedIn) unawaited(_registerToken());
    });
  }

  Future<void> _init() async {
    try {
      await FirebaseMessaging.instance.requestPermission();

      await _localNotifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (_) => _handleTap(),
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
        unawaited(_showLocalNotification(message));
        if (ref.mounted) ref.invalidate(notificationListProvider);
      });
      _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((_) => _handleTap());
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((_) => unawaited(_registerToken()));

      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) _handleTap();

      if (ref.read(authProvider).value != null) {
        await _registerToken();
      }
    } catch (_) {
      // Best-effort — native Android/iOS chưa wiring xong (Phase 4/5) không
      // được phép làm crash app; tính năng push chỉ hoạt động sau khi wiring.
    }
  }

  void _handleTap() {
    if (ref.mounted) ref.invalidate(notificationListProvider);
    // TODO Phase 3.1 — app hiện chỉ có 2 route go_router (/login, /home),
    // phần còn lại điều hướng bằng Navigator lồng trong AdaptiveShell nên
    // chưa deep-link được thẳng tới task/lead theo entity_id. Tạm thời tap
    // vào push chỉ đưa app lên foreground + refresh danh sách thông báo.
  }

  Future<void> _registerToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';
      await ref.read(notificationRepositoryProvider).registerDevice(fcmToken: token, platform: platform);
    } catch (_) {
      // best-effort — lỗi đăng ký token không được chặn luồng đăng nhập.
    }
  }
}
