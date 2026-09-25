import 'dart:convert';
import 'dart:io';

import 'package:carcare_service/core/services/notification_router.dart';
import 'package:carcare_service/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channelId = 'carcare_default';
  static const _channelName = 'CarCare мэдэгдэл';

  Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);

    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: _onTap,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(_channelId, _channelName, importance: Importance.high),
        );

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // Tap while the app is backgrounded (not terminated).
    FirebaseMessaging.onMessageOpenedApp.listen((m) => NotificationRouter.route(m.data));

    // Tap that cold-started the app from terminated state.
    final initial = await _messaging.getInitialMessage();
    if (initial != null) NotificationRouter.route(initial.data);
  }

  Future<String?> getToken() async {
    if (!kIsWeb && Platform.isIOS) {
      final token = await _messaging.getAPNSToken();
      if (token == null) return 'simulator';
    }
    return _messaging.getToken();
  }

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  void _showForegroundNotification(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    _localNotifications.show(
      id: n.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _onTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        NotificationRouter.route(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // Ignore malformed payloads — tapping still opens the app.
    }
  }
}
