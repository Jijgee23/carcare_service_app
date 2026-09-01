import 'package:carcare_service/features/models/user.dart';
import 'package:hive_flutter/hive_flutter.dart';

class Authenticator {
  static const _box = 'auth';
  static const _key = 'user';

  static Future<void> init() async {
    Hive.registerAdapter(UserAdapter());
    try {
      await Hive.openBox<User>(_box);
    } catch (_) {
      await Hive.deleteBoxFromDisk(_box);
      await Hive.openBox<User>(_box);
    }
  }

  static User? get user => Hive.box<User>(_box).get(_key);

  static set user(User? u) {
    final box = Hive.box<User>(_box);
    if (u == null) {
      box.delete(_key);
    } else {
      box.put(_key, u);
    }
  }

  static Future<void> clear() async {
    await Hive.box<User>(_box).delete(_key);
  }

  static void Function()? onUnauthorized;
}
