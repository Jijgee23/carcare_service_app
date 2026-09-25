import 'dart:io';
import 'dart:math' as math;

import 'package:carcare_service/core/network/api_client.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class DeviceService {
  DeviceService._();
  static final DeviceService instance = DeviceService._();

  static const _boxName = 'device';
  static const _idKey = 'device_id';

  Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  String get _deviceId {
    final box = Hive.box(_boxName);
    var id = box.get(_idKey) as String?;
    if (id == null) {
      final rng = math.Random();
      final bytes = List.generate(16, (_) => rng.nextInt(256));
      id = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      box.put(_idKey, id);
    }
    return id;
  }

  String get _platform {
    if (kIsWeb) return 'WEB';
    if (Platform.isAndroid) return 'ANDROID';
    if (Platform.isIOS) return 'IOS';
    return 'WEB';
  }

  /// Login хийсэн дараа дуудна — FCM token авч серверт бүртгэнэ.
  Future<void> registerAfterLogin() async {
    final token = await NotificationService.instance.getToken();
    await _register(token);
  }

  /// FCM token шинэчлэгдэхэд дуудна.
  Future<void> updateToken(String fcmToken) async {
    if (Authenticator.user == null) return;
    await _register(fcmToken);
  }

  Future<bool> unregister() async {
    try {
      await api(Api.delete, 'devices/$_deviceId');
      if (BindingBase.debugZoneErrorsAreFatal) {
        debugPrint('DeviceService.unregister: $_deviceId');
      }
      return true;
    } catch (e) {
      debugPrint('DeviceService.unregister error: $e');
      return false;
    }
  }

  Future<void> _register(String? fcmToken) async {
    try {
      await api(
        Api.post,
        'devices',
        body: {'deviceId': _deviceId, 'platform': _platform, 'firebaseToken': ?fcmToken},
      );
    } catch (e) {
      debugPrint('DeviceService.registerAfterLogin error: $e');
    }
  }
}
