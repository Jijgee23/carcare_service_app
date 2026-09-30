import 'package:carservice_business/core/domain/user.dart';
import 'package:carservice_business/core/network/working_branch_interceptor.dart';
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
    // The working branch lasts until the user switches it or signs out.
    await HiveWorkingBranchSelectionStore().clear();
  }

  static void Function()? onUnauthorized;

  /// Set by `AuthController.loadUser()`. Fired when a silent `account_closed`
  /// data push arrives (deactivation/deletion, including from the website) —
  /// `deleted` distinguishes the two toast messages.
  static void Function({required bool deleted})? onAccountClosed;

  /// True while `AccountClosureController.submit` is closing this device's
  /// own account. The backend sends the `account_closed` push right after
  /// its DB transaction commits but *before* the closure HTTP response
  /// returns, so this device can receive its own push while `submit` is
  /// still awaiting that response. `AuthController.handleRemoteAccountClosed`
  /// checks this and no-ops while it's true — `submit` already owns the
  /// sign-out and its own toast for that case, and letting the push handler
  /// run concurrently would sign out twice and show two toasts.
  static bool accountClosureInFlight = false;
}
